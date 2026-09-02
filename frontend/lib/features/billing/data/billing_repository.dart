import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/subscription.dart';

class BillingRepository {
  BillingRepository(this._dio);

  final Dio _dio;

  Future<Subscription> fetchSubscription() async {
    final resp = await _dio.get('/billing/subscription');
    return Subscription.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Returns the Stripe Checkout URL to open (real mode), or null when
  /// running in mock billing mode — the account is upgraded immediately
  /// server-side and there's nothing to open.
  Future<String?> startCheckout() async {
    final resp = await _dio.post('/billing/checkout-session', data: {});
    return resp.data['checkout_url'] as String?;
  }

  /// Real mode: a Stripe billing-portal URL to manage/cancel. Mock mode:
  /// null — the downgrade already happened server-side.
  Future<String?> startPortal() async {
    final resp = await _dio.post('/billing/portal-session', data: {});
    return resp.data['portal_url'] as String?;
  }
}

final billingRepositoryProvider = Provider<BillingRepository>((ref) => BillingRepository(ref.watch(dioProvider)));

final subscriptionProvider = FutureProvider.autoDispose<Subscription>((ref) {
  return ref.watch(billingRepositoryProvider).fetchSubscription();
});
