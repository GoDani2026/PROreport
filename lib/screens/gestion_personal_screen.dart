import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../utils/download_helper.dart' as download_helper;
import 'editar_trabajador_screen.dart';
import '../widgets/collapsible_sidebar.dart';
import 'registro_trabajador_screen.dart';
import 'solicitud_levantamiento_screen.dart';

const Color _bgDark = Color(0xFF0A1628);
const Color _cardDark = Color(0xFF132336);
const Color _cardBorder = Color(0xFF1E3456);
const Color _accentBlue = Color(0xFF1B3A5C);
const Color _green = Color(0xFF00E676);
const Color _yellow = Color(0xFFFFC107);
const Color _red = Color(0xFFFF5252);
const Color _orange = Color(0xFFFF6B35);
const Color _textPrimary = Color(0xFFECEFF1);
const Color _textSecondary = Color(0xFF90A4AE);
const Color _textMuted = Color(0xFF607D8B);
const Color _divider = Color(0xFF1E3456);
const _pageSize = 20;

enum _FiltroTrabajadores { habilitados, observados, inactivos }

class GestionPersonalScreen extends StatefulWidget {
  const GestionPersonalScreen({super.key});
  @override
  State<GestionPersonalScreen> createState() => _GestionPersonalScreenState();
}

class _GestionPersonalScreenState extends State<GestionPersonalScreen> {
  final _supabase = Supabase.instance.client;
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

  @override
  void initState() { super.initState(); _cargarDatos(); }

  @override
  void dispose() { _searchDebounce?.cancel(); super.dispose(); }

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
      final results = await Future.wait([
        _supabase.from('trabajadores').select('id, rut, nombre, apellido_paterno, apellido_materno, cargo, nacionalidad, vencimiento_residencia, sexo, turno, estado_trabajador, contrato_codigo').order('apellido_paterno', ascending: true),
        _supabase.from('cumplimiento_trabajadores').select('trabajador_id, requisito_id, valor_estado'),
        _supabase.from('requisitos_hse').select('id'),
      ]);
      final trabajadores = results[0] as List;
      final cumplimiento = results[1] as List;
      final requisitos = results[2] as List;
      if (!mounted) return;
      // Convertir a Map puros para evitar errores de serialización en compute/isolate
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
      final tieneNo = estados.contains('NO');

