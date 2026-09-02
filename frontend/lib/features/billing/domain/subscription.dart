class Subscription {
  const Subscription({
    required this.plan,
    required this.status,
    required this.billingMode,
    required this.isPremium,
    this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
  });

  final String plan;
  final String status;
  final String billingMode;
  final bool isPremium;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        plan: json['plan'] as String,
        status: json['status'] as String,
        billingMode: json['billing_mode'] as String,
        isPremium: json['is_premium'] as bool,
        currentPeriodEnd: json['current_period_end'] != null ? DateTime.parse(json['current_period_end'] as String) : null,
        cancelAtPeriodEnd: json['cancel_at_period_end'] as bool,
      );
}
