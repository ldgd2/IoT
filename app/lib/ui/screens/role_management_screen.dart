import 'package:flutter/material.dart';
import '../widgets/buttons/primary_action_button.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final List<Map<String, dynamic>> _users = [
    {
      'name': 'Líder Rojas (Administrador Principal)',
      'email': 'lider@colmena-iot.com',
      'role': 'Admin',
      'canControl': true,
      'canManageUsers': true,
      'canViewCctv': true,
    },
    {
      'name': 'María Rojas (Miembro del Hogar)',
      'email': 'maria@colmena-iot.com',
      'role': 'Familiar',
      'canControl': true,
      'canManageUsers': false,
      'canViewCctv': true,
    },
    {
      'name': 'Personal de Mantenimiento',
      'email': 'tecnico@servicio.com',
      'role': 'Invitado Temporal',
      'canControl': true,
      'canManageUsers': false,
      'canViewCctv': false,
    },
  ];

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
              const Text('Control de Accesos y Roles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              FilledButton.icon(
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Invitar Usuario'),
                onPressed: _showInviteModal,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _users.length,
            itemBuilder: (ctx, idx) {
              final u = _users[idx];
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
                              color: u['role'] == 'Admin' ? cs.primary.withValues(alpha: 0.2) : cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              u['role'],
                              style: TextStyle(
                                color: u['role'] == 'Admin' ? cs.primary : cs.onSurface,
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
                        value: u['canControl'],
                        onChanged: (v) => setState(() => u['canControl'] = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('Visualizar Cámaras CCTV en Vivo', style: TextStyle(fontSize: 14)),
                        value: u['canViewCctv'],
                        onChanged: (v) => setState(() => u['canViewCctv'] = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('Administrar Usuarios y Hubs', style: TextStyle(fontSize: 14)),
                        value: u['canManageUsers'],
                        onChanged: (v) => setState(() => u['canManageUsers'] = v),
                        contentPadding: EdgeInsets.zero,
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
    String selectedRole = 'Familiar';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitar Nuevo Usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                DropdownMenuItem(value: 'Familiar', child: Text('Miembro del Hogar')),
                DropdownMenuItem(value: 'Invitado Temporal', child: Text('Invitado Temporal')),
              ],
              onChanged: (v) {
                if (v != null) selectedRole = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          PrimaryActionButton(
            label: 'Enviar Invitación',
            onPressed: () {
              if (emailCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _users.add({
                    'name': 'Nuevo Usuario',
                    'email': emailCtrl.text.trim(),
                    'role': selectedRole,
                    'canControl': true,
                    'canManageUsers': selectedRole == 'Admin',
                    'canViewCctv': selectedRole != 'Invitado Temporal',
                  });
                });
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }
}
