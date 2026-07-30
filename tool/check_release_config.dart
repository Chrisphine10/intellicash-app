// Refuses to build a release pointed at the wrong backend.
//
//   dart run tool/check_release_config.dart          # checks .env
//   dart run tool/check_release_config.dart path.env # checks a specific file
//
// Exits 1 with an explanation when the configuration would produce a bad
// release. Wired into the Gradle release build, so `flutter build apk
// --release` fails rather than silently shipping.
//
// The app already reports this at RUNTIME, but only by logging — by then the
// APK exists and may be on a phone. A build that cannot be produced is a
// stronger guarantee than a warning nobody reads.

import 'dart:io';

/// Hosts that mean "a developer's machine". A release pointing at one of these
/// looks like a dead server to whoever installed it.
const devHosts = {'localhost', '127.0.0.1', '10.0.2.2', '0.0.0.0'};

/// Returns a problem description, or null when the config is sound.
/// Pure so it can be tested without touching the filesystem.
String? releaseConfigProblem(String envContents) {
  final line = RegExp(r'^\s*IC_BASE_URL\s*=\s*(.+)$', multiLine: true)
      .firstMatch(envContents)
      ?.group(1)
      ?.trim();

  if (line == null || line.isEmpty) {
    return 'IC_BASE_URL is not set. A release with no backend cannot sign anyone in.';
  }

  final uri = Uri.tryParse(line);
  if (uri == null || uri.host.isEmpty) {
    return 'IC_BASE_URL is not a valid URL: "$line".';
  }

  if (devHosts.contains(uri.host)) {
    return 'IC_BASE_URL points at a development machine ($line). '
        'Members would see a dead server.';
  }

  if (uri.scheme != 'https') {
    return 'IC_BASE_URL is not https ($line). A release would send members\' '
        'passwords in the clear.';
  }

  // An APK is a public artifact: anyone can unzip it and read what is inside.
  final key = RegExp(r'^\s*IC_API_KEY\s*=\s*(\S+)', multiLine: true)
      .firstMatch(envContents)
      ?.group(1);
  if (key != null && key.isNotEmpty) {
    return 'IC_API_KEY is set. Release ignores it, and shipping it in an APK '
        'publishes the key. Comment it out.';
  }

  return null;
}

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : '.env';
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('RELEASE CONFIG: $path is missing. Copy .env.example and set IC_BASE_URL.');
    exit(1);
  }

  final problem = releaseConfigProblem(file.readAsStringSync());
  if (problem != null) {
    stderr.writeln('');
    stderr.writeln('RELEASE BUILD REFUSED');
    stderr.writeln('  $problem');
    stderr.writeln('  Fix $path, then build again.');
    stderr.writeln('');
    exit(1);
  }

  stdout.writeln('Release config OK — backend is https and no API key is bundled.');
}
