import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import '../services/trabajador_service.dart';
import '../utils/validators.dart';
import '../widgets/collapsible_sidebar.dart';
import '../config/theme_context_ext.dart';
import '../providers/auth_provider.dart';

const _maxLote = 500;

const _nombresRequisitos = [
  'Ex. Ocupacionales', 'Alcohol/Drogas', 'Psicosensométrico',
  'Inducción SQM', 'Protocolo SQM', 'CTTA',
  'Certificación', 'Lic. Interna SQM', 'Dif. Procedimientos',
  'Dif. Plan SQM', 'Dif. Plan CTTAS', 'Dif. HDS',
];

List<String> _columnasTabla() {
  final cols = <String>[
    '', 'Fila', 'RUT', 'Nombre', 'Ap. Pat.', 'Ap. Mat.', 'Cargo',
    'Nac.', 'Venc.Res.', 'Sexo', 'Turno', 'Contrato', 'Estado',
  ];
  cols.addAll(_nombresRequisitos);
  return cols;
}

String _formatearRut(String raw) {
  String rut = raw.replaceAll(',', '.');
  final limpio = rut.replaceAll('.', '').replaceAll('-', '').replaceAll(' ', '').toUpperCase();
  if (limpio.length < 2) return raw;
  final dv = limpio.substring(limpio.length - 1);
  final cuerpo = limpio.substring(0, limpio.length - 1);
  final partes = <String>[];
  String temp = cuerpo;
  while (temp.length > 3) {
    partes.insert(0, temp.substring(temp.length - 3));
    temp = temp.substring(0, temp.length - 3);
  }
  if (temp.isNotEmpty) partes.insert(0, temp);
  final cuerpoFormateado = partes.join('.');
  return '$cuerpoFormateado-$dv';
}

String? _validarYFormatearRut(dynamic raw) {
  if (raw == null) return null;
  String str = raw.toString().trim().replaceAll(',', '.');
  if (str.isEmpty) return null;
  final limpio = str.replaceAll('.', '').replaceAll('-', '').replaceAll(' ', '').toUpperCase();
  if (limpio.length < 8 || limpio.length > 9) return null;
  if (!RegExp(r'^\d+[\dK]$').hasMatch(limpio)) return null;
  return _formatearRut(limpio);
}

enum _TipoCambio { invalido, nuevo, modificado, sinCambios }

class _FilaDiff {
  int numeroFila;
  String? rut;
  _TipoCambio tipo;
  Map<String, dynamic> datosArchivo;
  List<Map<String, dynamic>> cumplimientoArchivo;
  Map<String, String> cambios;
  List<String> erroresValidacion;
  Map<String, dynamic>? datosBd;

  _FilaDiff({
    required this.numeroFila,
    this.rut,
    required this.tipo,
    required this.datosArchivo,
    this.cumplimientoArchivo = const [],
    this.cambios = const {},
    this.erroresValidacion = const [],
    this.datosBd,
  });

  bool get esOk => erroresValidacion.isEmpty && tipo != _TipoCambio.invalido;
  int get vigentes => cumplimientoArchivo.where((c) => c['valor_estado'] == 'VIGENTE').length;
  int get noVigentes => cumplimientoArchivo.length - vigentes;

  Color colorTipo(BuildContext ctx) => switch (tipo) {
    _TipoCambio.invalido => ctx.errorRed.withValues(alpha: 0.25),
    _TipoCambio.nuevo => ctx.successGreen.withValues(alpha: 0.15),
    _TipoCambio.modificado => ctx.warningYellow.withValues(alpha: 0.15),
    _TipoCambio.sinCambios => ctx.borderColor.withValues(alpha: 0.25),
  };

  Color colorEtiqueta(BuildContext ctx) => switch (tipo) {
    _TipoCambio.invalido => ctx.errorRed,
    _TipoCambio.nuevo => ctx.successGreen,
    _TipoCambio.modificado => ctx.warningYellow,
    _TipoCambio.sinCambios => ctx.textMuted,
  };
}

class CargaMasivaScreen extends StatefulWidget {
  const CargaMasivaScreen({super.key});

  @override
  State<CargaMasivaScreen> createState() => _CargaMasivaScreenState();
}

class _CargaMasivaScreenState extends State<CargaMasivaScreen> {
  final _service = TrabajadorService();
  int _paso = 1;
  bool _isLoading = false;
  String? _errorGeneral;

  String? _archivoNombre;
  Uint8List? _archivoBytes;
  List<_FilaDiff> _filas = [];
  String? _contratoSeleccionado;
  int _validos = 0, _nuevos = 0, _modificados = 0, _sinCambios = 0, _invalidos = 0;
  bool _soloInsertarNuevos = false;

  String? _resultadoMensaje;
  int _insertados = 0, _actualizados = 0, _cumplimientoInsertados = 0, _erroresEjecucion = 0;

