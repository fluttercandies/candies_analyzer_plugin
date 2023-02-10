/// Font color range: 30-37
/// 30: Black
/// 31: Red
/// 32: Green
/// 33: Yellow
/// 34: Blue
/// 35: Purple
/// 36: Dark Green
/// 37: Gray White
enum AnsiCodeFontColor {
  /// black
  black(30),

  /// red
  red(31),

  /// green
  green(32),

  /// yellow
  yellow(33),

  /// red
  blue(34),

  /// purple
  purple(35),

  /// dark green
  darkGreen(36),

  /// gray white
  grayWhite(37);

  const AnsiCodeFontColor(this.value);
  final int value;
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
  /// black
  black(40),

  /// red
  red(41),

  /// green
  green(42),

  /// yellow
  yellow(43),

  /// red
  blue(44),

  /// purple
  purple(45),

  /// dark green
  darkGreen(46),

  /// gray white
  grayWhite(47);

  const AnsiCodeBackgroundColor(this.value);
  final int value;
}

/// Effect range: 0-8
/// 0: No effect
/// 1: Highlight (darken) display
/// 2: Low light (weaken) display
/// 4: Underline
/// 5: Flicker
/// 7: Reverse (replace background color and font color)
/// 8: Hide
enum AnsiCodeEffect {
  /// no effect
  noEffect(0),

  /// highlight (darken) display
  highlight(1),

  /// Lowlight (weaken) display
  lowlight(2),

  /// underline
  underline(4),

  /// flicker
  flicker(5),

  /// reverse (replace background color and font color)
  reverse(7),

  /// hide
  hide(8);

  const AnsiCodeEffect(this.value);
  final int value;
}

extension AnsiCodeE on String {
  String wrapAnsiCode({
    AnsiCodeFontColor? fontColor,
    AnsiCodeBackgroundColor? backgroundColor,
    AnsiCodeEffect? consoleEffect,
  }) {
    final List<String> infos = <String>[];
    if (backgroundColor != null) {
      infos.add('${backgroundColor.value}');
    }
    if (fontColor != null) {
      infos.add('${fontColor.value}');
    }
    if (consoleEffect != null) {
      infos.add('${consoleEffect.value}');
    }
    // echo '\033[43;34;4m abc \033[0m'
    // \033[0m should call end with it, so that no effect the text after it
    // m is end falg
    if (infos.isNotEmpty) {
      return '\\033[${infos.join(';')}m$this\\033[0m';
    }

    return this;
  }
}
