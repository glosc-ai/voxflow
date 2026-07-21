import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final app = defaultTargetPlatform == TargetPlatform.windows
      ? const ExcludeSemantics(child: VoxFlowBootstrap())
      : const VoxFlowBootstrap();
  runApp(app);
}
