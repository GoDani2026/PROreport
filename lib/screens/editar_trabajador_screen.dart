import 'package:flutter/material.dart';
import '../services/trabajador_service.dart';
import '../services/exceptions.dart';
import '../widgets/collapsible_sidebar.dart';
import '../config/theme_context_ext.dart';

class EditarTrabajadorScreen extends StatefulWidget {
  final Map<String, dynamic> trabajador;

  const EditarTrabajadorScreen({super.key, required this.trabajador});

  @override
  State<EditarTrabajadorScreen> createState() => _EditarTrabajadorScreenState();
}

class _EditarTrabajadorScreenState extends State<EditarTrabajadorScreen> {
  final _service = TrabajadorService();
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
    _vencimientoResidenciaController.text = t['fecha_vencimiento_residencia'] ?? 'PERMANENCIA DEFINITIVA';
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
    return null;
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
      final trabajadorId = widget.trabajador['id'] as int;

      final cumpl = await _service.fetchCumplimientoTrabajador(trabajadorId);
      debugPrint('[_loadRequisitos] Cargados ${cumpl.length} registros de cumplimiento para trabajador $trabajadorId');

      final reqs = await _service.fetchRequisitosHSE();

      final cumplMap = {for (var c in cumpl) c['requisito_id']: c};

