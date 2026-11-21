import 'package:flutter/material.dart';

/// Shows [message] in the nearest [ScaffoldMessenger].
void showSnackBarMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