      if (tieneVencido || tieneNo) {
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
    final trabajadorKey = _workerKey(t);
    if (t['estado_trabajador'] == 'DESVINCULADO') return _red;
    if (_observadosIds.contains(trabajadorKey)) return _yellow;
    if (_acreditadosIds.contains(trabajadorKey)) return _green;
    return _green;
  }
  void _navegarARegistro() => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistroTrabajadorScreen())).then((_) => _cargarDatos());
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
      final reqs = await _supabase.from('requisitos_hse').select().order('id', ascending: true);
      final requisitos = List<Map<String, dynamic>>.from(reqs);
      final ids = activos.map((t) => _toInt(t['id'])).whereType<int>().toList();
      final cumplMap = <int, Map<int, Map<String, dynamic>>>{};
      if (ids.isNotEmpty) {
        final cumpl = await _supabase.from('cumplimiento_trabajadores').select().inFilter('trabajador_id', ids);
        for (final c in cumpl) { final tid = _toInt(c['trabajador_id']); final rid = c['requisito_id'] as int; if (tid != null) cumplMap.putIfAbsent(tid, () => {})[rid] = c; }
      }
      final book = excel.Excel.createExcel();
      final sheet = book['Planilla Personal'];
      final headers = ['RUT','Nombre','Apellido Paterno','Apellido Materno','Cargo','Nacionalidad','Venc. Residencia','Sexo','Turno','Contrato', ...requisitos.map((r) => r['nombre_requisito'] as String)];
      sheet.appendRow(headers.map((h) => excel.TextCellValue(h)).toList());
      for (final t in activos) {
        final tid = _toInt(t['id']);
        final cumT = tid != null ? (cumplMap[tid] ?? {}) : {};
        final row = [t['rut'] ?? '', t['nombre'] ?? '', t['apellido_paterno'] ?? '', t['apellido_materno'] ?? '', t['cargo'] ?? '', t['nacionalidad'] ?? '', t['vencimiento_residencia'] ?? '', t['sexo'] ?? '', t['turno'] ?? '', t['contrato_codigo'] ?? '', ...requisitos.map((r) { final rid = r['id'] as int; final c = cumT[rid]; final val = c?['valor_estado'] ?? 'Pendiente'; final fecha = c?['fecha_vencimiento']; return fecha != null ? '$val ($fecha)' : val; })];
        sheet.appendRow(row.map((v) => excel.TextCellValue(v.toString())).toList());
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
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: _bgDark,
      body: isWide
          ? CollapsibleSidebar(
              items: [
                MenuItem(icon: Icons.dashboard_rounded, label: 'Inicio / Dashboard', color: _accentBlue, onTap: () => Navigator.pop(context)),
                MenuItem(icon: Icons.warning_amber_rounded, label: 'Detecciones de Peligro', color: _yellow),
                MenuItem(icon: Icons.route_rounded, label: 'Caminatas de Seguridad', color: _green),
                MenuItem(icon: Icons.assignment_rounded, label: 'Solicitud de Levantamiento', color: _orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SolicitudLevantamientoScreen()))),
                MenuItem(icon: Icons.people_rounded, label: 'Gestionar Personal', color: _green, isActive: true, onTap: () {}),
              ],
              child: _GestionPersonalContent(
                isLoading: _isLoading,
                dotacionOficial: _dotacionOficial,
                acreditadosOk: _acreditadosOk,
                observados: _observados,
                excluidos: _excluidos,
                paginaTrabajadores: _paginaTrabajadores,
                filtroActual: _filtroActual,
                currentPage: _currentPage,
                totalPaginas: _totalPaginas,
                onSearchChanged: updateSearchQuery,
                onSetFiltro: setFiltro,
                onPageChanged: changePage,
                onAgregarTrabajador: _navegarARegistro,
                onVerTrabajador: _abrirEdicion,
                onExportarPlanilla: _exportarPlanilla,
                nombreCompleto: _nombreCompleto,
                estadoActivacion: _estadoActivacion,
                colorEstado: _colorEstado,
              ),
            )
          : _GestionPersonalContent(
              isLoading: _isLoading,
              dotacionOficial: _dotacionOficial,
              acreditadosOk: _acreditadosOk,
              observados: _observados,
              excluidos: _excluidos,
              paginaTrabajadores: _paginaTrabajadores,
              filtroActual: _filtroActual,
              currentPage: _currentPage,
              totalPaginas: _totalPaginas,
              onSearchChanged: updateSearchQuery,
              onSetFiltro: setFiltro,
              onPageChanged: changePage,
              onAgregarTrabajador: _navegarARegistro,
              onVerTrabajador: _abrirEdicion,
              onExportarPlanilla: _exportarPlanilla,
              nombreCompleto: _nombreCompleto,
              estadoActivacion: _estadoActivacion,
              colorEstado: _colorEstado,
            ),
    );
  }
}

class _DatosBrutos { final List<Map<String, dynamic>> trabajadores; final List<Map<String, dynamic>> cumplimiento; final List<Map<String, dynamic>> requisitos; const _DatosBrutos({required this.trabajadores, required this.cumplimiento, required this.requisitos}); }
class DatosProcesados { final List<Map<String, dynamic>> trabajadores; final List<Map<String, dynamic>> cumplimiento; final Map<String, List<String>> cumplimientoIndex; final Set<String> acreditadosIds; final Set<String> observadosIds; final int dotacionOficial; final int acreditadosOk; final int observados; final int excluidos; const DatosProcesados({required this.trabajadores, required this.cumplimiento, required this.cumplimientoIndex, required this.acreditadosIds, required this.observadosIds, required this.dotacionOficial, required this.acreditadosOk, required this.observados, required this.excluidos}); }

