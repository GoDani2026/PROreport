import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart' as excel hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../config/theme_context_ext.dart';
import '../providers/auth_provider.dart';
import '../services/trabajador_service.dart';
import '../utils/download_helper.dart' as download_helper;
import 'editar_trabajador_screen.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/app_header.dart';
import 'registro_trabajador_screen.dart';
import 'deteccion_peligro_screen.dart';
import 'solicitud_levantamiento_screen.dart';
import 'carga_masiva_screen.dart';

const _pageSize = 20;

enum _FiltroTrabajadores { habilitados, observados, inactivos }

class GestionPersonalScreen extends StatefulWidget {
  const GestionPersonalScreen({super.key});
  @override
  State<GestionPersonalScreen> createState() => _GestionPersonalScreenState();
}

class _GestionPersonalScreenState extends State<GestionPersonalScreen> {
  final _service = TrabajadorService();
  List<Map<String, dynamic>> _todosTrabajadores = [];
  bool _isLoading = true;
  int _dotacionOficial = 0;
  int _acreditadosOk = 0;
  int _observados = 0;
  int _excluidos = 0;
  Set<String> _acreditadosIds = {};
  Set<String> _observadosIds = {};
  int _currentPage = 1;
  _FiltroTrabajadores _filtroActual = _FiltroTrabajadores.habilitados;
  String _searchQuery = '';
  Timer? _searchDebounce;
  String? _lastSearchQuery;
  List<Map<String, dynamic>>? _cachedFilteredResults;
  String? _ultimoContratoCargado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDatos());
  }

  @override
  void dispose() { _searchDebounce?.cancel(); super.dispose(); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  /// Se llama en cada build. Detecta cambios en el contrato seleccionado
  /// y recarga los datos si es necesario.
  void _verificarCambioContrato() {
    final auth = context.read<AuthProvider>();
    final contratoActual = auth.contratoSeleccionadoContexto;
    if (_ultimoContratoCargado != contratoActual && mounted) {
      debugPrint('=== Cambio de contrato detectado: "$_ultimoContratoCargado" -> "$contratoActual" ===');
      _cargarDatos();
    }
  }

  static int? _toIntStatic(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.isNotEmpty) return int.tryParse(value);
    return null;
  }

  static String _workerKey(Map<String, dynamic> row) => (row['id'] ?? '').toString().trim();

  int? _toInt(dynamic value) => _toIntStatic(value);

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      debugPrint('=== _cargarDatos: contratoSeleccionadoContexto="${auth.contratoSeleccionadoContexto}" ===');
      debugPrint('contratosUsuario: ${auth.contratosUsuario}');
      debugPrint('rolUsuario: ${auth.rolUsuario}');
      debugPrint('isAuthenticated: ${auth.isAuthenticated}');
      final data = await _service.fetchDatosExportacion(contratoCodigo: auth.contratoSeleccionadoContexto);
      final trabajadores = data['trabajadores']!;
      final cumplimiento = data['cumplimiento']!;
      final requisitos = data['requisitos']!;
      if (!mounted) return;
      final trabajadoresMap = trabajadores.map((t) => Map<String, dynamic>.from(t as Map)).toList();
      final cumplimientoMap = cumplimiento.map((c) => Map<String, dynamic>.from(c as Map)).toList();
      final requisitosMap = requisitos.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      final datosProcesados = await compute(_procesarDatosEnBackground, _DatosBrutos(trabajadores: trabajadoresMap, cumplimiento: cumplimientoMap, requisitos: requisitosMap));
      if (!mounted) return;
      setState(() {
        _todosTrabajadores = datosProcesados.trabajadores;
        _acreditadosIds = datosProcesados.acreditadosIds;
        _observadosIds = datosProcesados.observadosIds;
        _dotacionOficial = datosProcesados.dotacionOficial;
        _acreditadosOk = datosProcesados.acreditadosOk;
        _observados = datosProcesados.observados;
        _excluidos = datosProcesados.excluidos;
        _currentPage = 1;
        _searchQuery = '';
        _lastSearchQuery = null;
        _cachedFilteredResults = null;
        _ultimoContratoCargado = auth.contratoSeleccionadoContexto;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
    }
  }

  static DatosProcesados _procesarDatosEnBackground(_DatosBrutos datos) {
    final cumplimientoIndex = <String, List<String>>{};
    for (final c in datos.cumplimiento) {
      final trabajadorKey = (c['trabajador_id'] ?? '').toString().trim();
      final estado = c['valor_estado'] as String?;
      if (trabajadorKey.isNotEmpty && estado != null) cumplimientoIndex.putIfAbsent(trabajadorKey, () => []).add(estado);
    }
    final acreditadosIds = <String>{};
    final observadosIds = <String>{};
    for (final t in datos.trabajadores) {
      final trabajadorKey = _workerKey(t);
      if (trabajadorKey.isEmpty) continue;
      final estadoTrabajador = t['estado_trabajador'] as String?;
      if (estadoTrabajador != 'ACTIVO') continue;
      final estados = cumplimientoIndex[trabajadorKey] ?? [];
      final tieneVencido = estados.contains('VENCIDO');
      if (tieneVencido) {
        observadosIds.add(trabajadorKey);
      } else {
        acreditadosIds.add(trabajadorKey);
      }
    }
    return DatosProcesados(trabajadores: datos.trabajadores, cumplimiento: datos.cumplimiento, cumplimientoIndex: cumplimientoIndex, acreditadosIds: acreditadosIds, observadosIds: observadosIds, dotacionOficial: datos.trabajadores.length, acreditadosOk: acreditadosIds.length, observados: observadosIds.length, excluidos: datos.trabajadores.where((t) => t['estado_trabajador'] == 'DESVINCULADO').length);
  }

  List<Map<String, dynamic>> get _paginaTrabajadores {
    final filtered = _getFilteredResults();
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end);
  }

  int get _totalPaginas {
    final filtered = _getFilteredResults();
    final count = (filtered.length / _pageSize).ceil();
    return count == 0 ? 1 : count;
  }

  List<Map<String, dynamic>> _getFilteredResults() {
    if (_lastSearchQuery == _searchQuery && _cachedFilteredResults != null) return _cachedFilteredResults!;
    List<Map<String, dynamic>> result = List.from(_todosTrabajadores);
    switch (_filtroActual) {
      case _FiltroTrabajadores.habilitados:
        result = result.where((t) => t['estado_trabajador'] == 'ACTIVO').toList();
        break;
      case _FiltroTrabajadores.observados:
        result = result.where((t) => t['estado_trabajador'] == 'ACTIVO' && _observadosIds.contains(_workerKey(t))).toList();
        break;
      case _FiltroTrabajadores.inactivos:
        result = result.where((t) => t['estado_trabajador'] == 'DESVINCULADO').toList();
        break;
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((t) => '${t['nombre'] ?? ''} ${t['apellido_paterno'] ?? ''} ${t['apellido_materno'] ?? ''}'.toLowerCase().contains(query) || (t['rut'] ?? '').toLowerCase().contains(query) || (t['cargo'] ?? '').toLowerCase().contains(query)).toList();
    }
    _lastSearchQuery = _searchQuery;
    _cachedFilteredResults = result;
    return result;
  }

  void updateSearchQuery(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
          _currentPage = 1;
          _cachedFilteredResults = null;
        });
      }
    });
  }

  void changePage(int page) { setState(() => _currentPage = page.clamp(1, _totalPaginas)); }
  void setFiltro(_FiltroTrabajadores filtro) {
    setState(() {
      _filtroActual = filtro;
      _currentPage = 1;
      _cachedFilteredResults = null;
    });
  }
  String _nombreCompleto(Map<String, dynamic> t) => '${t['nombre'] ?? ''} ${t['apellido_paterno'] ?? ''}${(t['apellido_materno'] ?? '').isNotEmpty ? ' ${t['apellido_materno']}' : ''}';
  String _estadoActivacion(Map<String, dynamic> t) {
    final e = t['estado_trabajador'] as String? ?? 'ACTIVO';
    final trabajadorKey = _workerKey(t);
    if (e == 'DESVINCULADO') return 'Inactivo';
    if (_observadosIds.contains(trabajadorKey)) return 'Observado';
    if (_acreditadosIds.contains(trabajadorKey)) return 'Habilitado';
    return 'Habilitado';
  }
  Color _colorEstado(Map<String, dynamic> t) {
    final ctx = context;
    final trabajadorKey = _workerKey(t);
    if (t['estado_trabajador'] == 'DESVINCULADO') return ctx.errorRed;
    if (_observadosIds.contains(trabajadorKey)) return ctx.warningYellow;
    return ctx.successGreen;
  }
  void _navegarARegistro() {
    _mostrarDialogoRegistro();
  }

  void _mostrarDialogoRegistro() {
    final ctx = context;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ctx.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Registro de Personal", style: TextStyle(color: ctx.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _OpcionRegistro(
            icon: Icons.person_add_alt_rounded,
            titulo: "Registro Individual",
            descripcion: "Ingrese los datos de un trabajador manualmente, formulario personalizado",
            onTap: () {
              Navigator.pop(dialogCtx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroTrabajadorScreen())).then((_) => _cargarDatos());
            },
          ),
          const SizedBox(height: 12),
          _OpcionRegistro(
            icon: Icons.upload_file_rounded,
            titulo: "Carga Masiva",
            descripcion: "Subir multiples trabajadores desde un archivo CSV o Excel con validacion automatica",
            onTap: () {
              Navigator.pop(dialogCtx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CargaMasivaScreen())).then((_) => _cargarDatos());
            },
          ),
        ]),
      ),
    );
  }
  bool _isOpeningEdicion = false;

  Future<void> _abrirEdicion(Map<String, dynamic> trabajador) async {
    if (_isOpeningEdicion) return;
    _isOpeningEdicion = true;
    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => EditarTrabajadorScreen(trabajador: trabajador)),
      );
      if (!mounted) return;
      if (result == true) await _cargarDatos();
    } finally {
      _isOpeningEdicion = false;
    }
  }

  Future<void> _exportarPlanilla() async {
    setState(() => _isLoading = true);
    try {
      final activos = _todosTrabajadores.where((t) => t['estado_trabajador'] == 'ACTIVO').toList();
      final requisitos = await _service.fetchRequisitosHSE();
      final ids = activos.map((t) => _toInt(t['id'])).whereType<int>().toList();
      final cumplMap = <int, Map<int, Map<String, dynamic>>>{};
      if (ids.isNotEmpty) {
        final cumpl = await _service.fetchCumplimientoPorIds(ids);
        for (final c in cumpl) { final tid = _toInt(c['trabajador_id']); final rid = c['requisito_id'] as int; if (tid != null) cumplMap.putIfAbsent(tid, () => {})[rid] = c; }
      }

      final fixedHeaders = [
        'Nombre', 'Apellido Paterno', 'Apellido Materno', 'Rut', 'Cargo',
        'Nacionalidad', 'Vencimiento de Residencia', 'Turno', 'AG/AF',
        'Examen Alcohol y drogas', 'Examen Psicosensometrico',
        'Fecha Vencimiento Inducción SQM', 'Protocolo SQM (ODI)', 'CTTA(ODI)',
        'Certificación (Soldadores, electricos, riggers, op.Maquinaria, etc)',
        'Licencia Interna SQM', 'Difusión Procedimientos',
        'Difusión Plan y Sub Planes SQM', 'Difusión Plan y Sub Planes Cttas',
        'Difusión HDS',
      ];
      final reqToFixedCol = <String, int>{};
      for (int i = 8; i < fixedHeaders.length; i++) {
        reqToFixedCol[fixedHeaders[i].toLowerCase().trim()] = i;
      }
      final fixedReqs = <Map<String, dynamic>>[];
      final extraReqs = <Map<String, dynamic>>[];
      for (final r in requisitos) {
        final name = (r['nombre_requisito'] as String).toLowerCase().trim();
        if (reqToFixedCol.containsKey(name)) {
          fixedReqs.add(r);
        } else {
          extraReqs.add(r);
        }
      }
      final allHeaders = <String>[
        ...fixedHeaders,
        ...extraReqs.map((r) => r['nombre_requisito'] as String),
      ];

      final book = excel.Excel.createExcel();
      final sheetName = book.getDefaultSheet() ?? 'Sheet';
      final sheet = book[sheetName];
      final titulo = 'LISTADO DE PERSONAL CONTRATO - SC 9500014891 - Nombre "Servicios Operacionales para Planta Química Litio"';
      sheet.cell(excel.CellIndex.indexByString('E2')).value = excel.TextCellValue(titulo);

      final rowHeaders = List<excel.CellValue?>.filled(26, null);
      for (int i = 0; i < allHeaders.length && i < 26; i++) {
        rowHeaders[i] = excel.TextCellValue(allHeaders[i]);
      }
      sheet.appendRow(rowHeaders);

      for (final t in activos) {
        final tid = _toInt(t['id']);
        final cumT = tid != null ? (cumplMap[tid] ?? {}) : {};
        final rowData = List<dynamic>.filled(26, '');
        rowData[0] = t['nombre'] ?? '';
        rowData[1] = t['apellido_paterno'] ?? '';
        rowData[2] = t['apellido_materno'] ?? '';
        rowData[3] = t['rut'] ?? '';
        rowData[4] = t['cargo'] ?? '';
        rowData[5] = t['nacionalidad'] ?? '';
        rowData[6] = (t['fecha_vencimiento_residencia'] ?? '').toString();
        rowData[7] = t['turno'] ?? '';
        for (final r in fixedReqs) {
          final rid = r['id'] as int;
          final name = (r['nombre_requisito'] as String).toLowerCase().trim();
          final colIdx = reqToFixedCol[name] ?? -1;
          if (colIdx >= 8 && colIdx < 20) {
            final c = cumT[rid];
            final val = c?['valor_estado'] ?? 'N/A';
            final fecha = c?['fecha_vencimiento'];
            rowData[colIdx] = fecha != null ? '$val ($fecha)' : val;
          }
        }
        for (int r = 0; r < extraReqs.length; r++) {
          final req = extraReqs[r];
          final rid = req['id'] as int;
          final c = cumT[rid];
          final val = c?['valor_estado'] ?? 'N/A';
          final fecha = c?['fecha_vencimiento'];
          final colIdx = 20 + r;
          if (colIdx < 26) rowData[colIdx] = fecha != null ? '$val ($fecha)' : val;
        }
        final rowCells = rowData.map((v) => excel.TextCellValue(v.toString())).toList();
        sheet.appendRow(rowCells);
      }

      final encoded = book.encode();
      if (encoded == null) throw Exception('Error al codificar el archivo Excel');
      final bytes = Uint8List.fromList(encoded);

      if (kIsWeb) {
        _descargarEnWeb(bytes, 'planilla_personal_hse.xlsx');
      } else {
        final directory = (await getTemporaryDirectory()).path;
        final filePath = '$directory/planilla_personal_hse.xlsx';
        await File(filePath).writeAsBytes(encoded);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Planilla exportada: $filePath')));
          await OpenFile.open(filePath);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exportando planilla: $e')));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  void _descargarEnWeb(Uint8List bytes, String fileName) {
    download_helper.descargarArchivo(bytes, fileName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Planilla descargada: $fileName')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en AuthProvider para detectar cambio de contrato
    context.watch<AuthProvider>();
    _verificarCambioContrato();
    final ctx = context;
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: ctx.surfaceBg,
      body: isWide
          ? CollapsibleSidebar(
              items: [
                MenuItem(icon: Icons.dashboard_rounded, label: 'Inicio / Dashboard', color: ctx.accentBlue, onTap: () => Navigator.pop(context)),
                MenuItem(icon: Icons.warning_amber_rounded, label: 'Detecciones de Peligro', color: ctx.warningYellow, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeteccionPeligroScreen()))),
                MenuItem(icon: Icons.route_rounded, label: 'Caminatas de Seguridad', color: ctx.successGreen),
                MenuItem(icon: Icons.assignment_rounded, label: 'Solicitud de Levantamiento', color: ctx.accentOrange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SolicitudLevantamientoScreen()))),
                MenuItem(icon: Icons.people_rounded, label: 'Gestionar Personal', color: ctx.successGreen, isActive: true, onTap: () {}),
              ],
              child: _GestionPersonalContent(),
            )
          : _GestionPersonalContent(),
    );
  }
}

