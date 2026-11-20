import 'search_filter.dart';

/// Which search tab the filters apply to.
enum SearchSegment { videos, images, users, threads }

/// Filterable fields per segment, mirroring the official web client.
class SearchFilterConfig {
  const SearchFilterConfig._();

  static const List<SearchFilterField> _videoFields = [
    SearchFilterField("title", FilterFieldType.string),
    SearchFilterField("body", FilterFieldType.string, labelKey: "body"),
    SearchFilterField("tags", FilterFieldType.stringArray),
    SearchFilterField("author", FilterFieldType.string),
    SearchFilterField("date", FilterFieldType.date),
    SearchFilterField("private", FilterFieldType.boolean),
    SearchFilterField("duration", FilterFieldType.number),
    SearchFilterField("likes", FilterFieldType.number),
    SearchFilterField("views", FilterFieldType.number),
    SearchFilterField("comments", FilterFieldType.number),
    SearchFilterField("rating", FilterFieldType.select),
  ];

  static const List<SearchFilterField> _imageFields = [
    SearchFilterField("title", FilterFieldType.string),
    SearchFilterField("author", FilterFieldType.string),
    SearchFilterField("tags", FilterFieldType.stringArray),
    SearchFilterField("date", FilterFieldType.date),
    SearchFilterField("views", FilterFieldType.number),
    SearchFilterField("comments", FilterFieldType.number),
    SearchFilterField("images", FilterFieldType.number, labelKey: "imageCount"),
    SearchFilterField("likes", FilterFieldType.number),
    SearchFilterField("body", FilterFieldType.string, labelKey: "body"),
    SearchFilterField("rating", FilterFieldType.select),
  ];

  static const List<SearchFilterField> _userFields = [
    SearchFilterField("username", FilterFieldType.string),
    SearchFilterField("name", FilterFieldType.string, labelKey: "nickname"),
    SearchFilterField("date", FilterFieldType.date, labelKey: "registrationDate"),
    SearchFilterField("body", FilterFieldType.string, labelKey: "body"),
  ];

  static const List<SearchFilterField> _threadFields = [
    SearchFilterField("title", FilterFieldType.string),
    SearchFilterField("author", FilterFieldType.string),
    SearchFilterField("date", FilterFieldType.date),
  ];

  static List<SearchFilterField> fieldsFor(SearchSegment segment) {
    switch (segment) {
      case SearchSegment.videos:
        return _videoFields;
      case SearchSegment.images:
        return _imageFields;
      case SearchSegment.users:
        return _userFields;
      case SearchSegment.threads:
        return _threadFields;
    }
  }

  static SearchFilterField? findField(SearchSegment segment, String name) {
    for (final field in fieldsFor(segment)) {
      if (field.name == name) return field;
    }
    return null;
  }

  static List<FilterOperator> operatorsFor(FilterFieldType type) {
    switch (type) {
      case FilterFieldType.string:
        return [
          FilterOperator.contains,
          FilterOperator.equals,
          FilterOperator.notEquals,
        ];
      case FilterFieldType.number:
      case FilterFieldType.date:
        return [
          FilterOperator.equals,
          FilterOperator.notEquals,
          FilterOperator.greaterThan,
          FilterOperator.greaterEqual,
          FilterOperator.lessThan,
          FilterOperator.lessEqual,
          FilterOperator.range,
        ];
      case FilterFieldType.boolean:
        return [FilterOperator.equals];
      case FilterFieldType.stringArray:
        return [FilterOperator.inOp, FilterOperator.notIn];
      case FilterFieldType.select:
        return [FilterOperator.equals, FilterOperator.notEquals];
    }
  }

  static FilterOperator defaultOperatorFor(FilterFieldType type) {
    switch (type) {
      case FilterFieldType.string:
        return FilterOperator.contains;
      case FilterFieldType.stringArray:
        return FilterOperator.inOp;
      case FilterFieldType.date:
        return FilterOperator.range;
      case FilterFieldType.number:
        return FilterOperator.greaterEqual;
      case FilterFieldType.boolean:
      case FilterFieldType.select:
        return FilterOperator.equals;
    }
  }

  /// Options for the `rating` select field. Empty value means "all" (no filter).
  static const List<(String, String)> ratingOptions = [
    ("", "all"),
    ("ecchi", "ecchi"),
    ("general", "general"),
  ];
}