class _GestionPersonalContent extends StatelessWidget {
  final bool isLoading; final int dotacionOficial; final int acreditadosOk; final int observados; final int excluidos; final List<Map<String, dynamic>> paginaTrabajadores; final _FiltroTrabajadores filtroActual; final int currentPage; final int totalPaginas; final ValueChanged<String> onSearchChanged; final ValueChanged<_FiltroTrabajadores> onSetFiltro; final ValueChanged<int> onPageChanged; final VoidCallback onAgregarTrabajador; final ValueChanged<Map<String, dynamic>> onVerTrabajador; final VoidCallback onExportarPlanilla; final String Function(Map<String, dynamic>) nombreCompleto; final String Function(Map<String, dynamic>) estadoActivacion; final Color Function(Map<String, dynamic>) colorEstado;
  const _GestionPersonalContent({required this.isLoading, required this.dotacionOficial, required this.acreditadosOk, required this.observados, required this.excluidos, required this.paginaTrabajadores, required this.filtroActual, required this.currentPage, required this.totalPaginas, required this.onSearchChanged, required this.onSetFiltro, required this.onPageChanged, required this.onAgregarTrabajador, required this.onVerTrabajador, required this.onExportarPlanilla, required this.nombreCompleto, required this.estadoActivacion, required this.colorEstado});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Column(
      children: [
        const _GestionHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 0, isWide ? 24 : 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _KpiDashboardRow(dotacionOficial: dotacionOficial, acreditadosOk: acreditadosOk, observados: observados, excluidos: excluidos),
                const SizedBox(height: 20),
                _SearchAndAddRow(onSearchChanged: onSearchChanged, onAgregarTrabajador: onAgregarTrabajador, onExportarPlanilla: onExportarPlanilla),
                const SizedBox(height: 16),
                _StatusFilters(filtroActual: filtroActual, onSetFiltro: onSetFiltro),
                const SizedBox(height: 16),
                _TrabajadoresTable(isLoading: isLoading, trabajadores: paginaTrabajadores, currentPage: currentPage, totalPaginas: totalPaginas, onPageChanged: onPageChanged, onVerTrabajador: onVerTrabajador, nombreCompleto: nombreCompleto, estadoActivacion: estadoActivacion, colorEstado: colorEstado),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GestionHeader extends StatelessWidget {
  const _GestionHeader();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _divider, width: 1))),
    child: Row(
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Contrato: CON-1024-SQM', style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text('Gestion de Personal', style: TextStyle(color: _textSecondary, fontSize: 12)),
        ]),
        Spacer(),
        _HeaderBadge(icon: Icons.check_circle_rounded, label: 'Activo', color: _green),
        SizedBox(width: 12),
        _HeaderBadge(icon: Icons.notifications_none_rounded, label: '3', color: _yellow),
        SizedBox(width: 12),
        Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(8)), child: Row(children: const [Icon(Icons.calendar_today_rounded, color: _textMuted, size: 14), SizedBox(width: 6), Text('14 Jun 2026', style: TextStyle(color: _textSecondary, fontSize: 12))])),
        SizedBox(width: 12),
        CircleAvatar(radius: 18, backgroundColor: _orange, child: Icon(Icons.person, color: Colors.white, size: 20)),
      ],
    ),
  );
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _HeaderBadge({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 16), SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))]),
  );
}

