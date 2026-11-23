import 'package:flutter/material.dart';
import 'demo/demo_controller_page.dart';
import 'demo/generated_demo_contract.dart';

// Independent entry point: no Firebase, AppState, account or notification bootstrap.
void main() => runApp(const PrototypeDemoApp());

class PrototypeDemoApp extends StatelessWidget {
  const PrototypeDemoApp({super.key, this.home = const DemoControllerPage()});
  final Widget home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Prototype Demo Controller',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Color(demoPalette['background']!),
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: Color(demoPalette['primary']!),
            brightness: Brightness.dark,
          ).copyWith(
            primary: Color(demoPalette['primary']!),
            secondary: Color(demoPalette['ready']!),
            surface: Color(demoPalette['background']!),
            onSurface: Color(demoPalette['text']!),
          ),
      useMaterial3: true,
    ),
    home: home,
  );
}
