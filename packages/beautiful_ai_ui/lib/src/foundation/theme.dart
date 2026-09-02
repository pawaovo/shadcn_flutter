import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Semantic colors used by Beautiful AI UI modules.
final class BeautifulUiColors {
  /// Creates a semantic color set.
  const BeautifulUiColors({
    required this.brightness,
    required this.page,
    required this.canvas,
    required this.surface,
    required this.inset,
    required this.hover,
    required this.hoverStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.line,
    required this.lineStrong,
    required this.lineSoft,
    required this.field,
    required this.accent,
    required this.accentInk,
    required this.accentTint,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.destructive,
    required this.destructiveTint,
    required this.tooltipBackground,
    required this.tooltipForeground,
    required this.tooltipMuted,
    required this.tooltipBorder,
  });

  /// The light Beautiful UI foundation colors converted from OKLCH to sRGB.
  const BeautifulUiColors.light()
    : this(
        brightness: Brightness.light,
        page: const Color(0xfffafafb),
        canvas: const Color(0xfff1f2f3),
        surface: const Color(0xffffffff),
        inset: const Color(0xfff7f8f9),
        hover: const Color(0xfff4f5f6),
        hoverStrong: const Color(0xffe7e9eb),
        ink: const Color(0xff1f2124),
        inkMuted: const Color(0xff62656b),
        inkSubtle: const Color(0xff9a9da3),
        line: const Color(0xffecedef),
        lineStrong: const Color(0xffe0e2e5),
        lineSoft: const Color(0xfff3f4f5),
        field: const Color(0xfff2f2f3),
        accent: const Color(0xff0285ff),
        accentInk: const Color(0xff0070dd),
        accentTint: const Color(0xffe9f3ff),
        success: const Color(0xff199a4d),
        successTint: const Color(0xffe8f5ed),
        warning: const Color(0xffef720d),
        warningTint: const Color(0xfffdf1e5),
        destructive: const Color(0xffe3474c),
        destructiveTint: const Color(0xfffcecec),
        tooltipBackground: const Color(0xff25272b),
        tooltipForeground: const Color(0xfff6f7f8),
        tooltipMuted: const Color(0xffa5a8ad),
        tooltipBorder: const Color(0xff3a3c40),
      );

  /// The dark Beautiful UI foundation colors converted from OKLCH to sRGB.
  const BeautifulUiColors.dark()
    : this(
        brightness: Brightness.dark,
        page: const Color(0xff17181a),
        canvas: const Color(0xff1c1d1f),
        surface: const Color(0xff232427),
        inset: const Color(0xff1f2022),
        hover: const Color(0xff2a2b2e),
        hoverStrong: const Color(0xff313236),
        ink: const Color(0xfff2f3f4),
        inkMuted: const Color(0xffa5a8ad),
        inkSubtle: const Color(0xff6c6f75),
        line: const Color(0xff2e3033),
        lineStrong: const Color(0xff3a3c40),
        lineSoft: const Color(0xff27282b),
        field: const Color(0xff2b2c2f),
        accent: const Color(0xff3d9aff),
        accentInk: const Color(0xff7ec0ff),
        accentTint: const Color(0x293d9aff),
        success: const Color(0xff3cbb72),
        successTint: const Color(0x243cbb72),
        warning: const Color(0xfff68f3c),
        warningTint: const Color(0x24f68f3c),
        destructive: const Color(0xffee5c61),
        destructiveTint: const Color(0x24ee5c61),
        tooltipBackground: const Color(0xff111214),
        tooltipForeground: const Color(0xfff2f3f4),
        tooltipMuted: const Color(0xffa5a8ad),
        tooltipBorder: const Color(0xff2e3033),
      );

  /// Whether the palette is light or dark.
  final Brightness brightness;

  /// The outer page background.
  final Color page;

  /// The neutral application canvas.
  final Color canvas;

  /// The standard raised content surface.
  final Color surface;

  /// A recessed surface.
  final Color inset;

  /// The first hover or selection surface.
  final Color hover;

  /// A stronger hover or selection surface.
  final Color hoverStrong;

  /// Primary foreground ink.
  final Color ink;

  /// Secondary foreground ink.
  final Color inkMuted;

  /// Tertiary foreground ink.
  final Color inkSubtle;

  /// Standard hairline color.
  final Color line;

