import {
  FlutterAbility,
  FlutterEngine,
  MethodChannel,
  MethodCall,
  MethodResult,
} from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { picker, fileUri } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'IwrqkDownload';
const DOMAIN: number = 0x0000;
const CHANNEL_NAME: string = 'iwrqk/download_path';
const PREFERENCES_NAME: string = 'download_settings';
const PREF_KEY_URI: string = 'downloadDirUri';

export default class EntryAbility extends FlutterAbility {
  // 进程内缓存授权拿到的目录 URI，持久化兜底在 preferences
  private downloadDirUri: string = '';

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    const channel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      CHANNEL_NAME,
    );
    channel.setMethodCallHandler({
      onMethodCall: (call: MethodCall, result: MethodResult) => {
        if (call.method === 'getDownloadDir') {
          this.getDownloadDir()
            .then((path: string) => {
              result.success(path);
            })
            .catch((err: BusinessError) => {
              hilog.error(DOMAIN, TAG, `getDownloadDir failed: ${err.code} ${err.message}`);
              result.error('DOWNLOAD_DIR_ERROR', err.message, null);
            });
        } else if (call.method === 'moveFile') {
          this.moveFile(call.argument('srcPath'), call.argument('fileName'))
            .then((path: string) => {
              result.success(path);
            })
            .catch((err: BusinessError) => {
              hilog.error(DOMAIN, TAG, `moveFile failed: ${err.code} ${err.message}`);
              result.error('MOVE_FILE_ERROR', err.message, null);
            });
        } else {
          result.notImplemented();
        }
      },
    });
  }

  /**
   * 获取公共下载目录（下载/应用名），首次调用弹系统授权框，URI 持久化，
   * 之后调用直接返回缓存路径，不再弹框
   */
  private async getDownloadDir(): Promise<string> {
    const context = this.context as common.UIAbilityContext;

    if (this.downloadDirUri === '') {
      const dataPreferences =
        await preferences.getPreferences(context, PREFERENCES_NAME);
      this.downloadDirUri =
        (await dataPreferences.get(PREF_KEY_URI, '')) as string;
    }

    if (this.downloadDirUri === '') {
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
      const documentViewPicker = new picker.DocumentViewPicker(context);
      const uris: Array<string> =
        await documentViewPicker.save(documentSaveOptions);
      if (uris.length === 0) {
        // 用户取消授权，不是错误，走统一的 error 回调由 Dart 侧判 null
        throw new Error('user canceled download dir authorization');
      }
      this.downloadDirUri = uris[0];
      const dataPreferences =
        await preferences.getPreferences(context, PREFERENCES_NAME);
      await dataPreferences.put(PREF_KEY_URI, this.downloadDirUri);
      await dataPreferences.flush();
    }

    // URI 持久化后可能因卸载重装失效，写文件失败时由 moveFile 侧感知，
    // 这里只负责把 URI 换成可操作的真实路径
    return new fileUri.FileUri(this.downloadDirUri).path;
  }

  /**
   * 把沙箱内下载完成的文件移动到公共下载目录
   */
  private async moveFile(srcPath: string, fileName: string): Promise<string> {
    const dirPath = await this.getDownloadDir();
    let destPath = `${dirPath}/${fileName}`;

    // 避免覆盖同名文件：存在则追加序号
    if (fs.accessSync(destPath)) {
      const dotIndex = fileName.lastIndexOf('.');
      const baseName =
        dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
      const ext = dotIndex > 0 ? fileName.substring(dotIndex) : '';
      let seq = 1;
      do {
        destPath = `${dirPath}/${baseName}(${seq})${ext}`;
        seq++;
      } while (fs.accessSync(destPath));
    }

    await fs.moveFile(srcPath, destPath);
    hilog.info(DOMAIN, TAG, `moved to ${destPath}`);
    return destPath;
  }
}
