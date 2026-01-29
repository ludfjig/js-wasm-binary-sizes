#!/bin/bash
# Minimal builtins + -Os SpiderMonkey configuration
# Uses local componentize-js with minimal-sm preset (SpiderMonkey built from source with -Os)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_PROJECT="$PROJECT_DIR"
MINIMAL_DIR="$PROJECT_DIR/configs/minimal"

# These can be overridden via environment variables
JCO_DIR="${JCO_DIR:-$(dirname "$PROJECT_DIR")/jco}"
COMPONENTIZE_JS_DIR="${COMPONENTIZE_JS_DIR:-$(dirname "$PROJECT_DIR")/ComponentizeJS}"
WASMTIME_DIR="${WASMTIME_DIR:-$(dirname "$PROJECT_DIR")/wasmtime}"

echo "=== Minimal Builtins + -Os SpiderMonkey Configuration ==="
echo "Using local componentize-js with minimal-sm preset (SpiderMonkey from source with -Os)"

# Apply patches (includes minimal patches + spidermonkey cmake patch)
echo "Applying patches..."
cd "$COMPONENTIZE_JS_DIR"
git checkout -- .
git -C StarlingMonkey checkout -- .

# Apply minimal patches (shared with minimal config)
git apply "$MINIMAL_DIR/componentize-js.patch" || echo "ComponentizeJS patch already applied or failed"
git -C StarlingMonkey apply "$MINIMAL_DIR/starlingmonkey.patch" || echo "StarlingMonkey patch already applied or failed"

# Apply spidermonkey cmake patch (specific to minimal-sm)
git -C StarlingMonkey apply "$SCRIPT_DIR/spidermonkey-cmake.patch" || echo "SpiderMonkey cmake patch already applied or failed"

# Build componentize-js with minimal-sm preset
cmake --preset minimal-sm
make -j16 -C build-minimal-sm starlingmonkey_embedding

# Point jco to local componentize-js
cd "$JCO_DIR/packages/jco"
npm install --save @bytecodealliance/componentize-js@file:../../../ComponentizeJS

# Build the component
cd "$TEST_PROJECT/component/js"
rm -rf node_modules package-lock.json
npm install
./node_modules/.bin/jco componentize handler.js --wit ../component.wit -d all -o handler.wasm

# Record wasm size
WASM_SIZE=$(stat -c%s handler.wasm)
echo "Component size: $WASM_SIZE bytes ($(numfmt --to=iec $WASM_SIZE))"

# AOT compile
cd "$WASMTIME_DIR"
cargo run --release -- compile -o "$TEST_PROJECT/component/js/handler.cwasm" "$TEST_PROJECT/component/js/handler.wasm"

# Record cwasm size
CWASM_SIZE=$(stat -c%s "$TEST_PROJECT/component/js/handler.cwasm")
echo "AOT size: $CWASM_SIZE bytes ($(numfmt --to=iec $CWASM_SIZE))"

echo ""
echo "Results:"
WASM_MB=$(echo "scale=2; $WASM_SIZE / 1048576" | bc)
CWASM_MB=$(echo "scale=2; $CWASM_SIZE / 1048576" | bc)
echo "  .wasm:  $WASM_SIZE bytes (${WASM_MB} MB)"
echo "  .cwasm: $CWASM_SIZE bytes (${CWASM_MB} MB)"

# Copy outputs for later inspection
cp "$TEST_PROJECT/component/js/handler.wasm" "$SCRIPT_DIR/handler.wasm"
cp "$TEST_PROJECT/component/js/handler.cwasm" "$SCRIPT_DIR/handler.cwasm"
echo ""
echo "Outputs saved to:"
echo "  $SCRIPT_DIR/handler.wasm"
echo "  $SCRIPT_DIR/handler.cwasm"

# Cleanup - revert patches (but keep .gitignore changes)
echo ""
echo "Reverting patches..."
cd "$COMPONENTIZE_JS_DIR"
git checkout -- ':!.gitignore'
rm -f CMakePresets.json
git -C StarlingMonkey checkout -- .
echo "Done."
