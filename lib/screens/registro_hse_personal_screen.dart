import 'package:flutter/material.dart';
import '../services/trabajador_service.dart';
import '../widgets/collapsible_sidebar.dart';
import 'editar_trabajador_screen.dart';

const Color _bgDark = Color(0xFF0A1628);
const Color _cardDark = Color(0xFF132336);
const Color _cardBorder = Color(0xFF1E3456);
const Color _accentBlue = Color(0xFF1B3A5C);
const Color _green = Color(0xFF00E676);
const Color _orange = Color(0xFFFF6B35);
const Color _textPrimary = Color(0xFFECEFF1);
const Color _textSecondary = Color(0xFF90A4AE);
const Color _textMuted = Color(0xFF607D8B);
const Color _divider = Color(0xFF1E3456);

class RegistroHSEPersonalScreen extends StatefulWidget {
  final Map<String, dynamic>? trabajadorEdit;

  const RegistroHSEPersonalScreen({super.key, this.trabajadorEdit});

  @override
  State<RegistroHSEPersonalScreen> createState() => _RegistroHSEPersonalScreenState();
}

class _RegistroHSEPersonalScreenState extends State<RegistroHSEPersonalScreen> {
  final _service = TrabajadorService();
  int _pasoActual = 0;

  final _rutController = TextEditingController();
  final _nombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _cargoController = TextEditingController();
  final _nacionalidadController = TextEditingController(text: 'Boliviana');
  final _vencimientoResidenciaController = TextEditingController(text: 'PERMANENCIA DEFINITIVA');
  String? _sexoSeleccionado;
  final _turnoController = TextEditingController();
  final _contratoCodigoController = TextEditingController();
  String? _estadoSeleccionado;
  String? _tipoSeleccionado;
  String? _mutualidadSeleccionada;

  List<Map<String, dynamic>> _requisitos = [];
  List<Map<String, dynamic>> _cumplimientoData = [];
  bool _isLoadingRequisitos = false;
  bool _isGuardando = false;

  @override
  void initState() {
    super.initState();
    _precargarDatos();
    _cargarRequisitosHSE();
  }

  @override
  void dispose() {
    _rutController.dispose();
    _nombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _cargoController.dispose();
    _nacionalidadController.dispose();
    _vencimientoResidenciaController.dispose();
    _turnoController.dispose();
    _contratoCodigoController.dispose();
    super.dispose();
  }

  void _precargarDatos() {
    final t = widget.trabajadorEdit;
    if (t != null) {
      _rutController.text = t['rut'] ?? '';
      _nombreController.text = t['nombre'] ?? '';
      _apellidoPaternoController.text = t['apellido_paterno'] ?? '';
      _apellidoMaternoController.text = t['apellido_materno'] ?? '';
      _cargoController.text = t['cargo'] ?? '';
      _nacionalidadController.text = t['nacionalidad'] ?? 'Boliviana';
      _vencimientoResidenciaController.text = t['fecha_vencimiento_residencia'] ?? 'PERMANENCIA DEFINITIVA';
      _sexoSeleccionado = t['sexo'] ?? 'Masculino';
      _turnoController.text = t['turno'] ?? '';
      _contratoCodigoController.text = t['contrato_codigo'] ?? '';
      _estadoSeleccionado = t['estado_trabajador'] ?? 'ACTIVO';
      _tipoSeleccionado = t['tipo_trabajador'] ?? 'SUBCONTRATADO';
      _mutualidadSeleccionada = t['mutualidad'] ?? 'ACHS';
    }
  }

