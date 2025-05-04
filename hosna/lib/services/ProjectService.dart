import 'package:hosna/screens/CharityScreens/BlockchainService.dart';

class ProjectService {
  Future<bool> postProject({
    required String name,
    required String description,
    required int startDate,
    required int deadline,
    required double totalAmount,
    required String type,
    required BlockchainService blockchainService,
  }) async {
    // Add validation
    if (name.isEmpty ||
        description.isEmpty ||
        totalAmount <= 0 ||
        deadline <= startDate) {
      print("Missing or Invalid input. Posting project failed.");
      return false;
    }

    try {
      await blockchainService.addProject(
        name,
        description,
        startDate,
        deadline,
        totalAmount,
        type,
      );
      return true;
    } catch (e) {
      print("Blockchain error: $e");
      return false;
    }
  }
}
