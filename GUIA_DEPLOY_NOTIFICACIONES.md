# 🚀 Guía para Activar Notificaciones por Correo (Resend)

## Resumen

| Componente | Estado |
|---|---|
| Edge Function `send-notification-email` | ✅ Escrita |
| Triggers SQL en BD | ✅ Escritos |
| Deploy Edge Function | 🔲 Pendiente |
| Configurar variables de entorno | 🔲 Pendiente |
| Configurar BD (URL de Edge Function + pg_net) | 🔲 Pendiente |

---

## Paso 1: Desplegar la Edge Function desde el Dashboard

1. Ve a: [https://supabase.com/dashboard/project/inleckebqssizgeovgov](https://supabase.com/dashboard/project/inleckebqssizgeovgov)
2. En el menú izquierdo → **Edge Functions**
3. Haz clic en **"Deploy from local"** o crea una función nueva llamada `send-notification-email`
4. Pega el contenido de `supabase/functions/send-notification-email/index.ts`
5. Haz clic en **Deploy**
6. ⏳ Espera a que termine el deploy

---

## Paso 2: Configurar Variables de Entorno

En el Dashboard de Supabase, ve a:
- **Edge Functions** → `send-notification-email` → **Environment Variables**

Agrega estas 3 variables:

| Variable | Valor | Dónde obtenerla |
|---|---|---|
| `RESEND_API_KEY` | `re_...` | Dashboard de Resend → API Keys |
| `SUPABASE_URL` | `https://inleckebqssizgeovgov.supabase.co` | Project Settings → API |
| `SUPABASE_SERVICE_KEY` | `eyJ...` (service_role key) | Project Settings → API → service_role key |

> ⚠️ **IMPORTANTE**: Usa la **service_role key** (NO la anon key), porque necesitas poder consultar la base de datos sin RLS desde la Edge Function.

---

## Paso 3: Ejecutar los Triggers SQL en la Base de Datos

1. En Dashboard de Supabase → **SQL Editor** → New Query
2. Pega el contenido de `supabase/migrations/20260628_notification_triggers.sql`
3. **Antes de ejecutar**, cambia esta línea al final del script (aproximadamente línea 176):
   ```sql
   SELECT set_config('app.edge_function_url',
     'https://inleckebqssizgeovgov.supabase.co/functions/v1/send-notification-email',
     false);
   ```
4. Ejecuta el script completo

---

## Paso 4: Verificar la Extensión pg_net

En el SQL Editor, ejecuta:
```sql
SELECT * FROM pg_available_extensions WHERE name = 'pg_net';
```

Si no aparece instalada, ejecuta:
```sql
CREATE EXTENSION IF NOT EXISTS pg_net;
```

---

## Paso 5: Probar

Inserta un registro de prueba en `detecciones_peligro`:
```sql
INSERT INTO detecciones_peligro (
  usuario_reportante_id,
  area_id,
  turno,
  lugar_exacto,
  descripcion_hallazgo,
  nivel_atencion_lgf,
  accion_inmediata
) VALUES (
  (SELECT id FROM perfiles LIMIT 1),
  1,
  'Diurno',
  'Prueba - Sector A',
  'PRUEBA: Cable suelto en pasillo principal',
  'MEDIO',
  'Señalizar el área'
);
```

Luego revisa los logs de la Edge Function:
- Dashboard → Edge Functions → `send-notification-email` → **Logs**

Y revisa tu correo `santi.3975@gmail.com` (puede tardar 1-2 minutos).

---

## ¿Sobre la API Key de Resend?

**Solo necesitas ponerla en un lugar**: en las **Environment Variables** de la Edge Function como se indica en el Paso 2.

No necesitas ponerla en ningún otro lado (ni en Flutter, ni en la BD, ni en secrets de otra forma). La Edge Function la toma directamente de las variables de entorno al ejecutarse.

---

## Solución de problemas

| Síntoma | Causa posible | Solución |
|---|---|---|
| El correo no llega | RESEND_API_KEY incorrecta | Verificar la key en Resend Dashboard |
| Error 500 en logs | SUPABASE_SERVICE_KEY no configurada | Agregar la service_role key en env vars |
| No se ejecuta la función | pg_net no instalada | Ejecutar `CREATE EXTENSION pg_net;` |
| El trigger no dispara | URL de edge function no configurada | Ejecutar el `set_config` del Paso 3 |

---

## Resumen de archivos

| Archivo | Propósito |
|---|---|
| `supabase/functions/send-notification-email/index.ts` | La Edge Function (ya escrita) |
| `supabase/migrations/20260628_notification_triggers.sql` | Triggers SQL para llamar la función |