  /// Strong hairline color.
  final Color lineStrong;

  /// Subtle hairline color.
  final Color lineSoft;

  /// Input field background.
  final Color field;

  /// Primary accent.
  final Color accent;

  /// Accent foreground ink.
  final Color accentInk;

  /// Low-emphasis accent background.
  final Color accentTint;

  /// Positive state color.
  final Color success;

  /// Positive state background.
  final Color successTint;

  /// Warning state color.
  final Color warning;

  /// Warning state background.
  final Color warningTint;

  /// Destructive or error state color.
  final Color destructive;

  /// Destructive or error state background.
  final Color destructiveTint;

  /// Floating media and tooltip background.
  final Color tooltipBackground;

  /// Floating media and tooltip foreground.
  final Color tooltipForeground;

  /// Muted foreground on floating dark surfaces.
  final Color tooltipMuted;

  /// Floating surface border.
  final Color tooltipBorder;

  /// Returns a higher-contrast derivative while retaining the same hue roles.
  BeautifulUiColors highContrast() {
    return BeautifulUiColors(
      brightness: brightness,
      page: page,
      canvas: canvas,
      surface: surface,
      inset: inset,
      hover: hoverStrong,
      hoverStrong: hoverStrong,
      ink: ink,
      inkMuted: brightness == Brightness.light
          ? const Color(0xff3a3c40)
          : const Color(0xffd8dadd),
      inkSubtle: inkMuted,
      line: lineStrong,
      lineStrong: inkMuted,
      lineSoft: line,
      field: field,
      accent: accent,
      accentInk: accentInk,
      accentTint: accentTint,
      success: success,
      successTint: successTint,
      warning: warning,
      warningTint: warningTint,
      destructive: destructive,
      destructiveTint: destructiveTint,
      tooltipBackground: tooltipBackground,
      tooltipForeground: tooltipForeground,
      tooltipMuted: tooltipMuted,
      tooltipBorder: tooltipBorder,
    );
  }
}

/// The Beautiful UI radius scale in logical pixels.
final class BeautifulUiRadii {
  /// Creates a radius scale.
  const BeautifulUiRadii({
    this.chip = 6,
    this.control = 8,
    this.card = 10,
    this.window = 14,
  });

  /// Chip corner radius.
  final double chip;

  /// Control corner radius.
  final double control;

  /// Card corner radius.
  final double card;

  /// Window and large overlay corner radius.
  final double window;
}

/// The Beautiful UI spacing scale in logical pixels.
final class BeautifulUiSpacing {
  /// Creates a spacing scale.
  const BeautifulUiSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.xxl = 32,
  });

  /// Extra-small spacing.
  final double xs;

  /// Small spacing.
  final double sm;

  /// Medium spacing.
  final double md;

  /// Large spacing.
  final double lg;

  /// Extra-large spacing.
  final double xl;

  /// Two-times extra-large spacing.
  final double xxl;
}

/// Semantic type styles used by Beautiful AI UI modules.
final class BeautifulUiTypography {
  /// Creates the initial foundation typography.
  ///
  /// Geist is a bundled, license-tracked fallback during the first vertical
  /// slice. The semantic interface permits adopting Inter and JetBrains Mono
  /// without changing module call sites.
  const BeautifulUiTypography({
    this.body = const TextStyle(
      fontFamily: 'GeistSans',
      package: 'shadcn_flutter',
      fontSize: 14,
      height: 1.5,
      letterSpacing: -0.14,
    ),
    this.label = const TextStyle(
      fontFamily: 'GeistSans',
      package: 'shadcn_flutter',
      fontSize: 13,
      height: 1.5,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.13,
    ),
    this.caption = const TextStyle(
      fontFamily: 'GeistSans',
      package: 'shadcn_flutter',
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w400,
    ),
    this.mono = const TextStyle(
      fontFamily: 'GeistMono',
      package: 'shadcn_flutter',
      fontSize: 12,
      height: 1.5,
      letterSpacing: -0.12,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
  });

  /// Standard body style.
  final TextStyle body;

  /// Emphasized control and status label style.
  final TextStyle label;

  /// Supporting metadata style.
  final TextStyle caption;

  /// Monospace metadata and code style.
  final TextStyle mono;
}

/// Semantic shadow stacks used by Beautiful AI UI surfaces.
final class BeautifulUiShadows {
  /// Creates a shadow stack.
  const BeautifulUiShadows({
    this.card = const <BoxShadow>[
      BoxShadow(color: Color(0x0f000000), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3)),
    ],
    this.raised = const <BoxShadow>[
      BoxShadow(color: Color(0x1a000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
    this.overlay = const <BoxShadow>[
      BoxShadow(
        color: Color(0x0d000000),
        blurRadius: 50,
        offset: Offset(0, 25),
      ),
      BoxShadow(
        color: Color(0x0a000000),
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
      BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 6)),
      BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 3)),
      BoxShadow(
        color: Color(0x05000000),
        blurRadius: 3,
        offset: Offset(0, 1.5),
      ),
    ],
    this.overlayOutline = const Color(0xffecedef),
  });

