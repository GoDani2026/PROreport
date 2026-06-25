# Registro de versiones y novedades

## Flujo de trabajo
1. Revisar correcciones y mejoras
2. Desarrollar la tarea
3. Probar mejora
4. Registrar mejoras o errores capturados
5. Subir a git


## [V0.5.5] - 2026-06-22

### Funcionalidades y mejoras
- **Arquitectura desacoplada (Patrón Repository)**: Creada capa de servicios `TrabajadorService` (`lib/services/trabajador_service.dart`). Ninguna pantalla importa `supabase_flutter` directamente; todas las operaciones de datos se realizan a través del servicio.
- **Carga masiva atómica vía RPC**: Eliminado el bucle HTTP con `service_role_key`. Ahora la carga masiva usa la función PostgreSQL `upsert_trabajadores_lote`, que procesa el lote completo en una transacción ACID sin condiciones de carrera.
- **Guardado atómico por trabajador**: La función RPC `upsert_trabajador_completo` captura el `RETURNING id` y upserta los cumplimientos en la misma transacción, eliminando el desfase de llaves foráneas.
- **Excepciones tipadas**: Nuevo archivo `lib/services/exceptions.dart` con 7 excepciones específicas: `ServiceException`, `DuplicateEntryException`, `NotFoundException`, `ValidationException`, `NetworkException`, `RpcException`, `DatabaseException`.

### Correcciones
- **Desfase de IDs en carga masiva (crítico)**: El servicio anterior generaba un `POST /trabajadores` batch sin IDs, luego un `GET` para recuperarlos — condicion de carrera donde el filtro `contrato_codigo` devolvía IDs mezclados entre tandas. Eliminado completamente.
- **Eliminado acoplamiento de Supabase en pantallas**: `registro_trabajador_screen`, `editar_trabajador_screen`, `registro_hse_personal_screen`, `gestion_personal_screen` y `carga_masiva_screen` ya no usan `Supabase.instance.client`.
- **BulkUploadService legacy migrado**: `lib/services/bulk_upload_service.dart` ahora es un wrapper delgado sobre `TrabajadorService.cargaMasivaAtomica()`.
- Unificacion de secretos en .env

### Archivos nuevos
- `lib/services/exceptions.dart` — Excepciones tipadas
- `lib/services/trabajador_service.dart` — Capa de servicios
- `lib/services/bulk_upload_service.dart` — Wrapper legacy
- `sql/06_rpc_upsert_trabajador_completo.sql` — Funciones RPC PostgreSQL
- `scripts/deploy_rpc.py` — Deploy de RPC
- `scripts/verificar_rpc.py` — Verificación de RPC
- `scripts/env.py` — Loader de variables de entorno
- `.env` — Secrets de Supabase (no versionado)

### Archivos modificados
- `lib/screens/carga_masiva_screen.dart`
- `lib/screens/registro_trabajador_screen.dart`
- `lib/screens/editar_trabajador_screen.dart`
- `lib/screens/registro_hse_personal_screen.dart`
- `lib/screens/gestion_personal_screen.dart`

---

## [V0.5.4] - 2026-06-21

### Correcciones
- **IDs huérfanos en cumplimiento_trabajadores**: Se detectó que la tabla `cumplimiento_trabajadores` tenía registros con `trabajador_id` que no coincidían con ningún `id` de la tabla `trabajadores` (trabajadores empiezan en 731, cumplimiento en 772). Se creó `sql/05_fix_cumplimiento_orphans.sql` para diagnosticar y eliminar registros huérfanos en Supabase.

### Archivos modificados
- `sql/05_fix_cumplimiento_orphans.sql` — Script de diagnóstico y corrección de FK huérfanas



---

## [V0.5.3] - 2026-06-21

### Correcciones
- **Fecha de vencimiento no se mostraba en trabajadores habilitados**: En `EditarTrabajadorScreen._loadRequisitos()`, cuando un requisito no tenía registro previo en `cumplimiento_trabajadores` (caso común en trabajadores sin observaciones recién cargados), el fallback forzaba `N/A` para todos. Ahora se usa `VIGENTE` como fallback para requisitos con `requiere_vencimiento=true`, permitiendo que la fecha ingresada se refleje correctamente. Los trabajadores con observaciones siguen mostrando sus fechas ya que sus registros de cumplimiento sí existen. Se agregó debug logging para diagnosticar diferencias entre observados y habilitados.
- **fecha_vencimiento excluida del dashboard**: Agregada `fecha_vencimiento` al SELECT de cumplimiento en `GestionPersonalScreen._cargarDatos()` para mantener consistencia entre pantallas.

