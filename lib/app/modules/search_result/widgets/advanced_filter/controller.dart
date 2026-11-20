import 'package:get/get.dart';

import '../../../../data/models/search/search_filter.dart';
import '../../../../data/models/search/search_filter_config.dart';
import '../../controller.dart';

class AdvancedFilterController extends GetxController {
  final RxList<SearchFilter> filters = <SearchFilter>[].obs;
  late SearchSegment segment;

  List<SearchFilterField> get availableFields =>
      SearchFilterConfig.fieldsFor(segment);

  void init(SearchSegment segment, List<SearchFilter> initialFilters) {
    this.segment = segment;
    filters.value = initialFilters.map((f) => f.copy()).toList();
  }

  void addFilter(SearchFilterField field) {
    filters.add(
      SearchFilter(
        field: field,
        operator: SearchFilterConfig.defaultOperatorFor(field.type),
        value: initialValueFor(field),
      ),
    );
  }

  dynamic initialValueFor(SearchFilterField field) {
    switch (field.type) {
      case FilterFieldType.date:
        return RangeValue();
      case FilterFieldType.stringArray:
        return <String>[];
      case FilterFieldType.boolean:
        return false;
      case FilterFieldType.select:
        return "";
      case FilterFieldType.string:
      case FilterFieldType.number:
        return null;
    }
  }

  void removeFilterAt(int index) {
    filters.removeAt(index);
  }

  void changeField(int index, SearchFilterField field) {
    final filter = filters[index];
    filter.field = field;
    filter.operator = SearchFilterConfig.defaultOperatorFor(field.type);
    filter.value = initialValueFor(field);
    filters.refresh();
  }

  void changeOperator(int index, FilterOperator operator) {
    final filter = filters[index];
    filter.operator = operator;
    if (operator == FilterOperator.range && filter.value is! RangeValue) {
      filter.value = RangeValue();
    } else if (operator != FilterOperator.range && filter.value is RangeValue) {
      filter.value = null;
    }
    filters.refresh();
  }

  /// Triggers UI rebuild (chips, switches, dates, operator-dependent inputs).
  void changeValue(int index, dynamic value) {
    filters[index].value = value;
    filters.refresh();
  }

  /// Stores the value without rebuilding (free-text typing).
  void changeValueSilently(int index, dynamic value) {
    filters[index].value = value;
  }

  void reset() {
    filters.clear();
  }

  void apply() {
    final parent = Get.find<SearchResultController>();
    parent.applyFilters(segment, filters.toList());
    Get.back();
  }
}
