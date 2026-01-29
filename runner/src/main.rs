use wasmtime::{
    Store,
    component::{Component, Linker, ResourceTable},
};
use wasmtime_wasi::p2::add_to_linker_sync;
use wasmtime_wasi::{WasiCtx, WasiCtxBuilder, WasiCtxView, WasiView};

mod bindings {
    wasmtime::component::bindgen!(in "../component/component.wit");
}

struct MyState {
    ctx: WasiCtx,
    table: ResourceTable,
}

impl WasiView for MyState {
    fn ctx(&mut self) -> WasiCtxView<'_> {
        WasiCtxView {
            ctx: &mut self.ctx,
            table: &mut self.table,
        }
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: {} <rs|js> [--aot]", args[0]);
        std::process::exit(1);
    }

    let component_type = &args[1];
    let use_aot = args.iter().any(|a| a == "--aot");
    let manifest = std::env::var("CARGO_MANIFEST_DIR")
        .expect("CARGO_MANIFEST_DIR not set. Please run using cargo");

    let ext = if use_aot { "cwasm" } else { "wasm" };
    let component_path = match component_type.as_str() {
        "js" => format!("{}/../component/js/handler.{}", manifest, ext),
        "rs" => format!(
            "{}/../component/rust/target/wasm32-wasip1/release/handler_rs.{}",
            manifest, ext
        ),
        _ => {
            eprintln!(
                "Invalid component type: {}. Use 'rs' or 'js'",
                component_type
            );
            std::process::exit(1);
        }
    };

    println!("Loading {} component{} from: {}", component_type, if use_aot { " (AOT)" } else { "" }, component_path);

    // Setup Wasmtime engine and component
    let engine = wasmtime::Engine::default();
    let component = if use_aot {
        // SAFETY: We trust the AOT compiled file was produced by a compatible wasmtime version
        unsafe { Component::deserialize_file(&engine, &component_path) }.expect("Failed to load AOT component")
    } else {
        Component::from_file(&engine, component_path).expect("Failed to load component")
    };

    // Setup WASI linker
    let mut linker = Linker::new(&engine);
    add_to_linker_sync(&mut linker).expect("Failed to add WASI to linker");

    // Create WASI context and store
    let wasi_ctx = WasiCtxBuilder::new().build();
    let table = ResourceTable::new();
    let state = MyState { ctx: wasi_ctx, table };
    let mut store = Store::new(&engine, state);

    // Instantiate the component
    let instance = bindings::HandlerWorld::instantiate(&mut store, &component, &linker)
        .expect("Failed to instantiate component");

    let request = bindings::exports::test::test::handler_interface::Request {
        uri: "Test URI".to_string(),
    };

    let handler = instance.test_test_handler_interface();
    let response = handler.call_handleevent(&mut store, &request).expect("Failed to call handleevent");
    
    println!("Response: {}", response.uri);
}