### Archivos modificados
- `lib/screens/editar_trabajador_screen.dart` — Fallback inteligente en `_loadRequisitos` según `requiere_vencimiento` + debug logging
- `lib/screens/gestion_personal_screen.dart` — Incluida `fecha_vencimiento` en consulta de cumplimiento

---

## [V0.5.2] - 2026-06-21

### Funcionalidades y mejoras
- **Selector Fecha/N/A unificado en 3 pantallas**: En `EditarTrabajadorScreen`, `RegistroTrabajadorScreen` y `RegistroHSEPersonalScreen` se reemplazó el dropdown de estado por un selector de dos botones siempre visibles: **N/A** y **Fecha**. El estado VIGENTE/VENCIDO se calcula automáticamente desde la fecha seleccionada.
- **Toggle libre entre N/A y fecha**: Al seleccionar N/A, el usuario puede volver a elegir fecha tocando el botón de fecha (que muestra "Sin fecha" como alternativa). No hay estado irreversible.
- **Columnas reorganizadas en tabla de requisitos**: Se invirtió el orden de columnas de la tabla HSE de `ESTADO → FECHA` a `FECHA/N/A → ESTADO`, dejando el estado como badge informativo de solo lectura.
- **Centrado de contenido en edición**: `EditarTrabajadorScreen` ahora envuelve el contenido en `Center + ConstrainedBox(maxWidth: 1100)` para una presentación equilibrada en pantallas web anchas.

### Correcciones
- **RUT con comas en carga masiva**: La validación ya no marca en rojo filas con RUTs formateados con comas (ej: `201,261,406`); se formatean automáticamente a puntos antes de validar.
- **Warnings de análisis estático en pantallas modificadas**: Eliminados campo `_estadosRequisito` no usado, variables locales sin usar y parámetros de constructor obsoletos.

### Archivos modificados
- `lib/screens/editar_trabajador_screen.dart` — Selector unificado, centrado web, cálculo automático de estado
- `lib/screens/registro_trabajador_screen.dart` — Selector unificado, cálculo automático de estado
- `lib/screens/registro_hse_personal_screen.dart` — Selector unificado, cálculo automático de estado
- `lib/screens/carga_masiva_screen.dart` — Formateo previo de RUT con comas, llaves faltantes en if
- `lib/screens/gestion_personal_screen.dart` — Limpieza de parámetro `onCargaMasiva` no usado


---

## [V0.5.1] - 2026-06-21

### Funcionalidades y mejoras
- **Carga Masiva de Personal**: Pantalla completa `CargaMasivaScreen` con flujo de 3 pasos (Seleccionar archivo → Validar y corregir → Confirmar cambios). Soporta archivos CSV y XLSX con detección automática de cabecera (busca "RUT" en filas con ≥10 columnas, saltando metadata).
- **Parseo posicional de columnas**: En lugar de matchear por nombre de cabecera, se usa el orden fijo del CSV oficial (col 0: N°, 1: Nombre, 2: Ap. Paterno, 3: Ap. Materno, 4: RUT, 5-9: datos personales, 10-21: 12 requisitos HSE).
- **Requisitos HSE desde archivo**: Los 12 requisitos (4 con fecha de vencimiento + 8 con SI/N/A) se parsean automáticamente: fechas → VIGENTE/VENCIDO según la fecha actual, "SI"/"SÍ" → VIGENTE, "NO"/"N/A" → N/A, otros textos → VENCIDO.
- **Normalización de RUT**: Función `_formatearRut()` que convierte cualquier entrada (con/sin puntos, con/sin guión) a formato estándar `12.345.678-9` automáticamente.
- **Filtro de datos válidos**: `_esFilaDatos()` detecta y descarta filas de footer/firma (FIRMA, OBSERVACIONES, TOTAL, etc.), procesando solo filas con RUT válido.
- **Validación por longitud de RUT**: Se eliminó la dependencia del algoritmo de dígito verificador; ahora valida solo por cantidad de caracteres (≥8 dígitos) para máxima compatibilidad con datos de planilla.
- **Tabla comparativa Excel-like**: En paso 2 se muestra una `DataTable` con 25 columnas (13 datos personales + 12 HSE), con colores por fila (verde=nuevo, amarillo=modificado, rojo=inválido, gris=sin cambios) y scroll horizontal.
- **Edición de filas inválidas**: Al tocar el RUT en rojo se abre un diálogo de corrección de campos. Al aplicar se re-valida automáticamente y se recalcula el estado de la fila.
- **Eliminación de filas**: Botón rojo en la primera columna para eliminar registros no deseados antes de la confirmación.
- **Overlay de carga**: Pantalla semitransparente con spinner y texto "Procesando..." visible durante las operaciones de parseo y subida a BD.
- **Mensaje de error RLS claro**: Si el usuario no tiene permisos en Supabase, se muestra un mensaje explicativo con instrucciones para solucionarlo.
- **Script SQL para permisos**: `sql/04_fix_rls_policies.sql` que deshabilita completamente Row Level Security en las tablas `trabajadores`, `cumplimiento_trabajadores` y `requisitos_hse`, permitiendo operaciones sin restricciones de rol.

