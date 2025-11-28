import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'delivery_detail_screen.dart';

class DeliveriesListScreen extends StatefulWidget {
  const DeliveriesListScreen({super.key});

  @override
  State<DeliveriesListScreen> createState() => _DeliveriesListScreenState();
}

class _DeliveriesListScreenState extends State<DeliveriesListScreen> {
  final api = ApiService();
  List paquetes = [];
  bool loading = true;
  int? agentIdFromArgs;

  @override
  void initState() {
    super.initState();
    // wait for route arguments to load
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    int? agentId;
    if (args is Map && args.containsKey('agentId')) agentId = args['agentId'] as int?;
    agentIdFromArgs = agentId;
    try {
      int? id = agentId ?? await api.getAgentIdFromToken();
      if (id == null) {
        // ask user for id (simple fallback)
        final text = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final ctl = TextEditingController();
            return AlertDialog(
              title: const Text('Agent ID required'),
              content: TextField(controller: ctl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Enter your agent id')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('OK')),
              ],
            );
          },
        );
        if (text == null) {
          setState(() => loading = false);
          return;
        }
        id = int.tryParse(text);
      }

      if (id == null) throw Exception('Invalid agent id');
      final data = await api.getPaquetesAsignados(id);
      setState(() {
        paquetes = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paquetes asignados')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : paquetes.isEmpty
              ? const Center(child: Text('No hay paquetes asignados'))
              : ListView.builder(
                  itemCount: paquetes.length,
                  itemBuilder: (context, i) {
                    final p = paquetes[i];
                    return ListTile(
                      title: Text(p['referencia'] ?? 'Sin referencia'),
                      subtitle: Text(p['direccion'] ?? ''),
                      trailing: Text(p['estado'] ?? ''),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DeliveryDetailScreen(paquete: p)),
                        ).then((_) => _load());
                      },
                    );
                  },
                ),
    );
  }
}
