import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/collapsible_sidebar.dart';

// ──────────────────────────────────────────────────────────────
// Color palette for HSE Dark Dashboard (same as home_screen)
// ──────────────────────────────────────────────────────────────
const Color _bgDark = Color(0xFF0A1628);
const Color _cardDark = Color(0xFF132336);
const Color _cardBorder = Color(0xFF1E3456);
const Color _accentBlue = Color(0xFF1B3A5C);
const Color _green = Color(0xFF00E676);
const Color _red = Color(0xFFFF5252);
const Color _orange = Color(0xFFFF6B35);
const Color _textPrimary = Color(0xFFECEFF1);
const Color _textSecondary = Color(0xFF90A4AE);
const Color _textMuted = Color(0xFF607D8B);
const Color _divider = Color(0xFF1E3456);

class EditarTrabajadorScreen extends StatefulWidget {
  final Map<String, dynamic> trabajador;

  const EditarTrabajadorScreen({super.key, required this.trabajador});

  @override
  State<EditarTrabajadorScreen> createState() => _EditarTrabajadorScreenState();
}

class _EditarTrabajadorScreenState extends State<EditarTrabajadorScreen> {
  final _supabase = Supabase.instance.client;
  bool _isSaving = false;

  // ── Modo edición ──
  bool _isEditing = false;
  bool _hasUnsavedChanges = false;

  // Copias originales para poder deshacer
  late Map<String, dynamic> _originalTrabajador;
  late List<Map<String, dynamic>> _originalCumplimiento;

  // Datos del trabajador (editable)
  final _nombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _rutController = TextEditingController();
  final _cargoController = TextEditingController();
  final _nacionalidadController = TextEditingController();
  final _vencimientoResidenciaController = TextEditingController();
  final _turnoController = TextEditingController();
  final _contratoCodigoController = TextEditingController();

  String? _sexoSeleccionado;
  String? _estadoSeleccionado;

  // Requisitos HSE (12 items)
  List<Map<String, dynamic>> _requisitos = [];
  List<Map<String, dynamic>> _cumplimiento = [];