### Correcciones
- **XLSX no cargaba (sheet.maxRows)**: Eliminada dependencia del getter `maxRows` que no existe en el paquete `excel`. El parser ahora itera directamente sobre `sheet.rows` con fallback.
- **CSV detectaba metadata como cabecera**: Función `_encontrarHeader()` que busca primero filas con "RUT" Y ≥10 columnas antes de considerar "Nombre" como fallback.
- **Doble file picker**: Corregido flujo donde al presionar "Validar" se abría el selector de archivos nuevamente. Ahora los bytes se guardan en estado y se reutilizan.
- **Expresión regular rota en `_esFilaDatos`**: Reemplazada regex con comillas sueltas `''` que rechazaba todas las filas, por comparaciones directas de strings.
- **RUT se quedaba en rojo tras editar**: Al corregir en el diálogo, ahora se formatea automáticamente con `_formatearRut()` y se re-valida por longitud.
- **Valores numéricos con ".0" en XLSX**: Los números como `24315442.0` se convierten a string quitando el `.0` para que `_normalizarRut` pueda separar el DV correctamente.
- **Overlay no se mostraba en procesamiento pesado**: Agregado `await Future.delayed(100ms)` después de `setState(_isLoading=true)` para dar tiempo a Flutter de pintar el spinner.
- **Warnings de análisis estático**: Eliminadas funciones no usadas (`_labelCampo`, `_todasVacias`, `msg`), agregadas llaves en `if` statements donde faltaban.

### Archivos modificados
- `lib/screens/carga_masiva_screen.dart` — Nueva implementación completa con 760+ líneas
- `lib/utils/validators.dart` — Nuevas funciones: `normalizarSexo()`, `parsearFechaCsv()`, `estadoDesdeFecha()`, `mapearEstadoSiNa()`, `FilaCargaCompleta`
- `lib/models/trabajador_model.dart` — Nuevo factory `CumplimientoTrabajador.fromCsvValues()`
- `lib/services/trabajador_service.dart` — Nuevos métodos: `bulkUpsertCumplimiento()`, `obtenerOCrearIdPorRut()`
- `sql/04_fix_rls_policies.sql` — Nuevo script para deshabilitar RLS

### Problemas conocidos
- El error RLS 42501 requiere ejecutar `sql/04_fix_rls_policies.sql` en el SQL Editor de Supabase para deshabilitar restricciones de seguridad a nivel de fila.
- La validación de RUT por longitud (≥8 dígitos) es menos estricta que el algoritmo de dígito verificador, pero necesaria para compatibilidad con datos de planillas que pueden tener RUTs sin formato estándar.

### Sugerencias
- Ejecutar el script `sql/04_fix_rls_policies.sql` en Supabase antes de usar la carga masiva para evitar errores de permisos.
- Verificar que el archivo CSV/XLSX tenga el formato de columnas oficial (22 columnas en orden fijo) para un parseo correcto.
- Los RUTs sin guión ni puntos se formatean automáticamente, pero si el archivo tiene un número sin DV (ej: solo "24315442"), el sistema lo marcará como inválido por falta de dígitos.


