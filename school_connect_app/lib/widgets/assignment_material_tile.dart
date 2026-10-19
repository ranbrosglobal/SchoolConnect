import 'package:flutter/material.dart';

import '../models/assignment_material.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';

/// Icon and colour for a material kind. Shared by the teacher's upload screen
/// and the student's assignment view so a PDF looks the same everywhere.
IconData materialIcon(String kind) {
  switch (kind) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'image':
      return Icons.image_rounded;
    case 'video':
      return Icons.play_circle_fill_rounded;
    case 'audio':
      return Icons.graphic_eq_rounded;
    case 'document':
      return Icons.description_rounded;
    case 'archive':
      return Icons.folder_zip_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

Color materialColor(String kind) {
  switch (kind) {
    case 'pdf':
      return AppColors.danger;
    case 'image':
      return AppColors.tertiary;
    case 'video':
      return AppColors.studentAccent;
    case 'audio':
      return AppColors.success;
    case 'document':
      return AppColors.info;
    case 'archive':
      return AppColors.warning;
    default:
      return AppColors.inkSoft;
  }
}

String materialSubtitle(AssignmentMaterial material) {
  return [
    materialKindLabel(material.kind),
    if (material.sizeLabel.isNotEmpty) material.sizeLabel,
  ].join(' · ');
}

/// One material row: type icon, filename, kind + size, and a trailing action.
///
/// Used for existing materials (download), newly picked files (remove), and
/// upload progress (spinner).
class AssignmentMaterialTile extends StatelessWidget {
  final AssignmentMaterial material;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool busy;
  final bool compact;

  const AssignmentMaterialTile({
    super.key,
    required this.material,
    this.onTap,
    this.onRemove,
    this.busy = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = materialColor(material.kind);
    final icon = materialIcon(material.kind);
    final trailing = onRemove != null
        ? IconButton(
            onPressed: onRemove,
            tooltip: 'Remove file',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.inkFaint,
          )
        : busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : onTap == null
        ? null
        : const Icon(
            Icons.download_rounded,
            size: 20,
            color: AppColors.primary,
          );

    final content = Row(
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadius.brSm,
          ),
          child: Icon(icon, size: compact ? 17 : 20, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                material.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 12.5 : 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                materialSubtitle(material),
                style: AppText.caption.copyWith(
                  fontSize: 11,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (trailing != null) trailing,
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brSm,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 7 : 9,
          ),
          child: content,
        ),
      ),
    );
  }
}
