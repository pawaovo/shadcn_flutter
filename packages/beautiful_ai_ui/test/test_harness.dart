import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';

Widget beautifulTestApp({
  required Widget child,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  bool highContrast = false,
  BeautifulMotionPolicy motion = BeautifulMotionPolicy.system,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      platformBrightness: brightness,
      disableAnimations: disableAnimations,
      highContrast: highContrast,
      textScaler: textScaler,
    ),
    child: Directionality(
      textDirection: textDirection,
      child: BeautifulUiScope(
        motion: motion,
        child: SizedBox.fromSize(
          size: size,
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}
