import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/game_button.dart';
import '../widgets/warehouse_decorations.dart';

/// Settings screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _colorblindMode = false;
  bool _gradientBlocks = true;
  bool _blockPatterns = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final storage = StorageService();
    setState(() {
      _soundEnabled = storage.getSoundEnabled();
      _hapticsEnabled = storage.getHapticsEnabled();
      _colorblindMode = storage.getColorblindMode();
      _gradientBlocks = storage.getGradientBlocks();
      _blockPatterns = storage.getTextureSkinsEnabled();
    });
  }

  Future<void> _toggleSound() async {
    final storage = StorageService();
    final audio = AudioService();

    setState(() => _soundEnabled = !_soundEnabled);
    await storage.setSoundEnabled(_soundEnabled);
    audio.setSoundEnabled(_soundEnabled);

    if (_soundEnabled) {
      audio.playTap();
    }
  }

  Future<void> _toggleHaptics() async {
    final storage = StorageService();
    final nextValue = !_hapticsEnabled;

    setState(() => _hapticsEnabled = nextValue);
    await storage.setHapticsEnabled(nextValue);

    if (nextValue) {
      haptics.lightTap();
    }
  }

  Future<void> _toggleColorblindMode() async {
    final storage = StorageService();
    final nextValue = !_colorblindMode;

    setState(() => _colorblindMode = nextValue);
    await storage.setColorblindMode(nextValue);

    if (_soundEnabled) {
      AudioService().playTap();
    }
  }

  Future<void> _toggleBlockPatterns() async {
    final storage = StorageService();
    final nextValue = !_blockPatterns;
    setState(() => _blockPatterns = nextValue);
    await storage.setTextureSkinsEnabled(nextValue);
  }

  Future<void> _toggleGradientBlocks() async {
    final storage = StorageService();
    final nextValue = !_gradientBlocks;

    setState(() => _gradientBlocks = nextValue);
    await storage.setGradientBlocks(nextValue);

    if (_soundEnabled) {
      AudioService().playTap();
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GameIconButton(
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    const MetalNameplate(
                      text: 'SETTINGS',
                      icon: Icons.settings,
                      fontSize: 15,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionTitle('Audio'),
                    _buildToggleTile(
                      icon: Icons.volume_up,
                      title: 'Sound',
                      value: _soundEnabled,
                      onToggle: _toggleSound,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Feedback'),
                    _buildToggleTile(
                      icon: Icons.vibration,
                      title: 'Haptics',
                      value: _hapticsEnabled,
                      onToggle: _toggleHaptics,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Accessibility'),
                    _buildToggleTile(
                      icon: Icons.accessibility_new,
                      title: 'Colorblind Patterns',
                      value: _colorblindMode,
                      onToggle: _toggleColorblindMode,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Visuals'),
                    _buildToggleTile(
                      icon: Icons.gradient,
                      title: 'Gradient Blocks',
                      value: _gradientBlocks,
                      onToggle: _toggleGradientBlocks,
                    ),
                    _buildToggleTile(
                      icon: Icons.texture,
                      title: 'Block Patterns',
                      value: _blockPatterns,
                      onToggle: _toggleBlockPatterns,
                    ),
                    const SizedBox(height: 8),
                    _buildThemeButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    // Section divider styled like the printed-header strip on a
    // dispatch clipboard: uppercase Courier label with a hazard-tape
    // underline so each block of toggles reads as a sectioned manifest.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: GameColors.accent,
              letterSpacing: 2.2,
              fontFamily: 'Courier',
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(
            width: 64,
            child: HazardStripe(height: 2, stripeWidth: 6),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required VoidCallback onToggle,
  }) {
    // Dock-terminal row: brushed-steel gradient, accent border, corner
    // rivets, and a custom hazard-yellow toggle that reads like a real
    // panel switch on the warehouse floor.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
            color: GameColors.accent.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(left: -2, top: -4, child: _PanelRivet()),
            const Positioned(right: -2, top: -4, child: _PanelRivet()),
            Row(
              children: [
                Icon(icon, color: GameColors.accent, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: GameColors.text,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                _MetalToggle(value: value),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeButton() {
    // Warehouse Sort v1 ships with a locked theme (warehouse warm gray
    // + safety yellow), so the row is informational only — no theme
    // store entry. Themes will return in v1.1 with multiple unlockable
    // dock skins. Matches the dock-terminal styling of toggle rows so
    // the visuals block reads as one cohesive panel.
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(left: -2, top: -4, child: _PanelRivet()),
          const Positioned(right: -2, top: -4, child: _PanelRivet()),
          Row(
            children: const [
              Icon(Icons.palette_outlined,
                  size: 22, color: GameColors.textMuted),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: GameColors.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Default Warehouse',
                      style: TextStyle(
                          fontSize: 11,
                          color: GameColors.textMuted,
                          letterSpacing: 0.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

/// Tiny rivet drawn from a radial gradient — matches the corner rivets
/// on the WAYBILL placard so settings rows feel like the same machined
/// panel.
class _PanelRivet extends StatelessWidget {
  const _PanelRivet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF7A8290), Color(0xFF2A303A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 1.5,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
    );
  }
}

/// Custom warehouse-floor toggle: steel-grey track when off, hazard-
/// yellow when on. The thumb is a small machined puck that slides
/// between an ON and OFF stencil printed on the track. Drops the
/// system [Switch] entirely so the screen stops looking like a Material
/// settings page.
class _MetalToggle extends StatelessWidget {
  final bool value;
  const _MetalToggle({required this.value});

  static const double _trackW = 52;
  static const double _trackH = 26;
  static const double _thumbSize = 18;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: _trackW,
      height: _trackH,
      decoration: BoxDecoration(
        gradient: value
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFD24A),
                  GameColors.accent,
                  Color(0xFFE6A800),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1F26),
                  Color(0xFF252B36),
                ],
              ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: value
              ? const Color(0xFF8B6914)
              : const Color(0xFF505868),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: value
                ? GameColors.accent.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.4),
            blurRadius: value ? 6 : 3,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Stencil label printed on the track opposite the thumb.
          Positioned(
            left: value ? 8 : null,
            right: value ? null : 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                value ? 'ON' : 'OFF',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Courier',
                  letterSpacing: 1.2,
                  color: value
                      ? const Color(0xFF8B6914)
                      : GameColors.textMuted.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
          // Sliding thumb.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: value ? _trackW - _thumbSize - 4 : 4,
            top: (_trackH - _thumbSize) / 2,
            child: Container(
              width: _thumbSize,
              height: _thumbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.3),
                  radius: 1.0,
                  colors: [
                    Color(0xFFE8ECF2),
                    Color(0xFF8B95A1),
                    Color(0xFF3A4250),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
                border: Border.all(
                  color: const Color(0xFF1A1F26),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
