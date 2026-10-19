/// One piece of material a teacher attached to an assignment: a PDF, image,
/// video clip, voice note, document or any other file. [id] is the server file
/// id used by `get_file` to download it.
class AssignmentMaterial {
  final String id;
  final String name;
  final String kind;
  final int size;
  final String? mimeType;

  const AssignmentMaterial({
    required this.id,
    required this.name,
    this.kind = 'file',
    this.size = 0,
    this.mimeType,
  });

  factory AssignmentMaterial.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? 'Attachment').toString();
    return AssignmentMaterial(
      id: (json['id'] ?? json['file_id'] ?? '').toString(),
      name: name,
      kind: (json['kind'] ?? materialKindForName(name)).toString(),
      size: int.tryParse('${json['size'] ?? 0}') ?? 0,
      mimeType: json['mime_type']?.toString(),
    );
  }

  String get extension {
    final clean = name.split('?').first;
    final dot = clean.lastIndexOf('.');
    return dot >= 0 ? clean.substring(dot + 1).toLowerCase() : '';
  }

  /// Human size: 12 KB, 3.4 MB, 1.2 GB.
  String get sizeLabel {
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// A file the teacher picked in the app but has not uploaded yet.
class AssignmentMaterialUpload {
  final String name;
  final List<int> bytes;

  const AssignmentMaterialUpload({required this.name, required this.bytes});

  int get size => bytes.length;
  String get kind => materialKindForName(name);
}

/// Maps a filename to the same kind vocabulary the backend uses.
String materialKindForName(String name) {
  final clean = name.split('?').first;
  final dot = clean.lastIndexOf('.');
  final ext = dot >= 0 ? clean.substring(dot + 1).toLowerCase() : '';
  switch (ext) {
    case 'pdf':
      return 'pdf';
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
    case 'heic':
    case 'heif':
    case 'bmp':
    case 'svg':
      return 'image';
    case 'mp4':
    case 'm4v':
    case 'mov':
    case 'webm':
    case 'avi':
    case 'mkv':
    case '3gp':
      return 'video';
    case 'mp3':
    case 'm4a':
    case 'aac':
    case 'wav':
    case 'ogg':
    case 'oga':
    case 'opus':
    case 'amr':
    case 'flac':
      return 'audio';
    case 'txt':
    case 'md':
    case 'csv':
    case 'doc':
    case 'docx':
    case 'ppt':
    case 'pptx':
    case 'xls':
    case 'xlsx':
      return 'document';
    case 'zip':
    case 'rar':
    case '7z':
      return 'archive';
    default:
      return 'file';
  }
}

/// Short label used on chips: PDF, Image, Video, Voice, Doc, File.
String materialKindLabel(String kind) {
  switch (kind) {
    case 'pdf':
      return 'PDF';
    case 'image':
      return 'Image';
    case 'video':
      return 'Video';
    case 'audio':
      return 'Voice';
    case 'document':
      return 'Doc';
    case 'archive':
      return 'Archive';
    default:
      return 'File';
  }
}

const kMaxMaterialBytes = 20 * 1024 * 1024;
const kMaxMaterialsPerAssignment = 4;
