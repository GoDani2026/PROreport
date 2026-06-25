import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/trabajador_service.dart';
import '../services/exceptions.dart';

class RegistroTrabajadorScreen extends StatefulWidget {
  final Map<String, dynamic>? trabajadorEdit;

  const RegistroTrabajadorScreen({super.key, this.trabajadorEdit});

  @override
  State<RegistroTrabajadorScreen> createState() => _RegistroTrabajadorScreenState();
}

class _RegistroTrabajadorScreenState extends State<RegistroTrabajadorScreen> {
  final _service = TrabajadorService();

  // Controladores para campos del Paso 1 (trabajador)
  final _rutController = TextEditingController();
  final _nombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _cargoController = TextEditingController();
  final _nacionalidadController = TextEditingController(text: 'Chilena');
  final _vencimientoResidenciaController = TextEditingController();
  final _turnoController = TextEditingController();
  final _contratoCodigoController = TextEditingController();

  // Selecciones para campos cerrados
  String? _sexoSeleccionado;
  String? _estadoSeleccionado;

  // Lista de requisitos HSE (Paso 2)
  List<Map<String, dynamic>> _requisitos = [];
  bool _isLoadingRequisitos = true;

  // Datos del cumplimiento por requisito
  final List<Map<String, dynamic>> _cumplimientoData = [];

  // Estados de carga
  bool _isGuardando = false;

