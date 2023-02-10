import 'dart:io';

import 'package:io/ansi.dart' as ansi;

/// Font color range: 30-37
/// 30: Black
/// 31: Red
/// 32: Green
/// 33: Yellow
/// 34: Blue
/// 35: Purple
/// 36: Dark Green
/// 37: Gray White
enum AnsiCodeForegroundColor {
  black(ansi.black),

  red(ansi.red),

  green(ansi.green),

  yellow(ansi.yellow),

  blue(ansi.blue),

  magenta(ansi.magenta),

  cyan(ansi.cyan),

  lightGray(ansi.lightGray),

  defaultForeground(ansi.defaultForeground),

  darkGray(ansi.darkGray),

  lightRed(ansi.lightRed),

  lightGreen(ansi.lightGreen),

  lightYellow(ansi.lightYellow),

  lightBlue(ansi.lightBlue),

  lightMagenta(ansi.lightMagenta),

  lightCyan(ansi.lightCyan),

  white(ansi.white);

  const AnsiCodeForegroundColor(this.value);
  final ansi.AnsiCode value;
}

/// Background color range: 40-47
/// 40: Black
/// 41: Red
/// 42: Green
/// 43: Yellow
/// 44: Blue
/// 45: Purple
/// 46: Dark Green
/// 47: Gray White
enum AnsiCodeBackgroundColor {
  black(ansi.backgroundBlack),

  red(ansi.backgroundRed),

  green(ansi.backgroundGreen),

  yellow(ansi.backgroundYellow),

  blue(ansi.backgroundBlue),

  purple(ansi.backgroundMagenta),

  darkGreen(ansi.backgroundCyan),

  grayWhite(ansi.backgroundLightGray),

  backgroundDefault(ansi.backgroundDefault),

  gray(ansi.backgroundDarkGray),

  lightRed(ansi.backgroundLightRed),

  lightGreen(ansi.backgroundLightGreen),

  lightYellow(ansi.backgroundLightYellow),

  lightBlue(ansi.backgroundLightBlue),

  lightMagenta(ansi.backgroundLightMagenta),

  lightCyan(ansi.backgroundLightCyan),

  white(ansi.backgroundWhite);

  const AnsiCodeBackgroundColor(this.value);
  final ansi.AnsiCode value;
}

/// Effect range: 0-8
/// 0: No effect
/// 1: Highlight (darken) display
/// 2: Low light (weaken) display
/// 3: italic
/// 4: Underline
/// 5: Flicker
/// 7: Reverse (replace background color and font color)
/// 8: Hide
/// 9: crossedOut
enum AnsiCodeStyle {
  /// no effect
  noEffect(ansi.resetAll),

  /// highlight (darken) display
  bold(ansi.styleBold),

  /// Lowlight (weaken) display
  dim(ansi.styleDim),

  /// italic

  italic(ansi.styleItalic),

  /// underline
  underlined(ansi.styleUnderlined),

  /// flicker
  blink(ansi.styleBlink),

  /// reverse (replace background color and font color)
  reverse(ansi.styleReverse),

  /// hide
  hidden(ansi.styleHidden),

  /// crossedOut
  crossedOut(ansi.styleCrossedOut);

  const AnsiCodeStyle(this.value);
  final ansi.AnsiCode value;
}

extension AnsiCodeE on String {
  String wrapAnsiCode({
    AnsiCodeForegroundColor? foregroundColor,
    AnsiCodeBackgroundColor? backgroundColor,
    AnsiCodeStyle? style,
  }) {
    // color is not working in pre-commit shell at Windows.
    if (Platform.isWindows) {
      return this;
    }
    // echo '\033[43;34;4m abc \033[0m'
    // \033[0m should call end with it, so that no effect the text after it
    // m is end falg
    return ansi.wrapWith(
          this,
          <ansi.AnsiCode>[
            if (foregroundColor != null) foregroundColor.value,
            if (backgroundColor != null) backgroundColor.value,
            if (style != null) style.value,
          ],
          // \\033[0m
          forScript: true,
        ) ??
        this;
  }
}
