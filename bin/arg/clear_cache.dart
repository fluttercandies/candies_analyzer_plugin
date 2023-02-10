import 'dart:io';

import 'package:io/ansi.dart';

import 'arg.dart';
import 'package:path/path.dart' as path;

class ClearCache extends Argument<bool> {
  @override
  String? get abbr => null;

  @override
  bool get defaultsTo => false;

  @override
  String get help => 'Clear cache under .dartServer/.plugin_manager/';

  @override
  String get name => 'clear-cache';

  @override
  void run() {
    String? home;
    final Map<String, String> envVars = Platform.environment;
    if (Platform.isMacOS) {
      home = envVars['HOME'];
    } else if (Platform.isLinux) {
      home = envVars['HOME'];
    } else if (Platform.isWindows) {
      home = envVars['UserProfile'];
    }

    if (home != null) {
      Directory? directory;
      // macos:  `/Users/user_name/.dartServer/.plugin_manager/`
      // windows: `C:\Users\user_name\AppData\Local\.dartServer\.plugin_manager\`
      if (Platform.isMacOS) {
        directory =
            Directory(path.join(home, '.dartServer', '.plugin_manager'));
      } else if (Platform.isLinux) {
        directory =
            Directory(path.join(home, '.dartServer', '.plugin_manager'));
      } else if (Platform.isWindows) {
        directory = Directory(path.join(
            home, 'AppData', 'Local', '.dartServer', '.plugin_manager'));
      }

      if (directory != null && directory.existsSync()) {
        print(green.wrap('clear plugin_manager cache successfully!'));
        directory.deleteSync(recursive: true);
      }
    }
  }
}