  BuildContext get ctx => context;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final ctx = context;
    return Scaffold(
      backgroundColor: ctx.surfaceBg,
      body: Stack(
        children: [
          isWide
              ? CollapsibleSidebar(
                  items: [
                    MenuItem(icon: Icons.dashboard_rounded, label: 'Inicio / Dashboard', color: ctx.accentBlue, onTap: () => Navigator.pop(context)),
                    MenuItem(icon: Icons.upload_file_rounded, label: 'Carga Masiva', color: ctx.accentOrange, isActive: true, onTap: () {}),
                  ],
                  child: _buildBody(),
                )
              : _buildBody(),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: ctx.accentOrange),
                    const SizedBox(height: 16),
                    Text('Procesando...', style: TextStyle(color: ctx.textPrimary, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Esto puede tomar unos segundos', style: TextStyle(color: ctx.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() => Column(
    children: [
      _buildHeader(),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildPaso())),
    ],
  );

  Widget _buildHeader() {
    final auth = context.watch<AuthProvider>();
    final contratosDisponibles = auth.contratosUsuario;
    
    _contratoSeleccionado ??= auth.contratoSeleccionadoContexto;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      decoration: BoxDecoration(color: ctx.surfaceCard, border: Border(bottom: BorderSide(color: ctx.borderColor, width: 1))),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: ctx.textSecondary),
            onPressed: () {
              if (_paso == 1 || _resultadoMensaje != null) {
                Navigator.pop(context);
              } else if (_filas.isNotEmpty && _paso > 1) {
                setState(() { _paso--; _errorGeneral = null; });
              }
            },
          ),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Carga Masiva de Personal', style: TextStyle(color: ctx.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(_tituloPaso(), style: TextStyle(color: ctx.textSecondary, fontSize: 11)),
          ])),
          if (contratosDisponibles.length > 1)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: ctx.surfaceCard,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ctx.borderColor, width: 0.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _contratoSeleccionado,
                  icon: Icon(Icons.swap_vert, size: 16, color: ctx.textSecondary),
                  style: TextStyle(color: ctx.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                  onChanged: (val) {
                    if (val != null && mounted) {
                      setState(() {
                        _contratoSeleccionado = val;
                        for (final fila in _filas) {
                          fila.datosArchivo['contrato_codigo'] = val;
                        }
                      });
                    }
                  },
                  items: contratosDisponibles.map((codigo) {
                    return DropdownMenuItem(
                      value: codigo,
                      child: Text(codigo, style: TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                ),
              ),
            ),
          _StepperIndicator(pasoActual: _paso, ctx: ctx),
        ],
      ),
    );
  }

  String _tituloPaso() {
    if (_resultadoMensaje != null) return 'Resultado';
    return switch (_paso) { 1 => 'Paso 1/3 — Seleccionar archivo', 2 => 'Paso 2/3 — Validar y corregir', 3 => 'Paso 3/3 — Confirmar cambios', _ => '' };
  }

  Widget _buildPaso() {
    if (_resultadoMensaje != null) return _buildResultado();
    return switch (_paso) { 1 => _buildPaso1(), 2 => _buildPaso2(), 3 => _buildPaso3(), _ => const SizedBox.shrink() };
  }

  Widget _buildPaso1() {
    final tieneArchivo = _archivoBytes != null;
    final colorBorde = tieneArchivo ? ctx.successGreen.withValues(alpha: 0.6) : ctx.borderColor;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TarjetaContenido(ctx: ctx, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Seleccionar archivo', style: TextStyle(color: ctx.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        InkWell(
          onTap: _isLoading ? null : _pickArchivo,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: ctx.surfaceBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorBorde, width: 1.5)),
            child: Column(children: [
              Icon(tieneArchivo ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: tieneArchivo ? ctx.successGreen : colorBorde, size: 52),
              const SizedBox(height: 12),
              Text(_archivoNombre ?? 'Toca para seleccionar CSV o XLSX', style: TextStyle(color: ctx.textSecondary, fontSize: 13), textAlign: TextAlign.center),
              if (tieneArchivo) ...[
                const SizedBox(height: 8),
                Text('${(_archivoBytes!.length / 1024).toStringAsFixed(1)} KB — listo', style: TextStyle(color: ctx.successGreen, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 20),
        if (_errorGeneral != null) _ErrorBox(mensaje: _errorGeneral!, ctx: ctx),
        const SizedBox(height: 16),
        if (tieneArchivo)
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _procesarArchivo,
            icon: const Icon(Icons.read_more_rounded, size: 20),
            label: const Text('Validar y comparar con BD'),
            style: ElevatedButton.styleFrom(backgroundColor: ctx.accentOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
      ])),
    ]);
  }

  Widget _buildPaso2() {
    if (_filas.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: ctx.accentOrange)));
    final cols = _columnasTabla();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ResumenCarga(nuevos: _nuevos, modificados: _modificados, sinCambios: _sinCambios, invalidos: _invalidos, validos: _validos, ctx: ctx),
      const SizedBox(height: 20),
      if (_errorGeneral != null) _ErrorBox(mensaje: _errorGeneral!, ctx: ctx),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(ctx.accentBlue.withValues(alpha: 0.4)),
          headingTextStyle: TextStyle(color: ctx.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
          dataTextStyle: TextStyle(color: ctx.textPrimary, fontSize: 10),
          columnSpacing: 8,
          horizontalMargin: 6,
          columns: List.generate(cols.length, (i) => DataColumn(label: Text(cols[i], style: TextStyle(color: ctx.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)))),
          rows: _filas.asMap().entries.map((entry) {
            final idx = entry.key;
            final f = entry.value;
            final d = f.datosArchivo;
            return DataRow(
              color: WidgetStateProperty.all(f.colorTipo(ctx)),
              cells: [
                DataCell(IconButton(
                  icon: Icon(Icons.remove_circle_outline_rounded, color: ctx.errorRed, size: 18),
                  onPressed: () => _eliminarFila(idx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )),
                DataCell(Text('${f.numeroFila}', style: TextStyle(color: ctx.textPrimary))),
                DataCell(f.esOk
                    ? Text(f.rut ?? '', style: TextStyle(color: ctx.textPrimary))
                    : GestureDetector(
                        onTap: () => _mostrarDialogoCorreccion(f),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit_rounded, color: ctx.accentOrange, size: 12),
                          const SizedBox(width: 2),
                          Text(d['rut'] ?? '', style: TextStyle(color: ctx.errorRed, decoration: TextDecoration.underline, fontSize: 10)),
                        ]),
                      )),
                DataCell(Text(d['nombre'] ?? '', style: TextStyle(color: ctx.textPrimary))),
                DataCell(Text(d['apellido_paterno'] ?? '', style: TextStyle(color: ctx.textPrimary))),
                DataCell(Text(d['apellido_materno'] ?? '', style: TextStyle(color: ctx.textPrimary))),
                DataCell(Text(d['cargo'] ?? '', style: TextStyle(color: ctx.textPrimary))),
                DataCell(Text(d['nacionalidad'] ?? '', style: TextStyle(color: ctx.textPrimary))),
                DataCell(() {
                  // Verificar si hay error de fecha en Venc.Residencia
                  final vencResVal = d['fecha_vencimiento_residencia'] ?? '';
                  final tieneErrorVencRes = f.erroresValidacion.any((e) => e.startsWith('Venc.Residencia:'));
                  if (tieneErrorVencRes) {
                    return GestureDetector(
                      onTap: () => _mostrarDialogoCorreccion(f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: ctx.errorRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: ctx.errorRed.withValues(alpha: 0.4), width: 0.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.warning_amber_rounded, color: ctx.errorRed, size: 12),
                          const SizedBox(width: 2),
                          Text('$vencResVal', style: TextStyle(color: ctx.errorRed, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    );
                  }
                  return Text('$vencResVal', style: TextStyle(color: ctx.textPrimary));
                }()),
                DataCell(Text(d['sexo'] ?? '', style: TextStyle(color: ctx.textPrimary))),
                DataCell(Text(d['turno'] ?? '', style: TextStyle(color: ctx.textPrimary))),
                DataCell(Text(d['contrato_codigo'] ?? '', style: TextStyle(color: ctx.textPrimary))),
                DataCell(Text(d['estado_trabajador'] ?? '', style: TextStyle(color: ctx.textPrimary))),
                ...List.generate(12, (ri) {
                  final estado = ri < f.cumplimientoArchivo.length
                      ? (f.cumplimientoArchivo[ri]['valor_estado'] as String)
                      : 'N/A';
                  final errorFecha = ri < f.cumplimientoArchivo.length
                      ? (f.cumplimientoArchivo[ri]['error_fecha'] == true)
                      : false;
                  final rawValue = ri < f.cumplimientoArchivo.length
                      ? (f.cumplimientoArchivo[ri]['raw_value'] as String? ?? '')
                      : '';

                  // Si hay error en la fecha, mostrar celda editable con advertencia visual
                  if (errorFecha) {
                    return DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: ctx.errorRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: ctx.errorRed.withValues(alpha: 0.4), width: 0.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.warning_amber_rounded, color: ctx.errorRed, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            estado == 'VIGENTE' ? 'V' : (estado == 'VENCIDO' ? 'X' : '-'),
                            style: TextStyle(
                              color: estado == 'VIGENTE' ? ctx.successGreen : (estado == 'VENCIDO' ? ctx.errorRed : ctx.textMuted),
                              fontWeight: estado == 'VIGENTE' ? FontWeight.bold : FontWeight.normal,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 2),
                          IconButton(
                            icon: Icon(Icons.edit_rounded, color: ctx.accentOrange, size: 14),
                            onPressed: () => _corregirFechaRequisito(idx, ri),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            tooltip: '⚠️ Fecha inválida: "$rawValue" — toca para corregir',
                          ),
                        ]),
                      ),
                    );
                  }

                  // Tooltip con el valor original del Excel
                  final displayText = estado == 'VIGENTE' ? 'V' : (estado == 'VENCIDO' ? 'X' : '-');
                  final tooltipMsg = rawValue.isNotEmpty ? 'Valor original: "$rawValue"' : 'Vacío en Excel';
                  return DataCell(Tooltip(
                    message: tooltipMsg,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Text(
                      displayText,
                      style: TextStyle(
                        color: estado == 'VIGENTE' ? ctx.successGreen : (estado == 'VENCIDO' ? ctx.errorRed : ctx.textMuted),
                        fontWeight: estado == 'VIGENTE' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ));
                }),
              ],
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 8, children: [
        _leyenda(ctx.successGreen, 'Nuevo', ctx),
        _leyenda(ctx.warningYellow, 'Modificado', ctx),
        _leyenda(ctx.errorRed, 'Inválido', ctx),
        _leyenda(ctx.textMuted, 'Sin cambios', ctx),
        _chipLeyenda(ctx.successGreen, 'V', 'Vigente', ctx),
        _chipLeyenda(ctx.errorRed, 'X', 'Vencido', ctx),
        _chipLeyenda(ctx.textMuted, '-', 'N/A', ctx),
      ]),
      const SizedBox(height: 16),
      if (_invalidos > 0)
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: ctx.accentOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: ctx.accentOrange.withValues(alpha: 0.3))),
          child: Row(children: [
            Icon(Icons.edit_rounded, color: ctx.accentOrange, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Toca el RUT en rojo para corregir datos o las fechas inválidas en los requisitos', style: TextStyle(color: ctx.textPrimary, fontSize: 12))),
          ]),
        ),
      Row(children: [
        OutlinedButton(onPressed: () => setState(() => _paso = 1), style: OutlinedButton.styleFrom(foregroundColor: ctx.textSecondary, side: BorderSide(color: ctx.borderColor)), child: const Text('Volver')),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(
          onPressed: _validos == 0 ? null : () => setState(() => _paso = 3),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text('Continuar ($_validos registros)'),
          style: ElevatedButton.styleFrom(backgroundColor: ctx.accentOrange, foregroundColor: Colors.white),
        )),
      ]),
    ]);
  }

  void _eliminarFila(int idx) {
    setState(() { _filas.removeAt(idx); _recalcular(); });
  }

  Widget _chipLeyenda(Color color, String simbolo, String texto, BuildContext ctx) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 20, height: 20, alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Text(simbolo, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))),
      const SizedBox(width: 4),
      Text(texto, style: TextStyle(color: ctx.textSecondary, fontSize: 11)),
    ]);
  }

  Widget _leyenda(Color color, String texto, BuildContext ctx) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(texto, style: TextStyle(color: ctx.textSecondary, fontSize: 11)),
    ]);
  }

  Future<void> _corregirFechaRequisito(int filaIdx, int reqIdx) async {
    final f = _filas[filaIdx];
    final fechaActualStr = f.cumplimientoArchivo[reqIdx]['fecha_vencimiento'] as String?;
    final fechaInicial = fechaActualStr != null
        ? DateTime.tryParse(fechaActualStr) ?? DateTime.now()
        : DateTime.now();

    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (fechaSeleccionada != null && mounted) {
      final fechaStr = fechaSeleccionada.toIso8601String().split('T')[0];
      final nuevoEstado = fechaSeleccionada.isAfter(DateTime.now()) ? 'VIGENTE' : 'VENCIDO';
      
      // Reemplazar toda la lista para forzar detección de cambios en DataTable
      final filasNuevas = List<_FilaDiff>.from(_filas);
      final cumNuevo = Map<String, dynamic>.from(filasNuevas[filaIdx].cumplimientoArchivo[reqIdx]);
      cumNuevo['fecha_vencimiento'] = fechaStr;
      cumNuevo['valor_estado'] = nuevoEstado;
      cumNuevo['error_fecha'] = false;
      cumNuevo['raw_value'] = fechaStr;
      
      final cumplimientosNuevos = List<Map<String, dynamic>>.from(filasNuevas[filaIdx].cumplimientoArchivo);
      cumplimientosNuevos[reqIdx] = cumNuevo;
      filasNuevas[filaIdx].cumplimientoArchivo = cumplimientosNuevos;
      
      filasNuevas[filaIdx].erroresValidacion = List<String>.from(
        filasNuevas[filaIdx].erroresValidacion.where((e) => !e.startsWith('Req ${reqIdx + 1}:')),
      );
      
      if (filasNuevas[filaIdx].erroresValidacion.isEmpty && filasNuevas[filaIdx].tipo == _TipoCambio.invalido) {
        filasNuevas[filaIdx].tipo = _TipoCambio.nuevo;
      }
      
      setState(() {
        _filas = filasNuevas;
        _recalcular();
      });
    }
  }

  Future<void> _mostrarDialogoCorreccion(_FilaDiff f) async {
    final ctx = this.ctx;
    final rutCtrl = TextEditingController(text: f.datosArchivo['rut'] ?? '');
    final nombreCtrl = TextEditingController(text: f.datosArchivo['nombre'] ?? '');
    final apCtrl = TextEditingController(text: f.datosArchivo['apellido_paterno'] ?? '');
    final cargoCtrl = TextEditingController(text: f.datosArchivo['cargo'] ?? '');
    final turnoCtrl = TextEditingController(text: f.datosArchivo['turno'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctxDialog) => AlertDialog(
        backgroundColor: ctx.surfaceCard,
        title: Text('Corregir Fila ${f.numeroFila}', style: TextStyle(color: ctx.textPrimary)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _campoDialog(ctx, 'RUT (ej: 12.345.678-9)', rutCtrl),
            const SizedBox(height: 8),
            _campoDialog(ctx, 'Nombre', nombreCtrl),
            const SizedBox(height: 8),
            _campoDialog(ctx, 'Apellido Paterno', apCtrl),
            const SizedBox(height: 8),
            _campoDialog(ctx, 'Cargo', cargoCtrl),
            const SizedBox(height: 8),
            _campoDialog(ctx, 'Turno', turnoCtrl),
            if (f.erroresValidacion.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...f.erroresValidacion.map((e) => Text('• $e', style: TextStyle(color: ctx.errorRed, fontSize: 12))),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctxDialog, false), child: Text('Cancelar', style: TextStyle(color: ctx.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctxDialog, true),
            style: ElevatedButton.styleFrom(backgroundColor: ctx.accentOrange, foregroundColor: Colors.white),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() {
        final rutFormateado = _formatearRut(rutCtrl.text);
        f.datosArchivo['rut'] = rutFormateado;
        f.datosArchivo['nombre'] = nombreCtrl.text.trim();
        f.datosArchivo['apellido_paterno'] = apCtrl.text.trim();
        f.datosArchivo['cargo'] = cargoCtrl.text.trim();
        f.datosArchivo['turno'] = turnoCtrl.text.trim();
        f.rut = f.datosArchivo['rut'];
        f.erroresValidacion = [];
        if (Validators.validarRut(rutCtrl.text) == null) {
          f.erroresValidacion.add('RUT inválido (DV incorrecto según Módulo 11)');
        }
        if ((f.datosArchivo['nombre'] ?? '').isEmpty) {
          f.erroresValidacion.add('Nombre obligatorio');
        }
        if ((f.datosArchivo['apellido_paterno'] ?? '').isEmpty) {
          f.erroresValidacion.add('Ap. Paterno obligatorio');
        }
        if ((f.datosArchivo['cargo'] ?? '').isEmpty) {
          f.erroresValidacion.add('Cargo obligatorio');
        }
        if (f.erroresValidacion.isEmpty && f.tipo == _TipoCambio.invalido) {
          f.tipo = _TipoCambio.nuevo;
        }
        _recalcular();
      });
    }
  }

  Widget _campoDialog(BuildContext ctx, String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: ctx.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ctx.textSecondary, fontSize: 12),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: ctx.borderColor)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: ctx.accentOrange)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  void _recalcular() {
    _invalidos = _filas.where((f) => !f.esOk).length;
    _nuevos = _filas.where((f) => f.tipo == _TipoCambio.nuevo && f.esOk).length;
    _modificados = _filas.where((f) => f.tipo == _TipoCambio.modificado && f.esOk).length;
    _sinCambios = _filas.where((f) => f.tipo == _TipoCambio.sinCambios && f.esOk).length;
    _validos = _nuevos + _modificados + _sinCambios;
  }

  Widget _buildPaso3() {
    final aConfirmar = _soloInsertarNuevos ? _nuevos : _validos;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ResumenCarga(nuevos: _nuevos, modificados: _modificados, sinCambios: _sinCambios, invalidos: _invalidos, validos: _validos, ctx: ctx),
      const SizedBox(height: 20),
      _TarjetaContenido(ctx: ctx, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Checkbox(value: _soloInsertarNuevos, onChanged: (v) => setState(() => _soloInsertarNuevos = v ?? false), activeColor: ctx.accentOrange),
          Expanded(child: Text('Solo insertar registros nuevos', style: TextStyle(color: ctx.textPrimary, fontSize: 13))),
        ]),
        const SizedBox(height: 8),
        Text('Se procesarán $aConfirmar registros con ${aConfirmar * 12} cumplimientos HSE.', style: TextStyle(color: ctx.textSecondary, fontSize: 12)),
      ])),
      const SizedBox(height: 20),
      if (_errorGeneral != null) _ErrorBox(mensaje: _errorGeneral!, ctx: ctx),
      const SizedBox(height: 20),
      Row(children: [
        OutlinedButton(onPressed: () => setState(() => _paso = 2), style: OutlinedButton.styleFrom(foregroundColor: ctx.textSecondary, side: BorderSide(color: ctx.borderColor)), child: const Text('Volver')),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(
          onPressed: aConfirmar == 0 || _isLoading ? null : _ejecutarCarga,
          icon: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_rounded, size: 20),
          label: Text(_isLoading ? 'Guardando...' : 'Confirmar y guardar ($aConfirmar)'),
          style: ElevatedButton.styleFrom(backgroundColor: ctx.successGreen, foregroundColor: ctx.isDarkMode ? Colors.white : Colors.black87, padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
      ]),
    ]);
  }

  Widget _buildResultado() {
    final exito = _erroresEjecucion == 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TarjetaContenido(ctx: ctx, child: Column(children: [
        Icon(exito ? Icons.check_circle_rounded : Icons.error_rounded, color: exito ? ctx.successGreen : ctx.errorRed, size: 56),
        const SizedBox(height: 12),
        Text(_resultadoMensaje ?? '', style: TextStyle(color: ctx.textPrimary, fontSize: 15, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Insertados: $_insertados  |  Actualizados: $_actualizados  |  Cumplimientos: $_cumplimientoInsertados  |  Errores: $_erroresEjecucion', style: TextStyle(color: ctx.textSecondary, fontSize: 12)),
      ])),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text('Volver a Gestión de Personal'),
        style: ElevatedButton.styleFrom(backgroundColor: ctx.accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
      )),
    ]);
  }

  Future<void> _pickArchivo() async {
    setState(() { _errorGeneral = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.size == 0) { setState(() => _errorGeneral = 'Archivo vacío'); return; }
      if (file.bytes == null || file.bytes!.isEmpty) { setState(() => _errorGeneral = 'Archivo sin contenido legible'); return; }
      setState(() { _archivoNombre = file.name; _archivoBytes = file.bytes; });
    } catch (e) {
      setState(() => _errorGeneral = 'Error seleccionando archivo: $e');
    }
  }

  // ── Mapeo posicional de fila ──────────────────────────────────

  ({Map<String, dynamic> datos, List<Map<String, dynamic>> cumplimientos, List<String> errores}) _mapearFila(List<String> cols) {
    String getCol(int idx) => idx < cols.length ? cols[idx].trim() : '';
    final contratoActual = context.read<AuthProvider>().contratoSeleccionadoContexto;

    final rutRaw = getCol(4);
    final rut = _validarYFormatearRut(rutRaw) ?? _formatearRut(rutRaw);
    final nombre = getCol(1);
    final apellidoPaterno = getCol(2);
    final apellidoMaterno = getCol(3);
    final cargo = getCol(5);
    final nacionalidad = getCol(6);
    final vencResRaw = getCol(7);
    final sexo = Validators.normalizarSexo(getCol(8));
    final turno = getCol(9);

    final errores = <String>[];

    // Validar fecha_vencimiento_residencia:
    // La columna en BD es TEXT, acepta fechas ISO, texto libre o valores como "Permanencia definitiva"
    String vencResFormateada = vencResRaw.trim();
    if (vencResFormateada.isNotEmpty) {
      final parsed = Validators.parsearFechaCsv(vencResFormateada);
      if (parsed.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(parsed)) {
        // Es una fecha válida en ISO → usarla formateada
        vencResFormateada = parsed;
      } else if (vencResFormateada.toUpperCase() == 'N/A' || vencResFormateada.toUpperCase() == 'NA') {
        // N/A → vacío
        vencResFormateada = '';
      }
      // CUALQUIER otro texto (ej: "Permanencia definitiva", "PERMANENTE", texto libre)
      // se mantiene tal cual porque la columna es TEXT en BD
    }
    final vencRes = vencResFormateada;
    if (Validators.validarRut(rut) == null && Validators.validarRut(rutRaw) == null) errores.add('RUT inválido (DV incorrecto según Módulo 11)');
    if (nombre.isEmpty) errores.add('Nombre obligatorio');
    if (apellidoPaterno.isEmpty) errores.add('Apellido Paterno obligatorio');
    if (cargo.isEmpty) errores.add('Cargo obligatorio');

    final datos = <String, dynamic>{
      'rut': rut,
      'nombre': nombre,
      'apellido_paterno': apellidoPaterno,
      'apellido_materno': apellidoMaterno,
      'cargo': cargo,
      'nacionalidad': nacionalidad.isNotEmpty ? nacionalidad : 'Chilena',
      'fecha_vencimiento_residencia': vencRes,
      'sexo': sexo,
      'turno': turno,
      'estado_trabajador': 'ACTIVO',
      'contrato_codigo': contratoActual,
    };

    final cumplimientos = <Map<String, dynamic>>[];
    for (var i = 0; i < 12; i++) {
      final raw = getCol(10 + i);
      final requisitoId = i + 1;

      String estado;
      String? fecha;
      bool errorFecha = false;

      final esReqConFecha = i < 4;
      final rawUpper = raw.toUpperCase().trim();

      if (raw.trim().isEmpty) {
        estado = 'N/A';
        fecha = null;
      } else {
        // Si el valor parece una fecha (contiene dígitos con / o -), intentar parsearla
        final pareceFecha = RegExp(r'\d').hasMatch(raw) && (raw.contains('/') || raw.contains('-'));
        if (pareceFecha) {
          final fechaStr = Validators.parsearFechaCsv(raw);
          if (fechaStr.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fechaStr) && DateTime.tryParse(fechaStr) != null) {
            estado = Validators.estadoDesdeFecha(fechaStr);
            fecha = fechaStr;
          } else if (rawUpper == 'N/A' || rawUpper == 'NA') {
            estado = 'N/A';
            fecha = null;
          } else {
            estado = 'N/A';
            fecha = null;
            errorFecha = true;
            if (!errores.contains('Req $requisitoId: fecha inválida "$raw"')) {
              errores.add('Req $requisitoId: fecha inválida "$raw"');
            }
          }
        } else if (rawUpper == 'SI' || rawUpper == 'SÍ') {
          estado = 'VIGENTE';
          fecha = null;
        } else if (rawUpper == 'N/A' || rawUpper == 'NA' || rawUpper == 'NO APLICA') {
          // N/A explícito: el requisito no aplica, NO marcar como vencido
          estado = 'N/A';
          fecha = null;
          errorFecha = false;
        } else {
          // Texto plano no interpretable como fecha, SI ni N/A
          if (esReqConFecha) {
            estado = 'VENCIDO';
          } else {
            estado = 'N/A';
          }
          fecha = null;
          errorFecha = false;
        }
      }

      cumplimientos.add({
        'requisito_id': requisitoId,
        'valor_estado': estado,
        'fecha_vencimiento': fecha,
        'documento_url': null,
        'raw_value': raw.trim(),
        'error_fecha': errorFecha,
      });
    }

    return (datos: datos, cumplimientos: cumplimientos, errores: errores);
  }

  // ── Procesamiento ─────────────────────────────────────────────

  int _encontrarHeader(List<List<String>> todasLasFilas) {
    int best = -1;
    for (var i = 0; i < todasLasFilas.length; i++) {
      final row = todasLasFilas[i];
      if (row.length < 10) continue;
      final hasRut = row.any((c) => c.trim().toLowerCase().contains('rut'));
      if (hasRut) return i;
      if (best == -1) {
        if (row.any((c) => c.trim().toLowerCase().contains('nombre'))) {
          best = i;
        }
      }
    }
    return best;
  }

  bool _esFilaDatos(List<String> cols) {
    if (cols.length < 5) return false;
    final col1 = (cols.length > 1 ? cols[1] : '').trim().toUpperCase();
    if (col1.isEmpty) return false;
    if (col1 == 'FIRMA' || col1 == 'OBSERVACIONES' || col1 == 'OBSERVACIÓN' ||
        col1 == 'TOTAL' || col1 == 'SUBTOTAL' || col1 == 'NOTA') {
      return false;
    }
    final col4 = (cols.length > 4 ? cols[4] : '').trim();
    if (col4.length < 6) return false;
    return true;
  }

  Future<void> _procesarArchivo() async {
    final nombre = _archivoNombre;
    final bytes = _archivoBytes;
    if (nombre == null || bytes == null) {
      setState(() => _errorGeneral = 'Primero selecciona un archivo');
      return;
    }

    setState(() { _isLoading = true; _errorGeneral = null; });
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      final List<List<String>> filasRaw;
      if (nombre.toLowerCase().endsWith('.csv')) {
        filasRaw = _parsearCsv(bytes);
      } else {
        filasRaw = _parsearXlsx(bytes);
      }

      if (filasRaw.isEmpty || filasRaw.length < 2) {
        setState(() { _isLoading = false; _errorGeneral = 'No se detectaron filas con datos.'; });
        return;
      }

      final hdrIdx = _encontrarHeader(filasRaw);
      if (hdrIdx == -1) {
        setState(() { _isLoading = false; _errorGeneral = 'No se encontró cabecera "RUT" en fila con ≥10 columnas.'; });
        return;
      }

      final numCols = filasRaw[hdrIdx].length;
      final allRows = filasRaw.sublist(hdrIdx + 1);

      final paddedRows = allRows.map((r) {
        if (r.length >= numCols) return r;
        final padded = List<String>.from(r);
        while (padded.length < numCols) {
          padded.add('');
        }
        return padded;
      }).toList();

      final dataRows = paddedRows.where((r) => _esFilaDatos(r)).toList();

      if (dataRows.isEmpty) {
        setState(() { _isLoading = false;
          _errorGeneral = 'No se detectaron filas de datos. Total filas tras cabecera: ${allRows.length}. '
              'Primera: ${allRows.isNotEmpty ? allRows.first.take(5).join(", ") : "vacía"}';
        });
        return;
      }

      if (dataRows.length > _maxLote) {
        setState(() { _isLoading = false; _errorGeneral = 'Máximo $_maxLote registros (archivo: ${dataRows.length})'; });
        return;
      }

      if (numCols < 10) {
        setState(() { _isLoading = false; _errorGeneral = 'Cabecera con solo $numCols columnas.'; });
        return;
      }

      final bdIndex = await _service.fetchTrabajadoresIndexadosPorRut();
      final diff = <_FilaDiff>[];
      int inv = 0, nue = 0, mod = 0, sc = 0;

      for (var i = 0; i < dataRows.length; i++) {
        final cols = dataRows[i];
        final mapeado = _mapearFila(cols);
        final rut = (mapeado.datos['rut'] ?? '').toString().trim();

        if (mapeado.errores.isNotEmpty) {
          diff.add(_FilaDiff(numeroFila: hdrIdx + 1 + i + 1, rut: rut.isNotEmpty ? rut : null,
              tipo: _TipoCambio.invalido, datosArchivo: mapeado.datos, cumplimientoArchivo: mapeado.cumplimientos, erroresValidacion: mapeado.errores));
          inv++;
          continue;
        }

        final existente = bdIndex[rut];
        if (existente == null) {
          diff.add(_FilaDiff(numeroFila: hdrIdx + 1 + i + 1, rut: rut, tipo: _TipoCambio.nuevo, datosArchivo: mapeado.datos, cumplimientoArchivo: mapeado.cumplimientos));
          nue++;
        } else {
          final cambios = _compararCampos(mapeado.datos, existente);
          if (cambios.isEmpty) {
            diff.add(_FilaDiff(numeroFila: hdrIdx + 1 + i + 1, rut: rut, tipo: _TipoCambio.sinCambios, datosArchivo: mapeado.datos, cumplimientoArchivo: mapeado.cumplimientos, datosBd: existente));
            sc++;
          } else {
            diff.add(_FilaDiff(numeroFila: hdrIdx + 1 + i + 1, rut: rut, tipo: _TipoCambio.modificado, datosArchivo: mapeado.datos, cumplimientoArchivo: mapeado.cumplimientos, cambios: cambios, datosBd: existente));
            mod++;
          }
        }
      }

      setState(() {
        _filas = diff; _invalidos = inv; _nuevos = nue; _modificados = mod; _sinCambios = sc;
        _validos = nue + mod + sc; _paso = 2; _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _errorGeneral = 'Error: $e'; });
    }
  }

  /// Valida que todas las fechas de cumplimientos estén en formato ISO antes de enviar.
  /// NOTA: fecha_vencimiento_residencia es TEXT, no se valida como fecha.
  List<String> _validarFechasPreEnvio() {
    final erroresFecha = <String>[];
    for (final f in _filas) {
      if (!f.esOk) continue;
      // Validar fechas de cumplimientos (sí son DATE en BD)
      for (var r = 0; r < f.cumplimientoArchivo.length; r++) {
        final c = f.cumplimientoArchivo[r];
        final fecha = c['fecha_vencimiento'] as String?;
        if (fecha != null && fecha.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fecha)) {
          erroresFecha.add('Fila ${f.numeroFila} (${f.rut}), Req ${r + 1}: fecha inválida "$fecha"');
        }
      }
    }
    return erroresFecha;
  }

  Future<void> _ejecutarCarga() async {
    // Validación pre-envío: verificar que todas las fechas sean ISO
    final erroresFechaPreEnvio = _validarFechasPreEnvio();
    if (erroresFechaPreEnvio.isNotEmpty) {
      setState(() {
        _isLoading = false;
        _errorGeneral = '❌ Error de fechas detectado. Revisa el Paso 2:\n${erroresFechaPreEnvio.join('\n')}';
      });
      return;
    }

    setState(() { _isLoading = true; _errorGeneral = null; });
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      final aProcesar = _filas.where((f) => f.esOk).toList();
      if (aProcesar.isEmpty) {
        setState(() { _isLoading = false; _errorGeneral = 'No hay registros válidos'; });
        return;
      }

      final trabajadoresData = <Map<String, dynamic>>[];
      final cumplimientoMap = <String, List<Map<String, dynamic>>>{};
      final rutVisto = <String>{};

      for (final f in aProcesar) {
        if (_soloInsertarNuevos && f.tipo != _TipoCambio.nuevo) continue;
        final rut = f.rut ?? '';
        if (rut.isEmpty || rutVisto.contains(rut)) continue;
        rutVisto.add(rut);
        final payload = Map<String, dynamic>.from(f.datosArchivo);
        trabajadoresData.add(payload);
        cumplimientoMap[rut] = f.cumplimientoArchivo;
      }

      if (trabajadoresData.isEmpty) {
        setState(() { _isLoading = false; _errorGeneral = 'No hay registros válidos'; });
        return;
      }

      final lote = trabajadoresData.map((t) {
        final rut = (t['rut'] ?? '').toString().trim();
        return {
          'datos': t,
          'cumplimientos': (cumplimientoMap[rut] ?? []).map((c) => {
            'requisito_id': c['requisito_id'],
            'valor_estado': c['valor_estado'],
            'fecha_vencimiento': c['fecha_vencimiento'],
            'documento_url': c['documento_url'],
          }).toList(),
        };
      }).toList();

      final result = await _service.cargaMasivaAtomica(lote: lote);

      setState(() {
        _insertados = (result['total_ok'] as num?)?.toInt() ?? 0;
        _actualizados = 0;
        _cumplimientoInsertados = _insertados * 12;
        _erroresEjecucion = (result['total_err'] as num?)?.toInt() ?? 0;

        final invalidos = _filas.where((f) => !f.esOk).toList();
        final detalleInvalidos = invalidos.isNotEmpty
            ? '\n❌ Registros NO subidos (error de validación):\n${invalidos.map((f) => '• Fila ${f.numeroFila}: ${f.rut ?? "N/A"} — ${f.datosArchivo['nombre']} ${f.datosArchivo['apellido_paterno']} (${f.erroresValidacion.join(", ")})').join('\n')}\n'
            : '';

        final procesados = aProcesar
            .where((f) => !_soloInsertarNuevos || f.tipo == _TipoCambio.nuevo)
            .toList();
        final detalleProcesados = procesados.isNotEmpty
            ? '✅ Registros enviados a BD:\n${procesados.map((f) => '• Fila ${f.numeroFila}: ${f.rut} — ${f.datosArchivo['nombre']} ${f.datosArchivo['apellido_paterno']}').join('\n')}'
            : '';

        final erroresList = (result['errores'] as List?) ?? [];
        final errorStr = erroresList.isNotEmpty ? '\nDetalles: ${erroresList.join('; ')}' : '';

        if ((result['success'] == false) || _erroresEjecucion > 0) {
          _resultadoMensaje = '⚠️ Carga completada con $_erroresEjecucion error(es)$errorStr'
              '$detalleInvalidos'
              '\n$detalleProcesados';
        } else {
          _resultadoMensaje = '✅ Carga completada exitosamente'
              '$detalleInvalidos'
              '\n$detalleProcesados';
        }
        _paso = 1; _isLoading = false; _archivoNombre = null; _archivoBytes = null; _filas = [];
      });
    } catch (e) {
      setState(() { _isLoading = false; _errorGeneral = 'Error: $e'; });
    }
  }

  // ── Parseo ────────────────────────────────────────────────────

  List<List<String>> _parsearCsv(Uint8List bytes) {
    final texto = utf8.decode(bytes);
    final lineas = const LineSplitter().convert(texto);
    if (lineas.length < 2) return [];
    final result = <List<String>>[];
    for (var i = 0; i < lineas.length; i++) {
      final cols = _splitCsv(lineas[i]);
      if (cols.length <= 1 && cols.first.trim().isEmpty) continue;
      result.add(cols);
    }
    return result;
  }

  List<List<String>> _parsearXlsx(Uint8List bytes) {
    final doc = Excel.decodeBytes(bytes);
    Sheet? mejorSheet;
    int mejorColumnas = 0;
    for (final entry in doc.sheets.entries) {
      final nombre = entry.key.toUpperCase();
      final s = entry.value;
      if (s.rows.isEmpty) continue;
      for (final row in s.rows) {
        final count = row.where((c) => c?.value != null && c!.value.toString().trim().isNotEmpty).length;
        if (count >= 10) {
          if (nombre.contains('LISTADO') || nombre.contains('HOJA1') || count > mejorColumnas) {
            mejorSheet = s;
            mejorColumnas = count;
          }
          break;
        }
      }
    }
    if (mejorSheet == null) return [];
    final filas = mejorSheet.rows;
    final result = <List<String>>[];
    for (var i = 0; i < filas.length; i++) {
      final row = filas[i];
      bool allEmpty = true;
      final rowStr = row.map((c) {
        final cell = c;
        if (cell == null) return '';
        final dynamic rawValue = cell.value;
        if (rawValue == null) return '';
        String s;

        if (rawValue is DateTime) {
          s = '${rawValue.year}-${rawValue.month.toString().padLeft(2, '0')}-${rawValue.day.toString().padLeft(2, '0')}';
        } else if (rawValue is num && rawValue >= 1 && rawValue <= 73000) {
          final excelEpoch = DateTime(1899, 12, 30);
          final date = excelEpoch.add(Duration(days: rawValue.toInt()));
          s = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        } else {
          s = rawValue.toString();
          if (s.endsWith('.0')) {
            final sinDecimal = s.substring(0, s.length - 2);
            if (RegExp(r'^\d+$').hasMatch(sinDecimal)) s = sinDecimal;
          }
        }

        if (s.isNotEmpty) allEmpty = false;
        return s;
      }).toList();
      if (allEmpty) continue;
      result.add(rowStr);
    }
    if (result.length < 2) return [];
    return result;
  }

  List<String> _splitCsv(String linea) {
    final out = <String>[];
    final sb = StringBuffer();
    bool enComillas = false;
    for (var i = 0; i < linea.length; i++) {
      final c = linea[i];
      if (c == '"') {
        if (enComillas && i + 1 < linea.length && linea[i + 1] == '"') { sb.write('"'); i++; }
        else { enComillas = !enComillas; }
      } else if (c == ',' && !enComillas) { out.add(sb.toString()); sb.clear(); }
      else { sb.write(c); }
    }
    out.add(sb.toString());
    return out;
  }

  static Map<String, String> _compararCampos(Map<String, dynamic> a, Map<String, dynamic> b) {
    const campos = ['rut', 'nombre', 'apellido_paterno', 'apellido_materno', 'cargo', 'nacionalidad', 'fecha_vencimiento_residencia', 'sexo', 'turno', 'estado_trabajador'];
    final out = <String, String>{};
    for (final c in campos) {
      final va = (a[c] ?? '').toString().trim();
      final vb = (b[c] ?? '').toString().trim();
      if (va != vb) out[c] = 'BD: $vb  →  archivo: $va';
    }
    return out;
  }
}

