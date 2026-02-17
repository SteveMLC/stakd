#!/bin/bash
# Generate flat texture tiles for Stakd using Scenario.com API

source /Users/venomspike/.openclaw/workspace/secrets/scenario.env

OUTPUT_BASE="/Users/venomspike/.openclaw/workspace/projects/stakd/assets/generated/flat_textures"
mkdir -p "$OUTPUT_BASE/surface" "$OUTPUT_BASE/zen"

STYLE_SUFFIX="2D flat design, no 3D effects, no shadows, no perspective, mobile game texture, clean edges"
NEGATIVE="3D, isometric, cube, perspective, shadow, depth, realistic photo"

# Array to track jobs
declare -a JOBS=()
declare -a FILENAMES=()
declare -a FOLDERS=()

submit_job() {
    local prompt="$1"
    local filename="$2"
    local folder="$3"
    
    local full_prompt="$prompt, $STYLE_SUFFIX"
    
    echo "Submitting: $filename"
    
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
    
    job_id=$(echo "$response" | jq -r '.inference.id')
    
    if [ "$job_id" != "null" ] && [ -n "$job_id" ]; then
        JOBS+=("$job_id")
        FILENAMES+=("$filename")
        FOLDERS+=("$folder")
        echo "  -> Job: $job_id"
    else
        echo "  -> FAILED: $response"
    fi
    
    # Small delay to avoid rate limiting
    sleep 0.5
}

# Category 1: Subtle Surface Textures
echo "=== Category 1: Surface Textures ==="
submit_job "flat seamless subtle noise texture, soft grain, top down view, square tile, no shadows, transparent friendly" "noise_grain" "surface"
submit_job "flat seamless brushed metal texture, soft horizontal lines, top down, square tile, minimal" "brushed_metal" "surface"
submit_job "flat seamless fabric weave texture, subtle crosshatch, top down view, square tile" "fabric_weave" "surface"
submit_job "flat seamless paper texture, soft fiber pattern, top down, square tile, minimal" "paper_fiber" "surface"
submit_job "flat seamless frosted glass texture, soft blur pattern, top down, square tile" "frosted_glass" "surface"
submit_job "flat seamless soft gradient texture, smooth surface, top down, square tile" "soft_gradient" "surface"

# Category 2: Zen/Nature Patterns
echo ""
echo "=== Category 2: Zen Patterns ==="
submit_job "flat Japanese wave pattern, seigaiha, top down view, square tile, seamless, blue tones" "seigaiha_waves" "zen"
submit_job "flat cherry blossom pattern, sakura petals, top down view, square tile, seamless, pink" "cherry_blossom" "zen"
submit_job "flat bamboo leaf pattern, minimalist, top down view, square tile, seamless, green" "bamboo_leaf" "zen"
submit_job "flat zen sand ripple pattern, concentric circles, top down view, square tile, beige" "zen_sand" "zen"
submit_job "flat koi fish scale pattern, overlapping circles, top down view, square tile, gold" "koi_scales" "zen"
submit_job "flat moss texture pattern, organic dots, top down view, square tile, seamless, green" "moss_organic" "zen"

echo ""
echo "Submitted ${#JOBS[@]} jobs. Polling for completion..."
echo ""

# Poll for completion and download
for i in "${!JOBS[@]}"; do
    job_id="${JOBS[$i]}"
    filename="${FILENAMES[$i]}"
    folder="${FOLDERS[$i]}"
    
    echo "Waiting for $filename ($job_id)..."
    
    max_attempts=60
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        result=$(curl -s -u "${SCENARIO_API_ID}:${SCENARIO_API_SECRET}" \
            "${SCENARIO_API_BASE}/inferences/$job_id")
        
        status=$(echo "$result" | jq -r '.inference.status')
        
        if [ "$status" = "succeeded" ]; then
            image_url=$(echo "$result" | jq -r '.inference.images[0].url')
            
            if [ "$image_url" != "null" ] && [ -n "$image_url" ]; then
                output_path="$OUTPUT_BASE/$folder/${filename}.png"
                curl -s -o "$output_path" "$image_url"
                echo "  ✓ Downloaded: $output_path"
            else
                echo "  ✗ No image URL in result"
            fi
            break
        elif [ "$status" = "failed" ]; then
            echo "  ✗ Generation failed"
            break
        else
            sleep 2
            ((attempt++))
        fi
    done
    
    if [ $attempt -ge $max_attempts ]; then
        echo "  ✗ Timeout waiting for $filename"
    fi
done

echo ""
echo "=== Generation Complete ==="
echo "Surface textures: $(ls -1 "$OUTPUT_BASE/surface" 2>/dev/null | wc -l | tr -d ' ')"
echo "Zen textures: $(ls -1 "$OUTPUT_BASE/zen" 2>/dev/null | wc -l | tr -d ' ')"
