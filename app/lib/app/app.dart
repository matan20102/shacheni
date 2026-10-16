import 'package:flutter/material.dart';

import 'config.dart';
import '../features/building/building_app.dart';
import '../features/building/building_connected_app.dart';

class NayborApp extends StatelessWidget {
  const NayborApp({super.key});

  @override
  Widget build(BuildContext context) => kBackendConfigured
      ? const BuildingConnectedApp()
      : const BuildingPreviewApp();
}
