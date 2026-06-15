enum SubscriptionType {
  free,
  student,
  premium;

  bool get hasAccess => this != free;

  String get displayLabel => switch (this) {
        free => 'Free plan',
        student => 'Student Access',
        premium => 'Premium',
      };

  static SubscriptionType fromString(String? value) => switch (value) {
        'student' => student,
        'premium' => premium,
        _ => free,
      };
}
