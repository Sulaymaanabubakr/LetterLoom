import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../progression/progression_service.dart';
import '../../core/toast_utils.dart';
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
  List<String> _availableLetters = [];
  final List<String> _selectedLetters = [];
  int _selectedWordIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
  }

  Future<void> _loadPuzzle() async {
    final remote = await DailyChallengeService.syncRemote();
    if (remote != null) {
      if (!mounted) return;
      setState(() {
        _puzzleData = remote.data;
        _challengeState = remote.state;
        _isLoading = false;
      });
      _selectWord(_firstOpenWord(remote.state.solvedWordIndexes));
      return;
    }
    final loaded = await DailyChallengeService.loadState();
    final today = DailyChallengeService.getTodayString();
    final data = DailyChallengeService.generatePuzzle(
      today,
      streakDays: loaded.streakDays,
      puzzleId: loaded.puzzleId.isEmpty ? null : loaded.puzzleId,
      excludedPuzzleIds: loaded.playedPuzzleIds,
    );
    var state = loaded;
    if (loaded.dateStr != today || loaded.puzzleId.isEmpty) {
      state = DailyChallengeState(
        dateStr: today,
        puzzleId: data.puzzleId,
        isCompleted: false,
        scoreAchieved: 0,
        bestPossibleScore: data.targetScore,
        starRating: 0,
        streakDays: loaded.streakDays,
        playedPuzzleIds: loaded.playedPuzzleIds,
      );
      await DailyChallengeService.saveState(state);
    }
    if (!mounted) return;
    setState(() {
      _puzzleData = data;
      _challengeState = state;
      _isLoading = false;
    });
    _selectWord(_firstOpenWord(state.solvedWordIndexes));
  }

  int _firstOpenWord(List<int> solved) {
    for (var i = 0; i < _puzzleData.words.length; i++) {
      if (!solved.contains(i)) return i;
    }
    return 0;
  }

  void _selectWord(int index) {
    if (_challengeState.solvedWordIndexes.contains(index)) return;
    // Do not reset the active word when the player taps its clue card.
    if (index == _selectedWordIndex && _availableLetters.isNotEmpty) return;
    setState(() {
      _selectedWordIndex = index;
      _selectedLetters.clear();
      _availableLetters = List<String>.from(_puzzleData.words[index].letters);
    });
  }

  void _tapLetter(int index) {
    if (_challengeState.isCompleted ||
        _selectedLetters.length >=
            _puzzleData.words[_selectedWordIndex].answerLength)
      return;
    setState(() => _selectedLetters.add(_availableLetters.removeAt(index)));
    if (_selectedLetters.length ==
        _puzzleData.words[_selectedWordIndex].answerLength) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _submitWord();
      });
    }
  }

  void _clearWord() {
    if (_challengeState.isCompleted) return;
    setState(() {
      _selectedLetters.clear();
      _availableLetters = List<String>.from(
        _puzzleData.words[_selectedWordIndex].letters,
      );
    });
  }

  void _returnLastLetter() {
    if (_challengeState.isCompleted || _selectedLetters.isEmpty) return;
    setState(() {
      final lastLetter = _selectedLetters.removeLast();
      _availableLetters.add(lastLetter);
    });
  }

  void _shuffleLetters() {
    if (_challengeState.isCompleted) return;
    setState(() => _availableLetters.shuffle(Random()));
  }

  Future<void> _submitWord() async {
    if (_isSubmitting || _challengeState.isCompleted) return;
    final word = _puzzleData.words[_selectedWordIndex];
    if (_selectedLetters.length != word.answerLength) {
      ToastUtils.showToast(
        context,
        'Complete the word before submitting.',
        isError: true,
      );
      return;
    }
    if (word.answer.isNotEmpty && _selectedLetters.join() != word.answer) {
      ToastUtils.showToast(
        context,
        'That word does not match the clue. Try again.',
        isError: true,
      );
      return;
    }

    _isSubmitting = true;
    late DailyChallengeState updated;
    if (DailyChallengeService.hasRemoteAccount) {
      final remote = await DailyChallengeService.submitRemoteWord(
        wordIndex: _selectedWordIndex,
        letters: _selectedLetters,
      );
      if (remote == null) {
        _isSubmitting = false;
        if (mounted) {
          ToastUtils.showToast(
            context,
            'That word does not match the clue. Try again.',
            isError: true,
          );
        }
        return;
      }
      _puzzleData = remote.data;
      updated = remote.state;
    } else {
      final solved = [..._challengeState.solvedWordIndexes, _selectedWordIndex]
        ..sort();
      final score = solved.fold<int>(
        0,
        (sum, index) => sum + _puzzleData.words[index].answerLength,
      );
      final complete = solved.length == _puzzleData.words.length;
      final stars = complete
          ? 3
          : score >= _puzzleData.targetScore * 0.6
          ? 2
          : 1;
      final played = [..._challengeState.playedPuzzleIds];
      if (complete && !played.contains(_puzzleData.puzzleId)) {
        played.add(_puzzleData.puzzleId);
      }
      updated = DailyChallengeState(
        dateStr: _challengeState.dateStr,
        puzzleId: _challengeState.puzzleId,
        isCompleted: complete,
        scoreAchieved: score,
        bestPossibleScore: _puzzleData.targetScore,
        starRating: stars,
        streakDays: complete
            ? _challengeState.streakDays + 1
            : _challengeState.streakDays,
        solvedWordIndexes: solved,
        playedPuzzleIds: played,
      );
    }
    final complete = updated.isCompleted;
    final score = updated.scoreAchieved;
    final stars = updated.starRating;
    await DailyChallengeService.saveState(updated);
    if (complete) {
      await ref
          .read(progressionProvider)
          .addXP(150, reason: 'Daily Challenge Completed');
    }
    if (!mounted) return;
    setState(() => _challengeState = updated);
    _isSubmitting = false;
    if (complete) {
      _showResultDialog(score, _puzzleData.targetScore, stars);
    } else {
      _selectWord(_firstOpenWord(updated.solvedWordIndexes));
      ToastUtils.showToast(context, 'Word found! Keep going.');
    }
  }

  void _showResultDialog(int score, int optimal, int stars) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (context) => PremiumDialog(
        title: 'Daily Challenge Complete',
        child: Column(
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
              'Words Found: 6 / 6',
              style: GoogleFonts.lora(
                fontSize: 18,
                color: AppTheme.shinyGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Score: $score / $optimal',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.mutedIvory,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Today\'s challenge is complete. Your level progress increased.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.emeraldGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.shinyGold,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CONTINUE'),
            ),
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
    final solved = _challengeState.solvedWordIndexes;
    final selectedWord = _puzzleData.words[_selectedWordIndex];
    return Scaffold(
      backgroundColor: AppTheme.scaffoldDark,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const PremiumPageHeader(title: 'Daily Challenge'),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: FittedBox(
                      alignment: Alignment.topCenter,
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                          children: [
                            _buildStatsCard(),
                            _buildPuzzleHeading(solved.length),
                            ...List.generate(
                              _puzzleData.words.length,
                              (index) =>
                                  _buildWordCard(index, solved.contains(index)),
                            ),
                            _buildLetterTray(selectedWord),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.panelDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.45)),
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
                'Target Score: ${_puzzleData.targetScore}',
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
                Icons.local_fire_department_rounded,
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
    );
  }

  Widget _buildPuzzleHeading(int solved) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Word Mosaic',
                  style: GoogleFonts.lora(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ivoryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unscramble the clues to solve six words.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.mutedIvory,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.shinyGold.withValues(alpha: 0.65),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$solved / 6',
                  style: GoogleFonts.lora(
                    fontSize: 18,
                    color: AppTheme.shinyGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'SOLVED',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: AppTheme.mutedIvory,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(int index, bool isSolved) {
    final word = _puzzleData.words[index];
    final isSelected = index == _selectedWordIndex && !isSolved;
    final letters = isSolved
        ? (word.answer.isNotEmpty
              ? word.answer.split('')
              : List.filled(word.answerLength, ''))
        : isSelected
        ? [
            ..._selectedLetters,
            ...List.filled(
              max(0, word.answerLength - _selectedLetters.length),
              '',
            ),
          ]
        : List.filled(word.answerLength, '');
    return GestureDetector(
      onTap: () => _selectWord(index),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSolved
              ? AppTheme.shinyGold.withValues(alpha: 0.12)
              : AppTheme.panelDark,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? AppTheme.shinyGold
                : AppTheme.shinyGold.withValues(alpha: 0.35),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSolved ? AppTheme.shinyGold : Colors.transparent,
                border: Border.all(
                  color: AppTheme.shinyGold.withValues(alpha: 0.7),
                ),
              ),
              child: Center(
                child: isSolved
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppTheme.darkCharcoal,
                        size: 18,
                      )
                    : Text(
                        '${index + 1}',
                        style: GoogleFonts.lora(
                          color: AppTheme.ivoryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                word.clue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.ivoryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 3,
              children: List.generate(letters.length, (letterIndex) {
                final isLastPlayedLetter =
                    isSelected &&
                    letterIndex == _selectedLetters.length - 1 &&
                    letterIndex >= 0;
                final slot = _letterSlot(
                  letters[letterIndex],
                  isSolved,
                  isSelected && letterIndex < _selectedLetters.length,
                );
                return isLastPlayedLetter
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _returnLastLetter,
                        child: SizedBox(
                          width: 30,
                          height: 32,
                          child: Center(child: slot),
                        ),
                      )
                    : slot;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _letterSlot(String letter, bool solved, [bool filled = false]) {
    return Container(
      width: 20,
      height: 23,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: solved || filled ? AppTheme.shinyGold : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppTheme.shinyGold.withValues(
            alpha: solved || filled ? 0.95 : 0.55,
          ),
        ),
      ),
      child: Text(
        letter,
        style: GoogleFonts.lora(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: solved || filled ? AppTheme.darkCharcoal : AppTheme.ivoryText,
        ),
      ),
    );
  }

  Widget _buildLetterTray(DailyWord word) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: AppTheme.panelDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.shinyGold.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(
            'Your Letters',
            textAlign: TextAlign.center,
            style: GoogleFonts.lora(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.ivoryText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Clue: ${word.clue}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedIvory),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _shuffleLetters,
                icon: const Icon(Icons.shuffle_rounded, size: 16),
                label: const Text('SHUFFLE'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.shinyGold,
                  side: BorderSide(
                    color: AppTheme.shinyGold.withValues(alpha: 0.7),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 34),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _selectedLetters.isEmpty ? null : _clearWord,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('CLEAR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.shinyGold,
                  disabledForegroundColor: AppTheme.mutedIvory.withValues(
                    alpha: 0.45,
                  ),
                  side: BorderSide(
                    color: AppTheme.shinyGold.withValues(alpha: 0.7),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 34),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: List.generate(
              _availableLetters.length,
              (index) => GestureDetector(
                onTap: () => _tapLetter(index),
                child: Container(
                  width: 39,
                  height: 45,
                  alignment: Alignment.center,
                  decoration: AppTheme.tileDecoration(),
                  child: Text(
                    _availableLetters[index],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.tileText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
