import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

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
  final Map<String, String> _multiSelections = {
    'type': 'all',
    'region': 'all',
    'year': 'all',
    'sort': 'T',
  };

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 800;

    return isPC ? _buildPCLayout() : _buildMobileLayout();
  }

  // --- PC 端：紧凑行布局 + 下拉菜单 ---
  Widget _buildPCLayout() {
    final primaryOptions = _getPrimaryOptions();
    final isAllSelected = widget.primarySelection == '全部';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主分类行
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: primaryOptions.length,
            itemBuilder: (context, index) {
              final opt = primaryOptions[index];
              final isActive = widget.primarySelection == opt['value'];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _FilterChip(
                  label: opt['label']!,
                  isActive: isActive,
                  onTap: () => widget.onPrimaryChange(opt['value']!),
                ),
              );
            },
          ),
        ),
        
        // 当选中“全部”时，显示二级下拉组合，否则显示简单的二级行
        if (isAllSelected) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _getMultiLevelCategories().map((cat) {
              return _buildPCMenuButton(cat);
            }).toList(),
          ),
        ] else if (_getSecondaryOptions().isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _getSecondaryOptions().length,
              itemBuilder: (context, index) {
                final opt = _getSecondaryOptions()[index];
                final isActive = widget.secondarySelection == opt['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _FilterChip(
                    label: opt['label']!,
                    isActive: isActive,
                    onTap: () => widget.onSecondaryChange(opt['value']!),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPCMenuButton(_Category cat) {
    final currentVal = _multiSelections[cat.key] ?? 'all';
    final currentLabel = cat.options.firstWhere((o) => o.value == currentVal).label;
    final isDefault = currentVal == 'all' || currentVal == 'T';

    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 42),
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (val) {
        setState(() => _multiSelections[cat.key] = val);
        if (widget.onMultiLevelChange != null) widget.onMultiLevelChange!(_multiSelections);
      },
      itemBuilder: (context) => cat.options.map((opt) => PopupMenuItem(
        value: opt.value,
        child: Text(opt.label, style: const TextStyle(fontSize: 13)),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDefault 
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDefault ? Colors.transparent : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isDefault ? cat.label : currentLabel,
              style: TextStyle(
                fontSize: 13, 
                fontWeight: isDefault ? FontWeight.normal : FontWeight.bold,
                color: isDefault ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronDown, size: 14, color: isDefault ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  // --- 移动端：横向主行 + 弹出抽屉 ---
  Widget _buildMobileLayout() {
    final primaryOptions = _getPrimaryOptions();
    final secondaryOptions = _getSecondaryOptions();
    final isAllSelected = widget.primarySelection == '全部';
    final showSecondary = !isAllSelected && secondaryOptions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: primaryOptions.length,
                  itemBuilder: (context, index) {
                    final opt = primaryOptions[index];
                    final isActive = widget.primarySelection == opt['value'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: opt['label']!,
                        isActive: isActive,
                        onTap: () => widget.onPrimaryChange(opt['value']!),
                      ),
                    );
                  },
                ),
              ),
              if (isAllSelected) ...[
                const VerticalDivider(width: 16, indent: 8, endIndent: 8),
                _buildMobileDrawerButton(),
              ],
            ],
          ),
        ),
        if (showSecondary) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: secondaryOptions.length,
              itemBuilder: (context, index) {
                final opt = secondaryOptions[index];
                final isActive = widget.secondarySelection == opt['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: opt['label']!,
                    isActive: isActive,
                    onTap: () => widget.onSecondaryChange(opt['value']!),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileDrawerButton() {
    return GestureDetector(
      onTap: _showMobileFilterDrawer,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.filter, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text('筛选', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  void _showMobileFilterDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDrawerState) => _MobileFilterDrawer(
          categories: _getMultiLevelCategories(),
          selections: _multiSelections,
          onUpdate: (key, val) {
            setDrawerState(() => _multiSelections[key] = val);
            setState(() => _multiSelections[key] = val);
            if (widget.onMultiLevelChange != null) widget.onMultiLevelChange!(_multiSelections);
          },
        ),
      ),
    );
  }

  // --- 数据定义 ---
  List<Map<String, String>> _getPrimaryOptions() {
    switch (widget.type) {
      case 'movie':
        return [{'label': '全部', 'value': '全部'}, {'label': '热门', 'value': '热门'}, {'label': '最新', 'value': '最新'}, {'label': '高分', 'value': '豆瓣高分'}, {'label': '冷门', 'value': '冷门佳片'}];
      case 'tv':
      case 'show':
        return [{'label': '全部', 'value': '全部'}, {'label': '热门', 'value': '最近热门'}];
      case 'anime':
        return [{'label': '番剧', 'value': '番剧'}, {'label': '剧场版', 'value': '剧场版'}];
      default: return [];
    }
  }

  List<Map<String, String>> _getSecondaryOptions() {
    switch (widget.type) {
      case 'movie':
        return [{'label': '全部', 'value': '全部'}, {'label': '华语', 'value': '华语'}, {'label': '欧美', 'value': '欧美'}, {'label': '韩国', 'value': '韩国'}, {'label': '日本', 'value': '日本'}];
      case 'tv':
        return [{'label': '全部', 'value': 'tv'}, {'label': '国产', 'value': 'tv_domestic'}, {'label': '欧美', 'value': 'tv_american'}, {'label': '日本', 'value': 'tv_japanese'}, {'label': '韩国', 'value': 'tv_korean'}];
      case 'show':
        return [{'label': '全部', 'value': 'show'}, {'label': '国内', 'value': 'show_domestic'}, {'label': '国外', 'value': 'show_foreign'}];
      default: return [];
    }
  }

  List<_Category> _getMultiLevelCategories() {
    final categories = <_Category>[];
    if (widget.type == 'movie' || widget.type == 'tv') {
      categories.add(_Category(key: 'type', label: '类型', options: [_Option(label: '全部', value: 'all'), _Option(label: '喜剧', value: '喜剧'), _Option(label: '爱情', value: '爱情'), _Option(label: '动作', value: '动作'), _Option(label: '科幻', value: '科幻'), _Option(label: '悬疑', value: '悬疑')]));
    }
    categories.add(_Category(key: 'region', label: '地区', options: [_Option(label: '全部', value: 'all'), _Option(label: '华语', value: '华语'), _Option(label: '欧美', value: '欧美'), _Option(label: '韩国', value: '韩国'), _Option(label: '日本', value: '日本')]));
    categories.add(_Category(key: 'year', label: '年代', options: [_Option(label: '全部', value: 'all'), _Option(label: '2025', value: '2025'), _Option(label: '2024', value: '2024'), _Option(label: '2023', value: '2023'), _Option(label: '2022', value: '2022')]));
    categories.add(_Category(key: 'sort', label: '排序', options: [_Option(label: '综合', value: 'T'), _Option(label: '热度', value: 'U'), _Option(label: '评分', value: 'S')]));
    return categories;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white) : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _MobileFilterDrawer extends StatelessWidget {
  final List<_Category> categories;
  final Map<String, String> selections;
  final Function(String, String) onUpdate;

  const _MobileFilterDrawer({required this.categories, required this.selections, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('高级筛选', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, size: 20)),
            ],
          ),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.label, style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: cat.options.map((opt) {
                            final isActive = selections[cat.key] == opt.value;
                            return _FilterChip(label: opt.label, isActive: isActive, onTap: () => onUpdate(cat.key, opt.value));
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('应用筛选', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 16),
        ],
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