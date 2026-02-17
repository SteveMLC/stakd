import 'package:flutter/material.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';
import '../utils/constants.dart';
import '../widgets/game_button.dart';
import '../widgets/name_entry_dialog.dart';

/// Global leaderboards screen with tabbed categories
class LeaderboardScreen extends StatefulWidget {
  final LeaderboardType initialTab;

  const LeaderboardScreen({
    super.key,
    this.initialTab = LeaderboardType.dailyChallenge,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LeaderboardService _service = LeaderboardService();
  
  final Map<LeaderboardType, List<LeaderboardEntry>> _leaderboards = {};
  final Map<LeaderboardType, bool> _loading = {};
  final Map<LeaderboardType, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: LeaderboardType.values.length,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    _tabController.addListener(_onTabChange);
    _loadLeaderboard(widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (!_tabController.indexIsChanging) {
      final type = LeaderboardType.values[_tabController.index];
      _loadLeaderboard(type);
    }
  }

  Future<void> _loadLeaderboard(LeaderboardType type) async {
    if (_loading[type] == true) return;

    setState(() {
      _loading[type] = true;
      _errors[type] = null;
    });

    try {
      final entries = await _service.getLeaderboard(type);
      if (mounted) {
        setState(() {
          _leaderboards[type] = entries;
          _loading[type] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errors[type] = 'Failed to load leaderboard';
          _loading[type] = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    final type = LeaderboardType.values[_tabController.index];
    await _loadLeaderboard(type);
  }

  void _showNameDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => NameEntryDialog(
        currentName: _service.playerName,
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _service.setPlayerName(result);
      // Reload current leaderboard to reflect name change
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GameColors.backgroundDark, GameColors.backgroundMid],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: LeaderboardType.values
                      .map((type) => _buildLeaderboardTab(type))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GameIconButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Leaderboards',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: GameColors.textMuted),
            onPressed: _showNameDialog,
            tooltip: 'Change name',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: GameColors.text,
        unselectedLabelColor: GameColors.textMuted,
        indicatorColor: GameColors.accent,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: LeaderboardType.values.map((type) {
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.icon),
                const SizedBox(width: 6),
                Text(type.shortName),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeaderboardTab(LeaderboardType type) {
    final isLoading = _loading[type] ?? false;
    final error = _errors[type];
    final entries = _leaderboards[type] ?? [];

    if (isLoading && entries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: GameColors.accent),
      );
    }

    if (error != null && entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: GameColors.textMuted),
            const SizedBox(height: 16),
            Text(error, style: TextStyle(color: GameColors.textMuted)),
            const SizedBox(height: 16),
            GameButton(
              text: 'Retry',
              icon: Icons.refresh,
              onPressed: _refresh,
              isSmall: true,
            ),
          ],
        ),
      );
    }

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              type.icon,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              'No entries yet',
              style: TextStyle(
                fontSize: 18,
                color: GameColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptyMessage(type),
              style: const TextStyle(
                fontSize: 14,
                color: GameColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: GameColors.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildListHeader(type);
          }
          return _buildLeaderboardEntry(entries[index - 1], type);
        },
      ),
    );
  }

  Widget _buildListHeader(LeaderboardType type) {
    String subtitle;
    switch (type) {
      case LeaderboardType.dailyChallenge:
        subtitle = 'Fastest times today';
        break;
      case LeaderboardType.weeklyStars:
        subtitle = 'Stars earned this week';
        break;
      case LeaderboardType.allTimeStars:
        subtitle = 'Total lifetime stars';
        break;
      case LeaderboardType.bestCombo:
        subtitle = 'Highest combos ever';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            type.icon,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GameColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardEntry(LeaderboardEntry entry, LeaderboardType type) {
    final isTopThree = entry.rank <= 3;
    final isCurrentPlayer = entry.isCurrentPlayer;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentPlayer
            ? GameColors.accent.withValues(alpha: 0.2)
            : GameColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentPlayer
            ? Border.all(color: GameColors.accent, width: 2)
            : isTopThree
                ? Border.all(
                    color: _getMedalColor(entry.rank).withValues(alpha: 0.5),
                    width: 1,
                  )
                : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 40,
            child: isTopThree
                ? _buildMedal(entry.rank)
                : Text(
                    '#${entry.rank}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrentPlayer
                          ? GameColors.accent
                          : GameColors.textMuted,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          
          // Player name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.playerName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              isCurrentPlayer ? FontWeight.bold : FontWeight.w500,
                          color: isCurrentPlayer
                              ? GameColors.accent
                              : GameColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentPlayer) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: GameColors.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: GameColors.text,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Score
          Text(
            _service.formatScore(entry.score, type),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isCurrentPlayer ? GameColors.accent : GameColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedal(int rank) {
    final color = _getMedalColor(rank);
    final icon = rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          icon,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Color _getMedalColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return GameColors.textMuted;
    }
  }

  String _getEmptyMessage(LeaderboardType type) {
    switch (type) {
      case LeaderboardType.dailyChallenge:
        return 'Complete today\'s challenge\nto be the first!';
      case LeaderboardType.weeklyStars:
        return 'Earn stars this week\nto climb the ranks!';
      case LeaderboardType.allTimeStars:
        return 'Collect stars across all levels\nto make your mark!';
      case LeaderboardType.bestCombo:
        return 'Chain clears together\nto build combos!';
    }
  }
}
