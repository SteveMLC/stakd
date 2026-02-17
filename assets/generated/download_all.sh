#!/bin/bash
# Download all generated flat texture assets

source /Users/venomspike/.openclaw/workspace/secrets/scenario.env

OUTPUT_BASE="/Users/venomspike/.openclaw/workspace/projects/stakd/assets/generated/flat_textures"

download_asset() {
    local asset_id="$1"
    local output_path="$2"
    
    # Get asset URL
    response=$(curl -s -u "${SCENARIO_API_ID}:${SCENARIO_API_SECRET}" \
        "${SCENARIO_API_BASE}/assets/${asset_id}")
    
    url=$(echo "$response" | jq -r '.asset.url')
    
    if [ "$url" != "null" ] && [ -n "$url" ]; then
        # Use -L to follow redirects, and don't escape special chars
        curl -sL -o "$output_path" "$url"
        size=$(ls -la "$output_path" 2>/dev/null | awk '{print $5}')
        if [ "$size" -gt 0 ] 2>/dev/null; then
            echo "✓ $(basename "$output_path") ($size bytes)"
        else
            echo "✗ $(basename "$output_path") - empty file"
        fi
    else
        echo "✗ $(basename "$output_path") - no URL"
    fi
}

echo "=== Downloading Surface Textures ==="

# Get asset IDs from the completed jobs
jobs=$(curl -s -u "${SCENARIO_API_ID}:${SCENARIO_API_SECRET}" \
    "${SCENARIO_API_BASE}/jobs?limit=30")

# Map prompts to filenames and download
declare -A PROMPT_MAP=(
    ["flat seamless subtle noise texture, soft grain"]="noise_grain"
    ["flat seamless brushed metal texture, soft horizontal"]="brushed_metal"
    ["flat seamless fabric weave texture, subtle crosshatch"]="fabric_weave"
    ["flat seamless paper texture, soft fiber pattern"]="paper_fiber"
    ["flat seamless frosted glass texture, soft blur"]="frosted_glass"
    ["flat seamless soft gradient texture, smooth surface"]="soft_gradient"
)

for prompt_prefix in "${!PROMPT_MAP[@]}"; do
    filename="${PROMPT_MAP[$prompt_prefix]}"
    asset_id=$(echo "$jobs" | jq -r --arg p "$prompt_prefix" '.jobs[] | select(.status == "success" and (.metadata.input.prompt | startswith($p))) | .metadata.assetIds[0]' | head -1)
    
    if [ -n "$asset_id" ] && [ "$asset_id" != "null" ]; then
        download_asset "$asset_id" "$OUTPUT_BASE/surface/${filename}.png"
    else
        echo "✗ $filename - no completed job found"
    fi
done

echo ""
echo "=== Downloading Zen Textures ==="

declare -A ZEN_MAP=(
    ["flat Japanese wave pattern, seigaiha"]="seigaiha_waves"
    ["flat cherry blossom pattern, sakura petals"]="cherry_blossom"
    ["flat bamboo leaf pattern, minimalist"]="bamboo_leaf"
    ["flat zen sand ripple pattern, concentric"]="zen_sand"
    ["flat koi fish scale pattern, overlapping"]="koi_scales"
    ["flat moss texture pattern, organic dots"]="moss_organic"
)

for prompt_prefix in "${!ZEN_MAP[@]}"; do
    filename="${ZEN_MAP[$prompt_prefix]}"
    asset_id=$(echo "$jobs" | jq -r --arg p "$prompt_prefix" '.jobs[] | select(.status == "success" and (.metadata.input.prompt | startswith($p))) | .metadata.assetIds[0]' | head -1)
    
    if [ -n "$asset_id" ] && [ "$asset_id" != "null" ]; then
        download_asset "$asset_id" "$OUTPUT_BASE/zen/${filename}.png"
    else
        echo "✗ $filename - no completed job found"
    fi
done

echo ""
echo "=== Summary ==="
echo "Surface textures:"
ls -la "$OUTPUT_BASE/surface/"*.png 2>/dev/null | awk '{print "  " $NF " - " $5 " bytes"}'
echo ""
echo "Zen textures:"
ls -la "$OUTPUT_BASE/zen/"*.png 2>/dev/null | awk '{print "  " $NF " - " $5 " bytes"}'
