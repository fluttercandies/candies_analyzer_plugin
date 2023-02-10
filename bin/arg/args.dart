import 'clear_cache.dart';
import 'help.dart';
import 'example.dart';
import 'pre_commit.dart';

class Args {
  factory Args() => _args ??= Args._();

  Args._()
      : help = Help(),
        example = Example(),
        preCommit = PreCommit(),
        clearCache = ClearCache();
  static Args? _args;
  final Help help;
  final Example example;
  final ClearCache clearCache;
  final PreCommit preCommit;

  void run() {
    if (clearCache.value ?? false) {
      clearCache.run();
    } else if (preCommit.value ?? false) {
      preCommit.run();
    } else if (example.value != null) {
      example.run();
    }
  }
}
