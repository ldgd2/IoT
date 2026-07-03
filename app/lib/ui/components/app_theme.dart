import 'package:flutter/material.dart';

class AppTheme {
  /// Tema oscuro vibrante. Puedes cambiar el [seed] para personalizar.
  static ThemeData dark({Color seed = const Color(0xFF00E5A8)}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0E1116),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
      ),

      // ✅ En versiones nuevas es DialogThemeData
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF141920),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A212A),
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141920),
        border: _outlineBorder(Colors.transparent),
        enabledBorder: _outlineBorder(Colors.transparent),
        focusedBorder: _outlineBorder(scheme.primary, width: 1.4),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        // ✅ Reemplaza withOpacity por withValues(alpha: …)
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),

      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _outlineBorder(Color c, {double width = 1}) =>
      OutlineInputBorder(
        borderSide: BorderSide(color: c, width: width),
        borderRadius: BorderRadius.circular(12),
      );
}

/// Espaciados rápidos
class Gap {
  static const s = SizedBox(height: 8, width: 8);
  static const m = SizedBox(height: 12, width: 12);
  static const l = SizedBox(height: 16, width: 16);
  static const xl = SizedBox(height: 24, width: 24);
}

/// Duraciones + curvas comunes
class Dur {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
}

class Curv {
  static const ease = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}
