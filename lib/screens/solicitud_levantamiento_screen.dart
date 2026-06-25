import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme_context_ext.dart';
import '../providers/incidente_provider.dart';
import '../widgets/photo_grid.dart';
import '../widgets/supervisor_selector.dart';
import '../widgets/help_section.dart';
import 'login_screen.dart';
import '../widgets/collapsible_sidebar.dart';
import '../screens/deteccion_peligro_screen.dart';
import '../screens/gestion_personal_screen.dart';

class SolicitudLevantamientoScreen extends StatefulWidget {
  const SolicitudLevantamientoScreen({super.key});

  @override
  State<SolicitudLevantamientoScreen> createState() => _SolicitudLevantamientoScreenState();
}

class _SolicitudLevantamientoScreenState extends State<SolicitudLevantamientoScreen> {
  final _descripcionController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IncidenteProvider>().loadCatalogos();
    });
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final provider = context.read<IncidenteProvider>();
    provider.setDescripcion(_descripcionController.text);
    final success = await provider.submitReport();
    if (!mounted) return;
    if (success) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF00E676) : const Color(0xFF00E676), size: 32),
              const SizedBox(width: 12),
              const Text('¡Reporte Enviado!'),
            ],
          ),
          content: const Text(
            'Su reporte de incidente ha sido registrado exitosamente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                provider.resetForm();
                _descripcionController.clear();
              },
              child: const Text('Nuevo Reporte'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } else if (provider.errorMessage != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF5252) : const Color(0xFFFF5252),
        ),
      );
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF5252) : const Color(0xFFFF5252),
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final isWide = MediaQuery.of(context).size.width > 768;
    if (isWide) {
      return Scaffold(
        backgroundColor: ctx.surfaceBg,
        body: CollapsibleSidebar(
          items: [
            MenuItem(
              icon: Icons.dashboard_rounded,
              label: 'Inicio / Dashboard',
              color: ctx.accentBlue,
              onTap: () => Navigator.pop(context),
            ),
            MenuItem(
              icon: Icons.warning_amber_rounded,
              label: 'Detecciones de Peligro',
              color: ctx.warningYellow,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DeteccionPeligroScreen()),
              ),
            ),
            MenuItem(
              icon: Icons.route_rounded,
              label: 'Caminatas de Seguridad',
              color: ctx.successGreen,
            ),
            MenuItem(
              icon: Icons.assignment_rounded,
              label: 'Solicitud de Levantamiento',
              color: ctx.accentOrange,
              isActive: true,
            ),
            MenuItem(
              icon: Icons.people_rounded,
              label: 'Gestionar Personal',
              color: ctx.successGreen,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GestionPersonalScreen()),
              ),
            ),
          ],
          child: Column(
            children: [
              _screenHeader(ctx),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Consumer<IncidenteProvider>(
                    builder: (context, provider, child) {
                      if (provider.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      return _buildWideLayout(context, provider);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isWide ? 'SOLICITUD DE LEVANTAMIENTO' : 'NUEVO REPORTE',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              backgroundColor: ctx.accentOrange,
              child: IconButton(
                icon: const Icon(Icons.person, color: Colors.white, size: 20),
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
      body: Consumer<IncidenteProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: isWide ? _buildWideLayout(context, provider)
                          : _buildNarrowLayout(context, provider),
          );
        },
      ),
    );
  }

  Widget _screenHeader(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ctx.dividerColor, width: 1))),
      child: Row(
        children: [
          Icon(Icons.assignment_rounded, color: ctx.accentOrange, size: 22),
          const SizedBox(width: 10),
          Text(
            'Solicitud de Levantamiento',
            style: TextStyle(
              color: ctx.sidebarTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.logout, color: ctx.sidebarTextSecondary, size: 18),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, IncidenteProvider provider) {
    final ctx = context;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Complete el formulario para reportar un incidente',
          style: TextStyle(
            color: ctx.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildTipoIncidenteDropdown(context, provider),
                  const SizedBox(height: 16),
                  _buildAreaDropdown(context, provider),
                  const SizedBox(height: 16),
                  const PhotoGrid(),
                  const SizedBox(height: 16),
                  const SupervisorSelector(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _buildDescriptionField(context, provider),
                  const SizedBox(height: 16),
                  const HelpSection(),
                  const SizedBox(height: 16),
                  _buildSubmitButton(context, provider),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(
      BuildContext context, IncidenteProvider provider) {
    final ctx = context;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Complete el formulario para reportar un incidente',
          style: TextStyle(
            color: ctx.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        _buildDescriptionField(context, provider),
        const SizedBox(height: 16),
        _buildTipoIncidenteDropdown(context, provider),
        const SizedBox(height: 16),
        _buildAreaDropdown(context, provider),
        const SizedBox(height: 16),
        const PhotoGrid(),
        const SizedBox(height: 16),
        const SupervisorSelector(),
        const SizedBox(height: 16),
        const HelpSection(),
        const SizedBox(height: 16),
        _buildSubmitButton(context, provider),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDescriptionField(
      BuildContext context, IncidenteProvider provider) {
    final ctx = context;
    return Card(
      color: ctx.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: ctx.accentOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Descripción del Incidente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ctx.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descripcionController,
              maxLines: 8,
              style: TextStyle(color: ctx.textPrimary),
              decoration: InputDecoration(
                hintText: 'Describa detalladamente lo ocurrido...',
                hintStyle: TextStyle(color: ctx.textMuted),
              ),
              onChanged: (value) {
                provider.setDescripcion(value);
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Limit 20 words',
                style: TextStyle(
                  color: ctx.textMuted.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipoIncidenteDropdown(
      BuildContext context, IncidenteProvider provider) {
    final ctx = context;
    return Card(
      color: ctx.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: ctx.accentOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Tipo de Incidente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ctx.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: provider.tipoIncidente?.id,
              decoration: InputDecoration(
                hintText: 'Seleccionar tipo de incidente',
                hintStyle: TextStyle(color: ctx.textMuted),
              ),
              items: provider.tiposIncidente.map((tipo) {
                return DropdownMenuItem(
                  value: tipo.id,
                  child: Text(tipo.nombre, style: TextStyle(color: ctx.textPrimary)),
                );
              }).toList(),
              onChanged: (value) {
                final tipo = provider.tiposIncidente
                    .firstWhere((t) => t.id == value);
                provider.setTipoIncidente(tipo);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaDropdown(
      BuildContext context, IncidenteProvider provider) {
    final ctx = context;
    return Card(
      color: ctx.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: ctx.accentOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Área de Ocurrencia',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ctx.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: provider.area?.id,
              decoration: InputDecoration(
                hintText: 'Seleccionar área',
                hintStyle: TextStyle(color: ctx.textMuted),
              ),
              items: provider.areas.map((area) {
                return DropdownMenuItem(
                  value: area.id,
                  child: Text(area.nombre, style: TextStyle(color: ctx.textPrimary)),
                );
              }).toList(),
              onChanged: (value) {
                final area = provider.areas
                    .firstWhere((a) => a.id == value);
                provider.setArea(area);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(
      BuildContext context, IncidenteProvider provider) {
    final ctx = context;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: provider.isSubmitting ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: ctx.accentBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: provider.isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'ENVIAR SOLICITUD',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}