  Future<void> _cargarRequisitosHSE() async {
    setState(() => _isLoadingRequisitos = true);
    try {
      final response = await _service.fetchRequisitosHSE();
      if (mounted) {
        setState(() {
          _requisitos = List<Map<String, dynamic>>.from(response);
          _cumplimientoData = _requisitos.map((req) {
            return {
              'requisito_id': req['id'],
              'valor_estado': 'VIGENTE',
              'fecha_vencimiento': null,
              'requiere_vencimiento': req['requiere_vencimiento'] ?? false,
            };
          }).toList();
          _isLoadingRequisitos = false;
        });
        if (widget.trabajadorEdit != null) {
          await _cargarCumplimientoExistente();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRequisitos = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar requisitos: $e')));
      }
    }
  }

  Future<void> _cargarCumplimientoExistente() async {
    try {
      final trabajadorId = _toInt(widget.trabajadorEdit!['id']);
      if (trabajadorId == null) return;

      final response = await _service.fetchCumplimientoTrabajador(trabajadorId);
      if (mounted) {
        setState(() {
          for (var cum in response) {
            final index = _cumplimientoData.indexWhere((item) => item['requisito_id'] == cum['requisito_id']);
            if (index != -1) {
              _cumplimientoData[index] = {
                'requisito_id': cum['requisito_id'],
                'valor_estado': cum['valor_estado'] ?? 'VIGENTE',
                'fecha_vencimiento': cum['fecha_vencimiento'],
                'requiere_vencimiento': _requisitos.firstWhere(
                  (r) => r['id'] == cum['requisito_id'],
                  orElse: () => {'requiere_vencimiento': false},
                )['requiere_vencimiento'],
              };
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargar cumplimiento: $e');
    }
  }

  String _calcularEstadoDesdeFecha(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return 'N/A';
    try {
      final fecha = DateTime.parse(fechaStr);
      return fecha.isAfter(DateTime.now()) ? 'VIGENTE' : 'VENCIDO';
    } catch (_) {
      return 'N/A';
    }
  }

  void _actualizarEstadoReq(int index, {String? fecha, bool esNoAplica = false}) {
    setState(() {
      if (esNoAplica) {
        _cumplimientoData[index]['fecha_vencimiento'] = null;
        _cumplimientoData[index]['valor_estado'] = 'N/A';
      } else {
        _cumplimientoData[index]['fecha_vencimiento'] = fecha;
        _cumplimientoData[index]['valor_estado'] = _calcularEstadoDesdeFecha(fecha);
      }
    });
  }

  Future<void> _seleccionarFechaReq(int index) async {
    final fechaActualStr = _cumplimientoData[index]['fecha_vencimiento'] as String?;
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
      _actualizarEstadoReq(index, fecha: picked.toIso8601String().split('T')[0]);
    }
  }

  Future<void> _guardarTrabajador() async {
    if (_rutController.text.isEmpty ||
        _nombreController.text.isEmpty ||
        _apellidoPaternoController.text.isEmpty ||
        _cargoController.text.isEmpty ||
        _sexoSeleccionado == null ||
        _estadoSeleccionado == null ||
        _turnoController.text.isEmpty ||
        _contratoCodigoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete todos los campos obligatorios')),
      );
      return;
    }

    setState(() => _isGuardando = true);
    try {
      final trabajadorData = {
        'rut': _rutController.text.trim(),
        'nombre': _nombreController.text.trim(),
        'apellido_paterno': _apellidoPaternoController.text.trim(),
        'apellido_materno': _apellidoMaternoController.text.trim().isEmpty ? null : _apellidoMaternoController.text.trim(),
        'cargo': _cargoController.text.trim(),
        'nacionalidad': _nacionalidadController.text.trim(),
        'fecha_vencimiento_residencia': _vencimientoResidenciaController.text.trim().isEmpty ? null : _vencimientoResidenciaController.text.trim(),
        'sexo': _sexoSeleccionado,
        'turno': _turnoController.text.trim(),
        'estado_trabajador': _estadoSeleccionado,
        'contrato_codigo': _contratoCodigoController.text.trim(),
      };

      final cumplimientos = _cumplimientoData.map((item) => {
        'requisito_id': item['requisito_id'],
        'valor_estado': item['valor_estado'],
        'fecha_vencimiento': item['fecha_vencimiento'],
      }).toList();

      await _service.guardarTrabajadorCompleto(
        datosTrabajador: trabajadorData,
        cumplimientos: cumplimientos,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personal HSE registrado exitosamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGuardando = false);
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.isNotEmpty) return int.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trabajadorEdit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EditarTrabajadorScreen(trabajador: widget.trabajadorEdit!),
          ),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _orange)));
    }

    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: _bgDark,
      body: isWide
          ? CollapsibleSidebar(
              items: [
                MenuItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Inicio / Dashboard',
                  color: _accentBlue,
                  onTap: () => Navigator.pop(context),
                ),
                MenuItem(
                  icon: Icons.person_add_rounded,
                  label: 'Registrar Personal HSE',
                  color: _orange,
                  isActive: true,
                  onTap: () {},
                ),
              ],
              child: _buildContent(isWide),
            )
          : _buildContent(isWide),
    );
  }

  Widget _buildContent(bool isWide) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 16, isWide ? 24 : 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _StepperIndicator(pasoActual: _pasoActual),
                const SizedBox(height: 20),
                _buildFaseActual(),
              ],
            ),
          ),
        ),
        _buildFooter(isWide),
      ],
    );
  }

  Widget _buildFaseActual() {
    if (_pasoActual == 0) return _buildFase1();
    return _buildFase2();
  }

  Widget _buildFase1() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.library_books_rounded, color: _orange, size: 20),
            const SizedBox(width: 8),
            const Text('FASE 1: Datos Demográficos y Contractuales', style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: _green.withValues(alpha: 0.3), width: 0.5)),
              child: const Text('Guardados en Tabla Fija "trabajadores"', style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 16),
          _buildFase1Content(),
        ],
      ),
    );
  }

  Widget _buildFase1Content() {
    final esTablet = MediaQuery.of(context).size.width > 600;
    final pad = const EdgeInsets.symmetric(horizontal: 4);
    if (esTablet) {
      return Column(children: [
        Row(children: [
          Expanded(child: Padding(padding: pad, child: _buildField('RUT:', _rutController.text))),
          Expanded(child: Padding(padding: pad, child: _buildField('Nombres:', _nombreController.text))),
          Expanded(child: Padding(padding: pad, child: _buildField('Apellidos:', '${_apellidoPaternoController.text} ${_apellidoMaternoController.text}'.trim()))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Padding(padding: pad, child: _buildField('Cargo:', _cargoController.text))),
          Expanded(child: Padding(padding: pad, child: _buildField('Nacionalidad:', _nacionalidadController.text))),
          Expanded(child: Padding(padding: pad, child: _buildField('Residencia Venc.:', _vencimientoResidenciaController.text))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Padding(padding: pad, child: _buildField('Sexo:', _sexoSeleccionado ?? 'Hombre'))),
          Expanded(child: Padding(padding: pad, child: _buildField('Turno:', _turnoController.text))),
          Expanded(child: Padding(padding: pad, child: _buildField('Contrato:', _contratoCodigoController.text))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Padding(padding: pad, child: _buildFieldDropdown('Estado:', _estadoSeleccionado ?? 'ACTIVO', ['ACTIVO', 'DESVINCULADO', 'LICENCIA'], (v) => setState(() => _estadoSeleccionado = v)))),
          Expanded(child: Padding(padding: pad, child: _buildFieldDropdown('Tipo:', _tipoSeleccionado ?? 'SUBCONTRATADO', ['SUBCONTRATADO', 'DIRECTO', 'OTRO'], (v) => setState(() => _tipoSeleccionado = v)))),
          Expanded(child: Padding(padding: pad, child: _buildFieldDropdown('Mutualidad:', _mutualidadSeleccionada ?? 'ACHS', ['ACHS', 'AG-AF', 'OTRA'], (v) => setState(() => _mutualidadSeleccionada = v)))),
        ]),
      ]);
    }
    return Column(children: [
      _buildField('RUT:', _rutController.text),
      const SizedBox(height: 10),
      _buildField('Nombres:', _nombreController.text),
      const SizedBox(height: 10),
      _buildField('Apellidos:', '${_apellidoPaternoController.text} ${_apellidoMaternoController.text}'.trim()),
      const SizedBox(height: 10),
      _buildField('Cargo:', _cargoController.text),
      const SizedBox(height: 10),
      _buildField('Nacionalidad:', _nacionalidadController.text),
      const SizedBox(height: 10),
      _buildField('Residencia Venc.:', _vencimientoResidenciaController.text),
      const SizedBox(height: 10),
      _buildField('Sexo:', _sexoSeleccionado ?? 'Hombre'),
      const SizedBox(height: 10),
      _buildField('Turno:', _turnoController.text),
      const SizedBox(height: 10),
      _buildField('Contrato:', _contratoCodigoController.text),
      const SizedBox(height: 10),
      _buildFieldDropdown('Estado:', _estadoSeleccionado ?? 'ACTIVO', ['ACTIVO', 'DESVINCULADO', 'LICENCIA'], (v) => setState(() => _estadoSeleccionado = v)),
      const SizedBox(height: 10),
      _buildFieldDropdown('Tipo:', _tipoSeleccionado ?? 'SUBCONTRATADO', ['SUBCONTRATADO', 'DIRECTO', 'OTRO'], (v) => setState(() => _tipoSeleccionado = v)),
      const SizedBox(height: 10),
      _buildFieldDropdown('Mutualidad:', _mutualidadSeleccionada ?? 'ACHS', ['ACHS', 'AG-AF', 'OTRA'], (v) => setState(() => _mutualidadSeleccionada = v)),
    ]);
  }

  Widget _buildField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _divider, width: 0.5)),
      child: Row(children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500))),
        const SizedBox(width: 10),
        Expanded(child: Text(value, style: const TextStyle(color: _textPrimary, fontSize: 13))),
      ]),
    );
  }

  Widget _buildFieldDropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: _divider, width: 0.5)),
      child: Row(children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w500))),
        const SizedBox(width: 10),
        Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: _cardDark,
          style: const TextStyle(color: _textPrimary, fontSize: 13),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ))),
      ]),
    );
  }

  Widget _buildFase2() {
    final esTablet = MediaQuery.of(context).size.width > 600;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.assignment_rounded, color: _orange, size: 20),
            const SizedBox(width: 8),
            const Text('FASE 2: Matriz Dinámica de Estados y Vencimientos', style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _accentBlue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: _accentBlue.withValues(alpha: 0.3), width: 0.5)),
              child: const Text("Catálogo 'requisitos_hse'", style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 16),
          if (_isLoadingRequisitos)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _orange)))
          else if (_requisitos.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No hay requisitos HSE configurados', style: TextStyle(color: _textSecondary))))
          else
            esTablet ? _buildFase2Tablet() : _buildFase2Mobile(),
        ],
      ),
    );
  }

  Widget _buildSelectorFechaYNA(int index, String estado, String? fecha) {
    final esNoAplica = estado == 'N/A';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => _actualizarEstadoReq(index, esNoAplica: !esNoAplica),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: esNoAplica ? _orange.withValues(alpha: 0.25) : _bgDark,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: esNoAplica ? _orange.withValues(alpha: 0.8) : _divider, width: esNoAplica ? 1.5 : 1),
          ),
          child: Text('N/A', style: TextStyle(
            color: esNoAplica ? _orange : _textMuted,
            fontSize: 11, fontWeight: esNoAplica ? FontWeight.w700 : FontWeight.w600,
          )),
        ),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: () => _seleccionarFechaReq(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: esNoAplica ? _bgDark : _accentBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: esNoAplica ? _divider : _accentBlue.withValues(alpha: 0.5), width: esNoAplica ? 0.5 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(esNoAplica ? 'Sin fecha' : (fecha ?? 'Seleccionar'), style: TextStyle(color: esNoAplica ? _textMuted : _textPrimary, fontSize: 11)),
            const SizedBox(width: 4),
            Icon(Icons.calendar_today_rounded, color: esNoAplica ? _textMuted : _accentBlue, size: 14),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildBadgeEstado(String estado, {bool large = false}) {
    final color = estado == 'VIGENTE' ? _green : (estado == 'VENCIDO' ? Colors.red : _orange);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8, vertical: large ? 8 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        estado == 'VIGENTE' ? '✓ Vigente' : (estado == 'VENCIDO' ? '✗ Vencido' : '— N/A'),
        style: TextStyle(color: color, fontSize: large ? 12 : 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFase2Tablet() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 800),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(_accentBlue.withValues(alpha: 0.3)),
            columns: [
              DataColumn(label: _tableHeader('#')),
              DataColumn(label: _tableHeader('REQUISITO MANDANTE (SQM)')),
              DataColumn(label: _tableHeader('FECHA / N/A')),
              DataColumn(label: _tableHeader('ESTADO')),
            ],
            rows: _requisitos.asMap().entries.map((entry) {
              final index = entry.key;
              final requisito = entry.value;
              final cum = _cumplimientoData[index];
              final estado = cum['valor_estado'] ?? 'N/A';
              final fecha = cum['fecha_vencimiento'] as String?;

              return DataRow(cells: [
                DataCell(Text('${index + 1}', style: const TextStyle(color: _textSecondary, fontSize: 12))),
                DataCell(Text(requisito['nombre_requisito'] ?? '', style: const TextStyle(color: _textPrimary, fontSize: 13))),
                DataCell(_buildSelectorFechaYNA(index, estado, fecha)),
                DataCell(_buildBadgeEstado(estado)),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFase2Mobile() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _requisitos.length,
      itemBuilder: (context, index) {
        final requisito = _requisitos[index];
        final cum = _cumplimientoData[index];
        final estado = cum['valor_estado'] ?? 'N/A';
        final fecha = cum['fecha_vencimiento'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _divider, width: 0.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${index + 1}', style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(requisito['nombre_requisito'] ?? '', style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _buildSelectorFechaYNA(index, estado, fecha)),
              const SizedBox(width: 10),
              Expanded(child: _buildBadgeEstado(estado)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _tableHeader(String text) {
    return Text(text, style: const TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600));
  }

  Widget _buildFooter(bool isWide) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))]),
      child: Row(children: [
        if (_pasoActual > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _isGuardando ? null : () => setState(() => _pasoActual--),
              child: const Text('Volver a Fase 1'),
            ),
          ),
        if (_pasoActual > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isGuardando ? null : () {
              if (_pasoActual < 1) {
                setState(() => _pasoActual++);
              } else {
                _guardarTrabajador();
              }
            },
            icon: _isGuardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(_pasoActual == 1 ? Icons.save : Icons.arrow_forward, size: 20),
            label: Text(_pasoActual == 1 ? 'Enviar a Supabase' : 'Siguiente'),
            style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ]),
    );
  }
}

class _StepperIndicator extends StatelessWidget {
  final int pasoActual;
  const _StepperIndicator({required this.pasoActual});

  @override
  Widget build(BuildContext context) {
    final paso1Activo = pasoActual == 0;
    final paso2Activo = pasoActual == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder, width: 0.5)),
      child: Row(children: [
        Expanded(child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: paso1Activo ? _orange : _textMuted, shape: BoxShape.circle),
            child: Center(child: Text('1', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('Información de Personal', style: TextStyle(color: paso1Activo ? _orange : _textSecondary, fontSize: 13, fontWeight: paso1Activo ? FontWeight.w600 : FontWeight.normal))),
        ])),
        Expanded(child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: paso2Activo ? _orange : _textMuted, shape: BoxShape.circle),
            child: Center(child: Text('2', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('Matriz de Requisitos Mandante', style: TextStyle(color: paso2Activo ? _orange : _textSecondary, fontSize: 13, fontWeight: paso2Activo ? FontWeight.w600 : FontWeight.normal))),
        ])),
      ]),
    );
  }
}