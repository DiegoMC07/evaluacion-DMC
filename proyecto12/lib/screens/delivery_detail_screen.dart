import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final Map paquete;
  const DeliveryDetailScreen({super.key, required this.paquete});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  final api = ApiService();
  XFile? imageFile;
  Position? position;
  bool uploading = false;
  bool gettingLocation = false;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file != null) setState(() => imageFile = file);
  }

  Future<void> _getLocation() async {
    try {
      setState(() => gettingLocation = true);
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable location services')));
        setState(() => gettingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied forever')));
        setState(() => gettingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => position = pos);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    } finally {
      setState(() => gettingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Capture una foto')));
      return;
    }
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Obtenga ubicación')));
      return;
    }
    setState(() => uploading = true);

    // agent id from token
    final agentId = await api.getAgentIdFromToken();
    if (agentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo obtener agent id desde token')));
      setState(() => uploading = false);
      return;
    }

    final ok = await api.subirEntrega(
      paqueteId: widget.paquete['id'] is int ? widget.paquete['id'] as int : int.parse(widget.paquete['id'].toString()),
      agenteId: agentId,
      lat: position!.latitude,
      lon: position!.longitude,
      filePath: imageFile!.path,
    );

    setState(() => uploading = false);
    if (ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrega registrada correctamente')));
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al registrar entrega')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final paq = widget.paquete;
    return Scaffold(
      appBar: AppBar(title: Text(paq['referencia'] ?? 'Detalle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(paq['direccion'] ?? '', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          if (imageFile != null) Image.file(File(imageFile!.path), height: 220, fit: BoxFit.cover),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.camera_alt), label: const Text('Tomar foto')),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: gettingLocation ? null : _getLocation,
            icon: const Icon(Icons.my_location),
            label: gettingLocation ? const Text('Obteniendo ubicación...') : const Text('Obtener ubicación'),
          ),
          const SizedBox(height: 8),
          if (position != null) Text('Lat: ${position!.latitude.toStringAsFixed(6)}, Lon: ${position!.longitude.toStringAsFixed(6)}'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: uploading ? null : _submit,
            child: uploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Paquete entregado'),
          )
        ]),
      ),
    );
  }
}