  // Ruta actual del stepper
  int _pasoActual = 0;

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
    if (widget.trabajadorEdit != null) {
      final t = widget.trabajadorEdit!;
      _rutController.text = t['rut'] ?? '';
      _nombreController.text = t['nombre'] ?? '';
      _apellidoPaternoController.text = t['apellido_paterno'] ?? '';
      _apellidoMaternoController.text = t['apellido_materno'] ?? '';
      _cargoController.text = t['cargo'] ?? '';
      _nacionalidadController.text = t['nacionalidad'] ?? 'Chilena';
      _vencimientoResidenciaController.text = t['fecha_vencimiento_residencia'] ?? '';
      _turnoController.text = t['turno'] ?? '';
      _estadoSeleccionado = t['estado_trabajador'] ?? 'ACTIVO';
      _contratoCodigoController.text = t['contrato_codigo'] ?? '';
      _sexoSeleccionado = t['sexo'] ?? 'M';
    }
  }

  Future<void> _cargarRequisitosHSE() async {
    try {
      final response = await _service.fetchRequisitosHSE();

      if (mounted) {
        // Verificar que existan requisitos
        if (response.isEmpty) {
          setState(() => _isLoadingRequisitos = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error: No hay requisitos HSE configurados. '
                'Contacte al administrador para ejecutar el script SQL inicial.'
              ),
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }

        setState(() {
          _requisitos = List<Map<String, dynamic>>.from(response);
          // Inicializar estructura de cumplimiento
          _cumplimientoData.clear();
          for (var req in _requisitos) {
            _cumplimientoData.add({
              'requisito_id': req['id'],
              'valor_estado': 'N/A',
              'fecha_vencimiento': null,
              'documento_url': null,
              'requiere_vencimiento': req['requiere_vencimiento'],
            });
          }
          _isLoadingRequisitos = false;
        });

        // Si estamos editando, cargar el cumplimiento existente
        if (widget.trabajadorEdit != null) {
          await _cargarCumplimientoExistente();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRequisitos = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar requisitos: $e')),
        );
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
            final index = _cumplimientoData.indexWhere(
              (item) => item['requisito_id'] == cum['requisito_id'],
            );
            if (index != -1) {
              _cumplimientoData[index] = {
                'requisito_id': cum['requisito_id'],
                'valor_estado': cum['valor_estado'] ?? 'N/A',
                'fecha_vencimiento': cum['fecha_vencimiento'],
                'documento_url': cum['documento_url'],
                'requiere_vencimiento':
                    _requisitos.firstWhere(
                      (r) => r['id'] == cum['requisito_id'],
                      orElse: () => {'requiere_vencimiento': false},
                    )['requiere_vencimiento'],
              };
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar cumplimiento: $e');
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
        const SnackBar(content: Text('Complete todos los campos obligatorios del Paso 1')),
      );
      return;
    }

    setState(() => _isGuardando = true);

    try {
      final Map<String, dynamic> trabajadorData = {
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
        'sexo': _sexoSeleccionado,
        'turno': _turnoController.text.trim(),
        'estado_trabajador': _estadoSeleccionado,
        'contrato_codigo': _contratoCodigoController.text.trim(),
      };

      // En edición, incluir el ID existente
      if (widget.trabajadorEdit != null) {
        final editId = _toInt(widget.trabajadorEdit!['id']);
        if (editId != null) {
          trabajadorData['id'] = editId;
        }
      }

      // Guardar atómicamente usando RPC (trabajador + cumplimientos en una tx)
      final cumplimientos = _cumplimientoData.map((item) => {
        'requisito_id': item['requisito_id'],
        'valor_estado': item['valor_estado'],
        'fecha_vencimiento': item['fecha_vencimiento'],
        'documento_url': item['documento_url'],
      }).toList();

      await _service.guardarTrabajadorCompleto(
        datosTrabajador: trabajadorData,
        cumplimientos: cumplimientos,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trabajador guardado exitosamente')),
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
        setState(() => _isGuardando = false);
      }
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.isNotEmpty) return int.tryParse(value);
    return null;
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

  void _actualizarEstadoRequisito(int index, {String? fecha, bool esNoAplica = false}) {
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

  Future<void> _seleccionarFecha(int index) async {
    final fechaInicial = _cumplimientoData[index]['fecha_vencimiento'] != null
        ? DateTime.parse(_cumplimientoData[index]['fecha_vencimiento'])
        : DateTime.now();

    final fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'CL'),
    );

    if (fechaSeleccionada != null) {
      _actualizarEstadoRequisito(index, fecha: fechaSeleccionada.toIso8601String().split('T')[0]);
    }
  }

  /// Selector unificado: botones N/A y Fecha siempre visibles (toggle).
  Widget _buildSelectorFechaYNA(int index, String? fecha, String estadoActual) {
    final esNoAplica = estadoActual == 'N/A';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => _actualizarEstadoRequisito(index, esNoAplica: !esNoAplica),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: esNoAplica ? Colors.orange.withValues(alpha: 0.25) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: esNoAplica ? Colors.orange.withValues(alpha: 0.8) : Colors.grey, width: esNoAplica ? 1.5 : 1),
          ),
          child: Text('N/A', style: TextStyle(
            color: esNoAplica ? Colors.orange : Colors.grey,
            fontSize: 11, fontWeight: esNoAplica ? FontWeight.w700 : FontWeight.w600,
          )),
        ),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: () => _seleccionarFecha(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: esNoAplica ? Colors.grey.shade100 : Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: esNoAplica ? Colors.grey : Colors.blue.withValues(alpha: 0.5), width: esNoAplica ? 0.5 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(esNoAplica ? 'Sin fecha' : (fecha ?? 'Seleccionar'), style: TextStyle(color: esNoAplica ? Colors.grey : Colors.black87, fontSize: 11)),
            const SizedBox(width: 4),
            Icon(Icons.calendar_today, color: esNoAplica ? Colors.grey : Colors.blue, size: 14),
          ]),
        ),
      ),
    ]);
  }

  /// Badge de estado coloreado (informativo)
  Widget _buildBadgeEstado(String estado) {
    final color = estado == 'VIGENTE' ? Colors.green : (estado == 'VENCIDO' ? Colors.red : Colors.orange);
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

  Future<void> _subirDocumento(int index) async {
    // Funcionalidad pendiente: usar _service para subir documentos
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subida de documentos próximamente')),
    );
  }

  Widget _construirPaso1() {
    final anchoPantalla = MediaQuery.of(context).size.width;
    final esTablet = anchoPantalla > 600;
    final camposAncho = esTablet ? 400.0 : double.infinity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: camposAncho),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // RUT
              TextFormField(
                controller: _rutController,
                decoration: const InputDecoration(
                  labelText: 'RUT *',
                  hintText: '12345678-9',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9kK-]')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'RUT obligatorio';
                  if (!RegExp(r'^\d{7,8}-[\dkK]$').hasMatch(value)) {
                    return 'Formato inválido (ej: 12345678-9)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fila: Nombre + Apellido Paterno
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _apellidoPaternoController,
                      decoration: const InputDecoration(
                        labelText: 'Apellido Paterno *',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Apellido Materno
              TextFormField(
                controller: _apellidoMaternoController,
                decoration: const InputDecoration(
                  labelText: 'Apellido Materno',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Cargo
              TextFormField(
                controller: _cargoController,
                decoration: const InputDecoration(
                  labelText: 'Cargo *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Nacionalidad
              TextFormField(
                controller: _nacionalidadController,
                decoration: const InputDecoration(
                  labelText: 'Nacionalidad',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Vencimiento Residencia
              TextFormField(
                controller: _vencimientoResidenciaController,
                decoration: const InputDecoration(
                  labelText: 'Vencimiento Residencia',
                  hintText: 'PERMANENCIA DEFINITIVA o fecha',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Fila: Sexo + Turno
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sexoSeleccionado ??
                          (widget.trabajadorEdit?['sexo'] ?? 'M'),
                      decoration: const InputDecoration(
                        labelText: 'Sexo *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('Masculino')),
                        DropdownMenuItem(value: 'F', child: Text('Femenino')),
                        DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                      ],
                      onChanged: (value) {
                        setState(() => _sexoSeleccionado = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _turnoController,
                      decoration: const InputDecoration(
                        labelText: 'Turno *',
                        hintText: '39 o 7x7',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Estado Trabajador
              DropdownButtonFormField<String>(
                initialValue: _estadoSeleccionado ?? 'ACTIVO',
                decoration: const InputDecoration(
                  labelText: 'Estado Trabajador *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ACTIVO', child: Text('ACTIVO')),
                  DropdownMenuItem(
                      value: 'DESVINCULADO', child: Text('DESVINCULADO')),
                  DropdownMenuItem(value: 'LICENCIA', child: Text('LICENCIA')),
                ],
                onChanged: (value) {
                  setState(() => _estadoSeleccionado = value);
                },
              ),
              const SizedBox(height: 16),

              // Código de Contrato
              TextFormField(
                controller: _contratoCodigoController,
                decoration: const InputDecoration(
                  labelText: 'Código Contrato *',
                  hintText: 'CON-1024-SQM',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirPaso2() {
    if (_isLoadingRequisitos) {
      return const Center(child: CircularProgressIndicator());
    }

    final anchoPantalla = MediaQuery.of(context).size.width;
    final esTablet = anchoPantalla > 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: esTablet
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 900),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Requisito HSE')),
                    DataColumn(label: Text('Fecha / N/A')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Documento')),
                  ],
                  rows: _requisitos.asMap().entries.map((entry) {
                    final index = entry.key;
                    final requisito = entry.value;
                    final cum = _cumplimientoData[index];
                    final estadoSeleccionado = cum['valor_estado'] ?? 'N/A';
                    final fecha = cum['fecha_vencimiento'] as String?;

                    return DataRow(cells: [
                      DataCell(
                        SizedBox(
                          width: 300,
                          child: Text(
                            requisito['nombre_requisito'],
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      DataCell(
                        _buildSelectorFechaYNA(index, fecha, estadoSeleccionado),
                      ),
                      DataCell(
                        _buildBadgeEstado(estadoSeleccionado),
                      ),
                      DataCell(
                        IconButton(
                          icon: Icon(
                            Icons.picture_as_pdf,
                            color: cum['documento_url'] != null
                                ? Colors.green
                                : Colors.grey,
                          ),
                          tooltip: cum['documento_url'] != null
                              ? 'Documento cargado'
                              : 'Subir documento',
                          onPressed: () => _subirDocumento(index),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _requisitos.length,
              itemBuilder: (context, index) {
                final requisito = _requisitos[index];
                final cum = _cumplimientoData[index];
                final estadoSeleccionado = cum['valor_estado'] ?? 'N/A';
                final fecha = cum['fecha_vencimiento'] as String?;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requisito['nombre_requisito'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSelectorFechaYNA(index, fecha, estadoSeleccionado),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildBadgeEstado(estadoSeleccionado),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: Icon(
                                Icons.picture_as_pdf,
                                color: cum['documento_url'] != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              tooltip: cum['documento_url'] != null
                                  ? 'Documento cargado'
                                  : 'Subir documento',
                              onPressed: () => _subirDocumento(index),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _pasoActual == step;
    final isCompleted = _pasoActual > step;
    final Color circleColor;
    if (isCompleted) {
      circleColor = Colors.green;
    } else if (isActive) {
      circleColor = Colors.blue;
    } else {
      circleColor = Colors.grey.shade300;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.blue : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trabajadorEdit != null
            ? 'Editar Trabajador'
            : 'Registrar Trabajador'),
      ),
      body: Column(
        children: [
          // Indicador de pasos manual (evita problemas de layout del Stepper nativo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                _buildStepIndicator(0, 'Datos\nTrabajador'),
                Expanded(child: Container(height: 2, color: _pasoActual >= 1 ? Colors.blue : Colors.grey.shade300)),
                _buildStepIndicator(1, 'Requisitos\nHSE'),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          // Contenido del paso actual en el espacio restante
          Expanded(
            child: _pasoActual == 0
                ? _construirPaso1()
                : _construirPaso2(),
          ),
          // Barra inferior fija de navegación
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_pasoActual > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isGuardando
                          ? null
                          : () => setState(() => _pasoActual--),
                      child: const Text('Atrás'),
                    ),
                  ),
                if (_pasoActual > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isGuardando
                        ? null
                        : () {
                            if (_pasoActual < 1) {
                              setState(() => _pasoActual++);
                            } else {
                              _guardarTrabajador();
                            }
                          },
                    icon: _isGuardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _pasoActual == 1 ? Icons.save : Icons.arrow_forward,
                            size: 20,
                          ),
                    label: Text(_pasoActual == 1 ? 'Guardar' : 'Siguiente'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