  // Opciones de dropdown
  static const _nacionalidades = [
    'Chilena', 'Boliviana', 'Peruana', 'Colombiana', 'Argentina',
    'Venezolana', 'Ecuatoriana', 'Paraguaya', 'Uruguaya',
    'Brazilera', 'Americana', 'Española', 'Otra'
  ];
  static const _sexos = ['M', 'F', 'Otro'];
  static const _estados = ['ACTIVO', 'DESVINCULADO', 'LICENCIA'];
  static const _estadosRequisito = ['VIGENTE', 'SI', 'NO', 'N/A', 'VENCIDO'];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _saveOriginals();
    _loadRequisitos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _rutController.dispose();
    _cargoController.dispose();
    _nacionalidadController.dispose();
    _vencimientoResidenciaController.dispose();
    _turnoController.dispose();
    _contratoCodigoController.dispose();
    super.dispose();
  }

  void _initControllers() {
    final t = widget.trabajador;
    _nombreController.text = t['nombre'] ?? '';
    _apellidoPaternoController.text = t['apellido_paterno'] ?? '';
    _apellidoMaternoController.text = t['apellido_materno'] ?? '';
    _rutController.text = t['rut'] ?? '';
    _cargoController.text = t['cargo'] ?? '';
    _nacionalidadController.text = t['nacionalidad'] ?? 'Chilena';
    _vencimientoResidenciaController.text = t['vencimiento_residencia'] ?? 'PERMANENCIA DEFINITIVA';
    _turnoController.text = t['turno'] ?? '';
    _contratoCodigoController.text = t['contrato_codigo'] ?? '';
    _sexoSeleccionado = _getValidDropdownValue(t['sexo'], _sexos);
    _estadoSeleccionado = _getValidDropdownValue(t['estado_trabajador'], _estados);
  }

  /// Safe dropdown value: returns a value that exists in the items list, or null
  static String? _getValidDropdownValue(String? currentValue, List<String> availableItems) {
    if (currentValue == null || currentValue.isEmpty) return null;
    if (availableItems.contains(currentValue)) return currentValue;
    // Try case-insensitive match
    final match = availableItems.firstWhere(
      (item) => item.toLowerCase() == currentValue.toLowerCase(),
      orElse: () => '',
    );
    if (match.isNotEmpty) return match;
    return null; // Let the UI pick the first item or show "Otra"
  }

  void _saveOriginals() {
    _originalTrabajador = Map<String, dynamic>.from(widget.trabajador);
  }

  void _saveOriginalCumplimiento() {
    _originalCumplimiento = _cumplimiento.map((c) => Map<String, dynamic>.from(c)).toList();
  }

  void _markChanges() {
    if (!_isEditing) return;
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  /// Add listeners to all controllers for dirty tracking
  void _setupChangeListeners() {
    for (final controller in [
      _nombreController, _apellidoPaternoController, _apellidoMaternoController,
      _rutController, _cargoController, _nacionalidadController,
      _vencimientoResidenciaController, _turnoController, _contratoCodigoController,
    ]) {
      controller.addListener(_markChanges);
    }
  }

  Future<void> _loadRequisitos() async {
    try {
      final reqs = await _supabase.from('requisitos_hse').select().order('id', ascending: true);
      final trabajadorId = widget.trabajador['id'];
      final cumpl = await _supabase.from('cumplimiento_trabajadores').select().eq('trabajador_id', trabajadorId);

      final cumplMap = {for (var c in cumpl) c['requisito_id']: c};

      setState(() {
        _requisitos = List<Map<String, dynamic>>.from(reqs);
        _cumplimiento = _requisitos.map((r) {
          final id = r['id'];
          final existente = cumplMap[id];
          return {
            'requisito_id': id,
            'valor_estado': existente?['valor_estado'] ?? 'N/A',
            'fecha_vencimiento': existente?['fecha_vencimiento'],
            'requiere_vencimiento': r['requiere_vencimiento'] ?? false,
            'nombre': r['nombre_requisito'] ?? '',
          };
        }).toList();
      });
      _saveOriginalCumplimiento();
      _setupChangeListeners();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando requisitos: $e')),
        );
      }
    }
  }

  /// Enter edit mode
  void _enterEditMode() {
    _saveOriginalCumplimiento();
    setState(() {
      _isEditing = true;
      _hasUnsavedChanges = false;
    });
  }

  /// Cancel edits and restore originals
  void _cancelEdits() {
    _nombreController.text = _originalTrabajador['nombre'] ?? '';
    _apellidoPaternoController.text = _originalTrabajador['apellido_paterno'] ?? '';
    _apellidoMaternoController.text = _originalTrabajador['apellido_materno'] ?? '';
    _rutController.text = _originalTrabajador['rut'] ?? '';
    _cargoController.text = _originalTrabajador['cargo'] ?? '';
    _nacionalidadController.text = _originalTrabajador['nacionalidad'] ?? 'Chilena';
    _vencimientoResidenciaController.text = _originalTrabajador['vencimiento_residencia'] ?? 'PERMANENCIA DEFINITIVA';
    _turnoController.text = _originalTrabajador['turno'] ?? '';
    _contratoCodigoController.text = _originalTrabajador['contrato_codigo'] ?? '';
    _sexoSeleccionado = _getValidDropdownValue(_originalTrabajador['sexo'], _sexos);
    _estadoSeleccionado = _getValidDropdownValue(_originalTrabajador['estado_trabajador'], _estados);

    // Restore cumplimiento
    for (int i = 0; i < _cumplimiento.length && i < _originalCumplimiento.length; i++) {
      _cumplimiento[i]['valor_estado'] = _originalCumplimiento[i]['valor_estado'];
      _cumplimiento[i]['fecha_vencimiento'] = _originalCumplimiento[i]['fecha_vencimiento'];
    }

    setState(() {
      _isEditing = false;
      _hasUnsavedChanges = false;
    });
  }

  /// Confirm close when there are unsaved changes
  Future<bool> _confirmClose() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Cambios sin guardar', style: TextStyle(color: Colors.white)),
        content: const Text('Tienes cambios sin guardar. ¿Deseas salir sin guardar?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Quedar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: _red), child: const Text('Salir')),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _guardarCambios() async {
    if (_nombreController.text.isEmpty ||
        _apellidoPaternoController.text.isEmpty ||
        _cargoController.text.isEmpty ||
        _turnoController.text.isEmpty ||
        _contratoCodigoController.text.isEmpty ||
        _estadoSeleccionado == null ||
        _sexoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete todos los campos obligatorios')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final trabajadorId = widget.trabajador['id'];

      await _supabase.from('trabajadores').update({
        'rut': _rutController.text.trim(),
        'nombre': _nombreController.text.trim(),
        'apellido_paterno': _apellidoPaternoController.text.trim(),
        'apellido_materno': _apellidoMaternoController.text.trim().isEmpty
            ? null
            : _apellidoMaternoController.text.trim(),
        'cargo': _cargoController.text.trim(),
        'nacionalidad': _nacionalidadController.text.trim(),
        'vencimiento_residencia': _vencimientoResidenciaController.text.trim().isEmpty
            ? null
            : _vencimientoResidenciaController.text.trim(),
        'turno': _turnoController.text.trim(),
        'contrato_codigo': _contratoCodigoController.text.trim(),
        'sexo': _sexoSeleccionado,
        'estado_trabajador': _estadoSeleccionado,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', trabajadorId);

      for (final item in _cumplimiento) {
        await _supabase.from('cumplimiento_trabajadores').upsert({
          'trabajador_id': trabajadorId,
          'requisito_id': item['requisito_id'],
          'valor_estado': item['valor_estado'],
          'fecha_vencimiento': item['fecha_vencimiento'],
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'trabajador_id,requisito_id');
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
          _hasUnsavedChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados exitosamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _darDeBaja() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Dar de baja al trabajador', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se cambiará el estado a DESVINCULADO. Esta acción no elimina el registro, solo lo marca como inactivo.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(backgroundColor: Colors.red), child: const Text('Confirmar baja', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isSaving = true);
    try {
      final trabajadorId = widget.trabajador['id'];
      await _supabase.from('trabajadores').update({
        'estado_trabajador': 'DESVINCULADO',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', trabajadorId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trabajador dado de baja correctamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al dar de baja: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _rehabilitar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: const Text('Rehabilitar trabajador', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se cambiará el estado a ACTIVO. El trabajador volverá a estar habilitado para faena.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(backgroundColor: _green), child: const Text('Confirmar habilitación', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isSaving = true);
    try {
      final trabajadorId = widget.trabajador['id'];
      await _supabase.from('trabajadores').update({
        'estado_trabajador': 'ACTIVO',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', trabajadorId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trabajador habilitado nuevamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al habilitar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    final nombreCompleto =
        '${widget.trabajador['nombre'] ?? ''} ${widget.trabajador['apellido_paterno'] ?? ''} ${widget.trabajador['apellido_materno'] ?? ''}'.trim();
    final rut = widget.trabajador['rut'] ?? '';
    final estadoActual = widget.trabajador['estado_trabajador'] ?? 'ACTIVO';
    final navigator = Navigator.of(context);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmClose().then((shouldClose) {
          if (shouldClose && mounted) navigator.maybePop();
        });
      },
      child: Scaffold(
        backgroundColor: _bgDark,
        body: isWide
            ? CollapsibleSidebar(
                items: [
                  MenuItem(icon: Icons.dashboard_rounded, label: 'Inicio / Dashboard', color: _accentBlue, onTap: () { _confirmClose().then((ok) { if (ok && mounted) navigator.pop(); }); }),
                  MenuItem(icon: Icons.person_rounded, label: 'Editar Trabajador', color: _orange, isActive: true, onTap: () {}),
                ],
                child: _buildBody(isWide: true, nombreCompleto: nombreCompleto, rut: rut, estadoActual: estadoActual),
              )
            : _buildBody(isWide: false, nombreCompleto: nombreCompleto, rut: rut, estadoActual: estadoActual),
      ),
    );
  }

  Widget _buildBody({
    required bool isWide,
    required String nombreCompleto,
    required String rut,
    required String estadoActual,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _divider, width: 1))),
          child: Row(
            children: [
              // Botón Volver atrás
              _BotonVolver(onVolver: _confirmClose),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(_isEditing ? Icons.edit_rounded : Icons.visibility_rounded, color: _isEditing ? _orange : _green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _isEditing ? 'Editando Trabajador' : 'Ficha de Trabajador',
                        style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '$nombreCompleto   RUT: $rut   |   Estado: $estadoActual',
                      style: const TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    if (!_isEditing)
                      Text('Vista solo lectura — presiona "Editar" para modificar', style: TextStyle(color: _textMuted, fontSize: 11)),
                  ],
                ),
              ),
              // ── Action buttons in header ──
              if (!_isEditing) ...[
                _BotonEditar(onEdit: _enterEditMode),
                const SizedBox(width: 8),
                if (estadoActual == 'DESVINCULADO') _BotonRehabilitar(onRehabilitar: _rehabilitar),
                if (estadoActual != 'DESVINCULADO') _BotonDarBaja(onDarBaja: _darDeBaja),
              ],
              if (_isEditing) ...[
                TextButton(onPressed: _hasUnsavedChanges ? _cancelEdits : () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: _textSecondary))),
                const SizedBox(width: 8),
                _BotonGuardar(onSave: _isSaving ? null : _guardarCambios, isSaving: _isSaving),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 16, isWide ? 24 : 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDatosMaestros(),
                const SizedBox(height: 20),
                _buildRequisitosHSE(),
              ],
            ),
          ),
        ),
        // Footer (only in edit mode)
        if (_isEditing) _buildFooter(),
      ],
    );
  }

  Widget _buildDatosMaestros() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_isEditing ? Icons.edit_rounded : Icons.lock_outline_rounded, color: _isEditing ? _orange : _textMuted, size: 18),
              const SizedBox(width: 8),
              Text(
                _isEditing ? 'MODIFICAR DATOS MAESTROS' : 'DATOS MAESTROS',
                style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (!_isEditing)
                Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('Solo lectura', style: TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w600))),
              if (_isEditing)
                Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('Edición activa', style: TextStyle(color: _orange, fontSize: 10, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 14),
          _buildFieldRow([
            _buildField('RUT:', _rutController),
            _buildField('Cargo:', _cargoController),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            _buildField('Nombre:', _nombreController),
            _buildField('Apellido Paterno:', _apellidoPaternoController),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            _buildField('Apellido Materno:', _apellidoMaternoController),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            _buildField('Turno:', _turnoController),
            _buildField('Contrato:', _contratoCodigoController),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            _buildDropdownField('Nacionalidad:', _nacionalidadController.text, _nacionalidades, (v) { if (v != null) { _nacionalidadController.text = v; _markChanges(); } }),
            _buildField('Venc. Residencia:', _vencimientoResidenciaController),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            _buildDropdownField('Sexo:', _sexoSeleccionado, _sexos, (v) { if (v != null) { setState(() => _sexoSeleccionado = v); _markChanges(); } }),
            _buildDropdownField('Estado:', _estadoSeleccionado, _estados, (v) { if (v != null) { setState(() => _estadoSeleccionado = v); _markChanges(); } }),
          ]),
        ],
      ),
    );
  }

  Widget _buildFieldRow(List<Widget> children) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    if (isTablet) {
      return Row(children: children.map((w) => Expanded(child: w)).toList());
    }
    return Column(children: children);
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          if (!_isEditing)
            // Read-only display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: _bgDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _divider.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Text(controller.text.isEmpty ? '—' : controller.text, style: TextStyle(color: _textPrimary, fontSize: 13)),
            )
          else
            // Editable field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: _bgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _divider, width: 0.5),
              ),
              child: TextField(
                controller: controller,
                style: const TextStyle(color: _textPrimary, fontSize: 13),
                decoration: const InputDecoration(isDense: true, border: InputBorder.none),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
      String label, String? valor, List<String> items, ValueChanged<String?> onChange) {
    // Ensure valor is always a valid dropdown value
    final safeValor = _getValidDropdownValue(valor, items);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          if (!_isEditing)
            // Read-only display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: _bgDark.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _divider.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Text(valor?.isEmpty ?? true ? '—' : (valor ?? ''), style: TextStyle(color: _textPrimary, fontSize: 13)),
            )
          else
            // Editable dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _bgDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _divider, width: 0.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: safeValor,
                  isDense: true,
                  isExpanded: true,
                  dropdownColor: _cardDark,
                  style: const TextStyle(color: _textPrimary, fontSize: 13),
                  hint: Text('Seleccionar...', style: TextStyle(color: _textMuted, fontSize: 13)),
                  items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => onChange(v),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequisitosHSE() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assignment_rounded, color: _isEditing ? _orange : _textMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              _isEditing ? 'ACTUALIZACIÓN DE ESTADOS MANDANTE' : 'ESTADOS MANDANTE',
              style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (!_isEditing)
              Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('Solo lectura', style: TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w600))),
            if (_isEditing)
              Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('Edición activa', style: TextStyle(color: _orange, fontSize: 10, fontWeight: FontWeight.w600))),
          ],
        ),
        const SizedBox(height: 14),
        if (_requisitos.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _orange)))
        else if (isTablet)
          _buildTabletRequisitos()
        else
          _buildMobileRequisitos(),
      ],
    );
  }

  Color _colorEstado(String valor) {
    switch (valor) {
      case 'VIGENTE':
      case 'SI':
        return _green;
      case 'VENCIDO':
      case 'NO':
        return _red;
      default:
        return _orange;
    }
  }

  Widget _buildTabletRequisitos() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 700),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(_accentBlue.withValues(alpha: 0.3)),
            dividerThickness: 0.5,
            columns: const [
              DataColumn(label: Text('#', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('REQUISITO HSE', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('ESTADO VALOR', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('FECHA VENCIMIENTO', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
            ],
            rows: _cumplimiento.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              final requiereVen = c['requiere_vencimiento'] == true;
              final estado = c['valor_estado'] ?? 'N/A';
              final fecha = c['fecha_vencimiento'] as String?;

              return DataRow(cells: [
                DataCell(Text('${i + 1}', style: const TextStyle(color: _textSecondary, fontSize: 12))),
                DataCell(Text(c['nombre'], style: const TextStyle(color: _textPrimary, fontSize: 13))),
                DataCell(_buildEstadoDropdown(i, estado, _colorEstado(estado))),
                DataCell(_buildFechaField(i, requiereVen, estado, fecha)),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileRequisitos() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cumplimiento.length,
      itemBuilder: (context, i) {
        final c = _cumplimiento[i];
        final requiereVen = c['requiere_vencimiento'] == true;
        final estado = c['valor_estado'] ?? 'N/A';
        final fecha = c['fecha_vencimiento'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cardBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${i + 1}. ${c['nombre']}', style: const TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildEstadoDropdown(i, estado, _colorEstado(estado))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildFechaField(i, requiereVen, estado, fecha)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEstadoDropdown(int index, String valorActual, Color color) {
    final safeValor = _getValidDropdownValue(valorActual, _estadosRequisito);

    if (!_isEditing) {
      // Read-only display
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Text(valorActual, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValor,
          isDense: true,
          isExpanded: true,
          dropdownColor: _cardDark,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          hint: Text('Seleccionar...', style: TextStyle(color: _textMuted, fontSize: 12)),
          items: _estadosRequisito.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _cumplimiento[index]['valor_estado'] = v;
              final requiereVen = _cumplimiento[index]['requiere_vencimiento'] == true;
              if (!requiereVen || v == 'SI' || v == 'N/A') {
                _cumplimiento[index]['fecha_vencimiento'] = null;
              }
              _markChanges();
            });
          },
        ),
      ),
    );
  }

  Widget _buildFechaField(int index, bool requiereVencimiento, String estado, String? fecha) {
    final mostrarFecha = requiereVencimiento && estado != 'SI' && estado != 'N/A';

    if (!mostrarFecha) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _bgDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _divider, width: 0.5),
        ),
        child: Text('-- No Aplica --', style: TextStyle(color: _textMuted, fontSize: 12)),
      );
    }

    if (!_isEditing) {
      // Read-only display
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _bgDark.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _divider.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Text(fecha ?? '—', style: TextStyle(color: fecha != null ? _textPrimary : _textMuted, fontSize: 12)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _divider, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              fecha ?? 'dd/mm/aaaa',
              style: TextStyle(color: fecha != null ? _textPrimary : _textMuted, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, color: _textSecondary, size: 16),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: fecha != null ? DateTime.parse(fecha) : DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  _cumplimiento[index]['fecha_vencimiento'] = picked.toIso8601String().split('T')[0];
                  _markChanges();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardDark,
        border: Border(top: BorderSide(color: _divider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _cancelEdits,
              style: OutlinedButton.styleFrom(foregroundColor: _textSecondary, side: BorderSide(color: _divider)),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _guardarCambios,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar Cambios'),
              style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header Buttons ──

class _BotonVolver extends StatelessWidget {
  final Future<bool> Function() onVolver;

  const _BotonVolver({required this.onVolver});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _cardDark,
        border: Border.all(color: _cardBorder, width: 0.5),
      ),
      child: IconButton(
        onPressed: () async {
          final ok = await onVolver();
          if (ok && context.mounted) Navigator.of(context).pop();
        },
        icon: const Icon(Icons.arrow_back_rounded, color: _textSecondary),
        tooltip: 'Volver',
      ),
    );
  }
}

class _BotonEditar extends StatelessWidget {
  final VoidCallback onEdit;
  const _BotonEditar({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(colors: [_orange, const Color(0xFFE65100)])),
      child: ElevatedButton.icon(
        onPressed: onEdit,
        icon: const Icon(Icons.edit_rounded, size: 16),
        label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
      ),
    );
  }
}

class _BotonGuardar extends StatelessWidget {
  final VoidCallback? onSave;
  final bool isSaving;
  const _BotonGuardar({required this.onSave, required this.isSaving});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(colors: [_green, const Color(0xFF00C853)])),
      child: ElevatedButton.icon(
        onPressed: onSave,
        icon: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 16),
        label: Text(isSaving ? 'Guardando...' : 'Guardar', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
      ),
    );
  }
}

class _BotonDarBaja extends StatelessWidget {
  final VoidCallback onDarBaja;
  const _BotonDarBaja({required this.onDarBaja});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onDarBaja,
      icon: const Icon(Icons.person_off_rounded, color: Colors.red, size: 16),
      label: const Text('DAR DE BAJA', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.1), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
    );
  }
}

class _BotonRehabilitar extends StatelessWidget {
  final VoidCallback onRehabilitar;
  const _BotonRehabilitar({required this.onRehabilitar});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onRehabilitar,
      icon: const Icon(Icons.person_add_alt_rounded, color: _green, size: 16),
      label: const Text('HABILITAR', style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(backgroundColor: _green.withValues(alpha: 0.1), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
    );
  }
}