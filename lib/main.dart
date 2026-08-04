import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  final app = defaultTargetPlatform == TargetPlatform.windows
      ? const ExcludeSemantics(child: VoxFlowBootstrap())
      : const VoxFlowBootstrap();
  runApp(app);
}
