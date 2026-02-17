# Stakd Massive Improvement Plan
**Created:** 2026-02-17
**Goal:** Transform Stakd into a top-tier puzzle game with strong revenue potential

---

## Current State Summary

### What Stakd Already Has ✅
- Color sorting puzzle core (solid mechanic)
- Multi-grab mechanics (long press for consecutive same-color)
- Combo system (consecutive clears within 3s)
- Par scoring (BFS-calculated minimum moves)
- Undo system (3 base, +3 via rewarded ad)
- Zen Mode (endless, relaxing)
- Daily Challenge (deterministic seed)
- Zen Garden meta-progression (9 stages, session-based)
- Multi-color blocks (harder to stack)
- Locked blocks (must unlock first)
- Particle effects, screen shake, color flash
- Achievements system
- IAP: Remove ads, Hint packs
- Sound effects and haptics

### What's Missing 🔴
1. **No star rating system** — No replayability incentive
2. **No battle pass / season pass** — Major monetization gap
3. **No daily rewards / login streak** — Retention gap
4. **No weekly events / tournaments** — Engagement gap
5. **No social features** — Leaderboards, sharing
6. **Limited power-ups** — Only undo available
7. **No themes / customization** — Visual personalization
8. **No progressive tutorial** — Onboarding gap
9. **No lives system** — Monetization opportunity
10. **Visual polish gaps** — Garden needs more life

---

## Phase 1: Core Gameplay Juice (Week 1)

### 1.1 Star Rating System
**Impact:** High | **Effort:** Low (2-3 hours)

Add 3-star system to all levels:
- ★ = Complete the level
- ★★ = Complete at or under par
- ★★★ = Complete with perfect efficiency (par - 2 or no undo used)

**Changes:**
- `lib/models/game_state.dart` — Add star calculation
- `lib/screens/level_select_screen.dart` — Show stars per level
- `lib/widgets/level_complete_dialog.dart` — Show star rating
- Track total stars for meta-progression

### 1.2 Enhanced Power-Ups
**Impact:** High | **Effort:** Medium (1-2 days)

Add 3 new power-ups (purchasable with soft currency or IAP):
1. **Color Bomb** — Removes all blocks of one color from the board
2. **Shuffle** — Randomly rearranges all blocks (new solvable state)
3. **Freeze** — Freezes timer in timed modes for 30 seconds
4. **Magnet** — Auto-completes one stack that's 1 block away

**Monetization:** 
- Earn 1-2 power-ups per day from daily rewards
- Buy packs via IAP ($0.99 for 5, $2.99 for 20)

### 1.3 Chain Reaction System
**Impact:** Very High | **Effort:** Medium (3-4 days)

When completing a stack causes blocks to "cascade" and auto-complete another:
- Massive particle explosion
- Screen shake intensifies
- Bonus points multiplier
- Special sound effect
- Achievement: "Chain Master"

This is the "Puyo Puyo moment" — feels unplanned but amazing.

---

## Phase 2: Retention Systems (Week 2)

### 2.1 Daily Rewards Calendar
**Impact:** Very High | **Effort:** Medium (1-2 days)

7-day login calendar with escalating rewards:
- Day 1: 50 coins
- Day 2: 1 Power-up
- Day 3: 100 coins
- Day 4: 2 Power-ups
- Day 5: 200 coins
- Day 6: Premium hint pack (3)
- Day 7: 500 coins + Exclusive theme unlock

Reset on miss or continue from where you left off (player-friendly).

### 2.2 Weekly Challenges
**Impact:** High | **Effort:** Medium (2-3 days)

Special challenge modes that rotate weekly:
- **Speed Week** — All levels have time pressure
- **No Undo Week** — Complete levels without undo
- **Color Chaos** — Only multi-color and locked blocks
- **Minimalist** — Par or better on all levels

Rewards: Exclusive themes, badges, power-ups

### 2.3 Achievement Expansion
**Impact:** Medium | **Effort:** Low (1 day)

Add 50+ achievements across categories:
- **Speed Demon** — Complete 10 levels in under 30 seconds each
- **Perfectionist** — Get 3 stars on 50 levels
- **Combo King** — Achieve a 10x combo
- **Chain Master** — Trigger a 3-chain cascade
- **Zen Master** — Reach Garden Stage 9
- **Daily Devotee** — Complete 30 daily challenges

---

## Phase 3: Monetization Expansion (Week 3)

### 3.1 Battle Pass / Season Pass
**Impact:** VERY HIGH | **Effort:** High (1 week)

Monthly "Season" with free and premium tracks:

**Free Track:**
- Coins at every 5 levels
- 1 power-up at level 10, 20, 30
- Basic theme at level 50

**Premium Track ($4.99/month):**
- 2x coin rewards
- Exclusive animated themes
- Exclusive block skins
- Ad-free for the season
- Early access to new mechanics
- Exclusive garden decorations

