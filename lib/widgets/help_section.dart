import 'package:flutter/material.dart';
import '../config/theme.dart';

class HelpSection extends StatelessWidget {
  const HelpSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline, color: AppTheme.accentOrange),
        title: const Text(
          'Ayuda / Instrucciones',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'Cómo llenar un reporte de incidente',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        initiallyExpanded: false,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          _buildHelpItem(
            icon: Icons.photo_camera,
            title: 'Registro Fotográfico',
            description:
                'Tome fotos del área del incidente. Puede cargar hasta 5 imágenes desde la galería, cámara o archivos.',
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            icon: Icons.description,
            title: 'Descripción',
            description:
                'Describa detalladamente lo ocurrido. Incluya información como lugar, hora, personas involucradas y posibles causas. Límite: 20 palabras.',
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            icon: Icons.category,
            title: 'Tipo de Incidente',
            description:
                'Seleccione el tipo de incidente: Acto Inseguro (acción incorrecta), Condición Insegura (situación peligrosa), o Casi Accidente (evento sin lesión).',
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            icon: Icons.location_on,
            title: 'Área',
            description:
                'Indique el área donde ocurrió el incidente (Mina, Planta, Mantenimiento, Oficinas, etc.).',
          ),
          const SizedBox(height: 12),
          _buildHelpItem(
            icon: Icons.person,
            title: 'Supervisor Responsable',
            description:
                'Seleccione el supervisor a cargo del área donde ocurrió el incidente.',
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.accentOrange, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
