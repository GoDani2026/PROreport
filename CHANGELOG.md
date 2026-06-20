# Registro de versiones y novedades

## Flujo de trabajo
1. Revisar correcciones y mejoras
2. Desarrollar la tarea
3. Probar mejora
4. Registrar mejoras o errores capturados
5. Subir a git

---
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

### Correcciones
- **Políticas RLS duplicadas**: Se agregó `DROP POLICY IF EXISTS` en `supabase_schema_hse.sql` para permitir re-ejecución del script sin errores.
- **Layout de Stepper**: Reemplazado Stepper nativo de Flutter por indicador visual personalizado para evitar excepción "Cannot hit test a render box that has never been laid out".
- **Warnings de análisis estático**: Eliminados import `dart:io` no usado, variable `response` sin uso, deprecación de `value:` por `initialValue:` en DropdownButtonFormField, y guardas `mounted` faltantes.
- **Import no usado**: Eliminado import de `registro_trabajador_screen.dart` en `home_screen.dart` tras reemplazar la navegación directa por el nuevo dashboard.
- **Acceso a setState desde hijos**: Refactorizado el acceso a `setState` desde widgets hijos para usar métodos públicos (`updateSearchQuery`, `updateFilter`) y evitar warning `invalid_use_of_protected_member`.
- **Import no usado**: Eliminado import de `pressable_tile.dart` en `gestion_personal_screen.dart`.
- **RenderFlex overflow en sidebar**: Corregido diseño de `CollapsibleSidebar` ajustando paddings, margins y tamaños de fuente para evitar desbordamientos al colapsar/expandir.
- **Botones sin navegación**: Los items del menú del sidebar ahora tienen `onTap` asignado y navegan correctamente a sus pantallas correspondientes.
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
