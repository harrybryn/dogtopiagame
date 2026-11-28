class BreedingSession {
  final String parent1Id;
  final String parent2Id;
  final String parent1BreedId;
  final String parent2BreedId;
  final String resultBreedId;
  final String resultElement;
  final int startedAt;
  int endsAt;
  bool readyNotified;

  BreedingSession({
    required this.parent1Id,
    required this.parent2Id,
    required this.parent1BreedId,
    required this.parent2BreedId,
    required this.resultBreedId,
    required this.resultElement,
    required this.startedAt,
    required this.endsAt,
    this.readyNotified = false,
  });

  bool get isReady => DateTime.now().millisecondsSinceEpoch >= endsAt;

  int get remainingSeconds {
    final diff = endsAt - DateTime.now().millisecondsSinceEpoch;
    return diff > 0 ? (diff / 1000).ceil() : 0;
  }

  double get progress {
    final total = endsAt - startedAt;
    if (total <= 0) return 1.0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'parent1Id': parent1Id,
        'parent2Id': parent2Id,
        'parent1BreedId': parent1BreedId,
        'parent2BreedId': parent2BreedId,
        'resultBreedId': resultBreedId,
        'resultElement': resultElement,
        'startedAt': startedAt,
        'endsAt': endsAt,
        'readyNotified': readyNotified,
      };

  factory BreedingSession.fromJson(Map<String, dynamic> json) {
    return BreedingSession(
      parent1Id: json['parent1Id'] as String? ?? '',
      parent2Id: json['parent2Id'] as String? ?? '',
      parent1BreedId: json['parent1BreedId'] as String? ?? 'english-bulldog',
      parent2BreedId: json['parent2BreedId'] as String? ?? 'english-bulldog',
      resultBreedId: json['resultBreedId'] as String? ?? 'english-bulldog',
      resultElement: json['resultElement'] as String? ?? 'Garden Element',
      startedAt: (json['startedAt'] as num?)?.toInt() ?? 0,
      endsAt: (json['endsAt'] as num?)?.toInt() ?? 0,
      readyNotified: json['readyNotified'] as bool? ?? false,
    );
  }
}

class ShopOfferRule {
  final String id;
  final int cooldownSeconds;
  final int maxPurchasesPerWindow;
  final int requiredLevel;

  const ShopOfferRule({
    required this.id,
    required this.cooldownSeconds,
    this.maxPurchasesPerWindow = 1,
    this.requiredLevel = 1,
  });

  static const Map<String, ShopOfferRule> rules = {
    // Diamond Packs (PHP) - anti-exploit cooldowns & level gates
    'diam_pile': ShopOfferRule(id: 'diam_pile', cooldownSeconds: 12 * 3600, maxPurchasesPerWindow: 2, requiredLevel: 1),
    'diam_bag': ShopOfferRule(id: 'diam_bag', cooldownSeconds: 24 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 1),
    'diam_chest': ShopOfferRule(id: 'diam_chest', cooldownSeconds: 48 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 2),
    'diam_vault': ShopOfferRule(id: 'diam_vault', cooldownSeconds: 72 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 4),
    'diam_treasury': ShopOfferRule(id: 'diam_treasury', cooldownSeconds: 72 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 6),
    'diam_mountain': ShopOfferRule(id: 'diam_mountain', cooldownSeconds: 72 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 8),

    // Gold Packs (PHP)
    'gold_pouch': ShopOfferRule(id: 'gold_pouch', cooldownSeconds: 12 * 3600, maxPurchasesPerWindow: 2, requiredLevel: 1),
    'gold_sack': ShopOfferRule(id: 'gold_sack', cooldownSeconds: 24 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 1),
    'gold_chest': ShopOfferRule(id: 'gold_chest', cooldownSeconds: 48 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 2),
    'gold_vault': ShopOfferRule(id: 'gold_vault', cooldownSeconds: 72 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 4),
    'gold_treasury': ShopOfferRule(id: 'gold_treasury', cooldownSeconds: 72 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 6),
    'gold_mountain': ShopOfferRule(id: 'gold_mountain', cooldownSeconds: 72 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 8),

    // Diamond -> Coin Conversion
    'conv_pouch': ShopOfferRule(id: 'conv_pouch', cooldownSeconds: 12 * 3600, maxPurchasesPerWindow: 3, requiredLevel: 1),
    'conv_sack': ShopOfferRule(id: 'conv_sack', cooldownSeconds: 24 * 3600, maxPurchasesPerWindow: 2, requiredLevel: 2),
    'conv_chest': ShopOfferRule(id: 'conv_chest', cooldownSeconds: 24 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 3),
    'conv_mountain': ShopOfferRule(id: 'conv_mountain', cooldownSeconds: 48 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 5),
    'conv_treasury': ShopOfferRule(id: 'conv_treasury', cooldownSeconds: 72 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 7),
    'conv_royal': ShopOfferRule(id: 'conv_royal', cooldownSeconds: 72 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 10),

    // Kibble Packs
    'kibble_treat': ShopOfferRule(id: 'kibble_treat', cooldownSeconds: 6 * 3600, maxPurchasesPerWindow: 3, requiredLevel: 1),
    'kibble_snack': ShopOfferRule(id: 'kibble_snack', cooldownSeconds: 12 * 3600, maxPurchasesPerWindow: 2, requiredLevel: 1),
    'kibble_sack': ShopOfferRule(id: 'kibble_sack', cooldownSeconds: 24 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 2),
    'kibble_crate': ShopOfferRule(id: 'kibble_crate', cooldownSeconds: 24 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 3),
    'kibble_banquet': ShopOfferRule(id: 'kibble_banquet', cooldownSeconds: 48 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 5),
    'kibble_royal': ShopOfferRule(id: 'kibble_royal', cooldownSeconds: 72 * 3600, maxPurchasesPerWindow: 1, requiredLevel: 8),
  };

  static ShopOfferRule? findById(String id) => rules[id];
}

class ShopOfferState {
  final String offerId;
  int purchasesInWindow;
  int windowStartedAt;
  int cooldownEndsAt;

  ShopOfferState({
    required this.offerId,
    this.purchasesInWindow = 0,
    this.windowStartedAt = 0,
    this.cooldownEndsAt = 0,
  });

  bool isOnCooldown([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return now < cooldownEndsAt;
  }

  int remainingCooldownSeconds([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final diff = cooldownEndsAt - now;
    return diff > 0 ? (diff / 1000).ceil() : 0;
  }

  Map<String, dynamic> toJson() => {
        'offerId': offerId,
        'purchasesInWindow': purchasesInWindow,
        'windowStartedAt': windowStartedAt,
        'cooldownEndsAt': cooldownEndsAt,
      };

  factory ShopOfferState.fromJson(Map<String, dynamic> json) {
    return ShopOfferState(
      offerId: json['offerId'] as String? ?? '',
      purchasesInWindow: (json['purchasesInWindow'] as num?)?.toInt() ?? 0,
      windowStartedAt: (json['windowStartedAt'] as num?)?.toInt() ?? 0,
      cooldownEndsAt: (json['cooldownEndsAt'] as num?)?.toInt() ?? 0,
    );
  }
}
