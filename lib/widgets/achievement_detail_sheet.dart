import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/achievement.dart';
import '../utils/constants.dart';
import '../widgets/warehouse_decorations.dart';

/// Bottom sheet showing achievement details, styled as a shipping
/// certificate: dark dock surface bracketed by hazard bands, Courier
/// "OFFICIAL DISPATCH RECORD" header strip, embossed-seal icon, and a
/// wax-stamp rarity badge. Replaces the prior bright-white Material
/// sheet that was breaking the warehouse palette.
class AchievementDetailSheet extends StatefulWidget {
  final Achievement achievement;

  const AchievementDetailSheet({
    super.key,
    required this.achievement,
  });

  @override
  State<AchievementDetailSheet> createState() => _AchievementDetailSheetState();
}

class _AchievementDetailSheetState extends State<AchievementDetailSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.achievement.isUnlocked) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final rarity = a.rarity;
    final color = RarityColors.primary(rarity);
    final isCompleted = a.isUnlocked;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF252B36),
              Color(0xFF1A1F26),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top hazard band — the "this side handle-with-care" stripe
            // every dispatch certificate carries.
            const HazardStripe(height: 8, stripeWidth: 14),

            // Courier header strip — reads as the printed "OFFICIAL
            // DISPATCH RECORD" stamp across the top of a manifest.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F26).withValues(alpha: 0.7),
                border: Border(
                  bottom: BorderSide(
                    color: GameColors.accent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
              ),
              child: const Center(
                child: Text(
                  'OFFICIAL DISPATCH RECORD · STAMPED',
                  style: TextStyle(
                    color: GameColors.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
            ),

            // Drag handle (now styled to match the dark palette).
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GameColors.textMuted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Body — icon, title, wax-stamp rarity.
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Column(
                children: [
                  // Embossed-seal icon: white→silver→dark radial w/ metal
                  // border + drop shadow underneath.
                  _buildDetailIcon(color, isCompleted),
                  const SizedBox(height: 14),
                  // Title.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      a.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: GameColors.text,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Rarity badge rendered as a wax-stamp circle.
                  _WaxStamp(
                    label: RarityColors.label(rarity).toUpperCase(),
                    color: color,
                  ),
                ],
              ),
            ),

            // Description block.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Text(
                a.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: GameColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),

            // Completion info — date-stamped like a receipt.
            if (isCompleted && a.unlockedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  'CLEARED · ${DateFormat('MMM d, y').format(a.unlockedAt!).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    fontFamily: 'Courier',
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // Divider — a thin accent line bracketed by short dashes,
            // reads like the perforated tear-off on a freight ticket.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                height: 1,
                color: GameColors.accent.withValues(alpha: 0.25),
              ),
            ),

            const SizedBox(height: 12),

            // Reward pill — kept as a contained PP callout but re-skinned
            // to read as a stamped "+N PP" certificate badge.
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFD24A),
                    GameColors.accent,
                    Color(0xFFE6A800),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF8B6914),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: GameColors.accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFF8B6914),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${a.ppReward} PP',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8B6914),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Share button — re-skinned to read like a "DISPATCH COPY"
            // action on a paper manifest.
            Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: 14,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final a = widget.achievement;
                    Share.share(
                      'I unlocked "${a.title}" in Warehouse Sort. ${a.description}',
                    );
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text(
                    'DISPATCH COPY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: color.withValues(alpha: 0.7),
                        width: 1,
                      ),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),

            // Bottom hazard band — closes the certificate frame.
            const HazardStripe(height: 6, stripeWidth: 12),

            // Safe-area padding under the bottom band so the bands stay
            // flush with the rounded sheet edge instead of being eaten
            // by the home indicator.
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailIcon(Color color, bool isCompleted) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.3),
              radius: 0.9,
              colors: isCompleted
                  ? const [
                      Color(0xFFF5F7FA),
                      Color(0xFFB0BAC6),
                      Color(0xFF2A303A),
                    ]
                  : const [
                      Color(0xFF8B95A1),
                      Color(0xFF505868),
                      Color(0xFF1A1F26),
                    ],
              stops: const [0.0, 0.55, 1.0],
            ),
            border: Border.all(
              color: isCompleted ? color : const Color(0xFF505868),
              width: 3,
            ),
            boxShadow: [
              // Halo: pulses if unlocked, static if not.
              BoxShadow(
                color: isCompleted
                    ? color.withValues(alpha: _glowAnimation.value * 0.45)
                    : Colors.black.withValues(alpha: 0.4),
                blurRadius: 18,
                spreadRadius: isCompleted ? 3 : 0,
              ),
              // Deep underside shadow gives the seal an embossed lift.
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              RarityColors.categoryIcon(widget.achievement.category),
              style: const TextStyle(fontSize: 36),
            ),
          ),
        );
      },
    );
  }
}

/// A small "wax-stamp" rarity badge — circular with a darker outer
/// ring, a radial gradient centred on the rarity colour, and a slight
/// rotation so it reads as having been pressed in by hand.
class _WaxStamp extends StatelessWidget {
  final String label;
  final Color color;

  const _WaxStamp({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.08, // ~-4.5deg
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 1.1,
            colors: [
              Color.lerp(color, Colors.white, 0.18) ?? color,
              color,
              Color.lerp(color, Colors.black, 0.45) ?? color,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color.lerp(color, Colors.black, 0.5) ?? color,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2.0,
            fontFamily: 'Courier',
            shadows: [
              Shadow(
                color: Color(0xAA000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
