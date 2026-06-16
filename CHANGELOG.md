# Registro de versiones y novedades

## Flujo de trabajo
1. Revisar correcciones y mejoras
2. Desarrollar la tarea
3. Probar mejora
4. Registrar mejoras o errores capturados
5. Subir a git

---

## [V.02] - 2026-06-16

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

## [V.01] - 2026-06-16

### Funcionalidades y mejoras
- Versión inicial del proyecto ProReport.

### Correcciones
- Sin correcciones registradas.

### Problemas conocidos
- Sin problemas conocidos registrados.

### Sugerencias
- Sin sugerencias registradas.
