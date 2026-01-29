# JavaScript WebAssembly Component Binary Sizes

This document tracks binary sizes for a minimal JavaScript WebAssembly component under different build configurations.

## Test Component

A minimal handler that exports a single function:
```javascript
export const handlerInterface = {
  handleevent(event) {
    return event;
  }
};
```

## Versions

| Component | Version/Commit |
|-----------|----------------|
| jco | 1.15.4 (`f386b2a60d68a7b451eb53570b4b0422b3aee10b`) |
| componentize-js | 0.19.3 (`ab6483f82ee47df4b0eab74a2533e24075fdbb83`) |
| wasmtime | 42.0.0 (`68426f1a947e4f981a4f388edea4dfa6c0cde8a1`) |
| SpiderMonkey | FIREFOX_140_0_4_RELEASE_STARLING |

## Binary Sizes

| Configuration | Component (.wasm) | AOT (.cwasm) | Reduction vs Baseline |
|---------------|-------------------|--------------|----------------------|
| Baseline (npm packages) | 11.01 MB (11,548,679 bytes) | 44.20 MB (46,349,864 bytes) | — |
| Minimal builtins | 8.06 MB (8,453,786 bytes) | 33.11 MB (34,725,440 bytes) | 27% wasm, 25% cwasm |
| Minimal builtins + -Oz SM | 5.26 MB (5,518,383 bytes) | 23.90 MB (25,066,648 bytes) | **52% wasm, 46% cwasm** |

## Configurations

| Configuration | CMake Preset | Description |
|---------------|--------------|-------------|
| `baseline` | `release` | No patches, uses npm packages |
| `minimal` | `minimal` | Minimal builtins only (pre-built SpiderMonkey with -O3) |
| `minimal-sm` | `minimal-sm` | Minimal builtins + SpiderMonkey built from source with -Oz |

### Build Options

- **BUILD_MINIMAL**: Enables `-Oz` optimization for StarlingMonkey C/C++ code and `wasm-opt -Oz` (used in both `minimal` and `minimal-sm`)
- **MINIMAL_SM**: Builds SpiderMonkey from source with `-Oz` and disables unused features (only in `minimal-sm`)

### Project Structure

```
js-wasm-binary-sizes/
├── run.sh                     # Unified build script (takes config as argument)
├── patches/
│   ├── componentize-js.patch  # ComponentizeJS changes (CMakePresets, #ifdef guards)
│   └── starlingmonkey.patch   # StarlingMonkey changes (BUILD_MINIMAL, MINIMAL_SM, #ifdef guards)
├── configs/                   # Output artifacts stored per-config
│   ├── baseline/
│   ├── minimal/
│   └── minimal-sm/
├── component/                 # Test component sources
│   ├── component.wit
│   └── js/
└── runner/                    # Rust runner for AOT compilation
```

## How to Reproduce

### Prerequisites

1. **Required folder layout** (sibling directories):
   ```
   ~/
   ├── jco/                    # git clone https://github.com/bytecodealliance/jco
   ├── ComponentizeJS/         # git clone https://github.com/bytecodealliance/ComponentizeJS
   ├── wasmtime/               # git clone https://github.com/bytecodealliance/wasmtime
   └── js-wasm-binary-sizes/   # This benchmark folder
   ```

2. **Build dependencies**:
   - Node.js (v20+)
   - Rust toolchain with `wasm32-wasip1` target
   - CMake
   - WASI SDK (set `WASI_SYSROOT` env var if not auto-detected)
   - clang/clang++ (for SpiderMonkey builds in `minimal-sm`)

### Running Benchmarks

```bash
# Baseline (npm packages, no patches)
./run.sh baseline

# Minimal builtins (pre-built SpiderMonkey)
./run.sh minimal

# Minimal builtins + SpiderMonkey from source with -Oz
./run.sh minimal-sm
```

The script automatically detects sibling directories. To override, set environment variables:
```bash
JCO_DIR=/path/to/jco COMPONENTIZE_JS_DIR=/path/to/ComponentizeJS WASMTIME_DIR=/path/to/wasmtime ./run.sh minimal
```

## Patches

### componentize-js.patch

Adds to ComponentizeJS:
- **CMakePresets.json**: Defines `release`, `minimal`, and `minimal-sm` cmake presets
- **#ifdef guards**: Wraps optional builtins in embedding.cpp with `#ifdef` guards

### starlingmonkey.patch

Adds to StarlingMonkey:
- **BUILD_MINIMAL option**: Sets `-Oz` for C/CXX flags and `wasm-opt -Oz`
- **MINIMAL_SM option**: Builds SpiderMonkey from source with aggressive size optimizations:
  - `--enable-optimize=-Oz`
  - `--disable-jitspew`, `--disable-gczeal`, `--disable-spidermonkey-telemetry`
  - `--disable-js-streams`, `--disable-profiling`
  - `--wasm-no-experimental` and specific wasm feature disables
- **#ifdef guards**: Wraps URL and structured-clone builtins
