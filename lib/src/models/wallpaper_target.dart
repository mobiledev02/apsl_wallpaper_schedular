/// Which screen(s) the wallpaper should be applied to.
enum WallpaperTarget {
  /// Apply only to the Home Screen.
  homeScreen(1, 'Home Screen'),

  /// Apply only to the Lock Screen.
  lockScreen(2, 'Lock Screen'),

  /// Apply to both Home Screen and Lock Screen.
  both(3, 'Both Screens');

  /// The integer value stored internally and passed to the native plugin.
  final int value;

  /// A human-readable label.
  final String label;

  const WallpaperTarget(this.value, this.label);

  /// Returns the [WallpaperTarget] for a given [value].
  /// Falls back to [both] for unknown values.
  static WallpaperTarget fromValue(int value) {
    return WallpaperTarget.values.firstWhere(
      (t) => t.value == value,
      orElse: () => WallpaperTarget.both,
    );
  }
}
