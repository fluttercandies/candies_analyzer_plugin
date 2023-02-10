import 'dart:convert';
import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as path;

import 'arg/arg_parser.dart';
import 'arg/args.dart';
import 'arg/clear_cache.dart';
import 'arg/pre_commit.dart';

void main(List<String> args) {
  parseArgs(args);

  if (args.isEmpty || Args().help.value!) {
    print(green.wrap(parser.usage));
    return;
  }

  Args().run();
}
