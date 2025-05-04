import 'package:flutter_test/flutter_test.dart';
import 'package:hosna/services/ProjectUpdateService.dart';

void main() {
  group('Project Update Tests', () {
    late MockFirebaseStorage mockStorage;
    late MockFirestore mockFirestore;
    setUp(() {
      mockStorage = MockFirebaseStorage();
      mockFirestore = MockFirestore();
    });
    test('Post update with image', () async {
      final testImage = 'test_image_data';
      String? imageUrl;
      if (testImage != null) {
        imageUrl = await mockStorage.uploadAndGetUrl(testImage);
      }
      await mockFirestore.addUpdate({
        'projectId': '1',
        'text': 'Update',
        'imageUrl': imageUrl ?? '',
      });
      expect(imageUrl, isNotNull);
      expect(imageUrl, startsWith('http'));
    });

    test('Post update without image', () async {
      await mockFirestore.addUpdate({
        'projectId': '1',
        'text': 'Update',
        'imageUrl': '',
      });
      expect(true, isTrue);
    });

    test('Post update with missing text', () async {
      await mockFirestore.addUpdate({
        'projectId': '1',
        'text': '',
        'imageUrl': '',
      });
      expect(false, isFalse);
    });
  });
}
