build-js:
    cd component/js && npm run build

build-rs:
    cd component/rust && cargo component bindings && cargo component build --release

build-components: build-js build-rs

aot-js: build-js
    cd ../wasmtime && cargo run --release -- compile -o ../jco-vs-cargo-component-memory-usage/component/js/handler.cwasm ../jco-vs-cargo-component-memory-usage/component/js/handler.wasm

aot-rs: build-rs
    cd ../wasmtime && cargo run --release -- compile -o ../jco-vs-cargo-component-memory-usage/component/rust/target/wasm32-wasip1/release/handler_rs.cwasm ../jco-vs-cargo-component-memory-usage/component/rust/target/wasm32-wasip1/release/handler_rs.wasm

aot: aot-js aot-rs

run component *args:
    cd runner && cargo run --release -- {{component}} {{args}}