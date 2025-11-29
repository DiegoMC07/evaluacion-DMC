import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Importar para usar kIsWeb
import 'package:geolocator/geolocator.dart'; 
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> paquete;

  const DeliveryDetailScreen({super.key, required this.paquete});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;
  XFile? _pickedFile; 
  
  String? _deliveredPhotoUrl;
  String _currentStatus = 'PENDIENTE';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.paquete['estado'] ?? 'PENDIENTE'; 
  }

  // --- Manejadores de Interacción ---

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _pickedFile = photo;
      });
    }
  }

  Future<void> _completeDelivery() async {
    if (_pickedFile == null) {
      _showSnackBar('Debe tomar una foto para completar la entrega.');
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Obtener Ubicación (Lat/Lon)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      // 2. Obtener ID del Agente
      final agenteId = await _apiService.getStoredAgentId();
      if (agenteId == null) {
        throw Exception('ID de Agente no disponible. Por favor, vuelva a iniciar sesión.');
      }
      
      // 3. OBTENER LOS BYTES DEL ARCHIVO (CLAVE para API Service corregido)
      final fileBytes = await _pickedFile!.readAsBytes();
      final fileName = _pickedFile!.name;


      // 4. Subir Entrega usando los bytes (compatible con Web y Móvil)
      final String? photoUrl = await _apiService.subirEntrega(
        paqueteId: widget.paquete['id'] as int,
        agenteId: agenteId,
        lat: position.latitude,
        lon: position.longitude,
        fileBytes: fileBytes, // ¡CORREGIDO! Pasamos los bytes
        fileName: fileName,   // ¡CORREGIDO! Pasamos el nombre
      );

      // 5. Lógica de Actualización de Estado y Cierre
      if (photoUrl != null) {
        _showSnackBar('Entrega registrada con éxito.');
        if (mounted) {
          setState(() {
            _deliveredPhotoUrl = photoUrl;
            _currentStatus = 'ENTREGADO';
            _pickedFile = null; 
          });
        }
        
        if (mounted) {
          // Devuelve 'true' para que la lista sepa que debe recargar
          Navigator.pop(context, true); 
        }

      } else {
        _showSnackBar('Fallo al registrar la entrega. Intente nuevamente.');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // --- Construcción de la Interfaz ---

  @override
  Widget build(BuildContext context) {
    final isDelivered = _currentStatus == 'ENTREGADO';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.paquete['referencia'] ?? 'Detalle del Paquete'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Estatus
            Card(
              color: isDelivered ? Colors.green.shade100 : Colors.orange.shade100,
              margin: const EdgeInsets.only(bottom: 20),
              child: ListTile(
                leading: Icon(
                  isDelivered ? Icons.check_circle_outline : Icons.pending,
                  color: isDelivered ? Colors.green.shade700 : Colors.orange.shade700,
                ),
                title: Text(
                  'Estado Actual: $_currentStatus',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDelivered ? Colors.green.shade900 : Colors.orange.shade900,
                  ),
                ),
                subtitle: isDelivered
                    ? const Text('El paquete ha sido entregado exitosamente.')
                    : const Text('Pendiente de entrega.'),
              ),
            ),

            // Información del Paquete
            Text(
              'Dirección:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(widget.paquete['direccion'] ?? 'Dirección no especificada', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            Text(
              'Receptor:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(widget.paquete['receptor_nombre'] ?? 'Desconocido', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),

            // Sección de Foto (Entrega Pendiente)
            if (!isDelivered) ...[
              Text(
                'Evidencia de Entrega (Foto):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              
              if (_pickedFile != null)
                // --- PUNTO CLAVE: CORRECCIÓN PARA VISUALIZACIÓN WEB/MOBILE ---
                kIsWeb 
                  ? Image.network( // Usar Image.network para la web (el path es una URL temporal)
                      _pickedFile!.path,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.file( // Usar Image.file para mobile/desktop
                      File(_pickedFile!.path),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                // ---------------------------------------------------
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Text('No hay foto capturada', style: TextStyle(color: Colors.grey)),
                ),
              
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Tomar Foto'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Botón de Entrega
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _pickedFile != null && !_loading ? _completeDelivery : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('MARCAR COMO ENTREGADO', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],

            // Sección de Foto (Entrega Completada)
            if (isDelivered && _deliveredPhotoUrl != null) ...[
              const Divider(height: 40),
              Text(
                'Foto de Evidencia Registrada:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Image.network(
                _deliveredPhotoUrl!,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.red.shade100,
                  alignment: Alignment.center,
                  child: const Text('Error al cargar la imagen. Revise la Base URL.', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
            
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}