import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import '../services/trabajador_service.dart';
import '../utils/validators.dart';
import '../widgets/collapsible_sidebar.dart';

const _bgDark = Color(0xFF0A1628);
const _cardDark = Color(0xFF132336);
const _cardBorder = Color(0xFF1E3456);
const _accentBlue = Color(0xFF1B3A5C);
const _green = Color(0xFF00E676);
const _yellow = Color(0xFFFFC107);
const _red = Color(0xFFFF5252);
const _orange = Color(0xFFFF6B35);
const _textPrimary = Color(0xFFECEFF1);
const _textSecondary = Color(0xFF90A4AE);
const _textMuted = Color(0xFF607D8B);

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
  // 1. Reemplazar comas por puntos (ej: "201,261,406" -> "201.261.406")
  String rut = raw.replaceAll(',', '.');
  // 2. Eliminar puntos, guiones y espacios para obtener solo dígitos + DV
  final limpio = rut.replaceAll('.', '').replaceAll('-', '').replaceAll(' ', '').toUpperCase();
  if (limpio.length < 2) return raw;
  // 3. Separar DV (último carácter) del cuerpo numérico
  final dv = limpio.substring(limpio.length - 1);
  final cuerpo = limpio.substring(0, limpio.length - 1);
  // 4. Formatear cuerpo con puntos desde la DERECHA (ej: 24315442 -> 24.315.442)
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
  // Primero reemplazar comas por puntos (ej: "201,261,406" -> "201.261.406")
  String str = raw.toString().trim().replaceAll(',', '.');
  if (str.isEmpty) return null;
  final limpio = str.replaceAll('.', '').replaceAll('-', '').replaceAll(' ', '').toUpperCase();
  if (limpio.length < 8 || limpio.length > 9) return null;
  // DV válidos: solo 0-9 o K (estándar chileno)
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

  Color get colorTipo => switch (tipo) {
    _TipoCambio.invalido => _red.withValues(alpha: 0.25),
    _TipoCambio.nuevo => _green.withValues(alpha: 0.15),
    _TipoCambio.modificado => _yellow.withValues(alpha: 0.15),
    _TipoCambio.sinCambios => _cardBorder.withValues(alpha: 0.25),
  };

  Color get colorEtiqueta => switch (tipo) {
    _TipoCambio.invalido => _red,
    _TipoCambio.nuevo => _green,
    _TipoCambio.modificado => _yellow,
    _TipoCambio.sinCambios => _textMuted,
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
  int _validos = 0, _nuevos = 0, _modificados = 0, _sinCambios = 0, _invalidos = 0;
  bool _soloInsertarNuevos = false;

  String? _resultadoMensaje;
  int _insertados = 0, _actualizados = 0, _cumplimientoInsertados = 0, _erroresEjecucion = 0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        children: [
          isWide
              ? CollapsibleSidebar(
                  items: [
                    MenuItem(icon: Icons.dashboard_rounded, label: 'Inicio / Dashboard', color: _accentBlue, onTap: () => Navigator.pop(context)),
                    MenuItem(icon: Icons.upload_file_rounded, label: 'Carga Masiva', color: _orange, isActive: true, onTap: () {}),
                  ],
                  child: _buildBody(),
                )
              : _buildBody(),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _orange),
                    SizedBox(height: 16),
                    Text('Procesando...', style: TextStyle(color: Colors.white, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Esto puede tomar unos segundos', style: TextStyle(color: _textSecondary, fontSize: 12)),
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

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _cardBorder, width: 1))),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textSecondary),
          onPressed: () {
            if (_paso == 1 || _resultadoMensaje != null) {
              Navigator.pop(context);
            } else if (_filas.isNotEmpty && _paso > 1) {
              setState(() { _paso--; _errorGeneral = null; });
            }
          },
        ),
        const SizedBox(width: 4),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Carga Masiva de Personal', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(_tituloPaso(), style: const TextStyle(color: _textSecondary, fontSize: 11)),
        ])),
        _StepperIndicator(pasoActual: _paso),
      ],
    ),
  );

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
    final colorBorde = tieneArchivo ? _green.withValues(alpha: 0.6) : _cardBorder;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TarjetaContenido(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Seleccionar archivo', style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        InkWell(
          onTap: _isLoading ? null : _pickArchivo,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: _bgDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorBorde, width: 1.5)),
            child: Column(children: [
              Icon(tieneArchivo ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: tieneArchivo ? _green : colorBorde, size: 52),
              const SizedBox(height: 12),
              Text(_archivoNombre ?? 'Toca para seleccionar CSV o XLSX', style: TextStyle(color: _textSecondary, fontSize: 13), textAlign: TextAlign.center),
              if (tieneArchivo) ...[
                const SizedBox(height: 8),
                Text('${(_archivoBytes!.length / 1024).toStringAsFixed(1)} KB — listo', style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 20),
        if (_errorGeneral != null) _ErrorBox(mensaje: _errorGeneral!),
        const SizedBox(height: 16),
        if (tieneArchivo)
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _procesarArchivo,
            icon: const Icon(Icons.read_more_rounded, size: 20),
            label: const Text('Validar y comparar con BD'),
            style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
      ])),
    ]);
  }

  Widget _buildPaso2() {
    if (_filas.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _orange)));
    final cols = _columnasTabla();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ResumenCarga(nuevos: _nuevos, modificados: _modificados, sinCambios: _sinCambios, invalidos: _invalidos, validos: _validos),
      const SizedBox(height: 20),
      if (_errorGeneral != null) _ErrorBox(mensaje: _errorGeneral!),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(_accentBlue.withValues(alpha: 0.4)),
          headingTextStyle: const TextStyle(color: _textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
          dataTextStyle: const TextStyle(color: _textPrimary, fontSize: 10),
          columnSpacing: 8,
          horizontalMargin: 6,
          columns: List.generate(cols.length, (i) => DataColumn(label: Text(cols[i]))),
          rows: _filas.asMap().entries.map((entry) {
            final idx = entry.key;
            final f = entry.value;
            final d = f.datosArchivo;
            return DataRow(
              color: WidgetStateProperty.all(f.colorTipo),
              cells: [
                DataCell(IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: _red, size: 18),
                  onPressed: () => _eliminarFila(idx),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )),
                DataCell(Text('${f.numeroFila}')),
                DataCell(f.esOk
                    ? Text(f.rut ?? '')
                    : GestureDetector(
                        onTap: () => _mostrarDialogoCorreccion(f),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.edit_rounded, color: _orange, size: 12),
                          const SizedBox(width: 2),
                          Text(d['rut'] ?? '', style: const TextStyle(color: _red, decoration: TextDecoration.underline, fontSize: 10)),
                        ]),
                      )),
                DataCell(Text(d['nombre'] ?? '')),
                DataCell(Text(d['apellido_paterno'] ?? '')),
                DataCell(Text(d['apellido_materno'] ?? '')),
                DataCell(Text(d['cargo'] ?? '')),
                DataCell(Text(d['nacionalidad'] ?? '')),
                DataCell(Text(d['fecha_vencimiento_residencia'] ?? '')),
                DataCell(Text(d['sexo'] ?? '')),
                DataCell(Text(d['turno'] ?? '')),
                DataCell(Text(d['contrato_codigo'] ?? '')),
                DataCell(Text(d['estado_trabajador'] ?? '')),
                ...List.generate(12, (ri) {
                  final estado = ri < f.cumplimientoArchivo.length
                      ? (f.cumplimientoArchivo[ri]['valor_estado'] as String)
                      : 'N/A';
                  return DataCell(Text(
                    estado == 'VIGENTE' ? 'V' : (estado == 'VENCIDO' ? 'X' : '-'),
                    style: TextStyle(
                      color: estado == 'VIGENTE' ? _green : (estado == 'VENCIDO' ? _red : _textMuted),
                      fontWeight: estado == 'VIGENTE' ? FontWeight.bold : FontWeight.normal,
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
        _leyenda(_green, 'Nuevo'),
        _leyenda(_yellow, 'Modificado'),
        _leyenda(_red, 'Inválido'),
        _leyenda(_textMuted, 'Sin cambios'),
        _chipLeyenda(_green, 'V', 'Vigente'),
        _chipLeyenda(_red, 'X', 'Vencido'),
        _chipLeyenda(_textMuted, '-', 'N/A'),
      ]),
      const SizedBox(height: 16),
      if (_invalidos > 0)
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: _orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _orange.withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.edit_rounded, color: _orange, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('Toca el RUT en rojo para corregir datos', style: TextStyle(color: _textPrimary, fontSize: 12))),
          ]),
        ),
      Row(children: [
        OutlinedButton(onPressed: () => setState(() => _paso = 1), child: const Text('Volver')),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(
          onPressed: _validos == 0 ? null : () => setState(() => _paso = 3),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text('Continuar ($_validos registros)'),
          style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white),
        )),
      ]),
    ]);
  }

  void _eliminarFila(int idx) {
    setState(() { _filas.removeAt(idx); _recalcular(); });
  }

  Widget _chipLeyenda(Color color, String simbolo, String texto) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 20, height: 20, alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Text(simbolo, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))),
      const SizedBox(width: 4),
      Text(texto, style: const TextStyle(color: _textSecondary, fontSize: 11)),
    ]);
  }

  Widget _leyenda(Color color, String texto) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(texto, style: const TextStyle(color: _textSecondary, fontSize: 11)),
    ]);
  }

  Future<void> _mostrarDialogoCorreccion(_FilaDiff f) async {
    final rutCtrl = TextEditingController(text: f.datosArchivo['rut'] ?? '');
    final nombreCtrl = TextEditingController(text: f.datosArchivo['nombre'] ?? '');
    final apCtrl = TextEditingController(text: f.datosArchivo['apellido_paterno'] ?? '');
    final cargoCtrl = TextEditingController(text: f.datosArchivo['cargo'] ?? '');
    final turnoCtrl = TextEditingController(text: f.datosArchivo['turno'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardDark,
        title: Text('Corregir Fila ${f.numeroFila}', style: const TextStyle(color: _textPrimary)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _campoDialog('RUT (ej: 12.345.678-9)', rutCtrl),
            const SizedBox(height: 8),
            _campoDialog('Nombre', nombreCtrl),
            const SizedBox(height: 8),
            _campoDialog('Apellido Paterno', apCtrl),
            const SizedBox(height: 8),
            _campoDialog('Cargo', cargoCtrl),
            const SizedBox(height: 8),
            _campoDialog('Turno', turnoCtrl),
            if (f.erroresValidacion.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...f.erroresValidacion.map((e) => Text('• $e', style: const TextStyle(color: _red, fontSize: 12))),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white),
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
        // Si después de corregir ya no hay errores, cambiar estado a nuevo
        if (f.erroresValidacion.isEmpty && f.tipo == _TipoCambio.invalido) {
          f.tipo = _TipoCambio.nuevo;
        }
        _recalcular();
      });
    }
  }

  Widget _campoDialog(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: _textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSecondary, fontSize: 12),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: _cardBorder)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _orange)),
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
      _ResumenCarga(nuevos: _nuevos, modificados: _modificados, sinCambios: _sinCambios, invalidos: _invalidos, validos: _validos),
      const SizedBox(height: 20),
      _TarjetaContenido(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Checkbox(value: _soloInsertarNuevos, onChanged: (v) => setState(() => _soloInsertarNuevos = v ?? false), activeColor: _orange),
          const Expanded(child: Text('Solo insertar registros nuevos', style: TextStyle(color: _textPrimary, fontSize: 13))),
        ]),
        const SizedBox(height: 8),
        Text('Se procesarán $aConfirmar registros con ${aConfirmar * 12} cumplimientos HSE.', style: TextStyle(color: _textSecondary, fontSize: 12)),
      ])),
      const SizedBox(height: 20),
      if (_errorGeneral != null) _ErrorBox(mensaje: _errorGeneral!),
      const SizedBox(height: 20),
      Row(children: [
        OutlinedButton(onPressed: () => setState(() => _paso = 2), child: const Text('Volver')),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(
          onPressed: aConfirmar == 0 || _isLoading ? null : _ejecutarCarga,
          icon: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.upload_rounded, size: 20),
          label: Text(_isLoading ? 'Guardando...' : 'Confirmar y guardar ($aConfirmar)'),
          style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
      ]),
    ]);
  }

  Widget _buildResultado() {
    final exito = _erroresEjecucion == 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _TarjetaContenido(child: Column(children: [
        Icon(exito ? Icons.check_circle_rounded : Icons.error_rounded, color: exito ? _green : _red, size: 56),
        const SizedBox(height: 12),
        Text(_resultadoMensaje ?? '', style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Insertados: $_insertados  |  Actualizados: $_actualizados  |  Cumplimientos: $_cumplimientoInsertados  |  Errores: $_erroresEjecucion', style: TextStyle(color: _textSecondary, fontSize: 12)),
      ])),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text('Volver a Gestión de Personal'),
        style: ElevatedButton.styleFrom(backgroundColor: _accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
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

    final rutRaw = getCol(4);
    final rut = _validarYFormatearRut(rutRaw) ?? _formatearRut(rutRaw);
    final nombre = getCol(1);
    final apellidoPaterno = getCol(2);
    final apellidoMaterno = getCol(3);
    final cargo = getCol(5);
    final nacionalidad = getCol(6);
    final vencRes = getCol(7);
    final sexo = Validators.normalizarSexo(getCol(8));
    final turno = getCol(9);

    final errores = <String>[];
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
      'contrato_codigo': 'SC-9500014891',
    };

    final cumplimientos = <Map<String, dynamic>>[];
    for (var i = 0; i < 12; i++) {
      final raw = getCol(10 + i);
      final requisitoId = i + 1;

      String estado;
      String? fecha;

      final fechaStr = Validators.parsearFechaCsv(raw);
      // Solo tratar como fecha si el string parseado tiene formato yyyy-MM-dd
      if (fechaStr.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fechaStr)) {
        estado = Validators.estadoDesdeFecha(fechaStr);
        fecha = fechaStr;
      } else {
        final upper = raw.toUpperCase();
        if (upper == 'SI' || upper == 'SÍ') {
          estado = 'VIGENTE';
          fecha = null;
        } else if (upper == 'NO' || upper == 'N/A' || upper == 'NA' || upper.isEmpty) {
          estado = 'N/A';
          fecha = null;
        } else {
          estado = 'VENCIDO';
          fecha = null;
        }
      }

      cumplimientos.add({'requisito_id': requisitoId, 'valor_estado': estado, 'fecha_vencimiento': fecha, 'documento_url': null});
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

      // Pad all rows to match header column count (critical for XLSX with merged cells)
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

      debugPrint('=== CABECERA: $numCols cols, ${dataRows.length} filas ===');
      if (dataRows.isNotEmpty) {
        debugPrint('Primera fila: ${dataRows.first.length} columnas');
        if (dataRows.first.length > 10) {
          debugPrint('Req cols[10-21]: ${dataRows.first.sublist(10, dataRows.first.length > 22 ? 22 : dataRows.first.length).join(" | ")}');
        } else {
          debugPrint('ERROR: fila solo tiene ${dataRows.first.length} columnas, no hay columnas 10-21');
        }
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

  Future<void> _ejecutarCarga() async {
    setState(() { _isLoading = true; _errorGeneral = null; });
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      final aProcesar = _filas.where((f) => f.esOk).toList();
      if (aProcesar.isEmpty) {
        setState(() { _isLoading = false; _errorGeneral = 'No hay registros válidos'; });
        return;
      }

      // Construir lista única de trabajadores (deduplicada por RUT para evitar error 500 de PostgREST)
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

      // Carga masiva atómica vía RPC (transacción ACID en servidor)
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
        _cumplimientoInsertados = _insertados * 12; // 12 reqs por trabajador
        _erroresEjecucion = (result['total_err'] as num?)?.toInt() ?? 0;

        // Lista de registros con error de validación (los que NO se subieron)
        final invalidos = _filas.where((f) => !f.esOk).toList();
        final detalleInvalidos = invalidos.isNotEmpty
            ? '\n❌ Registros NO subidos (error de validación):\n${invalidos.map((f) => '• Fila ${f.numeroFila}: ${f.rut ?? "N/A"} — ${f.datosArchivo['nombre']} ${f.datosArchivo['apellido_paterno']} (${f.erroresValidacion.join(", ")})').join('\n')}\n'
            : '';

        // Lista de registros que se intentaron subir a la BD
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
    // Buscar la mejor sheet: priorizar "LISTADO", "HOJA1", o la primera con ≥10 columnas
    Sheet? mejorSheet;
    String? mejorNombre;
    int mejorColumnas = 0;
    for (final entry in doc.sheets.entries) {
      final nombre = entry.key.toUpperCase();
      final s = entry.value;
      if (s.rows.isEmpty) continue;
      // Contar columnas en la primera fila con datos
      for (final row in s.rows) {
        final count = row.where((c) => c?.value != null && c!.value.toString().trim().isNotEmpty).length;
        if (count >= 10) {
          if (nombre.contains('LISTADO') || nombre.contains('HOJA1') || count > mejorColumnas) {
            mejorSheet = s;
            mejorNombre = entry.key;
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
        // Manejo robusto de null
        final cell = c;
        if (cell == null) return '';
        final dynamic rawValue = cell.value;
        if (rawValue == null) return '';
        String s;

        // 1. Si el valor es un DateTime nativo de Excel, formatearlo a yyyy-MM-dd
        if (rawValue is DateTime) {
          s = '${rawValue.year}-${rawValue.month.toString().padLeft(2, '0')}-${rawValue.day.toString().padLeft(2, '0')}';
        }
        // 2. Detectar fecha serial de Excel (días desde 1899-12-30, rango ~45000-55000 para años 2020-2050)
        else if (rawValue is num && rawValue >= 43830 && rawValue <= 73000) {
          // Convertir serial number → DateTime: epoch Excel = 1899-12-30
          final excelEpoch = DateTime(1899, 12, 30);
          final date = excelEpoch.add(Duration(days: rawValue.toInt()));
          s = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        } else {
          s = rawValue.toString();
          // Limpiar ".0" de decimales irrelevantes (ej: "45293.0" -> "45293")
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
    debugPrint('XLSX parseado (sheet: $mejorNombre): ${result.length} filas');
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
    const campos = ['rut', 'nombre', 'apellido_paterno', 'apellido_materno', 'cargo', 'nacionalidad', 'fecha_vencimiento_residencia', 'sexo', 'turno', 'contrato_codigo', 'estado_trabajador'];
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
  const _StepperIndicator({required this.pasoActual});
  @override
  Widget build(BuildContext context) => Row(children: [
    _StepCircle(activo: pasoActual == 1, completo: pasoActual > 1, label: '1'),
    _StepLine(activo: pasoActual > 1),
    _StepCircle(activo: pasoActual == 2, completo: pasoActual > 2, label: '2'),
    _StepLine(activo: pasoActual > 2),
    _StepCircle(activo: pasoActual == 3, completo: false, label: '3'),
  ]);
}

class _StepCircle extends StatelessWidget {
  final bool activo, completo;
  final String label;
  const _StepCircle({required this.activo, required this.completo, required this.label});
  @override
  Widget build(BuildContext context) {
    final color = completo ? _green : activo ? _orange : _textMuted;
    return Container(width: 30, height: 30,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
      child: Center(child: completo ? const Icon(Icons.check, color: _green, size: 18)
          : Text(label, style: TextStyle(color: activo ? _textPrimary : _textMuted, fontSize: 13, fontWeight: FontWeight.bold))));
  }
}

class _StepLine extends StatelessWidget {
  final bool activo;
  const _StepLine({required this.activo});
  @override
  Widget build(BuildContext context) => Container(width: 32, height: 2, color: activo ? _orange : _cardBorder, margin: const EdgeInsets.symmetric(horizontal: 4));
}

class _TarjetaContenido extends StatelessWidget {
  final Widget child;
  const _TarjetaContenido({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder, width: 0.5)),
    child: child,
  );
}

class _ErrorBox extends StatelessWidget {
  final String mensaje;
  const _ErrorBox({required this.mensaje});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: _red.withValues(alpha: 0.4))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline_rounded, color: _red, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(mensaje, style: const TextStyle(color: _textPrimary, fontSize: 13))),
    ]),
  );
}

class _ResumenCarga extends StatelessWidget {
  final int nuevos, modificados, sinCambios, invalidos, validos;
  const _ResumenCarga({required this.nuevos, required this.modificados, required this.sinCambios, required this.invalidos, required this.validos});
  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiCarga(label: 'Nuevos', valor: '$nuevos', color: _green),
      _KpiCarga(label: 'Modificados', valor: '$modificados', color: _yellow),
      _KpiCarga(label: 'Sin cambios', valor: '$sinCambios', color: _textMuted),
      _KpiCarga(label: 'Inválidos', valor: '$invalidos', color: _red),
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
  const _KpiCarga({required this.label, required this.valor, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(valor, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: _textSecondary, fontSize: 11)),
    ]),
  );
}