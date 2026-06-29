// ================================================================
// PROreport - Pantalla: Seguimiento / Cierre de Peligro
// ----------------------------------------------------------------
// Vista de detalle para el Supervisor.
// - Si estatus = 'Pendiente' → formulario de Compromiso (Iniciar Ejecución)
// - Si estatus = 'En Ejecución' → formulario de Cierre
// - Si estatus = 'Eliminada' → vista de solo lectura
// Usa la paleta oficial de la app definida en AppTheme.
// ================================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/deteccion_peligro_model.dart';
import '../providers/peligro_provider.dart';
import '../config/theme.dart';

class SeguimientoPeligroScreen extends StatefulWidget {
  final int deteccionId;

  const SeguimientoPeligroScreen({super.key, required this.deteccionId});

  @override
  State<SeguimientoPeligroScreen> createState() =>
      _SeguimientoPeligroScreenState();
}

class _SeguimientoPeligroScreenState extends State<SeguimientoPeligroScreen> {
  // Formulario de Compromiso
  final _planAccionController = TextEditingController();
  int? _selectedSupervisorId;
  DateTime? _selectedFechaCompromiso;

  // Formulario de Cierre
  final _resumenCierreController = TextEditingController();
  String? _fotoCierrePath;

  // Alias a la paleta oficial de la app (AppTheme)
  Color get _primary => AppTheme.primaryBlue;
  Color get _accent => AppTheme.accentOrange;
  Color get _bg => AppTheme.surfaceColor;
  Color get _text => AppTheme.textPrimary;
  Color get _error => AppTheme.errorRed;
  Color get _success => AppTheme.successGreen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PeligroProvider>();
      provider.loadDeteccion(widget.deteccionId);
      if (provider.supervisores.isEmpty) {
        provider.loadCatalogos();
      }
    });
  }

  @override
  void dispose() {
    _planAccionController.dispose();
    _resumenCierreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Seguimiento de Peligro',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: _primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Consumer<PeligroProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingDeteccion) {
            return const Center(child: CircularProgressIndicator());
          }

          final deteccion = provider.deteccionActual;
          if (deteccion == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage ?? 'No se encontró la detección.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildReporteOriginalCard(deteccion),
                const SizedBox(height: 24),
                _buildDynamicSection(provider, deteccion),
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
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Tarjeta del Reporte Original (solo lectura)
  // ───────────────────────────────────────────────────────────────

  Widget _buildReporteOriginalCard(DeteccionPeligro deteccion) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: _primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Reporte Original',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _text,
                  ),
                ),
                const Spacer(),
                _buildEstatusChip(deteccion.estatusSeguimiento),
              ],
            ),
            const Divider(height: 20),
            _buildInfoRow('Código de Contrato', deteccion.contratoCodigo, Icons.assignment),
            _buildInfoRow('Lugar Exacto', deteccion.lugarExacto, Icons.location_on),
            _buildInfoRow('Turno', deteccion.turno, Icons.access_time),
            _buildInfoRow('Nivel LGF', deteccion.nivelAtencionLabel, Icons.warning),
            if (deteccion.descripcionHallazgo != null && deteccion.descripcionHallazgo!.isNotEmpty)
              _buildInfoRow('Descripción', deteccion.descripcionHallazgo!, Icons.description),
            if (deteccion.accionInmediata != null && deteccion.accionInmediata!.isNotEmpty)
              _buildInfoRow('Acción Inmediata', deteccion.accionInmediata!, Icons.flash_on),
            if (deteccion.fotoEvidenciaUrl != null && deteccion.fotoEvidenciaUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text('Foto Evidencia: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    Expanded(
                      child: Text(
                        deteccion.fotoEvidenciaUrl!,
                        style: const TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (deteccion.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Reportado: ${_formatDateTime(deteccion.createdAt!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w600, color: _text),
          ),
          Expanded(child: Text(value, style: TextStyle(color: _text))),
        ],
      ),
    );
  }

  Widget _buildEstatusChip(String estatus) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (estatus) {
      case 'Pendiente':
        bgColor = AppTheme.warningYellow.withValues(alpha: 0.2);
        textColor = AppTheme.warningYellow;
        icon = Icons.schedule;
        break;
      case 'En Ejecución':
        bgColor = AppTheme.primaryBlue.withValues(alpha: 0.2);
        textColor = AppTheme.primaryBlue;
        icon = Icons.engineering;
        break;
      case 'Eliminada':
        bgColor = AppTheme.successGreen.withValues(alpha: 0.2);
        textColor = AppTheme.successGreen;
        icon = Icons.check_circle;
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.2);
        textColor = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(estatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Sección Dinámica según Estatus
  // ───────────────────────────────────────────────────────────────

  Widget _buildDynamicSection(PeligroProvider provider, DeteccionPeligro deteccion) {
    if (deteccion.isEliminada) {
      return _buildCierreView(deteccion);
    } else if (deteccion.isEnEjecucion) {
      return _buildFormularioCierre(provider, deteccion);
    } else {
      return _buildFormularioCompromiso(provider, deteccion);
    }
  }

  // ── Formulario de Compromiso (Pendiente → En Ejecución) ──

  Widget _buildFormularioCompromiso(PeligroProvider provider, DeteccionPeligro deteccion) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.handshake, color: _primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Compromiso de Eliminación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text),
                ),
              ],
            ),
            const Divider(height: 20),
            const Text(
              '¿Qué se hará o se está haciendo para eliminar este peligro?',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _planAccionController,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                labelText: 'Plan de Acción *',
                hintText: 'Describa las acciones que se tomarán o se están tomando...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedSupervisorId,
              decoration: InputDecoration(
                labelText: 'Supervisor Responsable *',
                prefixIcon: Icon(Icons.supervisor_account, color: _primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: provider.supervisores.map((s) {
                final nombre = '${s['nombre'] ?? ''} ${s['apellido_paterno'] ?? ''}';
                return DropdownMenuItem(value: s['id'] as int, child: Text(nombre));
              }).toList(),
              onChanged: (val) => setState(() => _selectedSupervisorId = val),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedFechaCompromiso ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  helpText: 'Fecha Compromiso de Eliminación',
                );
                if (picked != null) setState(() => _selectedFechaCompromiso = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fecha Compromiso de Eliminación *',
                  prefixIcon: Icon(Icons.calendar_today, color: _primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                child: Text(
                  _selectedFechaCompromiso != null
                      ? '${_selectedFechaCompromiso!.day.toString().padLeft(2, '0')}/${_selectedFechaCompromiso!.month.toString().padLeft(2, '0')}/${_selectedFechaCompromiso!.year}'
                      : 'Seleccione una fecha',
                  style: TextStyle(color: _selectedFechaCompromiso != null ? _text : Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: provider.isSubmitting ? null : () => _iniciarEjecucion(provider, deteccion.id!),
                icon: provider.isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow, size: 28),
                label: Text(
                  provider.isSubmitting ? 'Procesando...' : 'Iniciar Ejecución',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _iniciarEjecucion(PeligroProvider provider, int deteccionId) async {
    if (_planAccionController.text.trim().isEmpty) {
      _showError('Debe ingresar un plan de acción.');
      return;
    }
    if (_selectedSupervisorId == null) {
      _showError('Debe seleccionar un supervisor responsable.');
      return;
    }
    if (_selectedFechaCompromiso == null) {
      _showError('Debe seleccionar una fecha compromiso.');
      return;
    }

    final success = await provider.iniciarEjecucion(
      deteccionId: deteccionId,
      supervisorId: _selectedSupervisorId!,
      planAccion: _planAccionController.text.trim(),
      fechaCompromiso: _selectedFechaCompromiso!,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ejecución iniciada exitosamente.'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );
      setState(() {
        _planAccionController.clear();
        _selectedSupervisorId = null;
        _selectedFechaCompromiso = null;
      });
    }
  }

  // ── Formulario de Cierre (En Ejecución → Eliminada) ──

  Widget _buildFormularioCierre(PeligroProvider provider, DeteccionPeligro deteccion) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: _primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Cierre del Caso',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text),
                ),
              ],
            ),
            const Divider(height: 20),
            if (deteccion.planAccion != null && deteccion.planAccion!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Plan de Acción en ejecución:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(deteccion.planAccion!, style: const TextStyle(fontSize: 13)),
                    if (deteccion.fechaCompromisoEliminacion != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Compromiso: ${_formatDate(deteccion.fechaCompromisoEliminacion!)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('Resumen de Cierre *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            TextField(
              controller: _resumenCierreController,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Describa cómo se eliminó el peligro y las acciones finales realizadas...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 80,
              child: ElevatedButton.icon(
                onPressed: _pickFotoCierre,
                icon: Icon(_fotoCierrePath != null ? Icons.check_circle : Icons.camera_alt, size: 32),
                label: Text(
                  _fotoCierrePath != null ? 'Foto de cierre capturada' : 'CAPTURAR FOTO DE CIERRE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _fotoCierrePath != null ? _primary : _text,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _fotoCierrePath != null ? _success.withValues(alpha: 0.2) : Colors.grey.shade200,
                  foregroundColor: _text,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _fotoCierrePath != null ? _success : _primary, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: provider.isSubmitting ? null : () => _cerrarCaso(provider, deteccion.id!),
                icon: provider.isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_outline, size: 28),
                label: Text(
                  provider.isSubmitting ? 'Cerrando...' : 'Cerrar Caso',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFotoCierre() async {
    try {
      final picker = ImagePicker();
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Foto de Cierre'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
              child: ListTile(leading: Icon(Icons.camera_alt, color: _primary), title: const Text('Cámara')),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
              child: ListTile(leading: Icon(Icons.photo_library, color: _primary), title: const Text('Galería')),
            ),
          ],
        ),
      );
      if (source != null) {
        final photo = await picker.pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 80);
        if (photo != null) setState(() => _fotoCierrePath = photo.path);
      }
    } catch (e) {
      _showError('Error al capturar foto: $e');
    }
  }

  Future<void> _cerrarCaso(PeligroProvider provider, int deteccionId) async {
    if (_resumenCierreController.text.trim().isEmpty) {
      _showError('Debe ingresar un resumen de cierre.');
      return;
    }

    final success = await provider.cerrarCaso(
      deteccionId: deteccionId,
      resumenCierre: _resumenCierreController.text.trim(),
      fotoCierrePath: _fotoCierrePath,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caso cerrado exitosamente.'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );
      setState(() {
        _resumenCierreController.clear();
        _fotoCierrePath = null;
      });
    }
  }

  // ── Vista de Cierre (Eliminada - solo lectura) ──

  Widget _buildCierreView(DeteccionPeligro deteccion) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Caso Cerrado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const Divider(height: 20),
            if (deteccion.planAccion != null && deteccion.planAccion!.isNotEmpty) ...[
              const Text('Plan de Acción ejecutado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(deteccion.planAccion!),
              const SizedBox(height: 12),
            ],
            if (deteccion.resumenCierre != null && deteccion.resumenCierre!.isNotEmpty) ...[
              const Text('Resumen de Cierre:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(deteccion.resumenCierre!),
              const SizedBox(height: 12),
            ],
            if (deteccion.fotoCierreUrl != null && deteccion.fotoCierreUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text('Foto de Cierre: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    Expanded(
                      child: Text(
                        deteccion.fotoCierreUrl!,
                        style: const TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (deteccion.fechaCierre != null)
              Text(
                'Cerrado el: ${_formatDateTime(deteccion.fechaCierre!)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            if (deteccion.urlPdfEvolutivo != null && deteccion.urlPdfEvolutivo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Text('PDF Evolutivo: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    Expanded(
                      child: Text(
                        deteccion.urlPdfEvolutivo!,
                        style: const TextStyle(color: Colors.blue, fontSize: 12, decoration: TextDecoration.underline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}