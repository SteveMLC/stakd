# Lovart Home Screen Mockup — Visual Design Target (2026-05-15)

Steve generated this mockup via Lovart (GPT Image 2) and shared it back as the
canonical visual target for Warehouse Sort's home screen.

## Recurring visual pattern: "RIVETED DARK PLATE"
Every interactive surface in the mockup is framed by a dark gradient plate
with 4 corner bolts/rivets visible. This is the single most reusable design
element — building one `RivetedPlate` widget unlocks the look across the
whole HUD + menu cluster.

## Per-element notes (top → bottom)

1. **Top bar**
   - Cash chip: gold $ disc + "12,450" inside a riveted dark plate
   - Settings gear: same riveted dark plate, no label
   - (Gift icon hidden in Lovart's mockup; we kept it — fine)

2. **WAREHOUSE SORT placard**
   - Heavy weathered stencil typography (much grittier than our smooth font)
   - Hazard stripes on LEFT + RIGHT sides flanking "SORT" word
   - "Sort the crates. Build the empire." subtitle in Courier with dash + star accents

3. **HUD row — 3 separate riveted plates**
   - "$ 48,750" cash plate
   - "WH Lv 3" plate with yellow warehouse-building glyph
   - "XP 650 / 1,000" plate with yellow accent fill bar

4. **Frozen milestone banner**
   - Frosty ice-crusted blue crate icon (snowflake on cardboard, with frost)
   - "Next: Frozen Crates unlock at Lv 5" in Courier
   - Hazard stripes on both END caps

5. **PLAY button — visual showstopper**
   - Massive yellow plate with hazard stripes left + right
   - Detailed industrial side-view forklift illustration (weathered yellow)
   - "PLAY" in heavy stencil text
   - 4 corner bolts/rivets

6. **Daily Contract pill**
   - Dark riveted plate
   - Clipboard-with-checkmark glyph (yellow stencil)
   - "DAILY CONTRACT" heavy stencil
   - Right arrow ">" affordance
   - Yellow accent border

7. **Bottom menu pills** (2 rows × 2 pills)
   - Dark riveted plate per pill
   - Yellow glyph + white stencil label inside
   - Machinery (forklift) | Forklifts (forklift)
   - Achievements (trophy) | Leaderboards (123 podium)

8. **Bottom edge**
   - Diagonal-hatched plate (industrial grid floor)

9. **Background**
   - Full-screen brushed-steel texture (vertical highlights, mid-grey)

## Priority ship-list (impact per LoC)

| # | Item | Tick scope | Notes |
|---|---|---|---|
| 1 | RivetedPlate widget + cash chip wrap | XS | Single tick — TODAY |
| 2 | WH Lv + XP plates split into RivetedPlates | S | Next tick |
| 3 | Daily Contract pill upgrade (clipboard + arrow + accent) | S | Next tick |
| 4 | Frosty crate icon for milestone | M | Custom painter |
| 5 | Hazard end-caps on placard + milestone banner | M | Restructure |
| 6 | Bottom-edge diagonal hatched plate | M | Custom painter |
| 7 | Brushed-steel screen background | L | Asset OR painter |
| 8 | Forklift illustration on PLAY button | L | Custom painter or PNG asset |

The riveted plate is the keystone primitive — once it exists, every subsequent
chip/pill can adopt it incrementally.

## Lovart canvas
https://www.lovart.ai/canvas?agent=1&projectId=edcc12fa376f4402a86fedb4f536ba56
