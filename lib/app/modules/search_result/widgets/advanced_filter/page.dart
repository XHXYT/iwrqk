import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:iwrqk/i18n/strings.g.dart';

import '../../../../components/load_empty.dart';
import '../../../../data/models/tag.dart';
import '../../../../data/providers/api_provider.dart';
import '../../../../data/models/search/search_filter.dart';
import '../../../../data/models/search/search_filter_config.dart';
import '../../controller.dart';
import 'controller.dart';

String _fieldLabel(SearchFilterField field) {
  switch (field.labelKey) {
    case "title":
      return t.searchFilter.fields.title;
    case "body":
      return t.searchFilter.fields.body;
    case "tags":
      return t.searchFilter.fields.tags;
    case "author":
      return t.searchFilter.fields.author;
    case "date":
      return t.searchFilter.fields.date;
    case "registrationDate":
      return t.searchFilter.fields.registrationDate;
    case "private":
      return t.searchFilter.fields.private;
    case "duration":
      return t.searchFilter.fields.duration;
    case "likes":
      return t.searchFilter.fields.likes;
    case "views":
      return t.searchFilter.fields.views;
    case "comments":
      return t.searchFilter.fields.comments;
    case "rating":
      return t.searchFilter.fields.rating;
    case "imageCount":
      return t.searchFilter.fields.imageCount;
    case "username":
      return t.searchFilter.fields.username;
    case "nickname":
      return t.searchFilter.fields.nickname;
    default:
      return field.name;
  }
}

String _operatorLabel(FilterOperator operator) {
  switch (operator) {
    case FilterOperator.contains:
      return t.searchFilter.operators.contains;
    case FilterOperator.equals:
      return t.searchFilter.operators.equals;
    case FilterOperator.notEquals:
      return t.searchFilter.operators.notEquals;
    case FilterOperator.greaterThan:
      return t.searchFilter.operators.greaterThan;
    case FilterOperator.greaterEqual:
      return t.searchFilter.operators.greaterEqual;
    case FilterOperator.lessThan:
      return t.searchFilter.operators.lessThan;
    case FilterOperator.lessEqual:
      return t.searchFilter.operators.lessEqual;
    case FilterOperator.range:
      return t.searchFilter.operators.range;
    case FilterOperator.inOp:
      return t.searchFilter.operators.inOp;
    case FilterOperator.notIn:
      return t.searchFilter.operators.notIn;
  }
}

class AdvancedFilterPage extends StatefulWidget {
  final SearchSegment segment;

  const AdvancedFilterPage({super.key, required this.segment});

  @override
  State<AdvancedFilterPage> createState() => _AdvancedFilterPageState();
}

class _AdvancedFilterPageState extends State<AdvancedFilterPage> {
  late AdvancedFilterController _controller;

  @override
  void initState() {
    super.initState();
    final parent = Get.find<SearchResultController>();
    _controller = Get.put(AdvancedFilterController());
    _controller.init(
      widget.segment,
      parent.activeFilters[widget.segment]!,
    );
  }

  @override
  void dispose() {
    Get.delete<AdvancedFilterController>();
    super.dispose();
  }

