#[allow(warnings)]
mod bindings;

use bindings::exports::test::test::handler_interface::{Guest, Request};

struct Component;

impl Guest for Component {
    fn handleevent(mut event: Request) -> Request {
        event
    }
}

bindings::export!(Component with_types_in bindings);
