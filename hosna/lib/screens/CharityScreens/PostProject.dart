import 'package:flutter/material.dart';

class PostProjectPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Post a New Project")),
      body: Center(
        child: Text("Form to create a new project."),
      ),
    );
  }
}
