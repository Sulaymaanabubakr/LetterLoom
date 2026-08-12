import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/billing_service.dart';
import '../../core/toast_utils.dart';
import '../../theme/app_theme.dart';
import 'hint_service.dart';

class BoostShopScreen extends ConsumerStatefulWidget {
  const BoostShopScreen({super.key});

  @override
  ConsumerState<BoostShopScreen> createState() => _BoostShopScreenState();
}

class _BoostShopScreenState extends ConsumerState<BoostShopScreen> {
  Map<String, String> _livePrices = const {};

  @override
  void initState() {
    super.initState();
    _loadLivePrices();
  }

  Future<void> _loadLivePrices() async {
    final billing = BillingService();
    await billing.refreshStoreProducts();
    if (!mounted) return;
    setState(() {
      _livePrices = {
        for (final entry in billing.storeProducts.entries)
          entry.key: entry.value.price,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final hints = ref.watch(hintServiceProvider);
    return Scaffold(
      backgroundColor: AppTheme.scaffoldDark,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const PremiumPageHeader(title: 'Boost Shop'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  children: [
                    Text(
                      'Keep a helpful move within reach.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lora(
                        color: AppTheme.ivoryText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Purchases are verified before they are added to your balance.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppTheme.mutedIvory,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionTitle('YOUR BALANCE'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _balanceCard('Move', hints.totalMoveHints()),
                        const SizedBox(width: 8),
                        _balanceCard('Letter', hints.totalLetterHints()),
                        const SizedBox(width: 8),
                        _balanceCard('Strong', hints.totalStrongHints()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('BOOST PACKS'),
                    const SizedBox(height: 8),
                    ...BillingService.availablePacks.map(
                      (pack) => _packCard(
                        context,
                        ref,
                        pack,
                        _livePrices[pack.productId] ?? pack.price,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.inter(
      color: AppTheme.shinyGold,
      fontWeight: FontWeight.bold,
      fontSize: 12,
      letterSpacing: 1.1,
    ),
  );

  Widget _balanceCard(String label, int amount) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.panelDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.shinyGold.withValues(alpha: .4)),
      ),
      child: Column(
        children: [
          Text(
            '$amount',
            style: GoogleFonts.lora(
              color: AppTheme.ivoryText,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: AppTheme.mutedIvory,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _packCard(
    BuildContext context,
    WidgetRef ref,
    PurchasedHintPack pack,
    String price,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.panelDark,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.shinyGold.withValues(alpha: .45)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pack.title,
                style: GoogleFonts.lora(
                  color: AppTheme.ivoryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                pack.description,
                style: GoogleFonts.inter(
                  color: AppTheme.mutedIvory,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () => _buy(context, ref, pack),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.shinyGold,
            foregroundColor: AppTheme.darkCharcoal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
          child: Text(
            price,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  Future<void> _buy(
    BuildContext context,
    WidgetRef ref,
    PurchasedHintPack pack,
  ) => BillingService().purchasePack(
    pack,
    onPurchaseFulfilled: () async {
      await ref.read(hintServiceProvider.notifier).refresh();
      if (context.mounted) {
        ToastUtils.showToast(
          context,
          '${pack.title} added. Your new balance is visible above and in the Helps header.',
        );
      }
    },
    onError: (error) {
      if (context.mounted) ToastUtils.showToast(context, error, isError: true);
    },
  );
}