---

## [V0.5] - 2026-06-20

### Funcionalidades y mejoras
- **Build APK release corregido**: El proyecto Android ahora genera correctamente el APK en modo release con `flutter build apk --release`.

### Correcciones
- **Kotlin Gradle DSL inválido**: Se eliminó el bloque `kotlin { compilerOptions { jvmTarget = ... } }` de `android/app/build.gradle.kts`, ya que no era aplicable al módulo Android de Flutter y generaba errores de compilación.
- **Compatibilidad Java 17**: Se mantuvo la configuración `JavaVersion.VERSION_17` en `compileOptions` para compatibilidad con las versiones actuales de Android Gradle Plugin y Kotlin.
- **compileSdk mínimo para dependencias**: Se actualizó `compileSdk` a `36` en `android/app/build.gradle.kts` para cumplir con los requisitos de `flutter_plugin_android_lifecycle`.
- **Subproyectos Android plugin**: Se agregó configuración en `android/build.gradle.kts` para forzar `compileSdk = 36` en subproyectos tipo Android library, permitiendo que plugins como `file_picker` compilen correctamente contra la versión requerida de Android APIs.

### Problemas conocidos
- La configuración de `compileSdk = 36` en subproyectos Android se mantiene como ajuste local de build para compatibilidad con dependencias actuales.

### Sugerencias
- Considerar actualizar Flutter SDK y Android Gradle Plugin en próximas iteraciones para reducir ajustes manuales de configuración Gradle.

---

## [V0.4] - 2026-06-19

### Funcionalidades y mejoras
- **Filtros de Gestión de Personal**: La pantalla `GestionPersonalScreen` ahora usa botones simples de filtro: **Habilitados**, **Observados** e **Inactivos**.
- **Lógica de activación HSE corregida**: La clasificación de trabajadores ahora considera como observados solo los casos con requisitos en estado `VENCIDO` o `NO`.
- **N/A no genera observaciones**: Los requisitos marcados como `N/A` ya no se cuentan como observaciones ni como falta de requisitos.
- **Compatibilidad con IDs UUID**: La lógica de habilitados/observados dejó de depender de convertir IDs a `int`, evitando errores con IDs UUID de Supabase.
- **Dashboard actualizado**: Los KPIs de acreditados OK y observados ahora reflejan la lógica corregida de activación.
- **Script de migración de IDs**: Se agregó `scripts/migrar_ids_sql.py` para generar un SQL de migración de IDs UUID a IDs numéricos/seriales en Supabase.
- **Script de ingesta CSV**: Se agregó `scripts/subir_csv_supabase.py` para cargar o actualizar trabajadores, requisitos HSE y cumplimiento desde el CSV oficial.
- **Verificación de datos**: Se mantiene `scripts/verificar_supabase.py` para validar conexión, existencia de tablas y consistencia entre CSV local y Supabase.

### Correcciones
- **Filtro inicial de Gestión de Personal**: Se ajustó para que el botón **Habilitados** muestre todos los trabajadores activos, evitando que la pantalla quede vacía si no hay acreditados OK.
- **IDs UUID en Supabase**: Se detectó que los IDs UUID dificultan la legibilidad y el mapeo manual; se agregó script de migración para pasarlos a IDs numéricos/seriales cuando se decida ejecutarlo en Supabase.
- **Validación estática**: Se ejecutó `flutter analyze`; no hay errores en los cambios realizados, solo `info` existentes en `download_helper_web.dart`.

### Problemas conocidos
- La migración de IDs UUID a IDs numéricos/seriales aún no se ejecuta automáticamente en Supabase; requiere revisión y ejecución manual del SQL generado.
- Algunas secciones del menú (Detecciones de Peligro, Caminatas de Seguridad) aún no tienen pantallas implementadas (placeholders).

### Sugerencias
- Ejecutar manualmente la migración de IDs en Supabase solo cuando se confirme que las llaves foráneas y dependencias están correctamente actualizadas.
- Revisar las columnas ODI del CSV (`Protocolo SQM (ODI)`, `CTTA(ODI)`) para confirmar si las fechas de vencimiento se cargaron correctamente en la base de datos.
- Implementar pantallas pendientes del menú Reportabilidad.

---

## [V0.3] - 2026-06-17

