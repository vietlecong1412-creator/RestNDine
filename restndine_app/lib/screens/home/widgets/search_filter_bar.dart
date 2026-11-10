import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_theme.dart';
import '../../../providers/place_provider.dart';
import '../../../widgets/common.dart';

/// Ô tìm kiếm: lọc ngay khi gõ (không phân biệt dấu), đồng bộ từ khoá giữa các tab.
class PlaceSearchField extends StatefulWidget {
  /// Nằm nổi trên bản đồ: không viền, có đổ bóng.
  final bool floating;

  const PlaceSearchField({super.key, this.floating = false});

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  late final PlaceProvider _prov = context.read<PlaceProvider>();
  late final TextEditingController _ctrl = TextEditingController(text: _prov.searchQuery);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _prov.addListener(_syncFromProvider);
  }

  @override
  void dispose() {
    _prov.removeListener(_syncFromProvider);
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // Từ khoá đổi ở tab khác hoặc do bấm "Xóa bộ lọc" thì cập nhật lại ô này
  void _syncFromProvider() {
    if (_debounce?.isActive ?? false) return;
    final q = _prov.searchQuery;
    if (_ctrl.text != q) {
      _ctrl.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
      setState(() {});
    }
  }

  void _onChanged(String value) {
    setState(() {}); // hiện/ẩn nút xoá
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _prov.setSearchQuery(value));
  }

  void _submit(String value) {
    _debounce?.cancel();
    _prov.setSearchQuery(value);
  }

  void _clear() {
    _debounce?.cancel();
    _ctrl.clear();
    _prov.setSearchQuery('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(16);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: color, width: width));

    final field = TextField(
      controller: _ctrl,
      onChanged: _onChanged,
      onSubmitted: _submit,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      textInputAction: TextInputAction.search,
      style: context.text.bodyLarge!.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Tìm quán ăn, cafe, khách sạn...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _ctrl.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Xóa từ khoá',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: _clear,
              ),
        fillColor: colors.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: border(widget.floating ? Colors.transparent : colors.border),
        border: border(colors.border),
        focusedBorder: border(context.scheme.primary, 1.6),
      ),
    );

    if (!widget.floating) return field;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: colors.softShadow),
      child: field,
    );
  }
}

/// Hàng chip danh mục cuộn ngang, chọn được nhiều danh mục.
class CategoryChips extends StatelessWidget {
  final bool floating;
  final EdgeInsetsGeometry padding;

  const CategoryChips({
    super.key,
    this.floating = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PlaceProvider>();
    final cats = prov.categories;

    if (cats.isEmpty && !prov.hasLoaded) {
      // Tải lỗi thì để trống, không nhấp nháy khung xương mãi
      if (prov.error != null && !prov.isLoading) return const SizedBox(height: 38);
      return SizedBox(
        height: 38,
        child: SkeletonPulse(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: padding,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => SkeletonBox(width: i == 0 ? 64 : 92, height: 38, radius: 999),
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        clipBehavior: Clip.none,
        itemCount: cats.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _FilterPill(
              label: 'Tất cả',
              selected: prov.selectedCategoryIds.isEmpty,
              floating: floating,
              onTap: prov.clearCategories,
            );
          }
          final cat = cats[i - 1];
          return _FilterPill(
            label: cat.name,
            emoji: cat.icon,
            selected: prov.selectedCategoryIds.contains(cat.id),
            floating: floating,
            onTap: () => prov.toggleCategory(cat.id),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool selected;
  final bool floating;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.emoji,
    required this.selected,
    required this.floating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = context.scheme;
    final fg = selected ? scheme.onPrimary : colors.textPrimary;
    final hasEmoji = emoji != null && emoji!.trim().isNotEmpty;

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : colors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected || floating ? Colors.transparent : colors.border),
          boxShadow: floating ? colors.softShadow : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasEmoji) ...[
                    Text(emoji!.trim(), style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: context.text.labelMedium!.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
