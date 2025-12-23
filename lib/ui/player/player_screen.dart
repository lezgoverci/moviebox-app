import 'package:flutter/material.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Text("Video Player Placeholder\nAuthentication & Stream Extraction logic needed.", 
                style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
        ),
    );
  }
}
