#!/bin/bash
# Baseline configuration - uses npm published packages
# No patches needed - uses unmodified upstream code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_PROJECT="$PROJECT_DIR"

# These can be overridden via environment variables
JCO_DIR="${JCO_DIR:-$(dirname "$PROJECT_DIR")/jco}"
WASMTIME_DIR="${WASMTIME_DIR:-$(dirname "$PROJECT_DIR")/wasmtime}"

echo "=== Baseline Configuration ==="
echo "Using npm published jco and componentize-js"

# Switch jco to use npm componentize-js
cd "$JCO_DIR/packages/jco"
npm install --save @bytecodealliance/componentize-js@0.19.3

# Build the component
cd "$TEST_PROJECT/component/js"
rm -rf node_modules package-lock.json
npm install
npm run build

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