  /// Creates the source-derived light shadow stack.
  const BeautifulUiShadows.light() : this();

  /// Creates the source-derived dark shadow stack.
  const BeautifulUiShadows.dark()
    : this(
        card: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        raised: const <BoxShadow>[
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        overlay: const <BoxShadow>[
          BoxShadow(
            color: Color(0x57000000),
            blurRadius: 28,
            offset: Offset(0, 8),
          ),
        ],
        overlayOutline: const Color(0x26ffffff),
      );

  /// Standard card shadow.
  final List<BoxShadow> card;

  /// Raised surface shadow.
  final List<BoxShadow> raised;

  /// Floating overlay shadow.
  final List<BoxShadow> overlay;

  /// Hairline color painted around floating overlays.
  final Color overlayOutline;
}

/// Complete semantic theme data for Beautiful AI UI modules.
final class BeautifulUiThemeData {
  /// Creates a theme from semantic token groups.
  const BeautifulUiThemeData({
    required this.colors,
    this.radii = const BeautifulUiRadii(),
    this.spacing = const BeautifulUiSpacing(),
    this.typography = const BeautifulUiTypography(),
    this.shadows = const BeautifulUiShadows(),
    this.motion = const BeautifulUiMotion(),
  });

  /// Creates the default light theme.
  const BeautifulUiThemeData.light()
    : this(
        colors: const BeautifulUiColors.light(),
        shadows: const BeautifulUiShadows.light(),
      );

  /// Creates the default dark theme.
  const BeautifulUiThemeData.dark()
    : this(
        colors: const BeautifulUiColors.dark(),
        shadows: const BeautifulUiShadows.dark(),
      );

  /// Semantic colors.
  final BeautifulUiColors colors;

  /// Semantic corner radii.
  final BeautifulUiRadii radii;

  /// Semantic spacing.
  final BeautifulUiSpacing spacing;

  /// Semantic type styles.
  final BeautifulUiTypography typography;

  /// Semantic shadows.
  final BeautifulUiShadows shadows;

  /// Semantic motion.
  final BeautifulUiMotion motion;

  /// Returns a theme derivative for the platform high-contrast preference.
  BeautifulUiThemeData highContrast() {
    return BeautifulUiThemeData(
      colors: colors.highContrast(),
      radii: radii,
      spacing: spacing,
      typography: typography,
      shadows: shadows,
      motion: motion,
    );
  }
}

/// Provides [BeautifulUiThemeData] to a subtree.
final class BeautifulUiTheme extends InheritedTheme {
  /// Creates a theme scope.
  const BeautifulUiTheme({super.key, required this.data, required super.child});

  /// The semantic theme data for the subtree.
  final BeautifulUiThemeData data;

  /// Returns the closest theme or throws a descriptive [FlutterError].
  static BeautifulUiThemeData of(BuildContext context) {
    final theme = maybeOf(context);
    if (theme == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No BeautifulUiTheme found.'),
        ErrorDescription(
          'Wrap the application or subtree in a BeautifulUiScope before '
          'building Beautiful AI UI modules.',
        ),
      ]);
    }
    return theme;
  }

  /// Returns the closest theme, or null when none is installed.
  static BeautifulUiThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BeautifulUiTheme>()?.data;
  }

  @override
  bool updateShouldNotify(BeautifulUiTheme oldWidget) {
    return oldWidget.data != data;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    final ancestor = context.findAncestorWidgetOfExactType<BeautifulUiTheme>();
    return identical(this, ancestor)
        ? child
        : BeautifulUiTheme(data: data, child: child);
  }
}
