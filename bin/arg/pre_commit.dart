import 'dart:io';

import 'arg.dart';
import 'package:path/path.dart' as path;

class PreCommit extends Argument<bool> {
  @override
  String? get abbr => null;

  @override
  bool get defaultsTo => false;

  @override
  String get help => 'Create a pre-commit script in .git/hooks';

  @override
  String get name => 'pre-commit';

  final String preCommitDartFile =
      path.join('tools', 'analyzer_plugin', 'bin', 'pre_commit.dart');

  File? findPreCommitFile(Directory directory) {
    for (final FileSystemEntity file in directory.listSync()) {
      if (file is Directory && !path.basename(file.path).startsWith('.')) {
        final File? dartFile = findPreCommitFile(file);
        if (dartFile != null) {
          return dartFile;
        }
      } else if (file is File && file.path.endsWith(preCommitDartFile)) {
        return file;
      }
    }

    return null;
  }

  @override
  void run() {
    final String gitRoot = processRun(
      executable: 'git',
      arguments: 'rev-parse --show-toplevel',
      //runInShell: true,
      printInfo: false,
    ).trim();

    final File preCommitSH =
        File(path.join(gitRoot, '.git', 'hooks', 'pre-commit'));

    final File? file = findPreCommitFile(Directory(gitRoot));
    if (file != null) {
      if (preCommitSH.existsSync()) {
        preCommitSH.deleteSync();
      }
      preCommitSH.createSync();
      final String source = Directory.current.path;
      final File localConfig = File(path.join(source, 'pre-commit'));
      String demo = preCommitSHDemo;
      if (localConfig.existsSync()) {
        demo = localConfig.readAsStringSync();
      }
      preCommitSH.writeAsString(
        demo
            .replaceAll(
              '{0}',
              source,
            )
            .replaceAll('{1}', file.path),
      );
      if (Platform.isMacOS || Platform.isLinux) {
        processRun(
          executable: 'chmod',
          arguments: '777 ${preCommitSH.path}',
          printInfo: false,
        );
      }
      print('${preCommitSH.path} has created');
    } else {
      print(
          'not find pre_commit.dart, please run \'candies_analyzer_plugin plugin_name\' first.');
    }
  }
}

const String preCommitSHDemo = '''
#!/bin/sh

# project path
base_dir="{0}"

dart format "\$base_dir"

# pre_commit.dart path
pre_commit="{1}"
 
echo "Checking the code before submit..."
echo "Analyzing \$base_dir..."

info=\$(dart "\$pre_commit" "\$base_dir")

echo "\$info"

if [[ -n \$info && \$info != *"No issues found"* ]];then
exit 1
fi
''';
