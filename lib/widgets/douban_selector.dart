import 'package:flutter/material.dart';
import 'multi_level_selector.dart';

class DoubanSelector extends StatefulWidget {
  final String type;
  final String primarySelection;
  final String secondarySelection;
  final Function(String) onPrimaryChange;
  final Function(String) onSecondaryChange;
  final Function(Map<String, String>)? onMultiLevelChange;

  const DoubanSelector({
    Key? key,
    required this.type,
    required this.primarySelection,
    required this.secondarySelection,
    required this.onPrimaryChange,
    required this.onSecondaryChange,
    this.onMultiLevelChange,
  }) : super(key: key);

  @override
  State<DoubanSelector> createState() => _DoubanSelectorState();
}

class _DoubanSelectorState extends State<DoubanSelector> {
  List<Map<String, String>> _getPrimaryOptions() {
    switch (widget.type) {
      case 'movie':
        return [
          {'label': '全部', 'value': '全部'},
          {'label': '热门电影', 'value': '热门'},
          {'label': '最新电影', 'value': '最新'},
          {'label': '豆瓣高分', 'value': '豆瓣高分'},
          {'label': '冷门佳片', 'value': '冷门佳片'},
        ];
      case 'tv':
        return [
          {'label': '全部', 'value': '全部'},
          {'label': '最近热门', 'value': '最近热门'},
        ];
      case 'show':
        return [
          {'label': '全部', 'value': '全部'},
          {'label': '最近热门', 'value': '最近热门'},
        ];
      case 'anime':
        return [
          {'label': '番剧', 'value': '番剧'},
          {'label': '剧场版', 'value': '剧场版'},
        ];
      default:
        return [];
    }
  }

  List<Map<String, String>> _getSecondaryOptions() {
    switch (widget.type) {
      case 'movie':
        return [
          {'label': '全部', 'value': '全部'},
          {'label': '华语', 'value': '华语'},
          {'label': '欧美', 'value': '欧美'},
          {'label': '韩国', 'value': '韩国'},
          {'label': '日本', 'value': '日本'},
        ];
      case 'tv':
        return [
          {'label': '全部', 'value': 'tv'},
          {'label': '国产', 'value': 'tv_domestic'},
          {'label': '欧美', 'value': 'tv_american'},
          {'label': '日本', 'value': 'tv_japanese'},
          {'label': '韩国', 'value': 'tv_korean'},
        ];
      case 'show':
        return [
          {'label': '全部', 'value': 'show'},
          {'label': '国内', 'value': 'show_domestic'},
          {'label': '国外', 'value': 'show_foreign'},
        ];
      default:
        return [];
    }
  }

  Widget _buildCapsuleSelector(
    List<Map<String, String>> options,
    String activeValue,
    Function(String) onChange,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            final isActive = activeValue == option['value'];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => onChange(option['value']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
            child: Text(
              option['label']!,
              style: TextStyle(
                // Ensure active text remains readable on both light and dark themes
                // by using a neutral dark text color for active state.
                color: isActive ? Colors.black87 : Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryOptions = _getPrimaryOptions();
    final secondaryOptions = _getSecondaryOptions();
    final showMultiLevel = widget.primarySelection == '全部';
    final showSecondary = !showMultiLevel && secondaryOptions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary selector
        if (primaryOptions.isNotEmpty) ...[
          Row(
            children: [
              const SizedBox(
                width: 48,
                child: Text('分类', style: TextStyle(fontSize: 13)),
              ),
              Flexible(
                child: _buildCapsuleSelector(
                  primaryOptions,
                  widget.primarySelection,
                  widget.onPrimaryChange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Secondary selector (when NOT "全部")
        if (showSecondary)
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  widget.type == 'movie' ? '地区' : '类型',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Flexible(
                child: _buildCapsuleSelector(
                  secondaryOptions,
                  widget.secondarySelection,
                  widget.onSecondaryChange,
                ),
              ),
            ],
          ),

        // Multi-level selector (when "全部")
        if (showMultiLevel)
          Row(
            children: [
              const SizedBox(
                width: 48,
                child: Text('筛选', style: TextStyle(fontSize: 13)),
              ),
              Flexible(
                child: MultiLevelSelector(
                  contentType: widget.type,
                  onChange: (values) {
                    if (widget.onMultiLevelChange != null) {
                      widget.onMultiLevelChange!(values);
                    }
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }
}
