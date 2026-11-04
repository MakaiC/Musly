/// Indices of [MainScreen]'s tabs (phone tab bars and the desktop sidebar).
///
/// Use these instead of bare numbers: the New tab was inserted second, as in
/// Apple Music, and Add in the middle, which moved Library and Search along.
abstract final class MainTabs {
  static const int home = 0;
  static const int newTab = 1;
  static const int add = 2;
  static const int library = 3;
  static const int search = 4;
}
