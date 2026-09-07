import 'package:dio/dio.dart';

import '../../const/config.dart';
import '../enums/result.dart';

class ConfigProvider {
  static late Dio _dio;

  static void init() {
    _dio = Dio();

    _dio.options.headers = {
      "user-agent":
          "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.5672.76 Mobile Safari/537.36",
    };
  }

  static Future<ApiResult<String>> getLatestVersion() async {
    String? message;
    String? data;
    try {
      final response = await _dio.get(ConfigConst.checkUpdateUrl);
      final releases = response.data;
      if (releases is List && releases.isNotEmpty) {
        data = releases[0]["tag_name"];
      } else {
        message = "No releases found";
      }
    } catch (e) {
      message = e.toString();
    }
    return ApiResult(data: data, message: message, success: message == null);
  }
}
