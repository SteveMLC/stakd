import 'package:flutter/material.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';
import '../utils/constants.dart';
import '../utils/game_assets.dart';
import '../widgets/game_button.dart';
import '../widgets/warehouse_decorations.dart';
import '../widgets/warehouse_spinner.dart';
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
          const SizedBox(width: 12),
          const Expanded(
            child: MetalNameplate(
              text: 'LEADERBOARDS',
              icon: Icons.leaderboard,
              fontSize: 14,
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
    // Tabs styled as clipboard category tabs — UPPERCASE Courier, tight
    // letterspacing, no emoji glyph. Reads as a printed manifest header
    // row instead of the previous Material tab labels.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3A4250),
            Color(0xFF252B36),
            Color(0xFF1A1F26),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: GameColors.accent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: GameColors.accent,
        unselectedLabelColor: GameColors.textMuted,
        indicatorColor: GameColors.accent,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          fontFamily: 'Courier',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          fontFamily: 'Courier',
        ),
        tabs: LeaderboardType.values.map((type) {
          return Tab(
            child: Text(_tabLabel(type)),
          );
        }).toList(),
      ),
    );
  }

  /// Manifest-style label for each tab. Replaces the emoji + mixed-case
  /// label combo with the clipboard categories called out in the spec.
  String _tabLabel(LeaderboardType type) {
    switch (type) {
      case LeaderboardType.dailyChallenge:
        return 'DAILY';
      case LeaderboardType.weeklyStars:
        return 'WEEKLY';
      case LeaderboardType.allTimeStars:
        return 'ALL-TIME';
      case LeaderboardType.bestCombo:
        return 'COMBO';
    }
  }

  Widget _buildLeaderboardTab(LeaderboardType type) {
    final isLoading = _loading[type] ?? false;
    final error = _errors[type];
    final entries = _leaderboards[type] ?? [];

    if (isLoading && entries.isEmpty) {
      return const Center(
        child: WarehouseSpinner(),
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
            // Lovart Wave 2 empty-state hero: cartoon foreman shrugging
            // next to an empty podium. Replaces the bare 64pt emoji.
            SizedBox(
              height: 160,
              child: Image.asset(
                emptyLeaderboardAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dispatch-manifest line item: brushed-steel gradient row with
          // a stenciled rank square on the left, Courier player name in
          // the middle, accent-yellow score on the right.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isCurrentPlayer
                    ? const [
                        Color(0xFF4A4030),
                        Color(0xFF2E2A1F),
                        Color(0xFF1F1B14),
                      ]
                    : const [
                        Color(0xFF3A4250),
                        Color(0xFF252B36),
                        Color(0xFF1A1F26),
                      ],
              ),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(6),
                bottom: Radius.circular(isTopThree ? 0 : 6),
              ),
              border: Border.all(
                color: isCurrentPlayer
                    ? GameColors.accent.withValues(alpha: 0.8)
                    : isTopThree
                        ? _getMedalColor(entry.rank).withValues(alpha: 0.55)
                        : GameColors.accent.withValues(alpha: 0.18),
                width: isCurrentPlayer ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Stenciled rank square — 32x32, Courier w900, accent
                // yellow for top 3 else white. Reads like a stamped
                // sequence number on a shipping label.
                _StenciledRankSquare(
                  rank: entry.rank,
                  highlight: isTopThree,
                ),
                const SizedBox(width: 12),

                // Player name in Courier, plus the YOU stamp if this is
                // the current player's row.
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.playerName,
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: 'Courier',
                            fontWeight: isCurrentPlayer
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: isCurrentPlayer
                                ? GameColors.accent
                                : GameColors.text,
                            letterSpacing: 0.6,
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
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1F26),
                              letterSpacing: 1.2,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Score, right-aligned, accent yellow w900.
                Text(
                  _service.formatScore(entry.score, type),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: GameColors.accent,
                    letterSpacing: 0.6,
                    shadows: [
                      Shadow(
                        color: Color(0x88000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Top-3 rows get a hazard-tape underline so the podium reads
          // visually distinct from the rest of the manifest.
          if (isTopThree)
            const HazardStripe(height: 2, stripeWidth: 8),
        ],
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

/// 32x32 stenciled rank square, Courier w900, accent-yellow ink for the
/// top-3 podium and white for everyone else. Drawn as a dark steel
/// plate with a subtle inset border so it reads as a metal placard
/// nailed to the side of the manifest row.
class _StenciledRankSquare extends StatelessWidget {
  final int rank;
  final bool highlight;

  const _StenciledRankSquare({
    required this.rank,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight
              ? GameColors.accent.withValues(alpha: 0.65)
              : const Color(0xFF505868),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          rank.toString().padLeft(2, '0'),
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: highlight ? GameColors.accent : GameColors.text,
            shadows: const [
              Shadow(
                color: Color(0xAA000000),
                blurRadius: 1.5,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
