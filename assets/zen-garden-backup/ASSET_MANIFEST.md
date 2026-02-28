# Zen Garden Asset Manifest

## Naming Convention
`zen_{family}_{variant}.png` — all lowercase, underscore separated

## Asset Map (raw file → production name)

| # | Raw File ID | Production Name | Family | Layer | Has Alpha | Needs Work |
|---|---|---|---|---|---|---|
| 1 | file_000000001d88722f | zen_grass_base_v1.png | ground | background | ✅ partial | Edge haze cleanup |
| 2 | file_000000002d1071f5 | zen_sand_raked_v1.png | ground | background | ✅ partial | Edge jagginess + corner artifact |
| 3 | file_00000000301071f5 | zen_rocks_small_v1.png | small_rocks | midground | ❌ white bg | Full rembg |
| 4 | file_00000000aa8471f5 | zen_shrub_low_v1.png | shrub | midground | ❌ white bg | Full rembg |
| 5 | file_0000000001b8722f | zen_rocks_medium_v1.png | medium_rocks | midground | ✅ partial | Residual ground cleanup |
| 6 | file_00000000bab8722f | zen_bamboo_v1.png | bamboo | foreground | ❌ white bg | Full rembg |
| 7 | file_000000000cf471f5 | zen_pond_koi_v1.png | water | midground | ❌ white bg | Full rembg |
| 8 | file_0000000097e471f5 | zen_lantern_v1.png | lantern | foreground | ✅ partial | Alpha halo cleanup |
| 9 | file_00000000ef98722f | zen_stepping_stones_v1.png | path | ground | ✅ partial | Haze cleanup |
| 10 | file_00000000dcf8722f | zen_bonsai_v1.png | bonsai | foreground | ❌ white bg | Full rembg (careful leaf edges) |
| 11 | file_00000000135c71f5 | zen_sand_swirl_v1.png | ground | background | ❌ white bg | Full rembg (low contrast) |
| 12 | file_00000000982c722f | zen_waterfall_v1.png | water | midground | ❌ white bg | Full rembg |
| 13 | file_000000009cc0722f | zen_shrub_gold_v1.png | shrub | midground | ❌ white bg | Full rembg |
| 14 | file_000000002ed071f5 | zen_lily_pads_v1.png | water | midground | ✅ partial | Alpha fringe cleanup |
| 15 | file_00000000ec4071f5 | zen_shrine_stone_v1.png | shrine | foreground | ✅ partial | Alpha fringe cleanup |
| 16 | file_00000000372c722f | zen_mist_v1.png | atmosphere | overlay | ✅ partial | Push empty areas to true 0 alpha |
| 17 | file_0000000053d4722f | zen_flowers_cherry_v1.png | flora | foreground | ✅ partial | Separate into 3 assets + cleanup |
| 18 | file_00000000164c722fb | zen_sand_plate_oval_v1.png | ground | background | ✅ partial | Edge haze cleanup |
| 19 | file_00000000d960722f | zen_sand_plate_organic_v1.png | ground | background | ✅ partial | Heavy haze — worst alpha |
| 20 | file_00000000de8071f5 | zen_grass_flowers_v1.png | ground | background | ✅ partial | Edge haze cleanup |
| 21 | file_000000009f0c71f5 | zen_rocks_small_v2.png | small_rocks | midground | ✅ partial | Edge haze cleanup |

## Missing from Drive (in Steve's table but not downloaded)
- Mini Bridge (file_00000000eb88722f) — NOT in Drive folder
- Fireflies overlay (file_000000001fb471f5) — NOT in Drive folder

## Processing Pipeline
1. **rembg** pass on all 12 white-bg images
2. **Alpha cleanup** pass on all 21 (trim haze, push empty → 0 alpha)
3. **Rename** to production names
4. **Resize** to game-ready sizes (512x512 or asset-appropriate)
5. **Cherry blossom sheet** → split into 3 separate assets
6. **Copy to** `stakd/assets/images/zen-garden/`
