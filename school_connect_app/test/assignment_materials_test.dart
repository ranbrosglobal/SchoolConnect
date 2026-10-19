import 'package:flutter_test/flutter_test.dart';
import 'package:school_connect_app/models/assignment_material.dart';
import 'package:school_connect_app/models/assignment_model.dart';

void main() {
  group('AssignmentModel materials', () {
    test('parses every uploaded file with its kind and size', () {
      final assignment = AssignmentModel.fromJson({
        'name': 'asgn-1',
        'title': 'Photosynthesis lab',
        'class_id': 'c-8a',
        'student_group_name': 'Grade 8 - A',
        'attachment': 'file-pdf',
        'attachment_name': 'worksheet.pdf',
        'files': [
          {
            'id': 'file-pdf',
            'file_id': 'file-pdf',
            'name': 'worksheet.pdf',
            'kind': 'pdf',
            'size': 2048,
            'mime_type': 'application/pdf',
          },
          {
            'id': 'file-audio',
            'name': 'voice-note.m4a',
            'kind': 'audio',
            'size': 3 * 1024 * 1024,
            'mime_type': 'audio/mp4',
          },
          {
            'id': 'file-video',
            'name': 'lesson.mp4',
            'kind': 'video',
            'size': 12 * 1024 * 1024,
            'mime_type': 'video/mp4',
          },
        ],
      });

      expect(assignment.hasMaterials, isTrue);
      expect(assignment.materials.length, 3);
      expect(assignment.materials.first.name, 'worksheet.pdf');
      expect(assignment.materials.first.kind, 'pdf');
      expect(assignment.materials.first.sizeLabel, '2 KB');
      expect(assignment.materials[1].sizeLabel, '3.0 MB');
      expect(assignment.materials[2].kind, 'video');
      // `files` wins over the legacy single-attachment fields.
      expect(assignment.materialKinds, ['pdf', 'audio', 'video']);
    });

    test('falls back to the legacy attachment when files are absent', () {
      final assignment = AssignmentModel.fromJson({
        'name': 'asgn-old',
        'title': 'Old upload',
        'attachment': 'file-legacy',
        'attachment_name': 'handout.pdf',
      });

      expect(assignment.hasMaterials, isTrue);
      expect(assignment.materials, hasLength(1));
      expect(assignment.materials.single.id, 'file-legacy');
      expect(assignment.materials.single.name, 'handout.pdf');
      expect(assignment.materials.single.kind, 'pdf');
    });

    test('reports no materials for a plain assignment', () {
      final assignment = AssignmentModel.fromJson({
        'name': 'asgn-2',
        'title': 'Read chapter 4',
      });

      expect(assignment.hasMaterials, isFalse);
      expect(assignment.materials, isEmpty);
      expect(assignment.materialKinds, isEmpty);
    });
  });

  group('material kind helpers', () {
    test('maps common audio, video and document extensions', () {
      expect(materialKindForName('note.m4a'), 'audio');
      expect(materialKindForName('note.MP3'), 'audio');
      expect(materialKindForName('clip.mov'), 'video');
      expect(materialKindForName('photo.HEIC'), 'image');
      expect(materialKindForName('slides.pptx'), 'document');
      expect(materialKindForName('archive.zip'), 'archive');
      expect(materialKindForName('worksheet.pdf'), 'pdf');
      expect(materialKindForName('no-extension'), 'file');
    });

    test('labels kinds for chips', () {
      expect(materialKindLabel('audio'), 'Voice');
      expect(materialKindLabel('pdf'), 'PDF');
      expect(materialKindLabel('video'), 'Video');
      expect(materialKindLabel('unknown'), 'File');
    });

    test('material uploads carry their own kind and size', () {
      const upload = AssignmentMaterialUpload(
        name: 'recording.ogg',
        bytes: [1, 2, 3, 4, 5],
      );
      expect(upload.kind, 'audio');
      expect(upload.size, 5);
    });
  });
}