50 levels per season, XP earned from:
- Completing levels (10 XP)
- Daily challenges (50 XP)
- Weekly challenges (200 XP)
- Achievements (varies)

### 3.2 Theme Store
**Impact:** High | **Effort:** Medium (3-4 days)

Purchasable visual themes:
- **Neon Night** — Glowing cyberpunk colors
- **Ocean Calm** — Blues and teals, wave animations
- **Forest Spirit** — Greens, leaf particles
- **Candy Land** — Pastel sweets aesthetic
- **Minimalist** — Clean black/white
- **Seasonal** — Holiday themes (limited time)

Price: 500-2000 coins or $0.99-$2.99

### 3.3 Block Skins
**Impact:** Medium | **Effort:** Low (1-2 days)

Cosmetic block appearances:
- Default (solid colors)
- Glossy (shiny reflections)
- Matte (soft, no shine)
- Gradient (color gradients)
- Patterned (stripes, dots)
- Animated (subtle pulse)

Unlock via achievements, battle pass, or purchase.

---

## Phase 4: Social & Competition (Week 4)

### 4.1 Global Leaderboards
**Impact:** High | **Effort:** Medium (2-3 days)

Firebase leaderboards for:
- Daily Challenge (fastest time)
- Weekly Challenge (highest score)
- Total Stars collected
- Highest combo achieved
- Garden stages reached

Show top 100 + player's rank.

### 4.2 Friend Challenges
**Impact:** Medium | **Effort:** Medium (2-3 days)

Challenge friends to beat your score on any level:
- Share via link/social
- Friend sees your time/moves
- Beat it to win bragging rights

### 4.3 Share Milestones
**Impact:** Medium | **Effort:** Low (1 day)

Auto-prompt to share at:
- First 3-star level
- 100 total stars
- Garden Stage 5
- 10x combo achievement
- Season pass completion

---

## Phase 5: Visual Polish & Assets (Ongoing)

### 5.1 Garden Enhancements
**Impact:** High | **Effort:** High (1 week)

Current garden is good but needs more life:
- Animated water in pond (ripples, reflections)
- Wind affecting trees/grass (subtle sway)
- Day/night cycle based on real time
- Weather effects (rain, snow, cherry blossoms)
- More interactive elements (tap to scatter birds)
- Seasonal variations (spring/summer/fall/winter)

### 5.2 Block Animations
**Impact:** Medium | **Effort:** Medium (2-3 days)

- Idle "breathing" animation on blocks
- Rainbow shimmer on multi-color blocks
- Lock icon pulse on locked blocks
- Satisfying "pop" on clear
- Trail effects when moving

### 5.3 UI Polish
**Impact:** Medium | **Effort:** Medium (2-3 days)

- Smoother screen transitions
- Button press animations
- Loading screen with tips
- Better level select grid
- Animated backgrounds

---

## Phase 6: New Game Modes (Future)

### 6.1 Puzzle Rush
Time attack mode — solve as many puzzles as possible in 3 minutes.

### 6.2 Endless Mode
Infinitely generating puzzles with increasing difficulty.

### 6.3 Versus Mode
Real-time 1v1 puzzle racing (same puzzle, first to complete wins).

### 6.4 Level Editor
Let players create and share custom puzzles.

---

## Overnight Sprint Assignments

### Sprint 1: Core Juice (Tonight)
- [ ] Star rating system
- [ ] Chain reaction system
- [ ] Enhanced power-ups UI/logic

### Sprint 2: Retention (Tomorrow)
- [ ] Daily rewards calendar
- [ ] Weekly challenges framework
- [ ] Achievement expansion

### Sprint 3: Monetization (Day 3)
- [ ] Battle pass framework
- [ ] Theme store
- [ ] Block skins

### Sprint 4: Social (Day 4)
- [ ] Leaderboards
- [ ] Share milestones
- [ ] Friend challenges

### Sprint 5: Polish (Day 5)
- [ ] Garden enhancements
- [ ] Block animations
- [ ] UI polish

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| D1 Retention | Unknown | 40%+ |
| D7 Retention | Unknown | 20%+ |
| D30 Retention | Unknown | 10%+ |
| ARPDAU | Unknown | $0.05+ |
| IAP Conversion | Unknown | 3-5% |
| Session Length | Unknown | 10+ min |
| Sessions/Day | Unknown | 2-3 |

---

## Implementation Priority

1. **Star Rating** — Immediate replayability ⭐⭐⭐
2. **Daily Rewards** — Retention boost ⭐⭐⭐
3. **Battle Pass** — Revenue driver ⭐⭐⭐
4. **Chain Reactions** — Game feel ⭐⭐⭐
5. **Power-ups** — Monetization + engagement ⭐⭐
6. **Themes** — Personalization ⭐⭐
7. **Leaderboards** — Competition ⭐⭐
8. **Garden Polish** — Visual appeal ⭐

---

*This plan will be executed through multiple overnight sprints with dedicated subagents.*
