import 'package:flutter/material.dart';

class MultiLevelSelector extends StatefulWidget {
  final String contentType;
  final Function(Map<String, String>) onChange;

  const MultiLevelSelector({
    Key? key,
    required this.contentType,
    required this.onChange,
  }) : super(key: key);

  @override
  State<MultiLevelSelector> createState() => _MultiLevelSelectorState();
}

class _MultiLevelSelectorState extends State<MultiLevelSelector> {
  final Map<String, String> _selections = {
    'type': 'all',
    'region': 'all',
    'year': 'all',
    'sort': 'T',
  };

  String? _activeCategory;
  OverlayEntry? _overlayEntry;
  final Map<String, GlobalKey> _buttonKeys = {};

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _activeCategory = null;
  }

  void _showOverlay(String categoryKey) {
    _removeOverlay();

    final buttonKey = _buttonKeys[categoryKey];
    if (buttonKey == null || buttonKey.currentContext == null) return;

    final renderBox = buttonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final category = _getCategories().firstWhere((c) => c.key == categoryKey);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy + size.height + 8,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: category.options.map((option) {
                final isSelected = _selections[categoryKey] == option.value;
                return GestureDetector(
                  onTap: () => _handleSelect(categoryKey, option.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 12,
                        // Use onPrimary for contrast against the primary/background color
                        // so active items remain readable in both light and dark themes.
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _activeCategory = categoryKey;
    });
  }

  List<_Category> _getCategories() {
    final categories = <_Category>[];

    // 类型
    if (widget.contentType == 'movie') {
      categories.add(_Category(
        key: 'type',
        label: '类型',
        options: [
          _Option(label: '全部', value: 'all'),
          _Option(label: '喜剧', value: '喜剧'),
          _Option(label: '爱情', value: '爱情'),
          _Option(label: '动作', value: '动作'),
          _Option(label: '科幻', value: '科幻'),
          _Option(label: '悬疑', value: '悬疑'),
        ],
      ));
    } else if (widget.contentType == 'tv') {
      categories.add(_Category(
        key: 'type',
        label: '类型',
        options: [
          _Option(label: '全部', value: 'all'),
          _Option(label: '喜剧', value: '喜剧'),
          _Option(label: '爱情', value: '爱情'),
          _Option(label: '悬疑', value: '悬疑'),
        ],
      ));
    }

    // 地区
    categories.add(_Category(
      key: 'region',
      label: '地区',
      options: [
        _Option(label: '全部', value: 'all'),
        _Option(label: '华语', value: '华语'),
        _Option(label: '欧美', value: '欧美'),
        _Option(label: '韩国', value: '韩国'),
        _Option(label: '日本', value: '日本'),
      ],
    ));

    // 年代
    categories.add(_Category(
      key: 'year',
      label: '年代',
      options: [
        _Option(label: '全部', value: 'all'),
        _Option(label: '2025', value: '2025'),
        _Option(label: '2024', value: '2024'),
        _Option(label: '2023', value: '2023'),
      ],
    ));

    // 排序
    categories.add(_Category(
      key: 'sort',
      label: '排序',
      options: [
        _Option(label: '综合排序', value: 'T'),
        _Option(label: '近期热度', value: 'U'),
        _Option(label: '高分优先', value: 'S'),
      ],
    ));

    return categories;
  }

  String _getDisplayText(String key) {
    final categories = _getCategories();
    final category = categories.firstWhere((c) => c.key == key);
    final value = _selections[key];

    if (value == 'all' || (key == 'sort' && value == 'T')) {
      return category.label;
    }

    final option = category.options.firstWhere((o) => o.value == value, orElse: () => _Option(label: category.label, value: 'all'));
    return option.label;
  }

  void _handleSelect(String key, String value) {
    setState(() {
      _selections[key] = value;
    });
    _removeOverlay();
    widget.onChange(_selections);
  }

  @override
  Widget build(BuildContext context) {
    final categories = _getCategories();

    // Initialize GlobalKeys for each category
    for (var category in categories) {
      _buttonKeys.putIfAbsent(category.key, () => GlobalKey());
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final key = category.key;
          final isActive = _activeCategory == key;
          final isDefault = _selections[key] == 'all' || (key == 'sort' && _selections[key] == 'T');

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: _buttonKeys[key],
              onTap: () {
                if (isActive) {
                  _removeOverlay();
                  setState(() {});
                } else {
                  _showOverlay(key);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getDisplayText(key),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDefault
                            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isActive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Category {
  final String key;
  final String label;
  final List<_Option> options;

  _Category({required this.key, required this.label, required this.options});
}

class _Option {
  final String label;
  final String value;

  _Option({required this.label, required this.value});
}
