// ================================================================
// PROreport - Pantalla: Solicitud de Levantamiento
// ----------------------------------------------------------------
// Formulario unificado con el mismo diseño de Detección de Peligro.
// ================================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/incidente_provider.dart';
import '../config/theme.dart';
import '../config/theme_context_ext.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/app_header.dart';
import 'deteccion_peligro_screen.dart';
import 'gestion_personal_screen.dart';

class SolicitudLevantamientoScreen extends StatefulWidget {
  const SolicitudLevantamientoScreen({super.key});

  @override
  State<SolicitudLevantamientoScreen> createState() =>
      _SolicitudLevantamientoScreenState();
}

class _SolicitudLevantamientoScreenState
    extends State<SolicitudLevantamientoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final _scrollController = ScrollController();
  bool _useMicDescripcion = false;

  Color get _primary => AppTheme.primaryBlue;
  Color get _accent => AppTheme.accentOrange;
  Color get _error => AppTheme.errorRed;

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
      _showSuccessDialog();
    } else {
      // El error se muestra inline desde el provider
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen, size: 32),
            const SizedBox(width: 12),
            Text('¡Solicitud Enviada!', style: TextStyle(color: ctx.textPrimary)),
          ],
        ),
        content: Text(
          'Su solicitud de levantamiento ha sido registrada exitosamente.',
          style: TextStyle(color: ctx.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _descripcionController.clear();
              context.read<IncidenteProvider>().resetForm();
            },
            child: const Text('Nuevo Reporte'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final isWide = MediaQuery.of(context).size.width > 768;
    final bodyContent = Consumer2<IncidenteProvider, AuthProvider>(
      builder: (context, provider, auth, _) {
        final contratos = auth.contratosUsuario;
        final mostrarDropdownContrato = contratos.length > 1;

        return Form(
          key: _formKey,
          child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader(ctx, 'Información del Incidente', Icons.assignment),

              // Dropdown de Código de Contrato (solo si hay múltiples contratos)
              if (mostrarDropdownContrato) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration(
                      ctx, 'Código de Contrato *', Icons.assignment),
                  items: contratos.map((codigo) {
                    return DropdownMenuItem(
                      value: codigo,
                      child: Text(codigo),
                    );
                  }).toList(),
                  onChanged: (val) {
                    // Si se necesita guardar contrato, agregar setter en IncidenteProvider
                  },
                ),
              ],

              const SizedBox(height: 16),

              // Tipo de Incidente
              DropdownButtonFormField<int>(
                initialValue: provider.tipoIncidente?.id,
                decoration: _inputDecoration(
                    ctx, 'Tipo de Incidente *', Icons.category),
                items: provider.tiposIncidente.map((tipo) {
                  return DropdownMenuItem(
                    value: tipo.id,
                    child: Text(tipo.nombre),
                  );
                }).toList(),
                onChanged: (val) {
                  final tipo =
                      provider.tiposIncidente.firstWhere((t) => t.id == val);
                  provider.setTipoIncidente(tipo);
                },
              ),
              const SizedBox(height: 16),

              // Área
              DropdownButtonFormField<int>(
                initialValue: provider.area?.id,
                decoration: _inputDecoration(
                    ctx, 'Área de Ocurrencia *', Icons.location_on),
                items: provider.areas.map((area) {
                  return DropdownMenuItem(
                    value: area.id,
                    child: Text(area.nombre),
                  );
                }).toList(),
                onChanged: (val) {
                  final area =
                      provider.areas.firstWhere((a) => a.id == val);
                  provider.setArea(area);
                },
              ),
              const SizedBox(height: 24),

              _buildSectionHeader(ctx, 'Evidencia (El Antes)', Icons.camera_alt),
              const SizedBox(height: 8),

              _buildFotoButton(ctx, provider),
              const SizedBox(height: 16),

              // Supervisor Responsable
              _buildSupervisorSelector(ctx, provider),
              const SizedBox(height: 16),

              _buildTextFieldWithMic(
                ctx,
                controller: _descripcionController,
                label: 'Descripción del Incidente',
                icon: Icons.description,
                hint: 'Describa detalladamente lo ocurrido...',
                onChanged: (val) => provider.setDescripcion(val),
                useMic: _useMicDescripcion,
                onMicToggle: () =>
                    setState(() => _useMicDescripcion = !_useMicDescripcion),
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: provider.isSubmitting ? null : _submitReport,
                  icon: provider.isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_alt, size: 28),
                  label: Text(
                    provider.isSubmitting
                        ? 'Enviando...'
                        : 'Guardar y Notificar',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Mensaje de error inline
              if (provider.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _error.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: _error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.errorMessage!,
                          style: TextStyle(color: _error, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => provider.clearError(),
                        child: Icon(Icons.close, color: _error, size: 18),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        );
      },
    );

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
                MaterialPageRoute(
                    builder: (_) => const DeteccionPeligroScreen()),
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
                MaterialPageRoute(
                    builder: (_) => const GestionPersonalScreen()),
              ),
            ),
          ],
          child: Column(
            children: [
              AppHeader(
                title: 'Solicitud de Levantamiento',
                subtitle: 'Reporte de incidentes y no conformidades',
                icon: Icons.assignment_rounded,
                iconColor: ctx.accentOrange,
              ),
              Expanded(child: bodyContent),
            ],
          ),
        ),
      );
    }

    // Mobile version without sidebar
    return Scaffold(
      backgroundColor: ctx.surfaceBg,
      appBar: AppBar(
        title: const Text(
          'Solicitud Levantamiento',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: const [
          SizedBox(width: 40),
        ],
      ),
      body: bodyContent,
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Widgets Auxiliares
  // ───────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext ctx, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: ctx.accentBlue, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ctx.textPrimary),
        ),
        const Spacer(),
        Divider(color: ctx.accentBlue.withValues(alpha: 0.3), thickness: 1.5),
      ],
    );
  }

  InputDecoration _inputDecoration(
      BuildContext ctx, String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: ctx.textSecondary),
      prefixIcon: Icon(icon, color: ctx.accentBlue),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ctx.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ctx.accentBlue, width: 2),
      ),
      filled: true,
      fillColor: ctx.surfaceInput,
    );
  }

  Widget _buildFotoButton(BuildContext ctx, IncidenteProvider provider) {
    final hasFoto = provider.fotoEvidencia != null;
    return SizedBox(
      height: 120,
      child: ElevatedButton(
        onPressed: () async {
          final source = await showDialog<ImageSource>(
            context: context,
            builder: (dialogCtx) => SimpleDialog(
              backgroundColor: ctx.surfaceCard,
              title: Text('Seleccionar fuente',
                  style: TextStyle(color: ctx.textPrimary)),
              children: [
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.pop(dialogCtx, ImageSource.camera),
                  child: ListTile(
                    leading: Icon(Icons.camera_alt, color: ctx.accentBlue),
                    title: Text('Cámara',
                        style: TextStyle(color: ctx.textPrimary)),
                  ),
                ),
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.pop(dialogCtx, ImageSource.gallery),
                  child: ListTile(
                    leading: Icon(Icons.photo_library, color: ctx.accentBlue),
                    title: Text('Galería',
                        style: TextStyle(color: ctx.textPrimary)),
                  ),
                ),
              ],
            ),
          );
          if (source != null) {
            await provider.pickFotoEvidencia(
                useCamera: source == ImageSource.camera);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: hasFoto ? ctx.accentOrange : ctx.surfaceCard,
          foregroundColor: ctx.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: hasFoto ? ctx.accentOrange : ctx.borderColor, width: 2),
          ),
          elevation: hasFoto ? 4 : 0,
        ),
        child: hasFoto
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 32, color: ctx.successGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '✓ Foto capturada: ${provider.fotoEvidencia!.name.length > 25 ? '${provider.fotoEvidencia!.name.substring(0, 22)}...' : provider.fotoEvidencia!.name}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: ctx.textPrimary),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => provider.clearFotoEvidencia(),
                    child: Icon(Icons.close, color: ctx.errorRed),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 48, color: ctx.accentBlue),
                  const SizedBox(height: 4),
                  Text(
                    'CAPTURAR FOTO EVIDENCIA *',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ctx.accentBlue),
                  ),
                  Text(
                    'Toque para tomar o seleccionar foto',
                    style: TextStyle(fontSize: 12, color: ctx.textMuted),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSupervisorSelector(
      BuildContext ctx, IncidenteProvider provider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ctx.borderColor),
        color: ctx.surfaceCard,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_pin, color: ctx.accentBlue, size: 22),
              const SizedBox(width: 8),
              Text(
                'Supervisor Responsable *',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ctx.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (provider.trabajadores.isEmpty)
            Text(
              'No hay supervisores disponibles',
              style: TextStyle(color: ctx.textMuted, fontSize: 14),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: provider.supervisorTrabajadorId,
              decoration: InputDecoration(
                hintText: 'Seleccionar supervisor',
                hintStyle: TextStyle(color: ctx.textMuted),
                prefixIcon:
                    Icon(Icons.supervisor_account, color: ctx.accentBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: ctx.accentBlue, width: 2),
                ),
                filled: true,
                fillColor: ctx.surfaceInput,
              ),
              items: provider.trabajadores.map((t) {
                final nombre =
                    '${t['nombre'] ?? ''} ${t['apellido_paterno'] ?? ''} ${t['apellido_materno'] ?? ''}'
                        .trim();
                return DropdownMenuItem(
                  value: t['id'] as int?,
                  child: Text(nombre),
                );
              }).toList(),
              onChanged: (val) {
                final t = provider.trabajadores.firstWhere(
                    (t) => t['id'] == val);
                final nombre =
                    '${t['nombre'] ?? ''} ${t['apellido_paterno'] ?? ''} ${t['apellido_materno'] ?? ''}'
                        .trim();
                provider.setSupervisor(val, nombre);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithMic(
    BuildContext ctx, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    required Function(String) onChanged,
    required bool useMic,
    required VoidCallback onMicToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ctx.borderColor),
        color: ctx.surfaceCard,
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        minLines: 2,
        style: TextStyle(color: ctx.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ctx.textSecondary),
          hintText: hint,
          hintStyle: TextStyle(color: ctx.textMuted),
          prefixIcon: Icon(icon, color: ctx.accentBlue),
          suffixIcon: IconButton(
            icon: Icon(useMic ? Icons.mic : Icons.mic_none,
                color: useMic ? ctx.accentOrange : ctx.textMuted),
            onPressed: onMicToggle,
            tooltip: 'Dictado por voz',
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true,
          fillColor: ctx.surfaceInput,
        ),
        onChanged: onChanged,
      ),
    );
  }
}