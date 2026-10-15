/// Google Play product IDs for Day One: No Contact Pro.
///
/// ============================================================================
/// PLAY CONSOLE STEP (required later — needs the user's $25 developer
/// account; cannot be done from code):
///   1. Play Console → Day One app → Monetize → Products → Subscriptions:
///      create `dayone_pro_monthly` ($4.99/mo) and `dayone_pro_yearly`
///      ($29.99/yr) with a base plan each.
///   2. Play Console → Monetize → Products → In-app products:
///      create `dayone_lifetime` ($19.99, managed product, one-time).
///   3. The IDs below MUST match the console exactly — they are referenced
///      by name throughout the billing service. Do not rename without
///      updating both sides.
/// ============================================================================
///
/// v1 note: purchase verification is client-side only (see billing_service).
/// Server-side verification requires a backend and is deferred to v1.1+.
library;

/// $4.99/month auto-renewing subscription.
const String kProMonthlyId = 'dayone_pro_monthly';

/// $29.99/year auto-renewing subscription.
const String kProYearlyId = 'dayone_pro_yearly';

/// $19.99 one-time purchase (launch offer).
const String kProLifetimeId = 'dayone_lifetime';

/// All purchasable product IDs, queried from Google Play Billing.
const Set<String> kProProductIds = {
  kProMonthlyId,
  kProYearlyId,
  kProLifetimeId,
};

/// Display prices shown in the paywall UI. These are labels only — the
/// actual charged price is whatever is configured in Play Console.
const Map<String, String> kProductDisplayPrices = {
  kProMonthlyId: '\$4.99/mo',
  kProYearlyId: '\$29.99/yr',
  kProLifetimeId: '\$19.99 once',
};