class _DatosBrutos { final List<Map<String, dynamic>> trabajadores; final List<Map<String, dynamic>> cumplimiento; final List<Map<String, dynamic>> requisitos; const _DatosBrutos({required this.trabajadores, required this.cumplimiento, required this.requisitos}); }
class DatosProcesados { final List<Map<String, dynamic>> trabajadores; final List<Map<String, dynamic>> cumplimiento; final Map<String, List<String>> cumplimientoIndex; final Set<String> acreditadosIds; final Set<String> observadosIds; final int dotacionOficial; final int acreditadosOk; final int observados; final int excluidos; const DatosProcesados({required this.trabajadores, required this.cumplimiento, required this.cumplimientoIndex, required this.acreditadosIds, required this.observadosIds, required this.dotacionOficial, required this.acreditadosOk, required this.observados, required this.excluidos}); }

class _GestionPersonalContent extends StatelessWidget {
  const _GestionPersonalContent();

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Column(
      children: [
        AppHeader(
          title: 'Gestion de Personal',
          subtitle: 'Administracion de trabajadores y acreditaciones',
          icon: Icons.people_rounded,
          iconColor: ctx.successGreen,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 0, isWide ? 24 : 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _KpiDashboardRow(),
                const SizedBox(height: 20),
                _SearchAndAddRow(),
                const SizedBox(height: 16),
                _StatusFilters(),
                const SizedBox(height: 16),
                _TrabajadoresTable(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiData { final String title; final String value; final Color color; final IconData icon; final String subtitle; const _KpiData({required this.title, required this.value, required this.color, required this.icon, required this.subtitle}); }

class _KpiDashboardRow extends StatelessWidget {
  const _KpiDashboardRow();
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final parent = context.findAncestorStateOfType<_GestionPersonalScreenState>();
    final dotacion = parent?._dotacionOficial ?? 0;
    final acreditados = parent?._acreditadosOk ?? 0;
    final observados = parent?._observados ?? 0;
    final excluidos = parent?._excluidos ?? 0;
    final kpis = [
      _KpiData(title: 'Dotacion Oficial', value: '$dotacion', color: ctx.accentBlue, icon: Icons.people_rounded, subtitle: 'Total trabajadores'),
      _KpiData(title: 'Acreditados OK', value: '$acreditados', color: ctx.successGreen, icon: Icons.verified_rounded, subtitle: 'Acreditacion valida'),
      _KpiData(title: 'Observados', value: '$observados', color: ctx.warningYellow, icon: Icons.warning_rounded, subtitle: 'Examenes vencidos'),
      _KpiData(title: 'Excluidos (Baja)', value: '$excluidos', color: ctx.errorRed, icon: Icons.person_off_rounded, subtitle: 'Inactivos / Desvinculados'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) return Wrap(spacing: 10, runSpacing: 10, children: kpis.map((kpi) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: _KpiCard(kpi: kpi))).toList());
        return Row(children: kpis.map((kpi) => Expanded(child: Padding(padding: EdgeInsets.only(left: kpis.first == kpi ? 0 : 14, right: kpis.last == kpi ? 0 : 0), child: _KpiCard(kpi: kpi)))).toList());
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final _KpiData kpi;
  const _KpiCard({required this.kpi});
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: ctx.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: ctx.borderColor, width: 0.5), boxShadow: ctx.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(padding: const EdgeInsets.all(6), decoration: ctx.iconContainer(kpi.color), child: Icon(kpi.icon, color: kpi.color, size: 18)), const Spacer(), Text(kpi.value, style: TextStyle(color: kpi.color, fontSize: 28, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 8), Text(kpi.title, style: ctx.headingSm),
        const SizedBox(height: 4), Text(kpi.subtitle, style: TextStyle(color: ctx.textMuted, fontSize: 11)),
      ]),
    );
  }
}

class _SearchAndAddRow extends StatelessWidget {
  const _SearchAndAddRow();
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) return Column(children: [_buildSearchBar(ctx), const SizedBox(height: 12), SizedBox(width: double.infinity, child: _buildAddButton(ctx)), const SizedBox(height: 8), SizedBox(width: double.infinity, child: _buildExportButton(ctx))]);
    return Row(children: [Expanded(child: _buildSearchBar(ctx)), const SizedBox(width: 16), _buildAddButton(ctx), const SizedBox(width: 8), _buildExportButton(ctx)]);
  }
  Widget _buildSearchBar(BuildContext ctx) => Container(
    height: 44,
    decoration: BoxDecoration(color: ctx.surfaceCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: ctx.borderColor, width: 0.5)),
    child: TextField(
      onChanged: (val) {
        final parent = ctx.findAncestorStateOfType<_GestionPersonalScreenState>();
        parent?.updateSearchQuery(val);
      },
      style: TextStyle(color: ctx.textPrimary, fontSize: 13),
      decoration: InputDecoration(hintText: 'Buscar por Nombre, RUT, Cargo...', hintStyle: TextStyle(color: ctx.textMuted, fontSize: 13), prefixIcon: Icon(Icons.search_rounded, color: ctx.textMuted, size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12)),
    ),
  );
  Widget _buildAddButton(BuildContext ctx) => SizedBox(
    height: 44,
    child: ElevatedButton.icon(
      onPressed: () {
        final parent = ctx.findAncestorStateOfType<_GestionPersonalScreenState>();
        parent?._navegarARegistro();
      },
      icon: const Icon(Icons.person_add_alt_rounded, size: 18),
      label: const Text('Agregar Trabajador', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      style: ElevatedButton.styleFrom(backgroundColor: ctx.accentOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20)),
    ),
  );
  Widget _buildExportButton(BuildContext ctx) => SizedBox(
    height: 44,
    child: ElevatedButton.icon(
      onPressed: () {
        final parent = ctx.findAncestorStateOfType<_GestionPersonalScreenState>();
        parent?._exportarPlanilla();
      },
      icon: const Icon(Icons.file_download_rounded, size: 18),
      label: const Text('Descargar Planilla', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      style: ElevatedButton.styleFrom(backgroundColor: ctx.accentBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16)),
    ),
  );
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters();
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final parent = context.findAncestorStateOfType<_GestionPersonalScreenState>();
    final filtroActual = parent?._filtroActual ?? _FiltroTrabajadores.habilitados;
    final items = [
      _FilterButton(label: 'Habilitados', icon: Icons.verified_rounded, color: ctx.successGreen, isSelected: filtroActual == _FiltroTrabajadores.habilitados, filtro: _FiltroTrabajadores.habilitados),
      _FilterButton(label: 'Observados', icon: Icons.warning_rounded, color: ctx.warningYellow, isSelected: filtroActual == _FiltroTrabajadores.observados, filtro: _FiltroTrabajadores.observados),
      _FilterButton(label: 'Inactivos', icon: Icons.person_off_rounded, color: ctx.errorRed, isSelected: filtroActual == _FiltroTrabajadores.inactivos, filtro: _FiltroTrabajadores.inactivos),
    ];
    return Wrap(spacing: 12, runSpacing: 8, children: items);
  }
}

