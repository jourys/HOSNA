import 'package:flutter_test/flutter_test.dart';
import 'package:hosna/services/ProjectService.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';

class MockBlockchainService extends BlockchainService {
  @override
  Future<void> addProject(String name, String description, int startDate,
      int deadline, double totalAmount, String type) async {
    // simulate success
  }
}

class FailingBlockchainService implements BlockchainService {
  @override
  Future<void> addProject(
    String name,
    String description,
    int startDate,
    int deadline,
    double totalAmount,
    String type,
  ) async {
    throw Exception('Simulated blockchain failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('postProject test case', () async {
    final projectService = ProjectService();
    final result = await projectService.postProject(
      name: "Test Project",
      description: "Test Description",
      startDate: 1746199614,
      deadline: 1748878014,
      totalAmount: 100.0,
      type: "Health",
      blockchainService: MockBlockchainService(),
    );
    expect(result, true);
  });

  test('postProject test case if name is missing', () async {
    final projectService = ProjectService();
    final result = await projectService.postProject(
      name: "",
      description: "Test Description",
      startDate: 1746199614,
      deadline: 1748878014,
      totalAmount: 100.0,
      type: "Health",
      blockchainService: MockBlockchainService(),
    );
    expect(result, false);
  });

  test('postProject test case with invalid start date and end date', () async {
    final projectService = ProjectService();
    final result = await projectService.postProject(
      name: "",
      description: "Test Description",
      startDate: 1748878014,
      deadline: 1746199614,
      totalAmount: 100.0,
      type: "Health",
      blockchainService: MockBlockchainService(),
    );
    expect(result, false);
  });

  test('postProject test case with total amount 0', () async {
    final projectService = ProjectService();
    final result = await projectService.postProject(
      name: "",
      description: "Test Description",
      startDate: 1672531200,
      deadline: 1675219600,
      totalAmount: 0.0,
      type: "Health",
      blockchainService: MockBlockchainService(),
    );

    expect(result, false);
  });

  test('postProject returns false when blockchainService throws an exception',
      () async {
    final projectService = ProjectService();
    final failingService = FailingBlockchainService();

    final result = await projectService.postProject(
      name: "Test Project",
      description: "Test Description",
      startDate: 1672531200,
      deadline: 1675219600,
      totalAmount: 1000.0,
      type: "Health",
      blockchainService: failingService,
    );

    expect(result, false);
  });
}
