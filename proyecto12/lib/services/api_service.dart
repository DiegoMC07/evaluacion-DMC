import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Ajusta esto si pruebas en dispositivo físico (ip de la máquina)
  static const String baseUrl = 'http://127.0.0.1:8000';
  final storage = const FlutterSecureStorage();

  // Guarda token (secure)
  Future<void> saveToken(String token) async {
    await storage.write(key: 'token', value: token);
  }

  Future<String?> getToken() async {
    return await storage.read(key: 'token');
  }

  Future<void> deleteToken() async {
    await storage.delete(key: 'token');
  }

  // LOGIN -> endpoint /login (OAuth2PasswordRequestForm style)
  Future<bool> login(String email, String password) async {
  final url = Uri.parse('$baseUrl/login');

  final resp = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email.trim(),
      'password': password.trim(),
    }),
  );

  if (resp.statusCode == 200) {
    final j = json.decode(resp.body);
    final token = j['access_token'] as String?;
    if (token != null) {
      await saveToken(token);
      return true;
    }
  }

  if (kDebugMode) {
    print("LOGIN ERROR -> ${resp.statusCode} ${resp.body}");
  }

  return false;
}

  // Helper: decode JWT payload without verifying to get agent id (sub and id)
  Map<String, dynamic>? decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      String normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) print('JWT decode error: $e');
      return null;
    }
  }

  // GET paquetes asignados para agente
  Future<List<dynamic>> getPaquetesAsignados(int agenteId) async {
    final url = Uri.parse('$baseUrl/paquetes/$agenteId');
    final token = await getToken();
    final resp = await http.get(url, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
      'Accept': 'application/json'
    });
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Error fetching paquetes: ${resp.statusCode} ${resp.body}');
    }
  }

  // Subir entrega: multipart -> campo foto es 'foto'
  Future<bool> subirEntrega({
    required int paqueteId,
    required int agenteId,
    required double lat,
    required double lon,
    required String filePath,
  }) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl/entregar');
    final request = http.MultipartRequest('POST', url);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    request.fields['paquete_id'] = paqueteId.toString();
    request.fields['agente_id'] = agenteId.toString();
    request.fields['lat_gps'] = lat.toString();
    request.fields['lon_gps'] = lon.toString();

    final file = await http.MultipartFile.fromPath('foto', filePath);
    request.files.add(file);

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (kDebugMode) print('subirEntrega resp: ${resp.statusCode} ${resp.body}');
    return resp.statusCode == 200;
  }

  // Extra: obtener agente id directamente del token (si está en payload como "id")
  Future<int?> getAgentIdFromToken() async {
    final token = await getToken();
    if (token == null) return null;
    final payload = decodeJwtPayload(token);
    if (payload == null) return null;
    if (payload.containsKey('id')) {
      final idVal = payload['id'];
      if (idVal is int) return idVal;
      if (idVal is String) return int.tryParse(idVal);
      if (idVal is double) return idVal.toInt();
    }
    // fallback: maybe sub is email; in that case, you would need another endpoint to fetch user id.
    return null;
  }
}
