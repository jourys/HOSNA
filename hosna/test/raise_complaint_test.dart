import 'package:flutter_test/flutter_test.dart';
import 'package:hosna/services/ComplaintService.dart';

class MockComplaintService extends ComplaintService {
  MockComplaintService()
      : super(
          rpcUrl: 'https://test.rpc.url', // dummy URL for testing
          contractAddress: '0xTestContractAddress', // dummy address for testing
        );
}

void main() {
  group('ComplaintService Tests', () {
    late MockComplaintService complaintService;

    setUp(() {
      complaintService = MockComplaintService();
    });

    test('sendComplaint with empty title should return false', () async {
      final result = await complaintService.sendComplaint(
        title: '',
        description: 'Valid description',
        targetCharityAddress: '0x123',
      );

      expect(result, false);
    });

    test('sendComplaint with valid parameters should return true', () async {
      final result = await complaintService.sendComplaint(
        title: 'Valid title',
        description: 'Valid description',
        targetCharityAddress: '0x123',
      );

      expect(result, true);
    });
  });
}
