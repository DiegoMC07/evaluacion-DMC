import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final api = ApiService();
  bool loading = false;

  void _login() async {
    setState(() => loading = true);
    final ok = await api.login(_emailC.text.trim(), _passC.text.trim());
    setState(() => loading = false);
    if (ok) {
      // try to read agent id from token
      final agentId = await api.getAgentIdFromToken();
      if (agentId != null) {
        Navigator.pushReplacementNamed(context, '/deliveries', arguments: {'agentId': agentId});
      } else {
        // if no id in token, navigate to deliveries without id and let screen ask for it
        Navigator.pushReplacementNamed(context, '/deliveries');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed: check credentials')));
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paquexpress - Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _emailC, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _passC, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : _login,
              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Login'),
            )
          ],
        ),
      ),
    );
  }
}
