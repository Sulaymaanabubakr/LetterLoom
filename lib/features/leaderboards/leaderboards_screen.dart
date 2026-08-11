import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_service.dart';
import 'leaderboards_service.dart';

class LeaderboardsScreen extends ConsumerStatefulWidget {
  const LeaderboardsScreen({super.key});

  @override
  ConsumerState<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends ConsumerState<LeaderboardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCategory('rating');
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final cat = _tabController.index == 0
        ? 'rating'
        : _tabController.index == 1
        ? 'wins'
        : 'game_score';
    _loadCategory(cat);
  }

  Future<void> _loadCategory(String category) async {
    setState(() {
      _isLoading = true;
    });

    final currentUserId = ref.read(authProvider).id;
    final data = await LeaderboardsService.fetchLeaderboard(
      category: category,
      currentUserId: currentUserId,
    );

    if (mounted) {
      setState(() {
        _entries = data;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldDark,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const PremiumPageHeader(title: 'Leaderboards'),
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.shinyGold,
                labelColor: AppTheme.shinyGold,
                unselectedLabelColor: AppTheme.mutedIvory,
                tabs: const [
                  Tab(text: 'Rating'),
                  Tab(text: 'Wins'),
                  Tab(text: 'High Scores'),
                ],
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.shinyGold,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _entries.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _buildLeaderboardTile(_entries[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile(LeaderboardEntry entry) {
    Color rankColor = AppTheme.mutedIvory;
    if (entry.rank == 1) rankColor = AppTheme.shinyGold;
    if (entry.rank == 2) rankColor = const Color(0xFFC0C0C0);
    if (entry.rank == 3) rankColor = const Color(0xFFCD7F32);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isCurrentPlayer
            ? const Color(0xFF07281D)
            : AppTheme.panelDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.isCurrentPlayer
              ? AppTheme.shinyGold
              : AppTheme.shinyGold.withValues(alpha: 0.25),
          width: entry.isCurrentPlayer ? 1.5 : 0.8,
        ),
      ),
      child: Row(
        children: [
          // Rank position badge
          SizedBox(
            width: 30,
            child: Text(
              '#${entry.rank}',
              style: GoogleFonts.lora(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: GoogleFonts.lora(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ivoryText,
                  ),
                ),
                Text(
                  '@${entry.username}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.shinyGold,
                  ),
                ),
              ],
            ),
          ),
          // Tier Badge & Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                style: GoogleFonts.lora(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.shinyGold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF021710),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.tier,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppTheme.mutedIvory,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