// ── Widgets auxiliares ──────────────────────────────────────────

class _StepperIndicator extends StatelessWidget {
  final int pasoActual;
  final BuildContext ctx;
  const _StepperIndicator({required this.pasoActual, required this.ctx});
  @override
  Widget build(BuildContext context) => Row(children: [
    _StepCircle(activo: pasoActual == 1, completo: pasoActual > 1, label: '1', ctx: ctx),
    _StepLine(activo: pasoActual > 1, ctx: ctx),
    _StepCircle(activo: pasoActual == 2, completo: pasoActual > 2, label: '2', ctx: ctx),
    _StepLine(activo: pasoActual > 2, ctx: ctx),
    _StepCircle(activo: pasoActual == 3, completo: false, label: '3', ctx: ctx),
  ]);
}

class _StepCircle extends StatelessWidget {
  final bool activo, completo;
  final String label;
  final BuildContext ctx;
  const _StepCircle({required this.activo, required this.completo, required this.label, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final color = completo ? ctx.successGreen : activo ? ctx.accentOrange : ctx.textMuted;
    return Container(width: 30, height: 30,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
      child: Center(child: completo ? Icon(Icons.check, color: ctx.successGreen, size: 18)
          : Text(label, style: TextStyle(color: activo ? ctx.textPrimary : ctx.textMuted, fontSize: 13, fontWeight: FontWeight.bold))));
  }
}

class _StepLine extends StatelessWidget {
  final bool activo;
  final BuildContext ctx;
  const _StepLine({required this.activo, required this.ctx});
  @override
  Widget build(BuildContext context) => Container(width: 32, height: 2, color: activo ? ctx.accentOrange : ctx.borderColor, margin: const EdgeInsets.symmetric(horizontal: 4));
}

class _TarjetaContenido extends StatelessWidget {
  final Widget child;
  final BuildContext ctx;
  const _TarjetaContenido({required this.child, required this.ctx});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: ctx.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: ctx.borderColor, width: 0.5)),
    child: child,
  );
}

