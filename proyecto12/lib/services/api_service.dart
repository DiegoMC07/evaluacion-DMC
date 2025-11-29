import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
	// URL base — ajusta según el dispositivo
	// 10.0.2.2 = Android Emulator
	// 127.0.0.1 = iOS/Web/Desktop
	static const String baseUrl = 'http://127.0.0.1:8000';

	final storage = const FlutterSecureStorage();

	// --------------------------
	// STORAGE HELPERS
	// --------------------------

	Future<void> saveToken(String token) async {
		await storage.write(key: 'token', value: token);
	}

	Future<void> saveAgentId(int agentId) async {
		await storage.write(key: 'agentId', value: agentId.toString());
	}

	Future<String?> getToken() async {
		return await storage.read(key: 'token');
	}

	Future<int?> getStoredAgentId() async {
		final idString = await storage.read(key: 'agentId');
		return idString != null ? int.tryParse(idString) : null;
	}

	Future<void> deleteToken() async {
		await storage.delete(key: 'token');
		await storage.delete(key: 'agentId');
	}

	// --------------------------
	// LOGIN
	// --------------------------

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
			final token = j['token'] as String?;
			final agentId = j['agentId'] as int?;

			if (token != null && agentId != null) {
				await saveToken(token);
				await saveAgentId(agentId);
				return true;
			}
		}

		if (kDebugMode) {
			print("LOGIN ERROR -> ${resp.statusCode} ${resp.body}");
		}

		return false;
	}

	// --------------------------
	// GET AGENT ID
	// --------------------------

	Future<int?> getAgentIdFromToken() async {
		return await getStoredAgentId();
	}

	// Solo se conserva como helper opcional
	Map<String, dynamic>? decodeJwtPayload(String token) {
		try {
			final parts = token.split('.');
			if (parts.length != 3) return null;
			final payload = parts[1];
			final normalized = base64Url.normalize(payload);
			final decoded = utf8.decode(base64Url.decode(normalized));
			return json.decode(decoded) as Map<String, dynamic>;
		} catch (e) {
			if (kDebugMode) print('JWT decode error: $e');
			return null;
		}
	}

	// --------------------------
	// OBTENER PAQUETES
	// --------------------------

	Future<List<dynamic>> getPaquetesAsignados(int agenteId) async {
		final url = Uri.parse('$baseUrl/paquetes/$agenteId');
		final token = await getToken();

		final resp = await http.get(
			url,
			headers: {
				if (token != null) 'Authorization': 'Bearer $token',
				'Accept': 'application/json'
			},
		);

		if (resp.statusCode == 200) {
			return json.decode(resp.body) as List<dynamic>;
		}

		if (kDebugMode) {
			print('Error fetching paquetes: ${resp.statusCode} ${resp.body}');
		}

		if (resp.statusCode == 401) {
			await deleteToken();
		}

		throw Exception('Error fetching paquetes: ${resp.statusCode} ${resp.body}');
	}

	// --------------------------
	// SUBIR ENTREGA (con bytes)
	// --------------------------

	Future<String?> subirEntrega({
		required int paqueteId,
		required int agenteId,
		required double lat,
		required double lon,
		required Uint8List fileBytes,
		required String fileName,
	}) async {
		final token = await getToken();
		final url = Uri.parse('$baseUrl/entregar');

		final request = http.MultipartRequest('POST', url);

		if (token != null) {
			request.headers['Authorization'] = 'Bearer $token';
		}

		request.fields['paquete_id'] = paqueteId.toString();
		request.fields['agente_id'] = agenteId.toString();
		request.fields['lat_gps'] = lat.toString();
		request.fields['lon_gps'] = lon.toString();

		final file = http.MultipartFile.fromBytes(
			'foto',
			fileBytes,
			filename: fileName,
			contentType: MediaType('image', 'jpeg'),
		);

		request.files.add(file);

		final streamed = await request.send();
		final resp = await http.Response.fromStream(streamed);

		if (kDebugMode) {
			print('subirEntrega resp: ${resp.statusCode} ${resp.body}');
		}

		if (resp.statusCode == 200) {
			final jsonResponse = json.decode(resp.body);
			final fotoUrlPath = jsonResponse['foto_url'] as String?;
			return fotoUrlPath != null ? '$baseUrl$fotoUrlPath' : null;
		}

		return null;
	}
}
