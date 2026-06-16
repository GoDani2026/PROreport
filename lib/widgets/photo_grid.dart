import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/incidente_provider.dart';
import '../config/theme.dart';

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<IncidenteProvider>(
      builder: (context, provider, child) {
        final imageCount = provider.imageCount;
        final maxImages = 5;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Registro Fotográfico',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Total: $imageCount / $maxImages',
                        style: const TextStyle(
                          color: AppTheme.accentOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Grid de imágenes
                if (imageCount > 0)
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageCount + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildAddButton(context, provider);
                        }
                        return _buildImagePreview(
                            context, provider, index - 1);
                      },
                    ),
                  )
                else
                  _buildAddButton(context, provider),

                const SizedBox(height: 8),

                // Botones de acción
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionButton(
                      context,
                      icon: Icons.photo_library,
                      label: 'Galería',
                      onPressed: () {
                        if (imageCount < maxImages) {
                          provider.pickImagesFromGallery();
                        } else {
                          _showMaxLimitMessage(context);
                        }
                      },
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.camera_alt,
                      label: 'Cámara',
                      onPressed: () {
                        if (imageCount < maxImages) {
                          provider.pickImageFromCamera();
                        } else {
                          _showMaxLimitMessage(context);
                        }
                      },
                    ),
                    _buildActionButton(
                      context,
                      icon: Icons.upload_file,
                      label: 'AGREGAR ARCHIVO',
                      onPressed: () {
                        if (imageCount < maxImages) {
                          provider.pickFilesForWeb();
                        } else {
                          _showMaxLimitMessage(context);
                        }
                      },
                      isPrimary: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddButton(
      BuildContext context, IncidenteProvider provider) {
    return GestureDetector(
      onTap: () => _showImageSourceDialog(context, provider),
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentOrange.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo,
              color: AppTheme.accentOrange,
              size: 32,
            ),
            SizedBox(height: 4),
            Text(
              'Agregar',
              style: TextStyle(
                color: AppTheme.accentOrange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(
      BuildContext context, IncidenteProvider provider, int index) {
    final image = index < provider.selectedImages.length
        ? _buildPlatformImage(provider.selectedImages[index].path)
        : Image.memory(
            provider.webImagesBytes[
                index - provider.selectedImages.length],
            fit: BoxFit.cover,
          );

    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: image,
        ),
        Positioned(
          top: 4,
          right: 12,
          child: GestureDetector(
            onTap: () => provider.removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isPrimary ? AppTheme.accentOrange : Colors.grey.withValues(alpha: 0.2),
        foregroundColor: isPrimary ? Colors.white : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildPlatformImage(String imagePath) {
    if (kIsWeb) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.red),
          );
        },
      );
    } else {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.red),
          );
        },
      );
    }
  }

  void _showImageSourceDialog(
      BuildContext context, IncidenteProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                provider.pickImagesFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(context);
                provider.pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Subir archivo'),
              onTap: () {
                Navigator.pop(context);
                provider.pickFilesForWeb();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMaxLimitMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Máximo 5 archivos permitidos'),
        backgroundColor: AppTheme.errorRed,
      ),
    );
  }
}
