import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/board_cell.dart';
import '../../models/tile.dart';
import '../../game_engine/rules_validator.dart';
import '../../core/toast_utils.dart';
import '../../core/supabase_bootstrap.dart';
import '../progression/progression_service.dart';
import 'daily_challenge_service.dart';

class DailyChallengeScreen extends ConsumerStatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  ConsumerState<DailyChallengeScreen> createState() =>
      _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen> {
  late DailyChallengeData _puzzleData;
  late DailyChallengeState _challengeState;
  late List<List<BoardCell>> _boardGrid;
  late List<Tile> _rack;
  Tile? _selectedTile;
  bool _isLoading = true;
  bool _isSubmitting = false;
  final RulesValidator _rulesValidator = RulesValidator();

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
  }

  Future<void> _loadPuzzle() async {
    _puzzleData = DailyChallengeService.generatePuzzle();
    _challengeState = await DailyChallengeService.loadState();
    _boardGrid = List.generate(
      _puzzleData.boardGrid.length,
      (r) => List.generate(
        _puzzleData.boardGrid[r].length,
        (c) => _puzzleData.boardGrid[r][c],
      ),
    );
    _rack = List.from(_puzzleData.rack);

    setState(() {
      _isLoading = false;
    });
  }

  void _onCellTap(int row, int col) {
    if (_challengeState.isCompleted) return;
    final cell = _boardGrid[row][col];

    if (cell.tile != null && cell.isNewPlacement) {
      setState(() {
        _rack.add(cell.tile!);
        _boardGrid[row][col] = cell.copyWith(
          clearTile: true,
          isNewPlacement: false,
        );
      });
      return;
    }

    if (_selectedTile != null) {
      if (cell.tile == null) {
        setState(() {
          _boardGrid[row][col] = cell.copyWith(
            tile: _selectedTile,
            isNewPlacement: true,
          );
          _rack.removeWhere((t) => t.id == _selectedTile!.id);
          _selectedTile = null;
        });
      }
    }
  }

  bool get _hasNewPlacements => _boardGrid.any(
    (row) => row.any((cell) => cell.tile != null && cell.isNewPlacement),
  );

  void _returnPlacedTiles() {
    if (!_hasNewPlacements || _challengeState.isCompleted) return;
    final returned = <Tile>[];
    setState(() {
      for (var row = 0; row < _boardGrid.length; row++) {
        for (var col = 0; col < _boardGrid[row].length; col++) {
          final cell = _boardGrid[row][col];
          if (cell.tile != null && cell.isNewPlacement) {
            returned.add(cell.tile!);
            _boardGrid[row][col] = cell.copyWith(
              clearTile: true,
              isNewPlacement: false,
            );
          }
        }
      }
      _rack.addAll(returned);
      _selectedTile = null;
    });
  }

  void _submitMove() async {
    if (_isSubmitting || _challengeState.isCompleted) return;
    _isSubmitting = true;
    final user = SupabaseBootstrap.configured
        ? Supabase.instance.client.auth.currentUser
        : null;
    if (user != null && !user.isAnonymous) {
      _isSubmitting = false;
      ToastUtils.showToast(
        context,
        'Daily Challenge rewards are temporarily unavailable until server validation is enabled.',
        isError: true,
      );
      return;
    }
    final validation = _rulesValidator.validateMove(_boardGrid);
    if (!validation.isValid) {
      _isSubmitting = false;
      ToastUtils.showToast(
        context,
        validation.errorMessage ?? 'Invalid move',
        isError: true,
      );
      return;
    }

    final score = validation.totalScore;
    final optimal = _puzzleData.optimalScore;
    int stars = 1;
    if (score >= optimal * 0.9) {
      stars = 3;
    } else if (score >= optimal * 0.6) {
      stars = 2;
    }

    final newStreak = _challengeState.streakDays + 1;
    final newState = DailyChallengeState(
      dateStr: _challengeState.dateStr,
      isCompleted: true,
      scoreAchieved: score,
      bestPossibleScore: optimal,
      starRating: stars,
      streakDays: newStreak,
    );

    await DailyChallengeService.saveState(newState);
    await ref
        .read(progressionProvider)
        .addXP(150, reason: 'Daily Challenge Completed');

    setState(() {
      _challengeState = newState;
    });

    if (mounted) {
      _showResultDialog(score, optimal, stars);
    }
    _isSubmitting = false;
  }

  void _showResultDialog(int score, int optimal, int stars) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.panelDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.shinyGold, width: 1.5),
        ),
        title: Text(
          'Daily Challenge Complete!',
          textAlign: TextAlign.center,
          style: GoogleFonts.lora(
            color: AppTheme.ivoryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Icon(
                  i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: AppTheme.shinyGold,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Move Score: $score',
              style: GoogleFonts.lora(
                fontSize: 18,
                color: AppTheme.shinyGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Best Possible: $optimal',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.mutedIvory,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '+150 XP Awarded!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.emeraldGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.shinyGold,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldDark,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.shinyGold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldDark,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const PremiumPageHeader(title: 'Daily Challenge'),
              Expanded(
                child: Column(
                  children: [
                    // Header stats bar
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.panelDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.shinyGold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date: ${_challengeState.dateStr}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.mutedIvory,
                                ),
                              ),
                              Text(
                                'Target Score: ${_puzzleData.optimalScore}',
                                style: GoogleFonts.lora(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.shinyGold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                color: Colors.orange,
                                size: 22,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_challengeState.streakDays} Day Streak',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.ivoryText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Board View (Compact 15x15)
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF031610),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.shinyGold.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 225,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 15,
                                ),
                            itemBuilder: (context, index) {
                              final r = index ~/ 15;
                              final c = index % 15;
                              final cell = _boardGrid[r][c];
                              return GestureDetector(
                                onTap: () => _onCellTap(r, c),
                                child: Container(
                                  margin: const EdgeInsets.all(0.5),
                                  decoration: AppTheme.cellDecoration(
                                    cell.type,
                                  ),
                                  child: Center(
                                    child: cell.tile != null
                                        ? Text(
                                            cell.tile!.displayLetter,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: cell.isNewPlacement
                                                  ? AppTheme.shinyGold
                                                  : Colors.white,
                                            ),
                                          )
                                        : Text(
                                            AppTheme.cellLabel(cell.type),
                                            style: const TextStyle(
                                              fontSize: 7,
                                              color: Colors.white38,
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    // Player Rack
                    Container(
                      height: 112,
                      margin: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.panelDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.shinyGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedTile == null
                                      ? (_hasNewPlacements
                                            ? 'Tap a placed letter to return it, or press Return.'
                                            : 'Select a letter, then tap an empty board square.')
                                      : 'Now tap an empty board square to place ${_selectedTile!.displayLetter}.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.mutedIvory,
                                  ),
                                ),
                              ),
                              if (_hasNewPlacements)
                                TextButton.icon(
                                  onPressed: _returnPlacedTiles,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(
                                    Icons.undo_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Return'),
                                ),
                            ],
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _rack.map((tile) {
                                final isSelected = _selectedTile?.id == tile.id;
                                return GestureDetector(
                                  onTap: () {
                                    if (_challengeState.isCompleted) return;
                                    setState(() {
                                      _selectedTile = isSelected ? null : tile;
                                    });
                                  },
                                  child: Container(
                                    width: 42,
                                    height: 48,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: AppTheme.tileDecoration(
                                      isSelected: isSelected,
                                    ),
                                    child: Center(
                                      child: Text(
                                        tile.displayLetter,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.tileText,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Submit Button
                    if (!_challengeState.isCompleted)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 20,
                          left: 24,
                          right: 24,
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.shinyGold,
                            foregroundColor: const Color(0xFF1E1402),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: Text(
                            'Submit Challenge Move',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _submitMove,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          'Challenge Completed! Come back tomorrow for a new puzzle.',
                          style: GoogleFonts.inter(
                            color: AppTheme.shinyGold,
                            fontWeight: FontWeight.bold,
                          ),
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
}