class _FilterButton extends StatelessWidget {
  final String label; final IconData icon; final Color color; final bool isSelected; final _FiltroTrabajadores filtro;
  const _FilterButton({required this.label, required this.icon, required this.color, required this.isSelected, required this.filtro});
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return GestureDetector(
      onTap: () {
        final parent = context.findAncestorStateOfType<_GestionPersonalScreenState>();
        parent?.setFiltro(filtro);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : ctx.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? color.withValues(alpha: 0.7) : ctx.borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : ctx.textMuted, size: 17),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? color : ctx.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TrabajadoresTable extends StatelessWidget {
  const _TrabajadoresTable();
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final parent = context.findAncestorStateOfType<_GestionPersonalScreenState>();
    if (parent == null) return const SizedBox.shrink();
    final isLoading = parent._isLoading;
    final trabajadores = parent._paginaTrabajadores;
    final currentPage = parent._currentPage;
    final totalPaginas = parent._totalPaginas;
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isLoading) return Container(padding: const EdgeInsets.all(40), decoration: BoxDecoration(color: ctx.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: ctx.borderColor, width: 0.5)), child: Center(child: CircularProgressIndicator(color: ctx.accentOrange)));
    if (trabajadores.isEmpty) return Container(padding: const EdgeInsets.all(40), decoration: BoxDecoration(color: ctx.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: ctx.borderColor, width: 0.5)), child: Center(child: Column(children: [Icon(Icons.search_off_rounded, color: ctx.textMuted, size: 48), const SizedBox(height: 12), Text('No se encontraron trabajadores', style: TextStyle(color: ctx.textSecondary, fontSize: 14))])));

    final content = isMobile ? _buildMobileList(context, ctx, trabajadores, parent) : _buildWebTable(ctx, trabajadores, parent);
    return Column(children: [content, const SizedBox(height: 16), _PaginationControls(currentPage: currentPage, totalPaginas: totalPaginas, onPageChanged: parent.changePage)]);
  }

  Widget _buildWebTable(BuildContext ctx, List<Map<String, dynamic>> lista, _GestionPersonalScreenState parent) => Container(
    decoration: BoxDecoration(color: ctx.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: ctx.borderColor, width: 0.5)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(ctx.accentBlue.withValues(alpha: 0.3)),
          dataRowColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? ctx.accentBlue.withValues(alpha: 0.15) : Colors.transparent),
          dividerThickness: 0.5,
          columns: [
            DataColumn(label: Text('Nombre Completo', style: TextStyle(color: ctx.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
            DataColumn(label: Text('RUT', style: TextStyle(color: ctx.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Cargo', style: TextStyle(color: ctx.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Estado Activacion', style: TextStyle(color: ctx.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
          ],
          rows: lista.map((t) {
            final estado = parent._estadoActivacion(t);
            final colorEstado = parent._colorEstado(t);
            return DataRow(
              onSelectChanged: (_) => parent._abrirEdicion(t),
              cells: [
                DataCell(Text(parent._nombreCompleto(t), style: TextStyle(color: ctx.textPrimary, fontSize: 13))),
                DataCell(Text(t['rut'] ?? '', style: TextStyle(color: ctx.textSecondary, fontSize: 13))),
                DataCell(Text(t['cargo'] ?? '', style: TextStyle(color: ctx.textSecondary, fontSize: 13))),
                DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: colorEstado.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: colorEstado.withValues(alpha: 0.3), width: 0.5)), child: Text(estado, style: TextStyle(color: colorEstado, fontSize: 12, fontWeight: FontWeight.w600)))),
              ],
            );
          }).toList(),
        ),
      ),
    ),
  );

  Widget _buildMobileList(BuildContext context, BuildContext ctx, List<Map<String, dynamic>> lista, _GestionPersonalScreenState parent) => ListView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: lista.length,
    itemBuilder: (context, index) {
      final t = lista[index]; final estado = parent._estadoActivacion(t); final colorEstado = parent._colorEstado(t);
      return InkWell(
        onTap: () => parent._abrirEdicion(t),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: ctx.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ctx.borderColor, width: 0.5)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(parent._nombreCompleto(t), style: TextStyle(color: ctx.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text('${t['rut'] ?? ''} - ${t['cargo'] ?? ''}', style: TextStyle(color: ctx.textMuted, fontSize: 11))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: colorEstado.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: colorEstado.withValues(alpha: 0.3), width: 0.5)), child: Text(estado, style: TextStyle(color: colorEstado, fontSize: 11, fontWeight: FontWeight.w600))),
              const SizedBox(width: 10),
              Icon(Icons.edit_rounded, color: ctx.accentBlue, size: 20),
            ]),
          ),
        ),
      );
    },
  );
}

