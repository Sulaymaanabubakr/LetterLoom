import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/board_cell.dart';
import '../../models/tile.dart';
import '../../core/ad_service.dart';
import '../../core/toast_utils.dart';
import '../auth/auth_service.dart';
import 'boost_shop_screen.dart';
import 'hint_service.dart';
import 'hint_engine.dart';

class HintModal extends ConsumerStatefulWidget {
  final List<List<BoardCell>> boardGrid;
  final List<Tile> playerRack;
  final Function(HintResult result) onHintGenerated;
  final VoidCallback? onModalOpened;
  final VoidCallback? onModalClosed;

  const HintModal({
    super.key,
    required this.boardGrid,
    required this.playerRack,
    required this.onHintGenerated,
    this.onModalOpened,
    this.onModalClosed,
  });

  static Future<void> show({
    required BuildContext context,
    required List<List<BoardCell>> boardGrid,
    required List<Tile> playerRack,
    required Function(HintResult result) onHintGenerated,
    VoidCallback? onModalOpened,
    VoidCallback? onModalClosed,
  }) async {
    onModalOpened?.call();
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => HintModal(
          boardGrid: boardGrid,
          playerRack: playerRack,
          onHintGenerated: onHintGenerated,
          onModalOpened: onModalOpened,
          onModalClosed: onModalClosed,
        ),
      );
    } finally {
      onModalClosed?.call();
    }
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
          // Replace the help sheet with one modal. Stacking a second sheet on
          // top of this one was the source of the cramped, inconsistent UI.
          final rootContext = Navigator.of(context, rootNavigator: true).context;
          // Keep a second pause lease while replacing this sheet with the
          // boost dialog. The sheet's close callback releases only its lease.
          widget.onModalOpened?.call();
          await Navigator.of(context).maybePop();
          if (rootContext.mounted) {
            final openBoostShop = await _showGetMoreHintsDialog(
              rootContext,
              hintType,
            );
            if (openBoostShop == true && rootContext.mounted) {
              await Navigator.of(rootContext).push(
                MaterialPageRoute(builder: (_) => const BoostShopScreen()),
              );
            }
          }
          widget.onModalClosed?.call();
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
    }
  }

  Future<bool?> _showGetMoreHintsDialog(
    BuildContext dialogContext,
    String hintType,
  ) {
    return showDialog<bool>(
      context: dialogContext,
      useSafeArea: false,
      builder: (context) => PremiumDialog(
        title: 'Get more help',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You have used today\'s ${_helperName(hintType)} helps. Watch ads or choose a boost pack to keep playing.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.mutedIvory),
            ),
          ],
        ),
        actions: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(false);
                await AdService().showRewardedAd(
                  hintType: hintType,
                  onRewardEarned: (type, amount) async {
                    final granted = await ref
                        .read(hintServiceProvider.notifier)
                        .grantAdReward(type);
                    if (dialogContext.mounted) {
                      ToastUtils.showToast(
                        dialogContext,
                        granted
                            ? '+1 ${_helperName(type)} help earned!'
                            : 'Daily ad limit reached.',
                        isError: !granted,
                      );
                    }
                  },
                  onError: (error) {
                    if (dialogContext.mounted) {
                      ToastUtils.showToast(dialogContext, error, isError: true);
                    }
                  },
                );
              },
              icon: const Icon(Icons.ondemand_video_rounded, size: 17),
              label: const Text('WATCH ADS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.shopping_bag_rounded, size: 17),
              label: const Text('BOOST SHOP'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.shinyGold, foregroundColor: AppTheme.darkCharcoal),
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
