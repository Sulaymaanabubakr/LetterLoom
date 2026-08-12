import 'package:flutter_test/flutter_test.dart';
import 'package:letterloom/core/billing_service.dart';

void main() {
  test('billing cancellation never exposes a raw store message', () {
    expect(
      BillingService.purchaseErrorMessage('USER_CANCELED'),
      'Purchase canceled.',
    );
  });

  test('unknown billing errors use a safe generic message', () {
    expect(
      BillingService.purchaseErrorMessage('SERVICE_DISCONNECTED: raw payload'),
      'We could not complete that purchase. Please try again.',
    );
  });
}
