import 'package:flutter/material.dart';

import 'app_layout.dart';
import 'catalog_sort.dart';

/// 控制排序与筛选底部面板显示哪些分组。
enum CatalogSheetMode {
  /// 只显示排序分组。
  sort,

  /// 只显示筛选分组（剧集状态、观看权限、集数完整度）。
  filters,

  /// 显示全部分组。
  all,
}

Future<CatalogView?> chooseCatalogView(
  BuildContext context,
  CatalogView current, {
  CatalogSheetMode mode = CatalogSheetMode.all,
}) => showModalBottomSheet<CatalogView>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) {
    var selected = current;
    return StatefulBuilder(
      builder: (context, update) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(switch (mode) {
              CatalogSheetMode.sort => '排序',
              CatalogSheetMode.filters => '筛选',
              CatalogSheetMode.all => '排序与筛选',
            }, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (mode != CatalogSheetMode.filters) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sort in CatalogSort.values)
                    ChoiceChip(
                      autofocus:
                          AppLayout.isTelevision(context) &&
                          sort == CatalogSort.values.first,
                      label: Text(sort.label),
                      selected: selected.sort == sort,
                      onSelected: (_) => update(
                        () => selected = selected.copyWith(sort: sort),
                      ),
                    ),
                ],
              ),
              if (mode == CatalogSheetMode.all) const SizedBox(height: 24),
            ],
            if (mode != CatalogSheetMode.sort) ...[
              const Text('剧集状态'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const {
                    '': '全部',
                    'ongoing': '连载中',
                    'finished': '已完结',
                    'unknown': '状态未知',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: selected.release == entry.key,
                      onSelected: (_) => update(
                        () => selected = selected.copyWith(release: entry.key),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('观看权限'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in CatalogView.playabilityOptions.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: selected.playability == entry.key,
                      onSelected: (_) => update(
                        () => selected = selected.copyWith(
                          playability: entry.key,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('集数完整度'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in CatalogView.completenessOptions.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: selected.completeness == entry.key,
                      onSelected: (_) => update(
                        () => selected = selected.copyWith(
                          completeness: entry.key,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '排序和筛选作用于已加载的剧集；缺少排序资料的条目排在最后。'
              '观看权限与集数完整度依据已检测的剧集信息，未检测过的条目在'
              '非「全部」筛选下不显示。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('应用'),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
