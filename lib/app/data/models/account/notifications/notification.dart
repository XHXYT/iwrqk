import '../../user.dart';

class NotificationItemModel {
  String id;
  String type;
  bool read;
  String createdAt;
  NotificationCommentModel? comment;
  NotificationDocumentModel? video;
  NotificationDocumentModel? image;
  NotificationDocumentModel? profile;
  NotificationDocumentModel? post;
  NotificationDocumentModel? tag;

  NotificationItemModel({
    required this.id,
    required this.type,
    required this.read,
    required this.createdAt,
    this.comment,
    this.video,
    this.image,
    this.profile,
    this.post,
    this.tag,
  });

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      createdAt: json['createdAt'] as String? ?? '',
      comment: json['comment'] != null
          ? NotificationCommentModel.fromJson(json['comment'])
          : null,
      video: json['video'] != null
          ? NotificationDocumentModel.fromJson(json['video'])
          : null,
      image: json['image'] != null
          ? NotificationDocumentModel.fromJson(json['image'])
          : null,
      profile: json['profile'] != null
          ? NotificationDocumentModel.fromJson(json['profile'])
          : null,
      post: json['post'] != null
          ? NotificationDocumentModel.fromJson(json['post'])
          : null,
      tag: json['tag'] != null
          ? NotificationDocumentModel.fromJson(json['tag'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'read': read,
      'createdAt': createdAt,
      'comment': comment?.toJson(),
      'video': video?.toJson(),
      'image': image?.toJson(),
      'profile': profile?.toJson(),
      'post': post?.toJson(),
      'tag': tag?.toJson(),
    };
  }
}

class NotificationCommentModel {
  UserModel user;
  String body;

  NotificationCommentModel({required this.user, required this.body});

  factory NotificationCommentModel.fromJson(Map<String, dynamic> json) {
    return NotificationCommentModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      body: json['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'user': user.toJson(), 'body': body};
  }
}

class NotificationDocumentModel {
  String id;
  String? title;
  String? username;

  NotificationDocumentModel({required this.id, this.title, this.username});

  factory NotificationDocumentModel.fromJson(Map<String, dynamic> json) {
    return NotificationDocumentModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String?,
      username: json['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'username': username};
  }
}
