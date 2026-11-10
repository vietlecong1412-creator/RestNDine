import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Màu riêng của RestNDine, đi kèm ColorScheme của Material.
/// Bám theo bảng màu của bản web (cam #F97316) để hai nền tảng nhìn như một sản phẩm.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.brandSoft,
    required this.canvas,
    required this.card,
    required this.field,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.star,
    required this.ai,
    required this.aiContainer,
    required this.restaurant,
    required this.cafe,
    required this.hotel,
    required this.sponsored,
    required this.skeleton,
    required this.shadow,
  });

  /// Cam thương hiệu, dùng cho điểm nhấn lớn (marker, gradient, minh hoạ).
  final Color brand;

  /// Nền cam nhạt cho icon, badge.
  final Color brandSoft;

  /// Nền màn hình.
  final Color canvas;

  /// Nền thẻ, sheet, thanh điều hướng.
  final Color card;

  /// Nền ô nhập liệu.
  final Color field;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color star;

  /// Màu riêng cho các tính năng AI để người dùng nhận ra ngay.
  final Color ai;
  final Color aiContainer;
  final Color restaurant;
  final Color cafe;
  final Color hotel;
  final Color sponsored;
  final Color skeleton;
  final Color shadow;

  LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brand, Color.lerp(brand, const Color(0xFFDC2626), 0.35)!],
      );

  LinearGradient get sponsoredGradient => const LinearGradient(
        colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
      );

  List<BoxShadow> get softShadow => [
        BoxShadow(color: shadow, blurRadius: 18, offset: const Offset(0, 6)),
      ];

  static const light = AppColors(
    brand: Color(0xFFF97316),
    brandSoft: Color(0xFFFFEDD5),
    canvas: Color(0xFFF6F7F9),
    card: Color(0xFFFFFFFF),
    field: Color(0xFFF1F3F6),
    border: Color(0xFFE6E8EC),
    textPrimary: Color(0xFF202124),
    textSecondary: Color(0xFF5F6368),
    textMuted: Color(0xFF70757A),
    success: Color(0xFF16A34A),
    successContainer: Color(0xFFDCFCE7),
    warning: Color(0xFFB45309),
    warningContainer: Color(0xFFFEF3C7),
    danger: Color(0xFFDC2626),
    dangerContainer: Color(0xFFFEE2E2),
    star: Color(0xFFF59E0B),
    ai: Color(0xFF7C3AED),
    aiContainer: Color(0xFFF5F3FF),
    restaurant: Color(0xFFF97316),
    cafe: Color(0xFF9A6239),
    hotel: Color(0xFF2563EB),
    sponsored: Color(0xFFF59E0B),
    skeleton: Color(0xFFE9ECF0),
    shadow: Color(0x14101828),
  );

  static const dark = AppColors(
    brand: Color(0xFFFB923C),
    brandSoft: Color(0xFF3B2416),
    canvas: Color(0xFF0F172A),
    card: Color(0xFF1E293B),
    field: Color(0xFF273449),
    border: Color(0xFF334155),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
    success: Color(0xFF4ADE80),
    successContainer: Color(0xFF14361F),
    warning: Color(0xFFFBBF24),
    warningContainer: Color(0xFF3A2C0B),
    danger: Color(0xFFF87171),
    dangerContainer: Color(0xFF3F1515),
    star: Color(0xFFFBBF24),
    ai: Color(0xFFA78BFA),
    aiContainer: Color(0xFF221B3B),
    restaurant: Color(0xFFFB923C),
    cafe: Color(0xFFC9946A),
    hotel: Color(0xFF60A5FA),
    sponsored: Color(0xFFFBBF24),
    skeleton: Color(0xFF273449),
    shadow: Color(0x59000000),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brand: l(brand, other.brand),
      brandSoft: l(brandSoft, other.brandSoft),
      canvas: l(canvas, other.canvas),
      card: l(card, other.card),
      field: l(field, other.field),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
      danger: l(danger, other.danger),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      star: l(star, other.star),
      ai: l(ai, other.ai),
      aiContainer: l(aiContainer, other.aiContainer),
      restaurant: l(restaurant, other.restaurant),
      cafe: l(cafe, other.cafe),
      hotel: l(hotel, other.hotel),
      sponsored: l(sponsored, other.sponsored),
      skeleton: l(skeleton, other.skeleton),
      shadow: l(shadow, other.shadow),
    );
  }
}

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'PlusJakartaSans';

  static const double radiusSm = 10;
  static const double radius = 14;
  static const double radiusLg = 20;

  static ThemeData get light => _build(
        colors: AppColors.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          // Cam đậm hơn màu thương hiệu một bậc để chữ trắng trên nút vẫn đủ tương phản
          primary: Color(0xFFEA580C),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFFFEDD5),
          onPrimaryContainer: Color(0xFF9A3412),
          secondary: Color(0xFF334155),
          onSecondary: Colors.white,
          // Nút tonal (FilledButton.tonal, IconButton.filledTonal) mang tông cam thương hiệu
          secondaryContainer: Color(0xFFFFEDD5),
          onSecondaryContainer: Color(0xFF9A3412),
          tertiary: Color(0xFF7C3AED),
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFF5F3FF),
          onTertiaryContainer: Color(0xFF4C1D95),
          error: Color(0xFFDC2626),
          onError: Colors.white,
          errorContainer: Color(0xFFFEE2E2),
          onErrorContainer: Color(0xFF7F1D1D),
          surface: Colors.white,
          onSurface: Color(0xFF202124),
          onSurfaceVariant: Color(0xFF5F6368),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Color(0xFFFAFAFB),
          surfaceContainer: Color(0xFFF6F7F9),
          surfaceContainerHigh: Color(0xFFF1F3F6),
          surfaceContainerHighest: Color(0xFFE9ECF0),
          outline: Color(0xFFD0D5DD),
          outlineVariant: Color(0xFFE6E8EC),
          inverseSurface: Color(0xFF202124),
          onInverseSurface: Color(0xFFF1F3F4),
          inversePrimary: Color(0xFFFDBA74),
          shadow: Colors.black,
          scrim: Colors.black,
          surfaceTint: Colors.transparent,
        ),
      );

  static ThemeData get dark => _build(
        colors: AppColors.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Color(0xFFFB923C),
          onPrimary: Color(0xFF431407),
          primaryContainer: Color(0xFF7C2D12),
          onPrimaryContainer: Color(0xFFFFEDD5),
          secondary: Color(0xFFCBD5E1),
          onSecondary: Color(0xFF0F172A),
          secondaryContainer: Color(0xFF7C2D12),
          onSecondaryContainer: Color(0xFFFFEDD5),
          tertiary: Color(0xFFA78BFA),
          onTertiary: Color(0xFF2E1065),
          tertiaryContainer: Color(0xFF3B2A6B),
          onTertiaryContainer: Color(0xFFEDE9FE),
          error: Color(0xFFF87171),
          onError: Color(0xFF450A0A),
          errorContainer: Color(0xFF7F1D1D),
          onErrorContainer: Color(0xFFFEE2E2),
          surface: Color(0xFF1E293B),
          onSurface: Color(0xFFF1F5F9),
          onSurfaceVariant: Color(0xFFCBD5E1),
          surfaceContainerLowest: Color(0xFF0F172A),
          surfaceContainerLow: Color(0xFF172033),
          surfaceContainer: Color(0xFF1E293B),
          surfaceContainerHigh: Color(0xFF273449),
          surfaceContainerHighest: Color(0xFF334155),
          outline: Color(0xFF475569),
          outlineVariant: Color(0xFF334155),
          inverseSurface: Color(0xFFF1F5F9),
          onInverseSurface: Color(0xFF1E293B),
          inversePrimary: Color(0xFFEA580C),
          shadow: Colors.black,
          scrim: Colors.black,
          surfaceTint: Colors.transparent,
        ),
      );

  static TextTheme _textTheme(ColorScheme scheme, AppColors c) {
    const base = TextTheme(
      displaySmall: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.8),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.6),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.4),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.2),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35, letterSpacing: -0.1),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.35),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.45),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25),
      labelSmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: 0.1),
    );
    final themed = base.apply(
      fontFamily: fontFamily,
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );
    return themed.copyWith(
      bodySmall: themed.bodySmall!.copyWith(color: c.textSecondary),
    );
  }

  static ThemeData _build({required ColorScheme scheme, required AppColors colors}) {
    final isDark = scheme.brightness == Brightness.dark;
    final text = _textTheme(scheme, colors);
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );

    final buttonText = text.labelLarge!.copyWith(fontFamily: fontFamily);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      dividerColor: colors.border,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.6,
        shadowColor: colors.shadow,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: colors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: rounded,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: rounded,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: scheme.outline),
          shape: rounded,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: buttonText.copyWith(fontSize: 14),
          shape: rounded,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: colors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(scheme.primary, 1.6),
        errorBorder: inputBorder(scheme.error, 1.2),
        focusedErrorBorder: inputBorder(scheme.error, 1.6),
        hintStyle: text.bodyMedium!.copyWith(color: colors.textMuted),
        labelStyle: text.bodyMedium!.copyWith(color: colors.textSecondary),
        floatingLabelStyle: text.bodyMedium!.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
        errorStyle: text.bodySmall!.copyWith(color: scheme.error),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? scheme.primary : colors.textMuted,
        ),
        suffixIconColor: colors.textMuted,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.card,
        selectedColor: scheme.primary,
        side: BorderSide(color: colors.border),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall!.copyWith(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? colors.textPrimary : colors.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : colors.textMuted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium!.copyWith(color: scheme.onInverseSurface, fontWeight: FontWeight.w500),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.card,
        modalBackgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium!.copyWith(color: colors.textSecondary),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: text.labelSmall!.copyWith(color: scheme.onInverseSurface),
      ),
    );
  }
}

/// Lối tắt đọc theme: `context.colors.brand`, `context.text.titleMedium`...
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
