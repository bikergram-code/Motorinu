import '../../domain/models/subscription.dart';
import '../datasources/remote/bikergram_api_service.dart';

class PaymentRepository {
  PaymentRepository({required BikergramApiService apiService})
      : _api = apiService;

  final BikergramApiService _api;

  /// Creates a Stripe Checkout session and returns the session URL.
  Future<String> createCheckoutSession({
    required String priceId,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final data = await _api.createCheckoutSession(
      priceId: priceId,
      successUrl: successUrl,
      cancelUrl: cancelUrl,
    );
    return data['url'] ?? data['sessionUrl'] ?? '';
  }

  /// Creates a Stripe Customer Portal session for managing subscriptions.
  Future<String> createPortalSession() async {
    final data = await _api.createPortalSession();
    return data['url'] ?? '';
  }

  /// Gets the current subscription status.
  Future<Subscription?> getSubscriptionStatus() async {
    try {
      final data = await _api.getSubscriptionStatus();
      if (data['subscription'] == null) return null;
      return Subscription.fromJson(data['subscription'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
