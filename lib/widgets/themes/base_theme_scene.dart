import 'package:flutter/material.dart';
import '../../models/garden_state.dart';
import '../../services/garden_service.dart';

abstract class BaseThemeScene extends StatefulWidget {
  final bool showStats;
  final bool interactive;

  const BaseThemeScene({
    super.key,
    this.showStats = false,
    this.interactive = false,
  });
}

abstract class BaseThemeSceneState<T extends BaseThemeScene> extends State<T> {
  GardenState get gardenState => GardenService.state;

  bool isUnlocked(String element) => GardenService.isUnlocked(element);
}