  void _showAddFilterDialog() {
    Get.dialog(
      SimpleDialog(
        title: Text(t.searchFilter.addFilter),
        children: _controller.availableFields.map((field) {
          return SimpleDialogOption(
            onPressed: () {
              Get.back();
              _controller.addFilter(field);
            },
            child: Text(_fieldLabel(field)),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.searchFilter.title),
        actions: [
          TextButton(
            onPressed: _controller.reset,
            child: Text(
              t.searchFilter.reset,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () {
              if (_controller.filters.isEmpty) {
                SmartDialog.showToast(t.searchFilter.empty);
                return;
              }
              _controller.apply();
            },
            child: Text(t.searchFilter.apply),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Obx(() {
                final filters = _controller.filters;
                if (filters.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 120),
                      const LoadEmpty(),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: filters.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _FilterRow(
                      key: ValueKey(filters[index].id),
                      index: index,
                      filter: filters[index],
                      controller: _controller,
                    );
                  },
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _showAddFilterDialog,
                  icon: const Icon(Icons.add),
                  label: Text(t.searchFilter.addFilter),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatefulWidget {
  final int index;
  final SearchFilter filter;
  final AdvancedFilterController controller;

  const _FilterRow({
    super.key,
    required this.index,
    required this.filter,
    required this.controller,
  });

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  late TextEditingController _textController;
  late TextEditingController _fromController;
  late TextEditingController _toController;
  late TextEditingController _tagController;
  late FocusNode _tagFocusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: _initialText(widget.filter.value),
    );
    final range = widget.filter.value is RangeValue
        ? widget.filter.value as RangeValue
        : null;
    _fromController = TextEditingController(text: _rangeEdgeText(range?.from));
    _toController = TextEditingController(text: _rangeEdgeText(range?.to));
    _tagController = TextEditingController();
    _tagFocusNode = FocusNode();
  }

  String _initialText(dynamic value) {
    if (value is RangeValue) return "";
    if (value == null) return "";
    return value.toString();
  }

  String _rangeEdgeText(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  @override
  void didUpdateWidget(covariant _FilterRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.field != widget.filter.field ||
        oldWidget.filter.operator != widget.filter.operator) {
      _textController.text = _initialText(widget.filter.value);
      final range = widget.filter.value is RangeValue
          ? widget.filter.value as RangeValue
          : null;
      _fromController.text = _rangeEdgeText(range?.from);
      _toController.text = _rangeEdgeText(range?.to);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _tagController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  Widget _buildFieldOperatorPickers() {
    final filter = widget.filter;
    final controller = widget.controller;
    return Row(
      children: [
        Expanded(
          child: DropdownButton<String>(
            value: filter.field.name,
            isExpanded: true,
            underline: const SizedBox(),
            items: controller.availableFields
                .map(
                  (field) => DropdownMenuItem(
                    value: field.name,
                    child: Text(
                      _fieldLabel(field),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (name) {
              for (final field in controller.availableFields) {
                if (field.name == name) {
                  controller.changeField(widget.index, field);
                  break;
                }
              }
            },
          ),
        ),
        if (SearchFilterConfig.operatorsFor(filter.field.type).length > 1) ...[
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<FilterOperator>(
              value: filter.operator,
              isExpanded: true,
              underline: const SizedBox(),
              items: SearchFilterConfig.operatorsFor(filter.field.type)
                  .map(
                    (op) => DropdownMenuItem(
                      value: op,
                      child: Text(
                        _operatorLabel(op),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (op) {
                if (op != null) {
                  controller.changeOperator(widget.index, op);
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickDate({dynamic current, required bool isRangeEdge}) async {
    final now = DateTime.now();
    final initial = current is DateTime
        ? current
        : (isRangeEdge ? now : now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(2013),
      lastDate: now,
    );
    if (picked == null) return;
    final filter = widget.filter;
    if (filter.operator == FilterOperator.range) {
      final range = (filter.value is RangeValue
              ? filter.value as RangeValue
              : RangeValue());
      if (isRangeEdge) {
        range.to = picked;
      } else {
        range.from = picked;
      }
      widget.controller.changeValue(widget.index, range);
    } else {
      widget.controller.changeValue(widget.index, picked);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Widget _buildDateButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildValueEditor() {
    final filter = widget.filter;
    final controller = widget.controller;
    final index = widget.index;

    switch (filter.field.type) {
      case FilterFieldType.string:
      case FilterFieldType.number:
        if (filter.operator == FilterOperator.range) {
          return Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fromController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t.searchFilter.startDate,
                  ),
                  onChanged: (text) {
                    final range = (filter.value is RangeValue
                            ? filter.value as RangeValue
                            : RangeValue());
                    range.from = text;
                    controller.changeValueSilently(index, range);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("~"),
              ),
              Expanded(
                child: TextField(
                  controller: _toController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t.searchFilter.endDate,
                  ),
                  onChanged: (text) {
                    final range = (filter.value is RangeValue
                            ? filter.value as RangeValue
                            : RangeValue());
                    range.to = text;
                    controller.changeValueSilently(index, range);
                  },
                ),
              ),
            ],
          );
        }
        return TextField(
          controller: _textController,
          keyboardType: filter.field.type == FilterFieldType.number
              ? TextInputType.number
              : null,
          decoration: InputDecoration(
            isDense: true,
            hintText: t.searchFilter.pleaseEnterValue,
          ),
          onChanged: (text) => controller.changeValueSilently(index, text),
        );

      case FilterFieldType.date:
        if (filter.operator == FilterOperator.range) {
          final range = filter.value is RangeValue
              ? filter.value as RangeValue
              : null;
          return Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  label: range?.from is DateTime
                      ? _formatDate(range!.from as DateTime)
                      : t.searchFilter.startDate,
                  onPressed: () => _pickDate(current: range?.from, isRangeEdge: false),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text("~"),
              ),
              Expanded(
                child: _buildDateButton(
                  label: range?.to is DateTime
                      ? _formatDate(range!.to as DateTime)
                      : t.searchFilter.endDate,
                  onPressed: () => _pickDate(current: range?.to, isRangeEdge: true),
                ),
              ),
            ],
          );
        }
        return SizedBox(
          width: double.infinity,
          child: _buildDateButton(
            label: filter.value is DateTime
                ? _formatDate(filter.value as DateTime)
                : t.searchFilter.selectDate,
            onPressed: () => _pickDate(current: filter.value, isRangeEdge: false),
          ),
        );

      case FilterFieldType.boolean:
        return Align(
          alignment: Alignment.centerLeft,
          child: Switch(
            value: filter.value == true,
            onChanged: (value) => controller.changeValue(index, value),
          ),
        );

      case FilterFieldType.stringArray:
        return _buildTagsEditor();

      case FilterFieldType.select:
        final currentValue = filter.value?.toString() ?? "";
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SearchFilterConfig.ratingOptions.map((option) {
            final (value, key) = option;
            return ChoiceChip(
              label: Text(_ratingOptionLabel(key)),
              selected: currentValue == value,
              onSelected: (selected) {
                if (selected) {
                  controller.changeValue(index, value);
                }
              },
            );
          }).toList(),
        );
    }
  }

  String _ratingOptionLabel(String key) {
    switch (key) {
      case "all":
        return t.filter.all;
      case "ecchi":
        return t.filter.ecchi;
      case "general":
        return t.filter.general;
      default:
        return key;
    }
  }

  Widget _buildTagsEditor() {
    final filter = widget.filter;
    final controller = widget.controller;
    final index = widget.index;
    final tags = (filter.value is List ? filter.value as List : const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RawAutocomplete<String>(
          textEditingController: _tagController,
          focusNode: _tagFocusNode,
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            try {
              final result = await ApiProvider.autoCompleteTags(
                keyword: textEditingValue.text,
              );
              if (result.success && result.data != null) {
                return result.data!
                    .map((TagModel tag) => tag.id)
                    .where((id) => !tags.contains(id));
              }
            } catch (_) {}
            return const Iterable<String>.empty();
          },
          onSelected: (String option) {
            _addTag(option);
          },
          fieldViewBuilder: (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                isDense: true,
                hintText: t.filter.tag,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () {
                    final text = textEditingController.text.trim();
                    if (text.isNotEmpty) {
                      _addTag(text);
                    }
                  },
                ),
              ),
              onSubmitted: (String value) {
                final text = value.trim();
                if (text.isNotEmpty) {
                  _addTag(text);
                }
              },
            );
          },
          optionsViewBuilder: (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final option = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        title: Text(option, overflow: TextOverflow.ellipsis),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(tags.length, (i) {
                final tag = tags[i].toString();
                return InputChip(
                  label: Text(tag),
                  onDeleted: () {
                    final list = List<String>.from(tags);
                    list.removeAt(i);
                    controller.changeValue(index, list);
                  },
                );
              }),
            ),
          ),
      ],
    );
  }

  void _addTag(String tag) {
    final filter = widget.filter;
    final tags = List<String>.from(
      filter.value is List ? filter.value as List : const [],
    );
    if (tags.contains(tag)) return;
    tags.add(tag);
    widget.controller.changeValue(widget.index, tags);
    _tagController.clear();
    _tagFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildFieldOperatorPickers()),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  onPressed: () =>
                      widget.controller.removeFilterAt(widget.index),
                ),
              ],
            ),
            _buildValueEditor(),
          ],
        ),
      ),
    );
  }
}
