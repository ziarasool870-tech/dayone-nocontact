/// Day One Pro paywall — REAL Google Play Billing.
///
/// Products come from Play Console via [BillingService]; prices shown are
/// the store's own. Handles pending / cancelled / error states honestly.
library;

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../billing/billing_products.dart';
import '../services/billing_service.dart';
import '../theme/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = kProYearlyId; // best value pre-selected
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ValueListenableBuilder<BillingUiState>(
        valueListenable: BillingService.instance.uiState,
        builder: (context, state, _) {
          if (state.isPro) {
            return _proActive();
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      DayOneColors.gold,
                      Color(0xFFE8C89F)
                    ]),
                  ),
                  alignment: Alignment.center,
                  child: const Text('★',
                      style:
                          TextStyle(fontSize: 32, color: Colors.white)),
                ),
                const SizedBox(height: 14),
                const Text('Day One Pro',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                  'Go deeper in your healing.\nCore stays free forever.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: DayOneColors.muted),
                ),
                const SizedBox(height: 20),
                _feature('90-day guided program',
                    'One 2-minute healing task a day'),
                _feature('Unsent-letter vault',
                    'Write what you\'ll never send'),
                _feature('Premium milestone art',
                    'Dark & gold cards, made to be posted'),
                _feature('Widget themes + ad-free',
                    'Your streak, your style'),
                const SizedBox(height: 20),
                if (!state.storeAvailable)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Google Play Billing isn\'t available here. Pro needs the Play Store version of the app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15, color: DayOneColors.muted),
                      ),
                    ),
                  )
                else if (state.products.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        state.lastError ??
                            'Loading Pro options…',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, color: DayOneColors.muted),
                      ),
                    ),
                  )
                else
                  ..._productCards(state),
                if (state.pendingProductId != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Waiting for Play Store…',
                            style: TextStyle(
                                fontSize: 15,
                                color: DayOneColors.muted)),
                      ],
                    ),
                  ),
                if (state.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(state.lastError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14.5, color: DayOneColors.sos)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (state.storeAvailable &&
                            _selectedId != null &&
                            state.pendingProductId == null)
                        ? () => BillingService.instance
                            .buy(_selectedId!)
                        : null,
                    child: const Text('Go Pro'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: state.restoring
                      ? null
                      : () =>
                          BillingService.instance.restorePurchases(),
                  child: Text(state.restoring
                      ? 'Checking your purchases…'
                      : 'Restore purchases'),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Billed by Google Play. Cancel anytime in the Play Store.\nSubscriptions auto-renew unless cancelled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: DayOneColors.faint, height: 1.5),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _proActive() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  DayOneColors.gold,
                  Color(0xFFE8C89F)
                ]),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check,
                  size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('Day One Pro is active',
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Thank you for investing in your own healing. Premium art, the letter vault and the 90-day program are yours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, height: 1.55, color: DayOneColors.muted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to my journey'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DayOneColors.sageSoft,
            ),
            child: const Icon(Icons.check,
                size: 18, color: DayOneColors.sage),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w700)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 14.5, color: DayOneColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _productCards(BillingUiState state) {
    // Order: monthly, yearly, lifetime.
    final order = [kProMonthlyId, kProYearlyId, kProLifetimeId];
    final byId = {for (final p in state.products) p.id: p};
    final cards = <Widget>[];
    for (final id in order) {
      final product = byId[id];
      if (product == null) continue;
      final selected = _selectedId == id;
      final isLifetime = id == kProLifetimeId;
      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => setState(() => _selectedId = id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? DayOneColors.terracotta
                      : DayOneColors.cardBorder,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected
                        ? DayOneColors.terracotta
                        : DayOneColors.faint,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_titleFor(id, product),
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            if (id == kProYearlyId) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: DayOneColors.sageSoft,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: const Text('BEST VALUE',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: DayOneColors.sage)),
                              ),
                            ],
                            if (isLifetime) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: DayOneColors.goldSoft,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: const Text('LAUNCH',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF8A5A1E))),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(product.description.isNotEmpty
                                ? product.description
                                : _subFor(id),
                            style: const TextStyle(
                                fontSize: 14,
                                color: DayOneColors.muted)),
                      ],
                    ),
                  ),
                  Text(product.price,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return cards;
  }

  String _titleFor(String id, ProductDetails product) {
    if (product.title.isNotEmpty) {
      // Play titles often look like "Day One Pro (Day One: No Contact)".
      // Keep the store's own title when present.
      return product.title;
    }
    return switch (id) {
      kProMonthlyId => 'Monthly',
      kProYearlyId => 'Yearly',
      _ => 'Lifetime',
    };
  }

  String _subFor(String id) => switch (id) {
        kProMonthlyId => 'Billed monthly · cancel anytime',
        kProYearlyId => 'Billed yearly · two months free',
        _ => 'One payment · yours forever',
      };
}
