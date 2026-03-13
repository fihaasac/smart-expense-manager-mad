import 'package:flutter/material.dart';

void main() {
  runApp(const FinTrackApp());
}

class FinTrackApp extends StatelessWidget {
  const FinTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FinTrack',
      home: Scaffold(
        appBar: AppBar(
          title: const Text("FinTrack Skeleton"),
          centerTitle: true,
        ),
        body: const Center(
          child: Text("Waiting for team to push UI..."),
        ),
      ),
    );
  }
}