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

| Configuration | Component (.wasm) | AOT (.cwasm) | Notes |
|---------------|-------------------|--------------|-------|
| Baseline (npm packages) | 11.01 MB (11,548,663 bytes) | 44.20 MB (46,349,864 bytes) | Default jco/componentize-js from npm |
| Minimal builtins | 8.17 MB (8,572,263 bytes) | 33.45 MB (35,075,848 bytes) | Only COMPONENTIZE_EMBEDDING + TEXT_CODEC |
| Minimal builtins + -Os SM | 5.96 MB (6,250,453 bytes) | 25.78 MB (27,035,856 bytes) | SpiderMonkey built from source with -Os |

## Configurations

Each configuration is in its own folder under `configs/`:

```
configs/
├── baseline/          # No patches, uses npm packages
│   └── run.sh
├── minimal/           # Minimal builtins, pre-built SpiderMonkey
│   ├── run.sh
│   ├── componentize-js.patch
│   └── starlingmonkey.patch
└── minimal-sm/        # Minimal builtins + -Os SpiderMonkey
    ├── run.sh
    └── spidermonkey-cmake.patch  (also uses minimal/ patches)
```

## How to Reproduce

### Prerequisites

1. **Required folder layout** (sibling directories):
   ```
   ~/
   ├── jco/                    # git clone https://github.com/bytecodealliance/jco
   ├── ComponentizeJS/         # git clone https://github.com/bytecodealliance/ComponentizeJS
   ├── wasmtime/               # git clone https://github.com/bytecodealliance/wasmtime
   └── js-wasm-binary-sizes/   # This benchmark folder (contains component/ and runner/)
   ```

2. **Build dependencies**:
   - Node.js (v20+)
   - Rust toolchain with `wasm32-wasip1` target
   - CMake
   - WASI SDK (set `WASI_SYSROOT` env var if not auto-detected)
   - clang/clang++ (for SpiderMonkey builds)

3. **Test component is included** in this repo at `component/js/`:
   ```
   component/
   ├── component.wit   # WIT interface definition
   ├── js/
   │   ├── handler.js      # JS component source
   │   └── package.json    # With jco dependency
   └── rust/               # Rust equivalent for comparison
   ```

### Running Benchmarks

```bash
# Baseline (npm packages)
./configs/baseline/run.sh

# Minimal builtins (pre-built SpiderMonkey)
./configs/minimal/run.sh

# Minimal builtins + -Os SpiderMonkey (builds SM from source)
./configs/minimal-sm/run.sh
```

The scripts automatically detect sibling directories. To override, set environment variables:
```bash
JCO_DIR=/path/to/jco COMPONENTIZE_JS_DIR=/path/to/ComponentizeJS WASMTIME_DIR=/path/to/wasmtime ./configs/minimal/run.sh
```

## Adding a New Configuration

1. Create a new folder: `configs/my-config/`
2. Add patches as needed (`.patch` files)
3. Create `run.sh` that:
   - Resets repos: `git checkout -- .` and `git -C StarlingMonkey checkout -- .`
   - Applies patches: `git apply ...`
   - Builds with cmake preset (or custom cmake options)
   - Runs jco componentize
