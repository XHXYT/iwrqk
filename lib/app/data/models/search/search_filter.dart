/// Iwara search filter models.
///
/// Filters are not separate API params: they are composed into the `query`
/// string with the `{field{op}value}` syntax (AND-ed with the keyword).
/// Syntax reverse-engineered by LoveIwara (tested against api.iwara.tv):
/// - `{field: value}` contains
/// - `{field=value}` / `{field!=value}` equals / not equals
/// - `{field>v}` `{field>=v}` `{field<v}` `{field<=v}` comparisons
/// - `{field: [a..b]}` range (dates as unix seconds)
/// - `{field: [a,b]}` / `{field: ![a,b]}` in / not in
enum FilterFieldType { string, number, date, boolean, stringArray, select }

enum FilterOperator {
  contains,
  equals,
  notEquals,
  greaterThan,
  greaterEqual,
  lessThan,
  lessEqual,
  range,
  inOp,
  notIn,
}

class RangeValue {
  dynamic from;
  dynamic to;

  RangeValue({this.from, this.to});
}

class SearchFilterField {
  final String name;
  final FilterFieldType type;

  /// Key used to resolve the localized label in the UI.
  final String labelKey;

  const SearchFilterField(this.name, this.type, {String? labelKey})
    : labelKey = labelKey ?? name;
}

class SearchFilter {
  static int _idCounter = 0;

  /// Stable identity for widget keys across list rebuilds.
  final int id = _idCounter++;

  SearchFilterField field;
  FilterOperator operator;

  /// String | num | bool | DateTime | List<String> | RangeValue
  dynamic value;

  SearchFilter({required this.field, required this.operator, this.value});

  SearchFilter copy() {
    dynamic copiedValue;
    if (value is RangeValue) {
      copiedValue = RangeValue(from: (value as RangeValue).from, to: (value as RangeValue).to);
    } else if (value is List) {
      copiedValue = List<String>.from(value as List);
    } else {
      copiedValue = value;
    }
    return SearchFilter(field: field, operator: operator, value: copiedValue);
  }

  bool get isEmptyValue {
    if (value == null) return true;
    if (value is String) return (value as String).trim().isEmpty;
    if (value is List) return (value as List).isEmpty;
    if (value is RangeValue) {
      final range = value as RangeValue;
      return !_hasRangeEdge(range.from) && !_hasRangeEdge(range.to);
    }
    return false;
  }

  static bool _hasRangeEdge(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    return true;
  }

  /// Normalizes a single value to its wire format. Returns null when invalid.
  String? _normalizeSingle(dynamic v) {
    if (v == null) return null;
    if (field.type == FilterFieldType.date) {
      if (v is DateTime) {
        return (v.millisecondsSinceEpoch ~/ 1000).toString();
      }
      return null;
    }
    if (v is bool) return v.toString();
    if (v is num) return v.toString();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    if (field.type == FilterFieldType.number) {
      final parsed = num.tryParse(s);
      if (parsed == null) return null;
      return parsed.toString();
    }
    return s;
  }

  /// Returns the `{...}` filter string, or null when this filter should be
  /// skipped (empty / invalid value, one-sided range, "all" select).
  String? toQueryString() {
    if (isEmptyValue) return null;
    final name = field.name;

    switch (operator) {
      case FilterOperator.contains:
        if (field.type == FilterFieldType.stringArray) {
          final list = value as List;
          final joined = list.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join(',');
          if (joined.isEmpty) return null;
          return '{$name: [$joined]}';
        }
        final v = _normalizeSingle(value);
        if (v == null) return null;
        return '{$name: $v}';

      case FilterOperator.range:
        if (value is! RangeValue) return null;
        final range = value as RangeValue;
        final from = _normalizeSingle(range.from);
        final to = _normalizeSingle(range.to);
        // One-sided ranges make the server 500 — require both edges.
        if (from == null || to == null) return null;
        return '{$name: [$from..$to]}';

      case FilterOperator.inOp:
        if (value is! List) return null;
        final joined = (value as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join(',');
        if (joined.isEmpty) return null;
        return '{$name: [$joined]}';

      case FilterOperator.notIn:
        if (value is! List) return null;
        final joined = (value as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join(',');
        if (joined.isEmpty) return null;
        return '{$name: ![$joined]}';

      case FilterOperator.equals:
        final v = _normalizeSingle(value);
        if (v == null) return null;
        return '{$name=$v}';

      case FilterOperator.notEquals:
        final v = _normalizeSingle(value);
        if (v == null) return null;
        return '{$name!=$v}';

      case FilterOperator.greaterThan:
        final v = _normalizeSingle(value);
        if (v == null) return null;
        return '{$name>$v}';

      case FilterOperator.greaterEqual:
        final v = _normalizeSingle(value);
        if (v == null) return null;
        return '{$name>=$v}';

      case FilterOperator.lessThan:
        final v = _normalizeSingle(value);
        if (v == null) return null;
        return '{$name<$v}';

      case FilterOperator.lessEqual:
        final v = _normalizeSingle(value);
        if (v == null) return null;
        return '{$name<=$v}';
    }
  }
}