class _KpiDashboardRow extends StatelessWidget {
  final int dotacionOficial; final int acreditadosOk; final int observados; final int excluidos;
  const _KpiDashboardRow({required this.dotacionOficial, required this.acreditadosOk, required this.observados, required this.excluidos});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final kpis = [
        _KpiData(title: 'Dotacion Oficial', value: '$dotacionOficial', color: Color(0xFF42A5F5), icon: Icons.people_rounded, subtitle: 'Total trabajadores'),
        _KpiData(title: 'Acreditados OK', value: '$acreditadosOk', color: _green, icon: Icons.verified_rounded, subtitle: 'Acreditacion valida'),
        _KpiData(title: 'Observados', value: '$observados', color: _yellow, icon: Icons.warning_rounded, subtitle: 'Examenes vencidos'),
        _KpiData(title: 'Excluidos (Baja)', value: '$excluidos', color: _red, icon: Icons.person_off_rounded, subtitle: 'Inactivos / Desvinculados'),
      ];
      if (isMobile) return Wrap(spacing: 10, runSpacing: 10, children: kpis.map((kpi) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: _KpiCard(title: kpi.title, value: kpi.value, color: kpi.color, icon: kpi.icon, subtitle: kpi.subtitle))).toList());
      return Row(children: kpis.map((kpi) => Expanded(child: Padding(padding: EdgeInsets.only(left: kpis.first == kpi ? 0 : 14, right: kpis.last == kpi ? 0 : 0), child: _KpiCard(title: kpi.title, value: kpi.value, color: kpi.color, icon: kpi.icon, subtitle: kpi.subtitle)))).toList());
    },
  );
}

class _KpiData { final String title; final String value; final Color color; final IconData icon; final String subtitle; const _KpiData({required this.title, required this.value, required this.color, required this.icon, required this.subtitle}); }
class _KpiCard extends StatelessWidget {
  final String title; final String value; final Color color; final IconData icon; final String subtitle;
  const _KpiCard({required this.title, required this.value, required this.color, required this.icon, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(18),
    decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder, width: 0.5), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)), Spacer(), Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold))]),
      SizedBox(height: 8), Text(title, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      SizedBox(height: 4), Text(subtitle, style: TextStyle(color: _textMuted, fontSize: 11)),
    ]),
  );
}

class _SearchAndAddRow extends StatelessWidget {
  final ValueChanged<String> onSearchChanged; final VoidCallback onAgregarTrabajador; final VoidCallback onExportarPlanilla;
  const _SearchAndAddRow({required this.onSearchChanged, required this.onAgregarTrabajador, required this.onExportarPlanilla});
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isMobile) return Column(children: [_buildSearchBar(onSearchChanged), SizedBox(height: 12), SizedBox(width: double.infinity, child: _buildAddButton(onAgregarTrabajador)), SizedBox(height: 8), SizedBox(width: double.infinity, child: _buildExportButton(onExportarPlanilla))]);
    return Row(children: [Expanded(child: _buildSearchBar(onSearchChanged)), SizedBox(width: 16), _buildAddButton(onAgregarTrabajador), SizedBox(width: 8), _buildExportButton(onExportarPlanilla)]);
  }
  Widget _buildSearchBar(ValueChanged<String> onChanged) => Container(
    height: 44,
    decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: _cardBorder, width: 0.5)),
    child: TextField(onChanged: onChanged, style: TextStyle(color: _textPrimary, fontSize: 13), decoration: InputDecoration(hintText: 'Buscar por Nombre, RUT, Cargo...', hintStyle: TextStyle(color: _textMuted, fontSize: 13), prefixIcon: Icon(Icons.search_rounded, color: _textMuted, size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12))),
  );
  Widget _buildAddButton(VoidCallback onPressed) => Container(
    height: 44,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: LinearGradient(colors: [_orange, Color(0xFFE65100)])),
    child: ElevatedButton.icon(onPressed: onPressed, icon: Icon(Icons.person_add_alt_rounded, size: 18), label: Text('Agregar Trabajador', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(horizontal: 20))),
  );
  Widget _buildExportButton(VoidCallback onPressed) => Container(
    height: 44,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: LinearGradient(colors: [_accentBlue, Color(0xFF0D47A1)])),
    child: ElevatedButton.icon(onPressed: onPressed, icon: Icon(Icons.file_download_rounded, size: 18), label: Text('Descargar Planilla', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.symmetric(horizontal: 16))),
  );
}