      setState(() {
        _requisitos = List<Map<String, dynamic>>.from(reqs);
        _cumplimiento = _requisitos.map((r) {
          final id = r['id'];
          final existente = cumplMap[id];
          final requiereVenc = r['requiere_vencimiento'] ?? false;

          final fechaVenc = existente?['fecha_vencimiento'];
          String valorEstado;

          if (fechaVenc != null && fechaVenc.toString().isNotEmpty) {
            valorEstado = _calcularEstadoDesdeFecha(fechaVenc.toString());
          } else {
            final guardado = existente?['valor_estado'];
            valorEstado = (guardado != null && guardado.isNotEmpty) ? guardado : (requiereVenc ? 'VIGENTE' : 'N/A');
          }

          return {
            'requisito_id': id,
            'valor_estado': valorEstado,
            'fecha_vencimiento': fechaVenc,
            'requiere_vencimiento': requiereVenc,
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

  void _enterEditMode() {
    _saveOriginalCumplimiento();
    setState(() {
      _isEditing = true;
      _hasUnsavedChanges = false;
    });
  }

  void _cancelEdits() {
    _nombreController.text = _originalTrabajador['nombre'] ?? '';
    _apellidoPaternoController.text = _originalTrabajador['apellido_paterno'] ?? '';
    _apellidoMaternoController.text = _originalTrabajador['apellido_materno'] ?? '';
    _rutController.text = _originalTrabajador['rut'] ?? '';
    _cargoController.text = _originalTrabajador['cargo'] ?? '';
    _nacionalidadController.text = _originalTrabajador['nacionalidad'] ?? 'Chilena';
    _vencimientoResidenciaController.text = _originalTrabajador['fecha_vencimiento_residencia'] ?? 'PERMANENCIA DEFINITIVA';
    _turnoController.text = _originalTrabajador['turno'] ?? '';
    _contratoCodigoController.text = _originalTrabajador['contrato_codigo'] ?? '';
    _sexoSeleccionado = _getValidDropdownValue(_originalTrabajador['sexo'], _sexos);
    _estadoSeleccionado = _getValidDropdownValue(_originalTrabajador['estado_trabajador'], _estados);

    for (int i = 0; i < _cumplimiento.length && i < _originalCumplimiento.length; i++) {
      _cumplimiento[i]['valor_estado'] = _originalCumplimiento[i]['valor_estado'];
      _cumplimiento[i]['fecha_vencimiento'] = _originalCumplimiento[i]['fecha_vencimiento'];
    }

    setState(() {
      _isEditing = false;
      _hasUnsavedChanges = false;
    });
  }

  Future<bool> _confirmClose() async {
    if (!_hasUnsavedChanges) return true;
    final ctx = context;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctxDialog) => AlertDialog(
        backgroundColor: ctx.surfaceCard,
        title: Text('Cambios sin guardar', style: TextStyle(color: ctx.textPrimary)),
        content: Text('Tienes cambios sin guardar. ¿Deseas salir sin guardar?', style: TextStyle(color: ctx.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctxDialog, false), child: Text('Quedar', style: TextStyle(color: ctx.textPrimary))),
          TextButton(onPressed: () => Navigator.pop(ctxDialog, true), style: TextButton.styleFrom(foregroundColor: ctx.errorRed), child: const Text('Salir')),
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
      final trabajadorData = {
        'rut': _rutController.text.trim(),
        'nombre': _nombreController.text.trim(),
        'apellido_paterno': _apellidoPaternoController.text.trim(),
        'apellido_materno': _apellidoMaternoController.text.trim().isEmpty
            ? null
            : _apellidoMaternoController.text.trim(),
        'cargo': _cargoController.text.trim(),
        'nacionalidad': _nacionalidadController.text.trim(),
        'fecha_vencimiento_residencia': _vencimientoResidenciaController.text.trim().isEmpty
            ? null
            : _vencimientoResidenciaController.text.trim(),
        'turno': _turnoController.text.trim(),
        'contrato_codigo': _contratoCodigoController.text.trim(),
        'sexo': _sexoSeleccionado,
        'estado_trabajador': _estadoSeleccionado,
      };

      final cumplimientosData = _cumplimiento.map((item) => {
        'requisito_id': item['requisito_id'],
        'valor_estado': item['valor_estado'],
        'fecha_vencimiento': item['fecha_vencimiento'],
      }).toList();

      await _service.guardarTrabajadorCompleto(
        datosTrabajador: trabajadorData,
        cumplimientos: cumplimientosData,
      );

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
    } on ServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
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
    final ctx = context;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctxDialog) => AlertDialog(
        backgroundColor: ctx.surfaceCard,
        title: Text('Dar de baja al trabajador', style: TextStyle(color: ctx.textPrimary)),
        content: Text(
          'Se cambiará el estado a DESVINCULADO. Esta acción no elimina el registro, solo lo marca como inactivo.',
          style: TextStyle(color: ctx.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctxDialog, false), child: Text('Cancelar', style: TextStyle(color: ctx.textPrimary))),
          TextButton(onPressed: () => Navigator.pop(ctxDialog, true), style: TextButton.styleFrom(backgroundColor: Colors.red), child: Text('Confirmar baja', style: const TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isSaving = true);
    try {
      final trabajadorId = widget.trabajador['id'] as int;
      await _service.darDeBaja(trabajadorId);

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
    final ctx = context;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctxDialog) => AlertDialog(
        backgroundColor: ctx.surfaceCard,
        title: Text('Rehabilitar trabajador', style: TextStyle(color: ctx.textPrimary)),
        content: Text(
          'Se cambiará el estado a ACTIVO. El trabajador volverá a estar habilitado para faena.',
          style: TextStyle(color: ctx.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctxDialog, false), child: Text('Cancelar', style: TextStyle(color: ctx.textPrimary))),
          TextButton(onPressed: () => Navigator.pop(ctxDialog, true), style: TextButton.styleFrom(backgroundColor: ctx.successGreen), child: Text('Confirmar habilitación', style: const TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isSaving = true);
    try {
      final trabajadorId = widget.trabajador['id'] as int;
      await _service.rehabilitar(trabajadorId);

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
    final ctx = context;
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
        backgroundColor: ctx.surfaceBg,
        body: isWide
            ? CollapsibleSidebar(
                items: [
                  MenuItem(icon: Icons.dashboard_rounded, label: 'Inicio / Dashboard', color: ctx.accentBlue, onTap: () { _confirmClose().then((ok) { if (ok && mounted) navigator.pop(); }); }),
                  MenuItem(icon: Icons.person_rounded, label: 'Editar Trabajador', color: ctx.accentOrange, isActive: true, onTap: () {}),
                ],
                child: _buildBody(ctx: ctx, isWide: true, nombreCompleto: nombreCompleto, rut: rut, estadoActual: estadoActual),
              )
            : _buildBody(ctx: ctx, isWide: false, nombreCompleto: nombreCompleto, rut: rut, estadoActual: estadoActual),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext ctx,
    required bool isWide,
    required String nombreCompleto,
    required String rut,
    required String estadoActual,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ctx.dividerColor, width: 1))),
          child: Row(
            children: [
              _BotonVolver(onVolver: _confirmClose, ctx: ctx),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(_isEditing ? Icons.edit_rounded : Icons.visibility_rounded, color: _isEditing ? ctx.accentOrange : ctx.successGreen, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _isEditing ? 'Editando Trabajador' : 'Ficha de Trabajador',
                        style: TextStyle(color: ctx.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '$nombreCompleto   RUT: $rut   |   Estado: $estadoActual',
                      style: TextStyle(color: ctx.textSecondary, fontSize: 12),
                    ),
                    if (!_isEditing)
                      Text('Vista solo lectura — presiona "Editar" para modificar', style: TextStyle(color: ctx.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              if (!_isEditing) ...[
                _BotonEditar(onEdit: _enterEditMode, ctx: ctx),
                const SizedBox(width: 8),
                if (estadoActual == 'DESVINCULADO') _BotonRehabilitar(onRehabilitar: _rehabilitar, ctx: ctx),
                if (estadoActual != 'DESVINCULADO') _BotonDarBaja(onDarBaja: _darDeBaja, ctx: ctx),
              ],
              if (_isEditing) ...[
                TextButton(onPressed: _hasUnsavedChanges ? _cancelEdits : () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: ctx.textSecondary))),
                const SizedBox(width: 8),
                _BotonGuardar(onSave: _isSaving ? null : _guardarCambios, isSaving: _isSaving, ctx: ctx),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 16, isWide ? 24 : 16, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDatosMaestros(ctx),
                    const SizedBox(height: 20),
                    _buildRequisitosHSE(ctx),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isEditing) _buildFooter(ctx),
      ],
    );
  }

  Widget _buildDatosMaestros(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ctx.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ctx.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_isEditing ? Icons.edit_rounded : Icons.lock_outline_rounded, color: _isEditing ? ctx.accentOrange : ctx.textMuted, size: 18),
              const SizedBox(width: 8),
              Text(
                _isEditing ? 'MODIFICAR DATOS MAESTROS' : 'DATOS MAESTROS',
                style: TextStyle(color: ctx.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (!_isEditing)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: ctx.successGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('Solo lectura', style: TextStyle(color: ctx.successGreen, fontSize: 10, fontWeight: FontWeight.w600))),
              if (_isEditing)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: ctx.accentOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('Edición activa', style: TextStyle(color: ctx.accentOrange, fontSize: 10, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 14),
          _buildFieldRow([
            _buildField(ctx, 'RUT:', _rutController),
            _buildField(ctx, 'Cargo:', _cargoController),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            _buildField(ctx, 'Nombre:', _nombreController),
            _buildField(ctx, 'Apellido Paterno:', _apellidoPaternoController),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            _buildField(ctx, 'Apellido Materno:', _apellidoMaternoController),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            _buildField(ctx, 'Turno:', _turnoController),
            _buildField(ctx, 'Contrato:', _contratoCodigoController),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            _buildDropdownField(ctx, 'Nacionalidad:', _nacionalidadController.text, _nacionalidades, (v) { if (v != null) { _nacionalidadController.text = v; _markChanges(); } }),
            _buildField(ctx, 'Venc. Residencia:', _vencimientoResidenciaController),
          ]),
          const SizedBox(height: 10),
          _buildFieldRow([
            _buildDropdownField(ctx, 'Sexo:', _sexoSeleccionado, _sexos, (v) { if (v != null) { setState(() => _sexoSeleccionado = v); _markChanges(); } }),
            _buildDropdownField(ctx, 'Estado:', _estadoSeleccionado, _estados, (v) { if (v != null) { setState(() => _estadoSeleccionado = v); _markChanges(); } }),
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

  Widget _buildField(BuildContext ctx, String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: ctx.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          if (!_isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: ctx.surfaceBg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Text(controller.text.isEmpty ? '—' : controller.text, style: TextStyle(color: ctx.textPrimary, fontSize: 13)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: ctx.surfaceInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ctx.borderColor, width: 0.5),
              ),
              child: TextField(
                controller: controller,
                style: TextStyle(color: ctx.textPrimary, fontSize: 13),
                decoration: const InputDecoration(isDense: true, border: InputBorder.none),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
      BuildContext ctx, String label, String? valor, List<String> items, ValueChanged<String?> onChange) {
    final safeValor = _getValidDropdownValue(valor, items);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: ctx.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          if (!_isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: ctx.surfaceBg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Text(valor?.isEmpty ?? true ? '—' : (valor ?? ''), style: TextStyle(color: ctx.textPrimary, fontSize: 13)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ctx.surfaceInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ctx.borderColor, width: 0.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: safeValor,
                  isDense: true,
                  isExpanded: true,
                  dropdownColor: ctx.surfaceCard,
                  style: TextStyle(color: ctx.textPrimary, fontSize: 13),
                  hint: Text('Seleccionar...', style: TextStyle(color: ctx.textMuted, fontSize: 13)),
                  items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: ctx.textPrimary)))).toList(),
                  onChanged: (v) => onChange(v),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequisitosHSE(BuildContext ctx) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assignment_rounded, color: _isEditing ? ctx.accentOrange : ctx.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              _isEditing ? 'ACTUALIZACIÓN DE ESTADOS MANDANTE' : 'ESTADOS MANDANTE',
              style: TextStyle(color: ctx.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (!_isEditing)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: ctx.successGreen.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('Solo lectura', style: TextStyle(color: ctx.successGreen, fontSize: 10, fontWeight: FontWeight.w600))),
            if (_isEditing)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: ctx.accentOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('Edición activa', style: TextStyle(color: ctx.accentOrange, fontSize: 10, fontWeight: FontWeight.w600))),
          ],
        ),
        const SizedBox(height: 14),
        if (_requisitos.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: ctx.accentOrange)))
        else if (isTablet)
          _buildTabletRequisitos(ctx)
        else
          _buildMobileRequisitos(ctx),
      ],
    );
  }

  Color _colorEstado(String valor) {
    switch (valor) {
      case 'VIGENTE':
        return ctx.successGreen;
      case 'VENCIDO':
        return ctx.errorRed;
      default:
        return ctx.accentOrange;
    }
  }

  BuildContext get ctx => context;

  Widget _buildTabletRequisitos(BuildContext ctx) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 700),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(ctx.accentBlue.withValues(alpha: 0.3)),
            dividerThickness: 0.5,
            columns: [
              DataColumn(label: Text('#', style: TextStyle(color: ctx.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('REQUISITO HSE', style: TextStyle(color: ctx.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('FECHA / N/A', style: TextStyle(color: ctx.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('ESTADO', style: TextStyle(color: ctx.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
            ],
            rows: _cumplimiento.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              final estado = c['valor_estado'] ?? 'N/A';
              final fecha = c['fecha_vencimiento'] as String?;

              return DataRow(cells: [
                DataCell(Text('${i + 1}', style: TextStyle(color: ctx.textSecondary, fontSize: 12))),
                DataCell(Text(c['nombre'], style: TextStyle(color: ctx.textPrimary, fontSize: 13))),
                DataCell(_buildSelectorFechaYNA(ctx, i, fecha, estado)),
                DataCell(_buildBadgeEstado(ctx, estado, _colorEstado(estado))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileRequisitos(BuildContext ctx) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cumplimiento.length,
      itemBuilder: (context, i) {
        final c = _cumplimiento[i];
        final estado = c['valor_estado'] ?? 'N/A';
        final fecha = c['fecha_vencimiento'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ctx.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ctx.borderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${i + 1}. ${c['nombre']}', style: TextStyle(color: ctx.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(flex: 3, child: _buildSelectorFechaYNA(ctx, i, fecha, estado)),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: _buildBadgeEstado(ctx, estado, _colorEstado(estado))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _calcularEstadoDesdeFecha(String? fechaStr, {String fallback = 'N/A'}) {
    if (fechaStr == null || fechaStr.isEmpty) return fallback;
    try {
      final fecha = DateTime.parse(fechaStr);
      return fecha.isAfter(DateTime.now()) ? 'VIGENTE' : 'VENCIDO';
    } catch (_) {
      return fallback;
    }
  }

  void _actualizarEstado(int index, {String? fecha, bool esNoAplica = false}) {
    setState(() {
      if (esNoAplica) {
        _cumplimiento[index]['fecha_vencimiento'] = null;
        _cumplimiento[index]['valor_estado'] = 'N/A';
      } else {
        _cumplimiento[index]['fecha_vencimiento'] = fecha;
        _cumplimiento[index]['valor_estado'] = _calcularEstadoDesdeFecha(fecha);
      }
      _markChanges();
    });
  }

  Widget _buildSelectorFechaYNA(BuildContext ctx, int index, String? fecha, String estadoActual) {
    final esNoAplica = estadoActual == 'N/A';

    if (!_isEditing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ctx.surfaceBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ctx.dividerColor.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Text(
          esNoAplica ? 'N/A' : (fecha ?? '—'),
          style: TextStyle(color: esNoAplica ? ctx.textMuted : ctx.textPrimary, fontSize: 12),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => _actualizarEstado(index, esNoAplica: !esNoAplica),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: esNoAplica ? ctx.accentOrange.withValues(alpha: 0.25) : ctx.surfaceInput,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: esNoAplica ? ctx.accentOrange.withValues(alpha: 0.8) : ctx.borderColor, width: esNoAplica ? 1.5 : 1),
          ),
          child: Text('N/A', style: TextStyle(
            color: esNoAplica ? ctx.accentOrange : ctx.textMuted,
            fontSize: 11, fontWeight: esNoAplica ? FontWeight.w700 : FontWeight.w600,
          )),
        ),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: () => _seleccionarFechaRequisito(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: esNoAplica ? ctx.surfaceInput : ctx.accentBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: esNoAplica ? ctx.borderColor : ctx.accentBlue.withValues(alpha: 0.5), width: esNoAplica ? 0.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                esNoAplica ? 'Sin fecha' : (fecha ?? 'Seleccionar'),
                style: TextStyle(
                  color: esNoAplica ? ctx.textMuted : ctx.textPrimary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.calendar_today_rounded, color: esNoAplica ? ctx.textMuted : ctx.accentBlue, size: 14),
            ],
          ),
        ),
      ),
    ]);
  }

  Future<void> _seleccionarFechaRequisito(int index) async {
    final fechaActualStr = _cumplimiento[index]['fecha_vencimiento'] as String?;
    final fechaInicial = fechaActualStr != null
        ? DateTime.tryParse(fechaActualStr) ?? DateTime.now()
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      final fechaStr = picked.toIso8601String().split('T')[0];
      _actualizarEstado(index, fecha: fechaStr);
    }
  }

  Widget _buildBadgeEstado(BuildContext ctx, String estado, Color color) {
    if (!_isEditing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Text(estado, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        estado == 'VIGENTE' ? '✓ Vigente' : (estado == 'VENCIDO' ? '✗ Vencido' : '— N/A'),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFooter(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ctx.surfaceCard,
        border: Border(top: BorderSide(color: ctx.dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _cancelEdits,
              style: OutlinedButton.styleFrom(foregroundColor: ctx.textSecondary, side: BorderSide(color: ctx.borderColor)),
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
              style: ElevatedButton.styleFrom(backgroundColor: ctx.accentOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
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
  final BuildContext ctx;

  const _BotonVolver({required this.onVolver, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: ctx.surfaceCard,
        border: Border.all(color: ctx.borderColor, width: 0.5),
      ),
      child: IconButton(
        onPressed: () async {
          final ok = await onVolver();
          if (ok && context.mounted) Navigator.of(context).pop();
        },
        icon: Icon(Icons.arrow_back_rounded, color: ctx.textSecondary),
        tooltip: 'Volver',
      ),
    );
  }
}

class _BotonEditar extends StatelessWidget {
  final VoidCallback onEdit;
  final BuildContext ctx;
  const _BotonEditar({required this.onEdit, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(colors: [ctx.accentOrange, ctx.accentOrange.withValues(alpha: 0.8)])),
      child: ElevatedButton.icon(
        onPressed: onEdit,
        icon: const Icon(Icons.edit_rounded, size: 16),
        label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
      ),
    );
  }
}

class _BotonDarBaja extends StatelessWidget {
  final VoidCallback onDarBaja;
  final BuildContext ctx;
  const _BotonDarBaja({required this.onDarBaja, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: ctx.errorRed.withValues(alpha: 0.2)),
      child: ElevatedButton.icon(
        onPressed: onDarBaja,
        icon: Icon(Icons.person_off_rounded, size: 16, color: ctx.errorRed),
        label: Text('Dar de baja', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ctx.errorRed)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
      ),
    );
  }
}

class _BotonRehabilitar extends StatelessWidget {
  final VoidCallback onRehabilitar;
  final BuildContext ctx;
  const _BotonRehabilitar({required this.onRehabilitar, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: ctx.successGreen.withValues(alpha: 0.2)),
      child: ElevatedButton.icon(
        onPressed: onRehabilitar,
        icon: Icon(Icons.replay_rounded, size: 16, color: ctx.successGreen),
        label: Text('Rehabilitar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ctx.successGreen)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
      ),
    );
  }
}

class _BotonGuardar extends StatelessWidget {
  final VoidCallback? onSave;
  final bool isSaving;
  final BuildContext ctx;
  const _BotonGuardar({required this.onSave, required this.isSaving, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: LinearGradient(colors: [ctx.successGreen, ctx.successGreen.withValues(alpha: 0.8)])),
      child: ElevatedButton.icon(
        onPressed: onSave,
        icon: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 16),
        label: Text(isSaving ? 'Guardando...' : 'Guardar', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
      ),
    );
  }
}