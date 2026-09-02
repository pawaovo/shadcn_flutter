/// The adaptive presentation selected for the available width.
enum BeautifulLayoutMode {
  /// A single-column presentation optimized for constrained widths.
  compact,

  /// An intermediate presentation that can expose selected secondary content.
  medium,

  /// A wide presentation that can expose the complete information hierarchy.
  expanded,
}

/// Width thresholds used as a starting point for adaptive presentation.
///
/// Individual modules still use their local constraints and may choose a more
/// compact presentation when their content does not fit.
final class BeautifulUiBreakpoints {
  /// Creates adaptive thresholds in logical pixels.
  ///
  /// Parameters:
  /// - [mediumFrom] (`double`, default: 600): Positive medium threshold.
  /// - [expandedFrom] (`double`, default: 1024): Threshold greater than
  ///   [mediumFrom].
  ///
  /// Assertions: thresholds must be positive and strictly increasing.
  const BeautifulUiBreakpoints({
    this.mediumFrom = 600,
    this.expandedFrom = 1024,
  }) : assert(mediumFrom > 0),
       assert(expandedFrom > mediumFrom);

  /// The minimum width for [BeautifulLayoutMode.medium].
  final double mediumFrom;

  /// The minimum width for [BeautifulLayoutMode.expanded].
  final double expandedFrom;

  /// Resolves the layout mode for an available logical width.
  ///
  /// Parameters:
  /// - [width] (`double`, required): Finite, non-negative available width.
  ///
  /// Returns: [BeautifulLayoutMode] selected by these thresholds.
  ///
  /// Assertions: [width] must be finite and non-negative.
  BeautifulLayoutMode resolve(double width) {
    assert(width.isFinite && width >= 0);
    if (width < mediumFrom) {
      return BeautifulLayoutMode.compact;
    }
    if (width < expandedFrom) {
      return BeautifulLayoutMode.medium;
    }
    return BeautifulLayoutMode.expanded;
  }
}