### Funcionalidades y mejoras
- **Sidebar colapsable**: Nuevo widget `CollapsibleSidebar` (`lib/widgets/collapsible_sidebar.dart`) con animación suave (280ms) entre estados expandido (220px) y colapsado (72px). Incluye botón de toggle en el header, tooltips en modo colapsado, y diseño responsivo que se adapta automáticamente al ancho del contenido.
- **Navegación funcional en sidebar**: Los items del menú ahora tienen callbacks `onTap` que permiten navegar entre pantallas (Dashboard, Solicitud de Levantamiento, Gestionar Personal).
- **Auto-creación de tablas HSE**: `SupabaseSetupService` ahora crea automáticamente las tablas `trabajadores`, `requisitos_hse` y `cumplimiento_trabajadores` al iniciar la app, junto con sus políticas RLS, triggers e índices.
- **Script de verificación**: Nuevo script `scripts/verificar_supabase.py` para validar la conexión, existencia de tablas y consistencia entre CSV local y Supabase (solo lectura).
- **Arquitectura escalable en Gestión de Personal**: Refactor de `GestionPersonalScreen` separando estado y presentación. Los widgets hijos ahora son `Stateless` y reciben datos y callbacks explícitamente por constructor.
- **Carga optimizada de datos**: Implementada carga paralela con `Future.wait` para traer trabajadores y cumplimiento_trabajadores simultáneamente.
- **Procesamiento background con isolate**: KPIs y cumplimiento se calculan en isolate usando `compute()` evitando bloqueos en el hilo UI.
- **Paginación del listado**: Se implementó paginación de 20 registros por página con controles Anterior/Siguiente e indicador de página actual.
- **Búsqueda con cache y debounce**: Búsqueda por nombre, RUT y cargo con cache local de resultados y debounce de 400ms para reducir consultas repetitivas.
- **Consultas selectivas**: Las queries a Supabase ahora seleccionan solo columnas necesarias reduciendo el tamaño de transferencia.
- **Efectos visuales en botones funcionales**: Se creó `PressableTile` (`lib/widgets/pressable_tile.dart`) que aplica efecto ripple/splash tipo Material solo a los botones que tienen acción asignada ("Solicitud de Levantamiento" en sidebar web y "Solicitud de Levantamiento de Incidentes" en vista móvil).
- **Optimización de plataformas**: Eliminadas carpetas de plataformas no utilizadas (linux, macos, windows, ios). El proyecto ahora se enfoca exclusivamente en Android y Web.
- **Módulo HSE - Gestión de Trabajadores**: Nuevo backend en Supabase con 3 tablas relacionales (`trabajadores`, `requisitos_hse`, `cumplimiento_trabajadores`) para gestión documental HSE de contratistas mineras.
- **Pantalla Registro de Trabajador**: Formulario por pasos (Stepper) con datos fijos del trabajador y matriz dinámica de 12 requisitos HSE. Incluye carga de documentos a Supabase Storage, selector de fecha condicional y guardado masivo (upsert + bulk insert).
- **Navegación HSE**: Botón "Registrar Trabajador" agregado en sidebar web y menú móvil dentro de la sección Reportabilidad.
- **Pantalla Gestionar Personal**: Nuevo dashboard de gestión de personal (`lib/screens/gestion_personal_screen.dart`) con panel de KPIs (Dotación Oficial, Acreditados OK, Observados, Excluidos), buscador con filtros por estado (Todos/Habilitados/Inactivos), tabla de trabajadores con estado de activación, y botón "Agregar Trabajador" que redirige al formulario de registro. Diseño responsive para web y móvil con carga de datos en tiempo real desde Supabase.
- **Menú renovado**: El ítem "Registrar Trabajador" en sidebar web y menú móvil pasó a llamarse "Gestionar Personal", abriendo el nuevo dashboard en lugar del formulario directo.

