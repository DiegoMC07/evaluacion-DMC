import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/deliveries_list_screen.dart';

void main() {
  runApp(const PaquexpressApp());
}

class PaquexpressApp extends StatelessWidget {
  const PaquexpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paquexpress',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
      routes: {
        '/deliveries': (_) => const DeliveriesListScreen(),
      },
    );
  }
}
