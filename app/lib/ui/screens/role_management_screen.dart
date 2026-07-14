import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bthapp/src/state/auth_state.dart';
import 'package:bthapp/src/state/app_state.dart';
import '../widgets/buttons/primary_action_button.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final auth = context.read<AuthState>();
    final app = context.read<AppState>();
    final currentUser = auth.user;
    final list = <Map<String, dynamic>>[];

    if (currentUser != null) {
      final roleStr = currentUser.email.toLowerCase().contains('admin') ? 'Admin' : 'Miembro Principal';
      list.add({
        'id': currentUser.userId,
        'name': '${currentUser.username} (Usuario Actual)',
        'email': currentUser.email,
        'role': roleStr,
        'canControl': true,
        'canManageUsers': roleStr.toLowerCase().contains('admin'),
        'canViewCctv': true,
      });
    }

    try {
      final host = app.hubHost;
      if (host.isNotEmpty) {
        final uri = Uri.parse('http://$host/api/auth/users');
        final r = await http.get(uri).timeout(const Duration(seconds: 4));
        if (r.statusCode == 200) {
          final data = jsonDecode(r.body) as List;
          for (final u in data) {
            final uid = u['id']?.toString() ?? u['user_id']?.toString() ?? '';
            if (uid != currentUser?.userId) {
              list.add({
                'id': uid,
                'name': u['name']?.toString() ?? u['username']?.toString() ?? 'Usuario del Hogar',
                'email': u['email']?.toString() ?? 'sin-correo@colmena.com',
                'role': u['role']?.toString() ?? 'Miembro',
                'canControl': u['can_control'] != false,
                'canManageUsers': (u['role']?.toString().toLowerCase() ?? '') == 'admin',
                'canViewCctv': u['can_cctv'] != false,
              });
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _users = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Control de Accesos y Roles Reales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Sincronizar usuarios',
                    onPressed: _loadUsers,
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Invitar Usuario'),
                    onPressed: _showInviteModal,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_users.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      const Text('No hay usuarios vinculados en el sistema', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _users.length,
              itemBuilder: (ctx, idx) {
                final u = _users[idx];
                final isAdmin = u['role']?.toString().toLowerCase().contains('admin') == true || idx == 0;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(u['email'], style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAdmin ? cs.primary.withValues(alpha: 0.2) : cs.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                u['role']?.toString().toUpperCase() ?? 'MIEMBRO',
                                style: TextStyle(
                                  color: isAdmin ? cs.primary : cs.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        SwitchListTile(
                          title: const Text('Controlar Dispositivos y Escenas', style: TextStyle(fontSize: 14)),
                          value: u['canControl'] == true,
                          onChanged: idx == 0 ? null : (v) => setState(() => u['canControl'] = v),
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: cs.primary,
                        ),
                        SwitchListTile(
                          title: const Text('Visualizar Cámaras CCTV en Vivo', style: TextStyle(fontSize: 14)),
                          value: u['canViewCctv'] == true,
                          onChanged: idx == 0 ? null : (v) => setState(() => u['canViewCctv'] = v),
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: cs.primary,
                        ),
                        SwitchListTile(
                          title: const Text('Administrar Usuarios y Hubs', style: TextStyle(fontSize: 14)),
                          value: u['canManageUsers'] == true,
                          onChanged: idx == 0 ? null : (v) => setState(() => u['canManageUsers'] = v),
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: cs.primary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showInviteModal() {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedRole = 'Miembro';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitar Nuevo Usuario al Hogar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del usuario', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Rol de acceso', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Admin', child: Text('Administrador Principal')),
                  DropdownMenuItem(value: 'Miembro', child: Text('Miembro del Hogar')),
                  DropdownMenuItem(value: 'Invitado', child: Text('Invitado Temporal')),
                ],
                onChanged: (v) {
                  if (v != null) selectedRole = v;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          PrimaryActionButton(
            label: 'Enviar Invitación Real',
            onPressed: () async {
              if (emailCtrl.text.trim().isNotEmpty && nameCtrl.text.trim().isNotEmpty) {
                final app = context.read<AppState>();
                try {
                  final host = app.hubHost;
                  if (host.isNotEmpty) {
                    await http.post(
                      Uri.parse('http://$host/api/auth/register'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'username': nameCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'role': selectedRole,
                        'password': 'colmena_default_password',
                      }),
                    );
                  }
                } catch (_) {}

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _loadUsers();
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
