import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/board_cell.dart';
import '../../models/tile.dart';
import '../../core/ad_service.dart';
import '../../core/billing_service.dart';
import '../../core/toast_utils.dart';
import 'hint_service.dart';
import 'hint_engine.dart';

class HintModal extends ConsumerStatefulWidget {
  final List<List<BoardCell>> boardGrid;
  final List<Tile> playerRack;
  final Function(HintResult result) onHintGenerated;
  final VoidCallback? onHintGenerationStarted;
  final VoidCallback? onHintGenerationFinished;

  const HintModal({
    super.key,
    required this.boardGrid,
    required this.playerRack,
    required this.onHintGenerated,
    this.onHintGenerationStarted,
    this.onHintGenerationFinished,
  });

  static Future<void> show({
    required BuildContext context,
    required List<List<BoardCell>> boardGrid,
    required List<Tile> playerRack,
    required Function(HintResult result) onHintGenerated,
    VoidCallback? onHintGenerationStarted,
    VoidCallback? onHintGenerationFinished,
  }) async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => HintModal(
        boardGrid: boardGrid,
        playerRack: playerRack,
        onHintGenerated: onHintGenerated,
        onHintGenerationStarted: onHintGenerationStarted,
        onHintGenerationFinished: onHintGenerationFinished,
      ),
    );
  }

  @override
  ConsumerState<HintModal> createState() => _HintModalState();
}

class _HintModalState extends ConsumerState<HintModal> {
  bool _generating = false;
  String? _generatingHintType;
  String _helperName(String type) {
    switch (type) {
      case 'move':
        return 'Word Path';
      case 'letter':
        return 'Letter Spark';
      case 'strong':
        return 'Word Weaver';
      default:
        return 'Helper';
    }
  }

  String _helperDescription(String type) {
    switch (type) {
      case 'move':
        return 'Shows a playable word on the board';
      case 'letter':
        return 'Highlights a useful letter to play';
      case 'strong':
        return 'Reveals the strongest play available';
      default:
        return 'Gives you a little help';
    }
  }

  Future<void> _requestHint(String hintType) async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _generatingHintType = hintType;
    });
    widget.onHintGenerationStarted?.call();
    final hintNotifier = ref.read(hintServiceProvider.notifier);

    // Compute hint first to ensure legal move exists BEFORE consuming hint
    try {
      final result = await HintEngine.generateHint(
        boardGrid: widget.boardGrid,
        playerRack: widget.playerRack,
        hintType: hintType,
      );

      if (result == null) {
        if (mounted) {
          ToastUtils.showToast(
            context,
            'No legal moves found on board right now.',
            isError: true,
          );
        }
        return;
      }

      final success = await hintNotifier.consumeHint(hintType);
      if (!success) {
        if (mounted) {
          _showGetMoreHintsDialog(hintType);
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onHintGenerated(result);
      }
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
          _generatingHintType = null;
        });
      }
      widget.onHintGenerationFinished?.call();
    }
  }

  void _showGetMoreHintsDialog(String hintType) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => PremiumDialog(
        title: 'Daily Helps Used',
        child: Text(
          'You have used today\'s ${_helperName(hintType)} helps. Watch a short video or get a help pack for more.',
          style: GoogleFonts.inter(color: AppTheme.mutedIvory),
        ),
        actions: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldGreen,
              ),
              icon: const Icon(
                Icons.ondemand_video_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'WATCH VIDEO',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await AdService().showRewardedAd(
                  hintType: hintType,
                  onRewardEarned: (type, amount) async {
                    final granted = await ref
                        .read(hintServiceProvider.notifier)
                        .grantAdReward(type);
                    if (mounted) {
                      if (granted) {
                        ToastUtils.showToast(
                          context,
                          '+1 ${_helperName(type)} help earned!',
                        );
                      } else {
                        ToastUtils.showToast(
                          context,
                          'Daily ad limit reached.',
                          isError: true,
                        );
                      }
                    }
                  },
                  onError: (err) {
                    if (mounted) {
                      ToastUtils.showToast(context, err, isError: true);
                    }
                  },
                );
              },
            ),
          ),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.shinyGold,
              ),
              icon: const Icon(
                Icons.shopping_bag_rounded,
                color: Colors.black,
                size: 18,
              ),
              label: const Text(
                'GET PACK',
                style: TextStyle(color: Colors.black),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                final pack = BillingService.availablePacks.firstWhere(
                  (p) => p.hintType == hintType || p.hintType == 'mixed',
                );
                await BillingService().purchasePack(
                  pack,
                  onPurchaseFulfilled: (type, amount) async {
                    await ref
                        .read(hintServiceProvider.notifier)
                        .addPurchasedHints(type, amount);
                    if (mounted) {
                      ToastUtils.showToast(
                        context,
                        'Added $amount ${_helperName(type)} helps.',
                      );
                    }
                  },
                  onError: (error) {
                    if (mounted)
                      ToastUtils.showToast(
                        context,
                        'Purchase could not be completed.',
                        isError: true,
                      );
                    debugPrint('[Hints] Purchase failed: $error');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hintState = ref.watch(hintServiceProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF021710),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppTheme.shinyGold, width: 1.5)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose Your Help',
                  style: GoogleFonts.lora(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ivoryText,
                  ),
                ),
                IconButton(
                  icon: _generating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.shinyGold,
                          ),
                        )
                      : const Icon(Icons.close, color: AppTheme.shinyGold),
                  onPressed: _generating
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHintOptionCard(
              title: _helperName('move'),
              subtitle: _helperDescription('move'),
              icon: Icons.grid_view_rounded,
              remainingText: '${hintState.totalMoveHints()} left',
              isGenerating: _generatingHintType == 'move',
              onTap: _generating ? null : () => _requestHint('move'),
            ),
            const SizedBox(height: 12),
            _buildHintOptionCard(
              title: _helperName('letter'),
              subtitle: _helperDescription('letter'),
              icon: Icons.text_fields_rounded,
              remainingText: '${hintState.totalLetterHints()} left',
              isGenerating: _generatingHintType == 'letter',
              onTap: _generating ? null : () => _requestHint('letter'),
            ),
            const SizedBox(height: 12),
            _buildHintOptionCard(
              title: _helperName('strong'),
              subtitle: _helperDescription('strong'),
              icon: Icons.auto_awesome_rounded,
              remainingText: '${hintState.totalStrongHints()} left',
              isGenerating: _generatingHintType == 'strong',
              onTap: _generating ? null : () => _requestHint('strong'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String remainingText,
    required bool isGenerating,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppTheme.panelDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppTheme.shinyGold.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFF021710),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.shinyGold),
        ),
        title: Text(
          title,
          style: GoogleFonts.lora(
            color: AppTheme.ivoryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedIvory),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.shinyGold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.shinyGold.withValues(alpha: 0.5),
            ),
          ),
          child: isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.shinyGold,
                  ),
                )
              : Text(
                  remainingText,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.shinyGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        onTap: onTap,
      ),
    );
  }
}
