// ================================================================
// PROreport - Edge Function: send-notification-email
// ----------------------------------------------------------------
// Disparada por Database Triggers via pg_net (HTTP POST).
// Recibe { type, operation, record } y envía correos con Resend.
//
// Variables de entorno (ya vienen pre-configuradas en Supabase):
//   RESEND_API_KEY              -> Clave API de Resend
//   SUPABASE_URL                -> URL del proyecto Supabase (default)
//   SUPABASE_SERVICE_ROLE_KEY   -> Service Role Key (default)
// ================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

interface NotificationPayload {
  type: "deteccion_peligro" | "incidente" | "cumplimiento";
  operation: "INSERT" | "UPDATE";
  record: Record<string, unknown>;
}

interface DestinatarioInfo {
  nombre: string;
  cargo: string;
}

// ────────────────────────────────────────────────────────────────
// Función principal
// ────────────────────────────────────────────────────────────────
serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response("Método no permitido", { status: 405 });
    }

    // 1. Leemos el cuerpo de la petición de forma dinámica
    const payload = await req.json();
    
    // Imprimimos el JSON crudo en los logs para auditarlo pase lo que pase
    console.log("JSON CRUDO DETECTADO ->", JSON.stringify(payload));

    // 2. Extraemos las variables con respaldos automáticos
    // Si viene de Webhook Nativo, la operación está en 'type' (INSERT). Si viene manual, en 'operation'.
    const operation = payload.operation || payload.type || "INSERT";

    // Determinamos el tipo de reporte de forma segura (evitando que guarde "INSERT" como tipo)
    let reportType = "";
    if (payload.table) {
      reportType = payload.table; // Formato Webhook Nativo de Supabase
    } else if (payload.type && payload.type !== "INSERT" && payload.type !== "UPDATE" && payload.type !== "DELETE") {
      reportType = payload.type; // Formato Manual viejo
    } else {
      // Fallback por si acaso: si es la tabla 'deteccion_peligro' o similar
      reportType = "deteccion_peligro"; 
    }

    const record = payload.record || {};

    console.log(
      `[PROCESADO CON ÉXITO] -> reportType=${reportType}, operation=${operation}, id=${record?.id}`
    );

    // 3. El switch ahora evalúa de manera segura 'reportType'
    switch (reportType) {
      case "deteccion_peligro":
        await procesarDeteccionPeligro(record, operation);
        break;
      case "incidente":
        await procesarIncidente(record, operation);
        break;
      case "cumplimiento":
        await procesarCumplimiento(record, operation);
        break;
      default:
        console.warn(`Tipo de notificación desconocido o no mapeado: ${reportType}`);
    }
    return new Response("OK", { status: 200 });
  } catch (error) {
    console.error("Error en send-notification-email:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

// ────────────────────────────────────────────────────────────────
// Normalizar texto: minúsculas + sin tildes + sin caracteres especiales
// ────────────────────────────────────────────────────────────────
function normalizarTexto(texto: string): string {
  return texto
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

// ────────────────────────────────────────────────────────────────
// Verificar si un cargo corresponde a supervisor
// ────────────────────────────────────────────────────────────────
function esSupervisor(cargo: string): boolean {
  const c = normalizarTexto(cargo);
  return (
    c.includes("supervisor") ||
    c.includes("superintendente") ||
    c.includes("jefe") ||
    c.includes("coordinador") ||
    c.includes("lider") ||
    c.includes("capataz") ||
    c.includes("encargado")
  );
}

// ────────────────────────────────────────────────────────────────
// Verificar si un cargo corresponde a prevención/HSE
// ────────────────────────────────────────────────────────────────
function esPrevencion(cargo: string): boolean {
  const c = normalizarTexto(cargo);
  return (
    c.includes("prevencion") ||
    c.includes("prevencionista") ||
    c.includes("riesgo") ||
    c.includes("riesgos") ||
    c.includes("hse") ||
    c.includes("seguridad") ||
    c.includes("higiene") ||
    c.includes("ambiente") ||
    c.includes("ambiental")
  );
}

// ────────────────────────────────────────────────────────────────
// PROCESAR: Detección de Peligro
// ────────────────────────────────────────────────────────────────
async function procesarDeteccionPeligro(
  record: Record<string, unknown>,
  _operation: string
): Promise<void> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

  if (!serviceKey) {
    console.warn("SUPABASE_SERVICE_ROLE_KEY no configurada");
    return;
  }

  const headers = {
    "Content-Type": "application/json",
    apikey: serviceKey,
    Authorization: `Bearer ${serviceKey}`,
  };

  // ── Datos del registro ──
  const deteccionId = record.id;
  const usuarioReportanteId = record.usuario_reportante_id;
  const contratoCodigo = (record.contrato_codigo as string) || "";
  const descripcion = record.descripcion_hallazgo || "(sin descripción)";
  const nivelAtencion = record.nivel_atencion_lgf || "BAJO";
  const lugarExacto = record.lugar_exacto || "";
  const turno = record.turno || "";
  const fotoUrl = record.foto_evidencia_url || "";
  const accionInmediata = record.accion_inmediata || "";
  const estatus = record.estatus_seguimiento || "Pendiente";

  console.log(`[DEBUG] Iniciando procesarDeteccionPeligro id=${deteccionId}, contratoCodigo="${contratoCodigo}", usuarioReportanteId=${usuarioReportanteId}`);

  // ── 1. Obtener perfil del reportante ──
  const perfilRes = await fetch(
    `${supabaseUrl}/rest/v1/perfiles?id=eq.${usuarioReportanteId}&select=*,trabajadores!trabajador_id(*)`,
    { headers }
  );
  if (!perfilRes.ok) {
    console.error("Error al obtener perfil:", await perfilRes.text());
    return;
  }
  const perfilData = await perfilRes.json();
  const perfil = perfilData?.[0];
  if (!perfil) {
    console.error("Perfil no encontrado:", usuarioReportanteId);
    return;
  }

  console.log(`[DEBUG] Perfil encontrado: trabajador_id=${perfil.trabajador_id}`);

  const trabajador = perfil.trabajadores;
  const nombreReportante = trabajador
    ? `${trabajador.nombre || ""} ${trabajador.apellido_paterno || ""} ${trabajador.apellido_materno || ""}`.trim()
    : perfil.nombre_completo || "Desconocido";
  const trabajadorId = perfil.trabajador_id;

  if (!trabajadorId) {
    console.warn(`[DEBUG] trabajador_id es nulo. No se pueden buscar contratos ni personal.`);
  }

  // ── 2. Obtener nombre del contrato ──
  let contratoNombre = contratoCodigo;
  if (contratoCodigo) {
    const contratoRes = await fetch(
      `${supabaseUrl}/rest/v1/contratos?codigo=eq.${encodeURIComponent(contratoCodigo)}&select=nombre`,
      { headers }
    );
    if (contratoRes.ok) {
      const contratoData = await contratoRes.json();
      if (contratoData?.[0]?.nombre) {
        contratoNombre = contratoData[0].nombre;
      }
    }
  }

  // ── 3. Contratos del trabajador (del registro y de trabajador_contratos) ──
  const contratosSet = new Set<string>();
  if (contratoCodigo) {
    contratosSet.add(contratoCodigo);
    console.log(`[DEBUG] Contrato desde record: "${contratoCodigo}"`);
  }

  if (trabajadorId) {
    const contratosRes = await fetch(
      `${supabaseUrl}/rest/v1/trabajador_contratos?trabajador_id=eq.${trabajadorId}&select=contrato_codigo`,
      { headers }
    );
    if (contratosRes.ok) {
      const contratosData = await contratosRes.json();
      console.log(`[DEBUG] Contratos desde trabajador_contratos: ${JSON.stringify(contratosData)}`);
      for (const c of (contratosData as Array<{ contrato_codigo: string }>)) {
        contratosSet.add(c.contrato_codigo);
      }
    } else {
      const errorText = await contratosRes.text();
      console.warn(`[DEBUG] Error al obtener contratos del trabajador: ${errorText}`);
    }
  }
  const contratos = Array.from(contratosSet);
  console.log(`[DEBUG] Contratos finales (${contratos.length}): ${JSON.stringify(contratos)}`);

  // ── 4. Buscar supervisores y HSE en los mismos contratos ──
  const supervisores: DestinatarioInfo[] = [];
  const personalHSE: DestinatarioInfo[] = [];

  if (contratos.length > 0 && trabajadorId) {
    const contratoFilters = contratos
      .map((c) => `contrato_codigo.eq.${encodeURIComponent(c)}`)
      .join(",");

    console.log(`[DEBUG] Buscando trabajadores en contratos con filtro: ${contratoFilters}`);

    const trabajadoresContratoRes = await fetch(
      `${supabaseUrl}/rest/v1/trabajador_contratos?or=(${contratoFilters})&select=trabajador_id`,
      { headers }
    );

    if (trabajadoresContratoRes.ok) {
      const tcData = await trabajadoresContratoRes.json();
      console.log(`[DEBUG] trabajador_contratos encontrados: ${JSON.stringify(tcData)}`);
      const idsTrabajadores = (
        tcData as Array<{ trabajador_id: number }>
      ).map((t) => t.trabajador_id);

      console.log(`[DEBUG] IDs de trabajadores en contratos: ${JSON.stringify(idsTrabajadores)}`);

      if (idsTrabajadores.length > 0) {
        const idsFilter = idsTrabajadores
          .filter((id) => id !== trabajadorId)
          .map((id) => `id.eq.${id}`)
          .join(",");

        console.log(`[DEBUG] Filtrando reportero (id=${trabajadorId}). IDs a consultar: "${idsFilter}"`);

        if (idsFilter) {
          const trabajadoresRes = await fetch(
            `${supabaseUrl}/rest/v1/trabajadores?or=(${idsFilter})&select=id,nombre,apellido_paterno,apellido_materno,cargo`,
            { headers }
          );

          if (trabajadoresRes.ok) {
            const trabajadoresData = await trabajadoresRes.json();
            console.log(`[DEBUG] Trabajadores encontrados en contratos: ${JSON.stringify(trabajadoresData.map((t: any) => ({ id: t.id, nombre: t.nombre, cargo: t.cargo })))}`);

            for (const t of trabajadoresData as Array<{
              id: number;
              nombre: string;
              apellido_paterno: string;
              apellido_materno: string;
              cargo: string;
            }>) {
              const nombreCompleto =
                `${t.nombre || ""} ${t.apellido_paterno || ""} ${t.apellido_materno || ""}`.trim();

              console.log(`[DEBUG] Evaluando cargo "${t.cargo}" (normalizado: "${normalizarTexto(t.cargo || "")}")`);

              if (esSupervisor(t.cargo || "")) {
                console.log(`[DEBUG] -> COINCIDE como SUPERVISOR`);
                supervisores.push({
                  nombre: nombreCompleto || "Supervisor",
                  cargo: t.cargo || "Supervisor",
                });
              } else {
                console.log(`[DEBUG] -> NO coincide como supervisor`);
              }

              if (esPrevencion(t.cargo || "")) {
                console.log(`[DEBUG] -> COINCIDE como PREVENCION/HSE`);
                personalHSE.push({
                  nombre: nombreCompleto || "Prevencionista",
                  cargo: t.cargo || "Prevención de Riesgos",
                });
              } else {
                console.log(`[DEBUG] -> NO coincide como prevencion/HSE`);
              }
            }
          } else {
            const errorText = await trabajadoresRes.text();
            console.error(`[DEBUG] Error al obtener datos de trabajadores: ${errorText}`);
          }
        } else {
          console.log(`[DEBUG] Solo hay un trabajador (el reportero) en los contratos. No hay otros para evaluar.`);
        }
      } else {
        console.log(`[DEBUG] No se encontraron trabajadores en trabajador_contratos para los contratos dados.`);
      }
    } else {
      const errorText = await trabajadoresContratoRes.text();
      console.warn(`[DEBUG] Error al consultar trabajador_contratos: ${errorText}`);
    }
  } else {
    console.log(`[DEBUG] No se buscan personas: contratos.length=${contratos.length}, trabajadorId=${trabajadorId}`);
  }

  console.log(`[DEBUG] Resultado final: ${supervisores.length} supervisores, ${personalHSE.length} prevencion/HSE`);

  // ── 5. Construir y enviar correo ──
  const nivelColores: Record<string, string> = {
    BAJO: "#4CAF50",
    MEDIO: "#FF9800",
    SIGNIFICATIVO: "#F44336",
  };

  const nivelColor = nivelColores[nivelAtencion as string] || "#333";

  const listaSupervisores =
    supervisores.length > 0
      ? supervisores.map((s) => `• ${s.nombre} (${s.cargo})`).join("<br>")
      : "<em>No se encontraron supervisores en el contrato</em>";

  const listaHSE =
    personalHSE.length > 0
      ? personalHSE.map((h) => `• ${h.nombre} (${h.cargo})`).join("<br>")
      : "<em>No se encontró personal HSE en el contrato</em>";

  const contratosStr = contratos.length > 0 ? contratos.join(", ") : "Sin contrato asignado";
  const areaNombre = contratoNombre;

  const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; margin: 0; padding: 0; background: #f4f4f4; }
    .container { max-width: 600px; margin: 20px auto; background: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
    .header { background: #1a237e; color: white; padding: 24px; text-align: center; }
    .header h1 { margin: 0; font-size: 20px; }
    .header p { margin: 8px 0 0; opacity: 0.9; font-size: 14px; }
    .nivel-badge { display: inline-block; background: ${nivelColor}; color: white; padding: 4px 12px; border-radius: 12px; font-size: 13px; font-weight: bold; }
    .body { padding: 24px; }
    .field { margin-bottom: 16px; }
    .field-label { font-size: 12px; color: #666; text-transform: uppercase; font-weight: bold; margin-bottom: 4px; }
    .field-value { font-size: 15px; color: #333; }
    .section-title { font-size: 14px; font-weight: bold; color: #1a237e; margin: 20px 0 8px; padding-bottom: 4px; border-bottom: 2px solid #1a237e; }
    .person-list { background: #f8f9fa; padding: 12px 16px; border-radius: 6px; font-size: 14px; line-height: 1.8; }
    .footer { background: #f4f4f4; padding: 16px 24px; text-align: center; font-size: 12px; color: #888; }
    .footer a { color: #1a237e; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⚠️ Nueva Detección de Peligro</h1>
      <p>Reportado por: ${nombreReportante}</p>
    </div>
    <div class="body">
      <p style="text-align:center;margin-bottom:20px;">
        <span class="nivel-badge">${nivelAtencion}</span>
        <span style="margin-left:8px;color:#666;">${estatus}</span>
      </p>

      <div class="field">
        <div class="field-label">Ubicación</div>
        <div class="field-value">${lugarExacto}</div>
      </div>

      <div class="field">
        <div class="field-label">Contrato</div>
        <div class="field-value">${areaNombre} (${contratosStr})</div>
      </div>

      <div class="field">
        <div class="field-label">Turno</div>
        <div class="field-value">${turno}</div>
      </div>

      <div class="field">
        <div class="field-label">Descripción del Hallazgo</div>
        <div class="field-value">${descripcion}</div>
      </div>

      ${
        accionInmediata
          ? `<div class="field"><div class="field-label">Acción Inmediata</div><div class="field-value">${accionInmediata}</div></div>`
          : ""
      }

      ${
        fotoUrl
          ? `<div class="field"><div class="field-label">Foto de Evidencia</div><div><a href="${fotoUrl}" target="_blank">Ver imagen</a></div></div>`
          : ""
      }

      <div class="section-title">📋 Personas Notificadas en el Contrato</div>

      <div class="field">
        <div class="field-label">Supervisores</div>
        <div class="person-list">${listaSupervisores}</div>
      </div>

      <div class="field">
        <div class="field-label">Prevención de Riesgos / HSE</div>
        <div class="person-list">${listaHSE}</div>
      </div>
    </div>
    <div class="footer">
      <p>PROreport - Sistema de Gestión HSE</p>
      <p>ID del reporte: #${deteccionId}</p>
    </div>
  </div>
</body>
</html>`;

  await enviarConResend({
    to: "santi.3975@gmail.com",
    subject: `⚠️ [Peligro ${nivelAtencion}] ${areaNombre} - ${lugarExacto}`,
    html: htmlContent,
  });
}

// ────────────────────────────────────────────────────────────────
// PROCESAR: Incidente
// ────────────────────────────────────────────────────────────────
async function procesarIncidente(
  record: Record<string, unknown>,
  _operation: string
): Promise<void> {
  const titulo = record.titulo || "Incidente reportado";
  const descripcion = record.descripcion || "";

  await enviarConResend({
    to: "santi.3975@gmail.com",
    subject: `⚠️ Nuevo Incidente: ${titulo}`,
    html: `<h2>Nuevo Incidente</h2><p>${descripcion}</p>`,
  });
}

// ────────────────────────────────────────────────────────────────
// PROCESAR: Cumplimiento
// ────────────────────────────────────────────────────────────────
async function procesarCumplimiento(
  record: Record<string, unknown>,
  _operation: string
): Promise<void> {
  const trabajadorId = record.trabajador_id;
  const requisitoId = record.requisito_id;

  await enviarConResend({
    to: "santi.3975@gmail.com",
    subject: "📋 Actualización de Cumplimiento HSE",
    html: `<h2>Cambio en Cumplimiento</h2>
           <p>Trabajador ID: ${trabajadorId}</p>
           <p>Requisito ID: ${requisitoId}</p>
           <p>Nuevo estado: ${record.valor_estado || "N/A"}</p>`,
  });
}

// ────────────────────────────────────────────────────────────────
// ENVIAR CORREO VÍA RESEND
// ────────────────────────────────────────────────────────────────
async function enviarConResend(opts: {
  to: string;
  subject: string;
  html: string;
}): Promise<void> {
  const resendApiKey = Deno.env.get("RESEND_API_KEY");

  if (!resendApiKey) {
    console.warn(
      "RESEND_API_KEY no configurada. " +
        "Configúrala en Supabase Dashboard -> Edge Functions -> send-notification-email"
    );
    return;
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${resendApiKey}`,
    },
    body: JSON.stringify({
      from: "onboarding@resend.dev",
      to: [opts.to],
      subject: opts.subject,
      html: opts.html,
    }),
  });

  if (!res.ok) {
    const errorBody = await res.text();
    console.error(`Error Resend (${res.status}): ${errorBody}`);
  } else {
    const data = await res.json();
    console.log("Correo enviado con Resend ID:", data.id);
  }
}