class _ErrorBox extends StatelessWidget {
  final String mensaje;
  final BuildContext ctx;
  const _ErrorBox({required this.mensaje, required this.ctx});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: ctx.errorRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: ctx.errorRed.withValues(alpha: 0.4))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.error_outline_rounded, color: ctx.errorRed, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(mensaje, style: TextStyle(color: ctx.textPrimary, fontSize: 13))),
    ]),
  );
}

class _ResumenCarga extends StatelessWidget {
  final int nuevos, modificados, sinCambios, invalidos, validos;
  final BuildContext ctx;
  const _ResumenCarga({required this.nuevos, required this.modificados, required this.sinCambios, required this.invalidos, required this.validos, required this.ctx});
  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiCarga(label: 'Nuevos', valor: '$nuevos', color: ctx.successGreen, ctx: ctx),
      _KpiCarga(label: 'Modificados', valor: '$modificados', color: ctx.warningYellow, ctx: ctx),
      _KpiCarga(label: 'Sin cambios', valor: '$sinCambios', color: ctx.textMuted, ctx: ctx),
      _KpiCarga(label: 'Inválidos', valor: '$invalidos', color: ctx.errorRed, ctx: ctx),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth < 500) return Wrap(spacing: 8, runSpacing: 8, children: items.map((k) => SizedBox(width: (c.maxWidth - 8) / 2, child: k)).toList());
      return Row(children: items.map((k) => Expanded(child: Padding(padding: EdgeInsets.only(left: items.first == k ? 0 : 8, right: items.last == k ? 0 : 0), child: k))).toList());
    });
  }
}

class _KpiCarga extends StatelessWidget {
  final String label, valor;
  final Color color;
  final BuildContext ctx;
  const _KpiCarga({required this.label, required this.valor, required this.color, required this.ctx});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(valor, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: ctx.textSecondary, fontSize: 11)),
    ]),
  );
}