class _PaginationControls extends StatelessWidget {
  final int currentPage; final int totalPaginas; final ValueChanged<int> onPageChanged;
  const _PaginationControls({required this.currentPage, required this.totalPaginas, required this.onPageChanged});
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    if (totalPaginas <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: ctx.surfaceCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: ctx.borderColor, width: 0.5)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(
          onTap: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: currentPage > 1 ? ctx.accentBlue.withValues(alpha: 0.4) : ctx.borderColor, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [Icon(Icons.chevron_left_rounded, color: currentPage > 1 ? ctx.textPrimary : ctx.textMuted, size: 18), const SizedBox(width: 4), Text('Anterior', style: TextStyle(color: currentPage > 1 ? ctx.textPrimary : ctx.textMuted, fontSize: 13, fontWeight: FontWeight.w500))])
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: ctx.accentBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: ctx.borderColor, width: 0.5)),
          child: Text('$currentPage / $totalPaginas', style: TextStyle(color: ctx.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        GestureDetector(
          onTap: currentPage < totalPaginas ? () => onPageChanged(currentPage + 1) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: currentPage < totalPaginas ? ctx.accentBlue.withValues(alpha: 0.4) : ctx.borderColor, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [Text('Siguiente', style: TextStyle(color: currentPage < totalPaginas ? ctx.textPrimary : ctx.textMuted, fontSize: 13, fontWeight: FontWeight.w500)), const SizedBox(width: 4), Icon(Icons.chevron_right_rounded, color: currentPage < totalPaginas ? ctx.textPrimary : ctx.textMuted, size: 18)]),
          ),
        ),
      ]),
    );
  }
}

class _OpcionRegistro extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;
  const _OpcionRegistro({required this.icon, required this.titulo, required this.descripcion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ctx.surfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ctx.borderColor, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ctx.accentBlue.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: ctx.accentOrange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(color: ctx.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(descripcion, style: TextStyle(color: ctx.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ctx.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}