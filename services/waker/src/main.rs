use std::net::SocketAddr;
use axum::{
    routing::get,
    http::StatusCode,
    Json, Router,
};
use axum_server;

use serde::Serialize;

mod wol;
mod util;

#[derive(Serialize)]
struct Response<'a> {
    message: &'a str,
}

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let app = Router::new().route("/wol", get(wol));

    let addr = SocketAddr::from(([0, 0, 0, 0], 9092));

    axum_server::bind(addr)
        .serve(app.into_make_service())
        .await?;

    Ok(())
}

// WoL endpoint
async fn wol() -> (StatusCode, Json<Response<'static>>) {
    wol::create_wol_message().ok();
    (StatusCode::OK, Json(Response { message: "Magic packet sent!" }))
}