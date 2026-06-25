# 🗄️ PROreport — Esquemas SQL para Supabase

Guía de ejecución de los scripts SQL para inicializar la base de datos de PROreport.

---

## 🚀 Instalación Rápida (Recomendado)

Ejecutar **un solo archivo** en el Supabase SQL Editor:

| Paso | Archivo | Descripción |
|------|---------|-------------|
| 1️⃣ | `FULL_SCHEMA_PROreport.sql` | **Esquema completo consolidado** con limpieza automática de tablas antiguas |

Este script incluye:
- ✅ **DROP TABLE IF EXISTS ... CASCADE** para limpiar esquemas parciales anteriores del MVP
- ✅ Tablas: `perfiles`, `trabajadores`, `requisitos_hse`, `cumplimiento_trabajadores`
- ✅ Tablas: `tipos_incidente`, `areas`, `incidentes`, `acciones_correctivas`
- ✅ Tabla de auditoría: `auditoria_cumplimiento`
- ✅ Triggers de actualización automática (`updated_at`)
- ✅ Triggers de auditoría y validación de consistencia
- ✅ Vistas Silver/Gold para analítica
- ✅ RPCs transaccionales (ACID)
- ✅ Row Level Security completo

---

## 📦 Instalación Modular (Opcional)

Si prefieres ejecutar por módulos, el orden debe ser:

| Paso | Archivo | Descripción |
|------|---------|-------------|
| 1️⃣ | `01_schema_autenticacion.sql` | Tabla `perfiles` + `trabajador_id` (relación 1:1 con trabajadores) + trigger `handle_new_user` |
| 2️⃣ | `02_schema_gestion_personal.sql` | Tablas `trabajadores`, `requisitos_hse`, `cumplimiento_trabajadores` (estados normalizados) |
| 3️⃣ | `03_schema_solicitud_levantamiento.sql` | Tablas `tipos_incidente`, `areas`, `incidentes`, `acciones_correctivas` |

**Nota:** Cada módulo es autocontenido y no requiere pasos previos.

---

## 🔗 Post-Instalación (Vinculación Perfil ↔ Trabajador)

Después de ejecutar el esquema, cada usuario debe vincular su perfil con su trabajador:

```sql
-- Vincular usuario autenticado con trabajador por RUT
SELECT public.sincronizar_trabajador_actual();
```

**Requisito:** El usuario debe tener su RUT configurado en `raw_user_meta_data` de `auth.users`.

---

## 🏗️ Estructura Relacional

```
perfiles (auth.users)
  ├── trabajador_id ───→ trabajadores (1:1)
  
trabajadores
  ├── cumplimiento_trabajadores (1:N)
      ├── requisitos_hse (N:1)

incidentes
  ├── usuario_reportante_id ───→ perfiles
  ├── supervisor_trabajador_id ──→ trabajadores
  ├── tipo_incidente_id ─────────→ tipos_incidente
  ├── area_id ───────────────────→ areas
  └── acciones_correctivas (1:N)

auditoria_cumplimiento (inmutable, solo admin)
```

---

## 📁 Estructura de Archivos

```
sql/
├── README.md                              ← Esta guía
├── FULL_SCHEMA_PROreport.sql              ← 🔥 Esquema completo (recomendado)
├── 01_schema_autenticacion.sql            ← Auth + perfiles + trabajador_id
├── 02_schema_gestion_personal.sql         ← Trabajadores + cumplimiento HSE
└── 03_schema_solicitud_levantamiento.sql  ← Incidentes + tipos + áreas + acciones
```

---

## ⚠️ Notas Importantes

- **Tabla `usuarios_trabajadores` eliminada**: Reemplazada por `perfiles.trabajador_id` (relación 1:1 directa).
- **Estados normalizados**: `cumplimiento_trabajadores.valor_estado` usa solo `VIGENTE`, `VENCIDO`, `N/A`.
- **Sin JSONB duplicado**: Las acciones correctivas solo existen en `acciones_correctivas` (estructura relacional).
- **FK consistentes**: `incidentes.usuario_reportante_id` → `perfiles.id` (UUID). `incidentes.supervisor_trabajador_id` → `trabajadores.id` (INTEGER).
- **Idempotencia**: Todos los scripts usan `CREATE TABLE IF NOT EXISTS` y `DROP POLICY IF EXISTS`, por lo que se pueden re-ejecutar sin dañar datos existentes.
- **Bucket de Storage**: Crear manualmente el bucket `incidentes_storage` en Supabase Storage para las fotos de incidentes.