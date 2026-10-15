import 'package:flutter/material.dart';
import 'agent_home.dart';

void main() => runApp(const QuickSupportAgentApp());

class QuickSupportAgentApp extends StatelessWidget {
  const QuickSupportAgentApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'QuickSupport Agent',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true),
        home: const AgentHome(),
      );
}
