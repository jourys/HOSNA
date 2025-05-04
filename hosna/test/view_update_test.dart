import 'package:flutter_test/flutter_test.dart';
import 'package:hosna/services/ProjectUpdateService.dart';

void main() {
  late Updates projectUpdateService;
  setUp(() {
    projectUpdateService = Updates();
  });
  group('getProjectUpdates', () {
    // Test 1: When updates exist
    test('returns list of updates with correct structure', () async {
      final updates =
          await projectUpdateService.getProjectUpdates('project_with_updates');

      // Verify list is NOT empty
      expect(updates, isNotEmpty);

      // Verify the first item is a Map with 'text' and 'timestamp'
      expect(updates[0], isA<Map<String, dynamic>>());
      expect(updates[0]['text'], isA<String>());
      expect(updates[0]['timestamp'], isA<DateTime>());
    });

    // Test 2: When NO updates exist
    test('returns empty list when no updates', () async {
      final updates = await projectUpdateService
          .getProjectUpdates('project_without_updates');
      expect(updates, isEmpty); // Check list IS empty
    });
  });
}
