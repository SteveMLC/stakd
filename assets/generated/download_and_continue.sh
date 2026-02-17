#!/bin/bash
# Download completed textures and generate remaining ones sequentially

source /Users/venomspike/.openclaw/workspace/secrets/scenario.env

OUTPUT_BASE="/Users/venomspike/.openclaw/workspace/projects/stakd/assets/generated/flat_textures"
mkdir -p "$OUTPUT_BASE/surface" "$OUTPUT_BASE/zen"

STYLE_SUFFIX="2D flat design, no 3D effects, no shadows, no perspective, mobile game texture, clean edges"
NEGATIVE="3D, isometric, cube, perspective, shadow, depth, realistic photo"

# Download completed assets
download_asset() {
    local asset_id="$1"
    local output_path="$2"
    
    # Get asset URL
    url=$(curl -s -u "${SCENARIO_API_ID}:${SCENARIO_API_SECRET}" \
        "${SCENARIO_API_BASE}/assets/${asset_id}" | jq -r '.asset.url')
    
    if [ "$url" != "null" ] && [ -n "$url" ]; then
        curl -s -o "$output_path" "$url"
        echo "  ✓ Downloaded: $(basename "$output_path")"
    else
        echo "  ✗ Failed to get URL for $asset_id"
    fi
}

# Generate and wait for single texture
generate_texture() {
    local prompt="$1"
    local filename="$2"
    local folder="$3"
    
    local full_prompt="$prompt, $STYLE_SUFFIX"
    local output_path="$OUTPUT_BASE/$folder/${filename}.png"
    
    echo "Generating: $filename"
    
    # Submit job
    response=$(curl -s -u "${SCENARIO_API_ID}:${SCENARIO_API_SECRET}" \
        "${SCENARIO_API_BASE}/models/flux.1-schnell/inferences" \
        -X POST -H "Content-Type: application/json" \
        -d "{
            \"parameters\": {
                \"type\": \"txt2img\",
                \"prompt\": \"$full_prompt\",
                \"negativePrompt\": \"$NEGATIVE\",
                \"negativePromptStrength\": 1.0,
                \"numSamples\": 1,
                \"width\": 512,
                \"height\": 512
            }
        }")
    
    job_id=$(echo "$response" | jq -r '.job.jobId')
    
    if [ "$job_id" = "null" ] || [ -z "$job_id" ]; then
        echo "  ✗ Failed to submit: $response"
        return 1
    fi
    
    echo "  Job: $job_id"
    
    # Poll for completion
    max_attempts=120
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        result=$(curl -s -u "${SCENARIO_API_ID}:${SCENARIO_API_SECRET}" \
            "${SCENARIO_API_BASE}/jobs/${job_id}")
        
        status=$(echo "$result" | jq -r '.job.status')
        
        if [ "$status" = "success" ]; then
            asset_id=$(echo "$result" | jq -r '.job.metadata.assetIds[0]')
            if [ "$asset_id" != "null" ] && [ -n "$asset_id" ]; then
                download_asset "$asset_id" "$output_path"
            else
                echo "  ✗ No asset ID in result"
            fi
            return 0
        elif [ "$status" = "failed" ]; then
            echo "  ✗ Generation failed"
            return 1
        fi
        
        sleep 2
        ((attempt++))
    done
    
    echo "  ✗ Timeout"
    return 1
}

echo "=== Downloading Already Completed Textures ==="
# These were generated in the first batch
download_asset "asset_86vx63st9NWSnEZtKRWyk6Sj" "$OUTPUT_BASE/surface/noise_grain.png"
download_asset "asset_UtxCebB4L7K56qkikWwVwj49" "$OUTPUT_BASE/surface/brushed_metal.png"
download_asset "asset_WRccLFdNTMeE42wZF584KxAh" "$OUTPUT_BASE/surface/fabric_weave.png"
download_asset "asset_qgNZxg5PXNfYFH1ePGA8euo1" "$OUTPUT_BASE/surface/paper_fiber.png"

echo ""
echo "=== Generating Remaining Surface Textures ==="
generate_texture "flat seamless frosted glass texture, soft blur pattern, top down, square tile" "frosted_glass" "surface"
generate_texture "flat seamless soft gradient texture, smooth surface, top down, square tile" "soft_gradient" "surface"

echo ""
echo "=== Generating Zen Pattern Textures ==="
generate_texture "flat Japanese wave pattern, seigaiha, top down view, square tile, seamless, blue tones" "seigaiha_waves" "zen"
generate_texture "flat cherry blossom pattern, sakura petals, top down view, square tile, seamless, pink" "cherry_blossom" "zen"
generate_texture "flat bamboo leaf pattern, minimalist, top down view, square tile, seamless, green" "bamboo_leaf" "zen"
generate_texture "flat zen sand ripple pattern, concentric circles, top down view, square tile, beige" "zen_sand" "zen"
generate_texture "flat koi fish scale pattern, overlapping circles, top down view, square tile, gold" "koi_scales" "zen"
generate_texture "flat moss texture pattern, organic dots, top down view, square tile, seamless, green" "moss_organic" "zen"

echo ""
echo "=== Generation Complete ==="
ls -la "$OUTPUT_BASE/surface/"
echo ""
ls -la "$OUTPUT_BASE/zen/"
