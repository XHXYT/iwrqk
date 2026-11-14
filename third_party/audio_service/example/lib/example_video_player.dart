/*
* Copyright (c) 2024 SwanLink (Jiangsu) Technology Development Co., LTD.
* Licensed under the Apache License, Version 2.0
*/

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

late AudioPlayerHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ryanheise.myapp.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Service Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() {
    _controller = VideoPlayerController.asset(
      'assets/video2.mp4',
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
    )..initialize().then((_) {
      if (!mounted) return;

      _audioHandler.setVideoFunctions(
        _controller.play,
        _controller.pause,
        _controller.seekTo,
            () {
          _controller.seekTo(Duration.zero);
          _controller.pause();
        },
      );

      // 初始化 StreamController 并连接到 playbackState
      _audioHandler.initializeStreamController(_controller);

      // 确保 playbackState 有初始值
      _audioHandler.playbackState.add(_audioHandler.getCurrentPlaybackState());

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioHandler.disposeHandler();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Service Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildVideoPlayer(),
            _buildPlaybackControls(),
            _buildProcessingState(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Center(
      child: _isInitialized && _controller.value.isInitialized
          ? AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      )
          : const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return StreamBuilder<bool>(
      stream: _audioHandler.playbackState
          .map((state) => state.playing)
          .distinct(),
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildButton(Icons.fast_rewind, _audioHandler.rewind),
            if (playing)
              _buildButton(Icons.pause, _audioHandler.pause)
            else
              _buildButton(Icons.play_arrow, _audioHandler.play),
            _buildButton(Icons.stop, _audioHandler.stop),
            _buildButton(Icons.fast_forward, _audioHandler.fastForward),
          ],
        );
      },
    );
  }

  Widget _buildProcessingState() {
    return StreamBuilder<AudioProcessingState>(
      stream: _audioHandler.playbackState
          .map((state) => state.processingState)
          .distinct(),
      builder: (context, snapshot) {
        final processingState = snapshot.data ?? AudioProcessingState.idle;
        return Text('Processing state: $processingState');
      },
    );
  }

  IconButton _buildButton(IconData iconData, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(iconData),
      iconSize: 64.0,
      onPressed: onPressed,
    );
  }
}

class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  StreamController<PlaybackState>? _streamController;
  bool stopIsClick = false;
  bool _isDisposed = false;
  VideoPlayerController? _currentController;

  static final MediaItem _item = MediaItem(
    id: 'video1.mp4',
    album: 'video1.mp4',
    title: 'video1.mp4',
    artist: 'Science Friday and WNYC Studios',
    duration: const Duration(milliseconds: 29024),
    artUri: Uri.parse(
      'https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg',
    ),
    extras: const {'mediaType': 'video'},
  );

  Function? _videoPlay;
  Function? _videoPause;
  Function? _videoSeek;
  Function? _videoStop;
  VoidCallback? _videoListener;

  void setVideoFunctions(
      Function play,
      Function pause,
      Function seek,
      Function stop) {
    _videoPlay = play;
    _videoPause = pause;
    _videoSeek = seek;
    _videoStop = stop;
    mediaItem.add(_item);
  }

  AudioPlayerHandler();

  @override
  Future<void> play() async {
    if (_isDisposed) return;
    stopIsClick = false;
    if (_videoPlay != null) {
      await _videoPlay!();
      // 播放后立即更新状态
      _updatePlaybackState();
    }
  }

  @override
  Future<void> pause() async {
    if (_isDisposed) return;
    if (_videoPause != null) {
      await _videoPause!();
      // 暂停后立即更新状态
      _updatePlaybackState();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;
    if (_videoSeek != null) {
      await _videoSeek!(position);
      _updatePlaybackState();
    }
  }

  @override
  Future<void> stop() async {
    if (_isDisposed) return;
    stopIsClick = true;
    if (_videoStop != null) {
      _videoStop!();
      _updatePlaybackState();
    }
  }

  // 获取当前播放状态
  PlaybackState getCurrentPlaybackState() {
    final isPlaying = _currentController?.value.isPlaying ?? false;
    final isInitialized = _currentController?.value.isInitialized ?? false;
    final position = _currentController?.value.position ?? Duration.zero;
    final duration = _currentController?.value.duration;

    AudioProcessingState processingState;
    if (!isInitialized) {
      processingState = AudioProcessingState.idle;
    } else if (stopIsClick) {
      // 用户点击了停止按钮
      processingState = AudioProcessingState.idle;
    } else if (duration != null &&
        position >= duration &&
        duration > Duration.zero) {
      // 视频播放结束
      processingState = AudioProcessingState.completed;
    } else {
      processingState = AudioProcessingState.ready;
    }

    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      processingState: processingState,
      playing: isPlaying,
      updatePosition: _currentController?.value.position ?? Duration.zero,
      bufferedPosition: _currentController?.value.duration ?? Duration.zero,
      speed: _currentController?.value.playbackSpeed ?? 1.0,
    );
  }

  void _updatePlaybackState() {
    if (_isDisposed) return;
    final state = getCurrentPlaybackState();

    // 同时更新两个流
    if (_streamController != null && !_streamController!.isClosed) {
      _streamController!.add(state);
    }
    playbackState.add(state);
  }

  void initializeStreamController(VideoPlayerController? videoPlayerController) {
    // 保存控制器引用
    _currentController = videoPlayerController;

    // 如果已经存在，先清理旧的
    _disposeCurrentController();

    void _onVideoEvent() {
      if (_isDisposed) return;
      _updatePlaybackState();
    }

    // 保存监听器引用以便移除
    _videoListener = _onVideoEvent;

    void startStream() {
      if (_isDisposed) return;
      videoPlayerController?.addListener(_onVideoEvent);
      // 发送初始状态
      _updatePlaybackState();
    }

    void stopStream() {
      if (_videoListener != null) {
        videoPlayerController?.removeListener(_videoListener!);
      }
    }

    _streamController = StreamController<PlaybackState>(
      onListen: startStream,
      onPause: stopStream,
      onResume: startStream,
      onCancel: () {
        stopStream();
        if (_streamController != null && !_streamController!.isClosed) {
          _streamController!.close();
        }
      },
    );
  }

  void _disposeCurrentController() {
    // 移除监听器
    if (_videoListener != null && _currentController != null) {
      _currentController!.removeListener(_videoListener!);
    }

    // 关闭并清理 StreamController
    if (_streamController != null) {
      if (!_streamController!.isClosed) {
        _streamController!.close();
      }
      _streamController = null;
    }

    _videoListener = null;
  }

  void disposeHandler() {
    _isDisposed = true;
    _disposeCurrentController();
    _videoPlay = null;
    _videoPause = null;
    _videoSeek = null;
    _videoStop = null;
    _currentController = null;
  }

  Stream<PlaybackState>? get stream => _streamController?.stream;
}