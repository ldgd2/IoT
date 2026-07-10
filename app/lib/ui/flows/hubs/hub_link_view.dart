import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../src/state/auth_state.dart';
import '../../../src/constants/api_constants.dart';

class HubLinkView extends StatefulWidget {
  const HubLinkView({Key? key}) : super(key: key);

  @override
  State<HubLinkView> createState() => _HubLinkViewState();
}

class _HubLinkViewState extends State<HubLinkView> {
  final _ipController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _pairHub() async {
    final ip = _ipController.text.trim();
    final name = _nameController.text.trim();
    
    if (ip.isEmpty || name.isEmpty) {
      setState(() => _error = 'Por favor ingresa un nombre y una IP/URL local válida');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authState = context.read<AuthState>();
    final userToken = authState.token;
    
    if (userToken == null) {
      setState(() {
        _error = 'Error: No hay sesión activa de usuario';
        _isLoading = false;
      });
      return;
    }

    try {
      // Intentar contactar al Hub en la IP proporcionada para enviarle el token y la URL del servidor
      String hubUrl = ip;
      if (!hubUrl.startsWith('http')) {
        hubUrl = 'http://$ip';
      }
      
      final uri = Uri.parse('$hubUrl/api/hub/pair');
      final r = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'server_url': ApiConstants.serverBaseUrl.replaceAll('/api', ''),
          'user_token': userToken,
          'name': name,
        }),
      ).timeout(const Duration(seconds: 10));

      if (r.statusCode == 200) {
        // Vinculación exitosa. Refrescar la lista de hubs del usuario.
        await authState.refreshHubs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Hub vinculado exitosamente!')),
          );
          Navigator.of(context).pop();
        }
      } else {
        String msg = 'Error desconocido';
        try {
          msg = jsonDecode(r.body)['error'] ?? r.body;
        } catch (_) {}
        setState(() => _error = 'No se pudo vincular: $msg');
      }
    } catch (e) {
      setState(() => _error = 'No se pudo conectar al Hub en esa IP: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vincular Hub Colmena')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hub, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'Para vincular un nuevo Hub, conéctate a la misma red Wi-Fi e ingresa su dirección IP (ej: 192.168.1.100:5000).',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Hub',
                hintText: 'Ej: Casa Principal',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Dirección IP del Hub',
                hintText: '192.168.x.x:5000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.router),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : _pairHub,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                  ? const CircularProgressIndicator() 
                  : const Text('Vincular Hub', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
