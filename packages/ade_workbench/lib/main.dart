import 'package:flutter/widgets.dart';

import 'workbench.dart';
import 'workbench_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(WorkbenchApp(controller: await WorkbenchController.load()));
}
