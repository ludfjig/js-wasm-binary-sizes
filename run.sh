#!/bin/bash
# Unified build script for js-wasm-binary-sizes benchmarks
# Usage: ./run.sh [baseline|minimal|minimal-sm]

set -e

CONFIG="${1:-minimal}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# These can be overridden via environment variables
JCO_DIR="${JCO_DIR:-$(dirname "$PROJECT_DIR")/jco}"
COMPONENTIZE_JS_DIR="${COMPONENTIZE_JS_DIR:-$(dirname "$PROJECT_DIR")/ComponentizeJS}"
WASMTIME_DIR="${WASMTIME_DIR:-$(dirname "$PROJECT_DIR")/wasmtime}"

# Validate config
case "$CONFIG" in
    baseline|minimal|minimal-sm)
        ;;
    *)
        echo "Usage: $0 [baseline|minimal|minimal-sm]"
        echo "  baseline   - Use npm packages (no patches, standard build)"
        echo "  minimal    - Minimal builtins, pre-built SpiderMonkey"
        echo "  minimal-sm - Minimal builtins + SpiderMonkey built from source with -Oz"
        exit 1
        ;;
esac

echo "=== Configuration: $CONFIG ==="
echo ""

OUTPUT_DIR="$PROJECT_DIR/configs/$CONFIG"
mkdir -p "$OUTPUT_DIR"

if [ "$CONFIG" = "baseline" ]; then
    echo "Using npm packages (no patches)"
    
    # Build the component using npm jco from registry (not local)
    cd "$PROJECT_DIR/component/js"
    rm -rf node_modules package-lock.json
    
    # Create a temporary package.json that uses npm registry packages
    cat > package.json.tmp <<EOF
{
  "name": "handler",
  "version": "1.0.0",
  "devDependencies": {
    "@bytecodealliance/jco": "^1.15.4"
  }
}
EOF
    mv package.json package.json.bak
    mv package.json.tmp package.json
    
    npm install
    npx @bytecodealliance/jco componentize handler.js --wit ../component.wit -d all -o handler.wasm
    
    # Restore original package.json
    mv package.json.bak package.json
else
    echo "Using local componentize-js with $CONFIG preset"
    
    # Apply patches (skip if already applied, fail if conflicts)
    echo "Applying patches..."
    cd "$COMPONENTIZE_JS_DIR"
    
    # Check if componentize-js patch is already applied
    if git apply --reverse --check "$PROJECT_DIR/patches/componentize-js.patch" 2>/dev/null; then
        echo "ComponentizeJS patch already applied, skipping"
    elif git apply --check "$PROJECT_DIR/patches/componentize-js.patch" 2>/dev/null; then
        git apply "$PROJECT_DIR/patches/componentize-js.patch"
        echo "Applied componentize-js.patch"
    else
        echo "ERROR: Cannot apply componentize-js.patch - you may have uncommitted changes."
        echo "Please commit or stash your changes in ComponentizeJS first."
        exit 1
    fi
    
    # Check if starlingmonkey patch is already applied
    if git -C StarlingMonkey apply --reverse --check "$PROJECT_DIR/patches/starlingmonkey.patch" 2>/dev/null; then
        echo "StarlingMonkey patch already applied, skipping"
    elif git -C StarlingMonkey apply --check "$PROJECT_DIR/patches/starlingmonkey.patch" 2>/dev/null; then
        git -C StarlingMonkey apply "$PROJECT_DIR/patches/starlingmonkey.patch"
        echo "Applied starlingmonkey.patch"
    else
        echo "ERROR: Cannot apply starlingmonkey.patch - you may have uncommitted changes."
        echo "Please commit or stash your changes in StarlingMonkey first."
        exit 1
    fi
    
    # Build componentize-js with selected preset
    BUILD_DIR="build-$CONFIG"
    cmake --preset "$CONFIG"
    make -j16 -C "$BUILD_DIR" starlingmonkey_embedding
    
    # Point jco to local componentize-js
    cd "$JCO_DIR/packages/jco"
    npm install --save @bytecodealliance/componentize-js@file:../../../ComponentizeJS
    
    # Build the component
    cd "$PROJECT_DIR/component/js"
    rm -rf node_modules package-lock.json
    npm install
    ./node_modules/.bin/jco componentize handler.js --wit ../component.wit -d all -o handler.wasm
fi

# Record wasm size
WASM_SIZE=$(stat -c%s handler.wasm)
echo "Component size: $WASM_SIZE bytes ($(numfmt --to=iec $WASM_SIZE))"

# AOT compile
cd "$WASMTIME_DIR"
cargo run --release -- compile -o "$PROJECT_DIR/component/js/handler.cwasm" "$PROJECT_DIR/component/js/handler.wasm"

# Record cwasm size
cd "$PROJECT_DIR/component/js"
CWASM_SIZE=$(stat -c%s handler.cwasm)
echo "AOT size: $CWASM_SIZE bytes ($(numfmt --to=iec $CWASM_SIZE))"

echo ""
echo "Results ($CONFIG):"
WASM_MB=$(echo "scale=2; $WASM_SIZE / 1048576" | bc)
CWASM_MB=$(echo "scale=2; $CWASM_SIZE / 1048576" | bc)
echo "  .wasm:  $WASM_SIZE bytes (${WASM_MB} MB)"
echo "  .cwasm: $CWASM_SIZE bytes (${CWASM_MB} MB)"

# Copy outputs for later inspection
cp handler.wasm "$OUTPUT_DIR/handler.wasm"
cp handler.cwasm "$OUTPUT_DIR/handler.cwasm"
echo ""
echo "Outputs saved to:"
echo "  $OUTPUT_DIR/handler.wasm"
echo "  $OUTPUT_DIR/handler.cwasm"

echo "Done."
