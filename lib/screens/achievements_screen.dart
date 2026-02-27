import 'package:flutter/material.dart';
import '../services/achievement_service.dart';
import '../utils/constants.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _achievementService = AchievementService();
  AchievementCategoryExt? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _achievementService.addListener(_onAchievementUpdate);
  }

  @override
  void dispose() {
    _achievementService.removeListener(_onAchievementUpdate);
    super.dispose();
  }

  void _onAchievementUpdate() {
    if (mounted) setState(() {});
  }

  String _getCategoryEmoji(AchievementCategoryExt category) {
    switch (category) {
      case AchievementCategoryExt.mastery:
        return '🎯';
      case AchievementCategoryExt.speed:
        return '⚡';
      case AchievementCategoryExt.streak:
        return '🔥';
      case AchievementCategoryExt.specialBlocks:
        return '❄️';
      case AchievementCategoryExt.garden:
        return '🌿';
      case AchievementCategoryExt.variety:
        return '🎨';
      case AchievementCategoryExt.hidden:
        return '🔮';
    }
  }

  Color _getCategoryColor(AchievementCategoryExt category) {
    switch (category) {
      case AchievementCategoryExt.mastery:
        return const Color(0xFFE74C3C); // red
      case AchievementCategoryExt.speed:
        return const Color(0xFF3498DB); // blue
      case AchievementCategoryExt.streak:
        return const Color(0xFFFF9800); // orange
      case AchievementCategoryExt.specialBlocks:
        return const Color(0xFF9B59B6); // purple
      case AchievementCategoryExt.garden:
        return const Color(0xFF4CAF50); // green
      case AchievementCategoryExt.variety:
        return const Color(0xFFFF9800); // orange
      case AchievementCategoryExt.hidden:
        return const Color(0xFF9E9E9E); // gray
    }
  }

  String _getCategoryName(AchievementCategoryExt category) {
    switch (category) {
      case AchievementCategoryExt.mastery:
        return 'Mastery';
      case AchievementCategoryExt.speed:
        return 'Speed';
      case AchievementCategoryExt.streak:
        return 'Streak';
      case AchievementCategoryExt.specialBlocks:
        return 'Special';
      case AchievementCategoryExt.garden:
        return 'Garden';
      case AchievementCategoryExt.variety:
        return 'Variety';
      case AchievementCategoryExt.hidden:
        return 'Hidden';
    }
  }

  List<AchievementDef> _getFilteredAchievements() {
    final all = _achievementService.allAchievements;
    if (_selectedCategory == null) return all;
    return all.where((a) => a.category == _selectedCategory).toList();
  }

  int _getCategoryCount(AchievementCategoryExt? category) {
    final all = _achievementService.allAchievements;
    if (category == null) return all.length;
    return all.where((a) => a.category == category).length;
  }

  int _getCategoryUnlockedCount(AchievementCategoryExt? category) {
    final all = _achievementService.allAchievements;
    final achievements = category == null 
        ? all 
        : all.where((a) => a.category == category);
    
    return achievements.where((a) {
      final state = _achievementService.getState(a.id);
      return state.unlocked;
    }).length;
  }

  int get _totalXPEarned {
    return _achievementService.allAchievements.where((def) {
      final state = _achievementService.getState(def.id);
      return state.unlocked;
    }).fold(0, (sum, def) => sum + def.xpReward);
  }

  int get _totalCoinsEarned {
    return _achievementService.allAchievements.where((def) {
      final state = _achievementService.getState(def.id);
      return state.unlocked;
    }).fold(0, (sum, def) => sum + def.coinReward);
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _achievementService.unlockedCount;
    final totalCount = _achievementService.totalCount;

    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        backgroundColor: GameColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: GameColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Achievements',
          style: TextStyle(
            color: GameColors.text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$unlockedCount/$totalCount 🏆',
                style: TextStyle(
                  color: const Color(0xFFFFD700), // Gold
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsHeader(),
          _buildCategoryTabs(),
          Expanded(
            child: _buildAchievementsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Unlocked', '${_achievementService.unlockedCount}/${_achievementService.totalCount}', Icons.stars),
          _buildStatItem('Total XP', '+$_totalXPEarned', Icons.flash_on),
          _buildStatItem('Total Gems', '+$_totalCoinsEarned 🪙', Icons.diamond),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFFD700), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: GameColors.text,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: GameColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip(null, 'All', '📋'),
          ...AchievementCategoryExt.values.map((category) {
            return _buildCategoryChip(
              category,
              _getCategoryName(category),
              _getCategoryEmoji(category),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(AchievementCategoryExt? category, String name, String emoji) {
    final isSelected = _selectedCategory == category;
    final unlocked = _getCategoryUnlockedCount(category);
    final total = _getCategoryCount(category);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF2FB9B3).withValues(alpha: 0.3)
              : GameColors.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF2FB9B3)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: GameColors.text,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$unlocked/$total',
              style: TextStyle(
                color: GameColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsList() {
    final achievements = _getFilteredAchievements();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final def = achievements[index];
        final state = _achievementService.getState(def.id);
        return _buildAchievementCard(def, state);
      },
    );
  }

  Widget _buildAchievementCard(AchievementDef def, AchievementState state) {
    final isUnlocked = state.unlocked;
    final isHidden = def.isHidden && !isUnlocked;
    final hasProgress = def.target != null;
    final progress = hasProgress ? (state.progress / def.target!).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked 
              ? const Color(0xFFFFD700).withValues(alpha: 0.5)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Category emoji with color-coded background
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isUnlocked 
                        ? _getCategoryColor(def.category).withValues(alpha: 0.2)
                        : GameColors.surface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: isUnlocked ? Border.all(
                      color: _getCategoryColor(def.category).withValues(alpha: 0.4),
                      width: 1,
                    ) : null,
                  ),
                  child: Center(
                    child: Text(
                      isHidden ? '❓' : _getCategoryEmoji(def.category),
                      style: TextStyle(
                        fontSize: 24,
                        color: isUnlocked ? null : GameColors.textMuted.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Center: Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isHidden ? '???' : def.name,
                              style: TextStyle(
                                color: isUnlocked ? GameColors.text : GameColors.textMuted,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (def.isHidden && isUnlocked)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text('🎁', style: TextStyle(fontSize: 16)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isHidden ? 'Keep playing to discover...' : def.description,
                        style: TextStyle(
                          color: GameColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      if (!isHidden) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '+${def.xpReward} XP',
                              style: TextStyle(
                                color: const Color(0xFF2FB9B3),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '+${def.coinReward} 🪙',
                              style: TextStyle(
                                color: const Color(0xFFFFD700),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Right: Status indicator
                _buildStatusIndicator(def, state, isUnlocked, isHidden),
              ],
            ),
          ),
          // Progress bar (if applicable)
          if (hasProgress && !isUnlocked && !isHidden)
            _buildProgressBar(progress, state.progress, def.target!),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(AchievementDef def, AchievementState state, bool isUnlocked, bool isHidden) {
    if (isUnlocked) {
      return Column(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 28),
          if (state.unlockedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatDate(state.unlockedAt!),
              style: TextStyle(
                color: GameColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ],
      );
    }

    if (isHidden) {
      return Icon(
        Icons.lock,
        color: GameColors.textMuted.withValues(alpha: 0.5),
        size: 24,
      );
    }

    if (def.target != null) {
      return Column(
        children: [
          Text(
            '${state.progress}/${def.target}',
            style: TextStyle(
              color: GameColors.text,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${(state.progress / def.target! * 100).toInt()}%',
            style: TextStyle(
              color: GameColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Icon(
      Icons.lock,
      color: GameColors.textMuted,
      size: 24,
    );
  }

  Widget _buildProgressBar(double progress, int current, int target) {
    return Container(
      height: 6,
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2FB9B3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
