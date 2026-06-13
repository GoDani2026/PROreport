import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../providers/incidente_provider.dart';
import '../widgets/photo_grid.dart';
import '../widgets/supervisor_selector.dart';
import '../widgets/help_section.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _descripcionController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Cargar catálogos después del build
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

    // Sincronizar descripción del TextField al provider
    provider.setDescripcion(_descripcionController.text);

    final success = await provider.submitReport();

    if (!mounted) return;

    if (success) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.successGreen, size: 32),
              SizedBox(width: 12),
              Text('¡Reporte Enviado!'),
            ],
          ),
          content: const Text(
            'Su reporte de incidente ha sido registrado exitosamente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                provider.resetForm();
                _descripcionController.clear();
              },
              child: const Text('Nuevo Reporte'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isWide ? 'SOLICITUD DE REPORTE DE INCIDENTE' : 'NUEVO REPORTE',
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
              backgroundColor: AppTheme.accentOrange,
              child: IconButton(
                icon: const Icon(Icons.person, color: Colors.white, size: 20),
                onPressed: () {
                  // Perfil / Configuración
                },
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

  // Layout para escritorio/tablet (pantalla ancha)
  Widget _buildWideLayout(BuildContext context, IncidenteProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Información del reporte
        const Text(
          'Complete el formulario para reportar un incidente',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),

        // Dos columnas
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Columna izquierda
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
            // Columna derecha
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

  // Layout para móvil (pantalla estrecha)
  Widget _buildNarrowLayout(
      BuildContext context, IncidenteProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Complete el formulario para reportar un incidente',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),

        // Descripción
        _buildDescriptionField(context, provider),
        const SizedBox(height: 16),

        // Tipo de Incidente
        _buildTipoIncidenteDropdown(context, provider),
        const SizedBox(height: 16),

        // Área
        _buildAreaDropdown(context, provider),
        const SizedBox(height: 16),

        // Fotos
        const PhotoGrid(),
        const SizedBox(height: 16),

        // Supervisor
        const SupervisorSelector(),
        const SizedBox(height: 16),

        // Ayuda
        const HelpSection(),
        const SizedBox(height: 16),

        // Botón Enviar
        _buildSubmitButton(context, provider),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDescriptionField(
      BuildContext context, IncidenteProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description,
                    color: AppTheme.accentOrange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Descripción del Incidente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descripcionController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText:
                    'Describa detalladamente lo ocurrido...',
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
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.category, color: AppTheme.accentOrange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Tipo de Incidente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: provider.tipoIncidente?.id,
              decoration: const InputDecoration(
                hintText: 'Seleccionar tipo de incidente',
              ),
              items: provider.tiposIncidente.map((tipo) {
                return DropdownMenuItem(
                  value: tipo.id,
                  child: Text(tipo.nombre),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on,
                    color: AppTheme.accentOrange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Área de Ocurrencia',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: provider.area?.id,
              decoration: const InputDecoration(
                hintText: 'Seleccionar área',
              ),
              items: provider.areas.map((area) {
                return DropdownMenuItem(
                  value: area.id,
                  child: Text(area.nombre),
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: provider.isSubmitting ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
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
