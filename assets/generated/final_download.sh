#!/bin/bash
source /Users/venomspike/.openclaw/workspace/secrets/scenario.env
BASE="/Users/venomspike/.openclaw/workspace/projects/stakd/assets/generated/flat_textures"

download() {
    local id="$1"
    local path="$2"
    url=$(curl -s -u "${SCENARIO_API_ID}:${SCENARIO_API_SECRET}" "${SCENARIO_API_BASE}/assets/${id}" | jq -r '.asset.url')
    curl -sL -o "$path" "$url"
    sz=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null)
    echo "$(basename "$path"): ${sz} bytes"
}

echo "=== Surface Textures ==="
download "asset_86vx63st9NWSnEZtKRWyk6Sj" "$BASE/surface/noise_grain.png"
download "asset_UtxCebB4L7K56qkikWwVwj49" "$BASE/surface/brushed_metal.png"
download "asset_WRccLFdNTMeE42wZF584KxAh" "$BASE/surface/fabric_weave.png"
download "asset_qgNZxg5PXNfYFH1ePGA8euo1" "$BASE/surface/paper_fiber.png"
download "asset_KJeYZR6hgFd9YFyevR7snXjs" "$BASE/surface/frosted_glass.png"
download "asset_RLfaVjtWLRXrZgBD5tArum8U" "$BASE/surface/soft_gradient.png"

echo ""
echo "=== Zen Textures ==="
download "asset_86iEr1G622EHTQ87B1Y8pqQt" "$BASE/zen/seigaiha_waves.png"
download "asset_NAoseEEwCTe8Cx1c1PxhvjVn" "$BASE/zen/cherry_blossom.png"
download "asset_UqNHgQumX6TSmNggGEKKC5hz" "$BASE/zen/bamboo_leaf.png"
download "asset_u9743QWdujbRNut41oUh4PRV" "$BASE/zen/zen_sand.png"
download "asset_oa6CANnyCpmFz137a5Tjsf99" "$BASE/zen/koi_scales.png"
download "asset_jLomdbZpjEY4ooaiuBChV4M4" "$BASE/zen/moss_organic.png"

echo ""
echo "=== Done ==="