### Correcciones
- **Políticas RLS duplicadas**: Se agregó `DROP POLICY IF EXISTS` en `supabase_schema_hse.sql` para permitir re-ejecución del script sin errores.
- **Layout de Stepper**: Reemplazado Stepper nativo de Flutter por indicador visual personalizado para evitar excepción "Cannot hit test a render box that has never been laid out".
- **Warnings de análisis estático**: Eliminados import `dart:io` no usado, variable `response` sin uso, deprecación de `value:` por `initialValue:` en DropdownButtonFormField, y guardas `mounted` faltantes.
- **Import no usado**: Eliminado import de `registro_trabajador_screen.dart` en `home_screen.dart` tras reemplazar la navegación directa por el nuevo dashboard.
- **Acceso a setState desde hijos**: Refactorizado el acceso a `setState` desde widgets hijos para usar métodos públicos (`updateSearchQuery`, `updateFilter`) y evitar warning `invalid_use_of_protected_member`.
- **Import no usado**: Eliminado import de `pressable_tile.dart` en `gestion_personal_screen.dart`.
- **RenderFlex overflow en sidebar**: Corregido diseño de `CollapsibleSidebar` ajustando paddings, margins y tamaños de fuente para evitar desbordamientos al colapsar/expandir.
- **Botones sin navegación**: Los items del menú del sidebar ahora tienen `onTap` asignado y navegan correctamente a sus pantallas correspondientes.

### Problemas conocidos
- La arquitectura de agentes se encuentra en fase de implementación inicial.
- La vectorización depende de la integración con Supabase pgvector y servicios de embeddings.
- El sidebar colapsable en la vista web de Gestionar Personal comparte estado con el dashboard principal; al colapsar/expandir afecta a ambas pantallas.
- Algunas secciones del menú (Detecciones de Peligro, Caminatas de Seguridad) aún no tienen pantallas implementadas (placeholders).

### Sugerencias
- Completar implementación de agentes en próximas iteraciones.
- Configurar pgvector en Supabase para habilitar búsqueda semántica.
- Considerar integración con OpenAI Embeddings API o Sentence Transformers para generación de vectores.
- Crear bucket `documentos_hse` en Supabase Storage para la carga de archivos.
- Implementar pantallas pendientes del menú Reportabilidad.

---

---

## [V0.2] - 2026-06-16

### Funcionalidades y mejoras
- **Autenticación reactivada**: La app ahora inicia en la pantalla de login en lugar del dashboard.
- **Modelo unificado**: Se creó `lib/models/solicitud_levantamiento.dart` con todas las clases (`Incidente`, `TipoIncidente`, `Area`, `Perfil`) en un solo archivo.
- **Auto-configuración de Supabase**: Nuevo `SupabaseSetupService` que detecta si faltan tablas o el bucket de storage y los crea automáticamente al iniciar la app.
- **Datos de ejemplo mejorados**: El formulario ahora muestra supervisores y catálogos aunque Supabase devuelva listas vacías.
- **Bucket storage**: Creación automática del bucket `incidentes_storage` con carpeta `incidentes/` si no existe.
- **Versión actualizada**: `pubspec.yaml` → `1.1.0+2`

### Correcciones
- **photo_grid.dart**: Crash fatal en Web por uso de `Image.file`. Se reemplazó con `Image.network` en Web y `Image.file` en móvil usando `kIsWeb`.
- **Error PGRST205 (Table not found)**: Se añadió política RLS para rol `anon` en la tabla `incidentes` y se precargaron datos en `tipos_incidente` y `areas`.
- **Error UUID inválido**: Los IDs de supervisores de ejemplo (`"1"`, `"2"`, `"3"`) ya no se envían como `supervisor_id` a Supabase. Se validan con regex antes de enviar.
- **Importaciones corregidas**: Todos los archivos apuntan al nuevo modelo unificado.
- **Archivos antiguos eliminados**: `incidente.dart`, `tipo_incidente.dart`, `area.dart`, `perfil.dart`.

### Problemas conocidos
- La auto-configuración de Supabase requiere la clave `service_role` en `supabase_config.dart`. Sin ella, la app funciona con datos de ejemplo.
- La tabla `perfiles` se llena solo cuando usuarios reales se registran (trigger `on_auth_user_created`).

### Sugerencias
- Obtener la `service_role key` desde Supabase Dashboard → Project Settings → API para activar la creación automática de tablas y bucket.


## [V0.1] - 2026-06-16

### Funcionalidades y mejoras
- Versión inicial del proyecto ProReport.

### Correcciones
- Sin correcciones registradas.

### Problemas conocidos
- Sin problemas conocidos registrados.

### Sugerencias
- Sin sugerencias registradas.