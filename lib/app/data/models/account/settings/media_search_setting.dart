import '../../../enums/types.dart';

class MediaSearchSettingModel {
  final OrderType orderType;
  final SearchType searchType;
  String keyword;

  MediaSearchSettingModel({
    required this.orderType,
    required this.searchType,
    required this.keyword,
  });
}