class _StatusFilters extends StatelessWidget {
  final _FiltroTrabajadores filtroActual; final ValueChanged<_FiltroTrabajadores> onSetFiltro;
  const _StatusFilters({required this.filtroActual, required this.onSetFiltro});

  @override
  Widget build(BuildContext context) {
    final items = [
      _FilterButton(label: 'Habilitados', icon: Icons.verified_rounded, color: _green, isSelected: filtroActual == _FiltroTrabajadores.habilitados, onTap: () => onSetFiltro(_FiltroTrabajadores.habilitados)),
      _FilterButton(label: 'Observados', icon: Icons.warning_rounded, color: _yellow, isSelected: filtroActual == _FiltroTrabajadores.observados, onTap: () => onSetFiltro(_FiltroTrabajadores.observados)),
      _FilterButton(label: 'Inactivos', icon: Icons.person_off_rounded, color: _red, isSelected: filtroActual == _FiltroTrabajadores.inactivos, onTap: () => onSetFiltro(_FiltroTrabajadores.inactivos)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: items,
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label; final IconData icon; final Color color; final bool isSelected; final VoidCallback onTap;
  const _FilterButton({required this.label, required this.icon, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : _cardDark,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? color.withValues(alpha: 0.7) : _cardBorder.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : _textMuted, size: 17),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? color : _textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TrabajadoresTable extends StatelessWidget {
  final bool isLoading; final List<Map<String, dynamic>> trabajadores; final int currentPage; final int totalPaginas; final ValueChanged<int> onPageChanged; final ValueChanged<Map<String, dynamic>> onVerTrabajador; final String Function(Map<String, dynamic>) nombreCompleto; final String Function(Map<String, dynamic>) estadoActivacion; final Color Function(Map<String, dynamic>) colorEstado;
  const _TrabajadoresTable({required this.isLoading, required this.trabajadores, required this.currentPage, required this.totalPaginas, required this.onPageChanged, required this.onVerTrabajador, required this.nombreCompleto, required this.estadoActivacion, required this.colorEstado});
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    if (isLoading) return Container(padding: EdgeInsets.all(40), decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder, width: 0.5)), child: Center(child: CircularProgressIndicator(color: _orange)));
    if (trabajadores.isEmpty) return Container(padding: EdgeInsets.all(40), decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder, width: 0.5)), child: Center(child: Column(children: [Icon(Icons.search_off_rounded, color: _textMuted, size: 48), SizedBox(height: 12), Text('No se encontraron trabajadores', style: TextStyle(color: _textSecondary, fontSize: 14))])));
    final content = isMobile ? _buildMobileList(trabajadores, nombreCompleto, estadoActivacion, colorEstado, onVerTrabajador) : _buildWebTable(trabajadores, nombreCompleto, estadoActivacion, colorEstado, onVerTrabajador);
    return Column(children: [content, SizedBox(height: 16), _PaginationControls(currentPage: currentPage, totalPaginas: totalPaginas, onPageChanged: onPageChanged)]);
  }
  Widget _buildWebTable(List<Map<String, dynamic>> lista, String Function(Map<String, dynamic>) nombreCompletoFn, String Function(Map<String, dynamic>) estadoActivacionFn, Color Function(Map<String, dynamic>) colorEstadoFn, ValueChanged<Map<String, dynamic>> onVerTrabajadorFn) => Container(
    decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder, width: 0.5)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(_accentBlue.withValues(alpha: 0.3)),
          dataRowColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? _accentBlue.withValues(alpha: 0.15) : Colors.transparent),
          dividerThickness: 0.5,
          columns: [
            DataColumn(label: _TableHeaderText('Nombre Completo')),
            DataColumn(label: _TableHeaderText('RUT')),
            DataColumn(label: _TableHeaderText('Cargo')),
            DataColumn(label: _TableHeaderText('Estado Activacion')),
          ],
          rows: lista.map((t) {
            final estado = estadoActivacionFn(t);
            final colorEstado = colorEstadoFn(t);
            return DataRow(
              onSelectChanged: (_) => onVerTrabajadorFn(t),
              cells: [
                DataCell(Text(nombreCompleto(t), style: TextStyle(color: _textPrimary, fontSize: 13))),
                DataCell(Text(t['rut'] ?? '', style: TextStyle(color: _textSecondary, fontSize: 13))),
                DataCell(Text(t['cargo'] ?? '', style: TextStyle(color: _textSecondary, fontSize: 13))),
                DataCell(Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: colorEstado.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: colorEstado.withValues(alpha: 0.3), width: 0.5)), child: Text(estado, style: TextStyle(color: colorEstado, fontSize: 12, fontWeight: FontWeight.w600)))),
              ],
            );
          }).toList(),
        ),
      ),
    ),
  );
  Widget _buildMobileList(List<Map<String, dynamic>> lista, String Function(Map<String, dynamic>) nombreCompleto, String Function(Map<String, dynamic>) estadoActivacionFn, Color Function(Map<String, dynamic>) colorEstadoFn, ValueChanged<Map<String, dynamic>> onVerTrabajadorFn) => ListView.builder(
    shrinkWrap: true, physics: NeverScrollableScrollPhysics(), itemCount: lista.length,
    itemBuilder: (context, index) {
      final t = lista[index]; final estado = estadoActivacionFn(t); final colorEstado = colorEstadoFn(t);
      return InkWell(
        onTap: () => onVerTrabajadorFn(t),
        child: Container(
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder, width: 0.5)),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nombreCompleto(t), style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w500)), SizedBox(height: 4), Text('${t['rut'] ?? ''} - ${t['cargo'] ?? ''}', style: TextStyle(color: _textMuted, fontSize: 11))])),
              Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: colorEstado.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: colorEstado.withValues(alpha: 0.3), width: 0.5)), child: Text(estado, style: TextStyle(color: colorEstado, fontSize: 11, fontWeight: FontWeight.w600))),
              SizedBox(width: 10),
              Icon(Icons.edit_rounded, color: _accentBlue, size: 20),
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
    if (totalPaginas <= 1) return SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: _cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cardBorder, width: 0.5)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(onTap: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null, child: Container(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: currentPage > 1 ? _accentBlue.withValues(alpha: 0.4) : _cardBorder.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(Icons.chevron_left_rounded, color: currentPage > 1 ? _textPrimary : _textMuted, size: 18), SizedBox(width: 4), Text('Anterior', style: TextStyle(color: currentPage > 1 ? _textPrimary : _textMuted, fontSize: 13, fontWeight: FontWeight.w500))]))),
        Container(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: _accentBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: _cardBorder, width: 0.5)), child: Text('$currentPage / $totalPaginas', style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
        GestureDetector(onTap: currentPage < totalPaginas ? () => onPageChanged(currentPage + 1) : null, child: Container(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: currentPage < totalPaginas ? _accentBlue.withValues(alpha: 0.4) : _cardBorder.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)), child: Row(children: [Text('Siguiente', style: TextStyle(color: currentPage < totalPaginas ? _textPrimary : _textMuted, fontSize: 13, fontWeight: FontWeight.w500)), SizedBox(width: 4), Icon(Icons.chevron_right_rounded, color: currentPage < totalPaginas ? _textPrimary : _textMuted, size: 18)]))),
      ]),
    );
  }
}

class _TableHeaderText extends StatelessWidget { final String text; const _TableHeaderText(this.text); @override Widget build(BuildContext context) => Text(text, style: TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w600)); }