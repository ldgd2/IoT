import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../src/state/auth_state.dart';
import '../../../src/models/hub.dart';
import 'hub_link_view.dart';

class HubManagementView extends StatefulWidget {
  const HubManagementView({super.key});

  @override
  State<HubManagementView> createState() => _HubManagementViewState();
}

class _HubManagementViewState extends State<HubManagementView> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<AuthState>().refreshHubs();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Hubs', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: 'Vincular nuevo Hub',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HubLinkView()),
              );
            },
          ),
        ],
      ),
      body: auth.hubs.isEmpty
          ? RefreshIndicator(
              onRefresh: () async {
                await context.read<AuthState>().refreshHubs();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
                children: [
                  Icon(Icons.hub_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No tienes ningún Hub vinculado.', style: tt.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Vincular Hub ahora'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HubLinkView()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    await context.read<AuthState>().refreshHubs();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: auth.hubs.length,
                    itemBuilder: (ctx, idx) {
                      final hub = auth.hubs[idx];
                      final isActive = auth.activeHub?.id == hub.id;
                      return _buildHubCard(hub, isActive, cs, tt);
                    },
                  ),
                ),
                if (_loading)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildHubCard(Hub hub, bool isActive, ColorScheme cs, TextTheme tt) {
    return Card(
      elevation: isActive ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isActive ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hub.online
                        ? const Color(0xFF00E5A8).withValues(alpha: 0.15)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    hub.online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    color: hub.online ? const Color(0xFF00E5A8) : cs.onSurfaceVariant,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              hub.name,
                              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'ACTIVO',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hub.online ? 'En línea • Sincronizado' : 'Desconectado',
                        style: tt.bodyMedium?.copyWith(
                          color: hub.online ? const Color(0xFF00E5A8) : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Renombrar'),
                    onPressed: () => _showRenameDialog(hub),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.errorContainer,
                      foregroundColor: cs.onErrorContainer,
                    ),
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    label: const Text('Desvincular'),
                    onPressed: () => _showStep1Warning(hub),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(Hub hub) {
    final ctrl = TextEditingController(text: hub.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar Hub'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del Hub',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty || newName == hub.name) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              setState(() => _loading = true);
              final success = await context.read<AuthState>().renameHub(hub.id, newName);
              if (mounted) {
                setState(() => _loading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Hub renombrado con éxito.' : 'Error al renombrar el Hub.'),
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showStep1Warning(Hub hub) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Desvincular Hub', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estás a punto de desvincular y eliminar el Hub "${hub.name}" de tu cuenta Colmena.',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.error.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ADVERTENCIA CRÍTICA:', style: tt.labelLarge?.copyWith(color: cs.error, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('• Se eliminarán automáticamente todos tus dispositivos registrados en este Hub.', style: tt.bodySmall),
                  const SizedBox(height: 4),
                  Text('• Se borrarán todas las habitaciones, espacios y automatizaciones asociadas.', style: tt.bodySmall),
                  const SizedBox(height: 4),
                  Text('• El Hub físico perderá la sincronización y habrá que vincular y configurar todo desde cero.', style: tt.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('¿Deseas continuar a la verificación de seguridad?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              Navigator.pop(ctx);
              _showStep2Verification(hub);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _showStep2Verification(Hub hub) {
    final ctrl = TextEditingController();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isExact = ctrl.text.trim() == 'ELIMINAR';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Verificación de 2 pasos', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esta acción es definitiva e irreversible.',
                    style: tt.bodyMedium?.copyWith(color: cs.error, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Para confirmar que deseas desvincular el Hub "${hub.name}" y borrar todos sus dispositivos, escribe exactamente la palabra ELIMINAR en el recuadro de abajo:',
                    style: tt.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Escribe ELIMINAR',
                      border: const OutlineInputBorder(),
                      errorText: ctrl.text.isNotEmpty && !isExact ? 'Debes escribir ELIMINAR en mayúsculas' : null,
                    ),
                    onChanged: (val) {
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isExact ? cs.error : cs.surfaceContainerHighest,
                    foregroundColor: isExact ? cs.onError : cs.onSurfaceVariant,
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Eliminar definitivamente'),
                  onPressed: isExact
                      ? () async {
                          Navigator.pop(ctx);
                          setState(() => _loading = true);
                          final success = await context.read<AuthState>().deleteHub(hub.id);
                          if (mounted) {
                            setState(() => _loading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Hub y dispositivos eliminados y desvinculados por completo.'
                                    : 'Error al eliminar el Hub.'),
                              ),
                            );
                          }
                        }
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
