// ================================================================
// PROreport - Pantalla: Detección de Peligro (Creación)
// ----------------------------------------------------------------
// Formulario ágil mobile-first para reportar un peligro en terreno.
// Flujo: 1 Reporte = 1 Registro.
// ================================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/peligro_provider.dart';
import '../config/theme.dart';
import '../config/theme_context_ext.dart';
import '../services/peligros_service.dart';
import '../widgets/collapsible_sidebar.dart';
import 'gestion_personal_screen.dart';
import 'solicitud_levantamiento_screen.dart';

class DeteccionPeligroScreen extends StatefulWidget {
  const DeteccionPeligroScreen({super.key});

  @override
  State<DeteccionPeligroScreen> createState() =>
      _DeteccionPeligroScreenState();
}

class _DeteccionPeligroScreenState extends State<DeteccionPeligroScreen> {
  final _lugarController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _accionController = TextEditingController();
  final _scrollController = ScrollController();
  bool _useMicDescripcion = false;
  bool _useMicAccion = false;

  Color get _primary => AppTheme.primaryBlue;
  Color get _accent => AppTheme.accentOrange;
  Color get _error => AppTheme.errorRed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PeligroProvider>().loadCatalogos();
    });
  }

  @override
  void dispose() {
    _lugarController.dispose();
    _descripcionController.dispose();
    _accionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final provider = context.read<PeligroProvider>();
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;
    if (user == null) {
      _showError('Debe iniciar sesión para reportar.');
      return;
    }

    final peligroService = PeligrosService();
    final turno = await peligroService.fetchTurnoDelTrabajador(user.id);
    final turnoFinal = turno ?? 'No asignado';

    provider.setDescripcion(_descripcionController.text);
    provider.setAccionInmediata(_accionController.text);

    final success = await provider.submitReport(user.id, turnoFinal);
    if (!mounted) return;

    if (success) {
      _showSuccessDialog();
    } else {
      _showError(provider.errorMessage ?? 'Error al enviar reporte.');
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
            Text('¡Reporte Enviado!', style: TextStyle(color: ctx.textPrimary)),
          ],
        ),
        content: Text(
          'Su detección de peligro ha sido registrada exitosamente.',
          style: TextStyle(color: ctx.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _lugarController.clear();
              _descripcionController.clear();
              _accionController.clear();
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final isWide = MediaQuery.of(context).size.width > 768;
    final bodyContent = Consumer<PeligroProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader(ctx, 'Identificación', Icons.person_pin),
              const SizedBox(height: 8),

              DropdownButtonFormField<int>(
                initialValue: provider.selectedAreaId,
                decoration: _inputDecoration(ctx, 'Área *', Icons.business),
                items: provider.areas.map((area) {
                  return DropdownMenuItem(
                    value: area['id'] as int,
                    child: Text(area['nombre'] as String),
                  );
                }).toList(),
                onChanged: (val) => provider.setAreaId(val),
                validator: (val) => val == null ? 'Seleccione un área' : null,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _lugarController,
                decoration: _inputDecoration(ctx, 'Lugar Exacto *', Icons.location_on),
                onChanged: (val) => provider.setLugarExacto(val),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader(ctx, 'Hallazgo (El Antes)', Icons.search),
              const SizedBox(height: 8),

              _buildFotoButton(ctx, provider),
              const SizedBox(height: 16),

              _buildNivelAtencionSelector(provider),
              const SizedBox(height: 16),

              _buildTextFieldWithMic(ctx,
                controller: _descripcionController,
                label: 'Descripción del Hallazgo',
                icon: Icons.description,
                hint: 'Describa detalladamente el peligro detectado...',
                onChanged: (val) => provider.setDescripcion(val),
                useMic: _useMicDescripcion,
                onMicToggle: () => setState(() => _useMicDescripcion = !_useMicDescripcion),
              ),
              const SizedBox(height: 16),

              _buildTextFieldWithMic(ctx,
                controller: _accionController,
                label: 'Acción Inmediata',
                icon: Icons.flash_on,
                hint: '¿Qué acción inmediata se tomó? (opcional)',
                onChanged: (val) => provider.setAccionInmediata(val),
                useMic: _useMicAccion,
                onMicToggle: () => setState(() => _useMicAccion = !_useMicAccion),
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: provider.isSubmitting ? null : _submitReport,
                  icon: provider.isSubmitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_alt, size: 28),
                  label: Text(
                    provider.isSubmitting ? 'Enviando...' : 'Guardar y Notificar',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
              isActive: true,
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SolicitudLevantamientoScreen()),
              ),
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
              _buildDeteccionHeader(ctx),
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
          'Detectar Peligro',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: bodyContent,
    );
  }

  Widget _buildDeteccionHeader(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ctx.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: ctx.warningYellow, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detecciones de Peligro',
                style: ctx.headingLg,
              ),
              const SizedBox(height: 2),
              Text(
                'Reporte de condiciones peligrosas en terreno',
                style: TextStyle(color: ctx.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Widgets Auxiliares (reciben BuildContext explícitamente para colores dinámicos)
  // ───────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext ctx, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: ctx.accentBlue, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ctx.textPrimary),
        ),
        const Spacer(),
        Divider(color: ctx.accentBlue.withValues(alpha: 0.3), thickness: 1.5),
      ],
    );
  }

  InputDecoration _inputDecoration(BuildContext ctx, String label, IconData icon) {
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

  Widget _buildFotoButton(BuildContext ctx, PeligroProvider provider) {
    final hasFoto = provider.fotoEvidencia != null;
    return SizedBox(
      height: 120,
      child: ElevatedButton(
        onPressed: () async {
          final source = await showDialog<ImageSource>(
            context: context,
            builder: (dialogCtx) => SimpleDialog(
              backgroundColor: ctx.surfaceCard,
              title: Text('Seleccionar fuente', style: TextStyle(color: ctx.textPrimary)),
              children: [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogCtx, ImageSource.camera),
                  child: ListTile(
                    leading: Icon(Icons.camera_alt, color: ctx.accentBlue),
                    title: Text('Cámara', style: TextStyle(color: ctx.textPrimary)),
                  ),
                ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogCtx, ImageSource.gallery),
                  child: ListTile(
                    leading: Icon(Icons.photo_library, color: ctx.accentBlue),
                    title: Text('Galería', style: TextStyle(color: ctx.textPrimary)),
                  ),
                ),
              ],
            ),
          );
          if (source != null) {
            await provider.pickFotoEvidencia(useCamera: source == ImageSource.camera);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: hasFoto ? ctx.accentOrange : ctx.surfaceCard,
          foregroundColor: ctx.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: hasFoto ? ctx.accentOrange : ctx.borderColor, width: 2),
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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ctx.textPrimary),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ctx.accentBlue),
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

  Widget _buildNivelAtencionSelector(PeligroProvider provider) {
    final ctx = context;
    const niveles = {
      'BAJO': AppTheme.successGreen,
      'MEDIO': AppTheme.warningYellow,
      'SIGNIFICATIVO': AppTheme.errorRed,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nivel de Atención LGF *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ctx.textPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: niveles.entries.map((entry) {
            final isSelected = provider.nivelAtencionLgf == entry.key;
            return ChoiceChip(
              label: Text(
                entry.key,
                style: TextStyle(
                  color: isSelected ? Colors.white : entry.value,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              selectedColor: entry.value,
              backgroundColor: entry.value.withValues(alpha: 0.1),
              side: BorderSide(
                color: isSelected ? entry.value : entry.value.withValues(alpha: 0.5),
                width: 2,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (selected) => provider.setNivelAtencion(selected ? entry.key : null),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTextFieldWithMic(BuildContext ctx, {
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
            icon: Icon(useMic ? Icons.mic : Icons.mic_none, color: useMic ? ctx.accentOrange : ctx.textMuted),
            onPressed: onMicToggle,
            tooltip: 'Dictado por voz',
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true,
          fillColor: ctx.surfaceInput,
        ),
        onChanged: onChanged,
      ),
    );
  }
}