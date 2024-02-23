use std::{env, net::SocketAddr};
use axum::{
    routing::put,
    Router
};

use axum_server;
use clap::{Parser, Subcommand};
use color_eyre::{eyre::eyre, Result};
use lib::tracing as lib_tracing;

use opentelemetry_sdk::Resource;
use opentelemetry_semantic_conventions as semcov;

use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};


mod auth;
mod http;

#[derive(Parser)]
struct Cli {
    #[arg(short, long, default_value_t = 3000)]
    port: u16,

    #[clap(subcommand)]
    command: Option<Command>,
}

#[derive(Subcommand)]
enum Command {
}

#[tokio::main]
async fn main() -> Result<()>{
    color_eyre::install()?;
    let cli = Cli::parse();

    if env::var("JWT_SECRET").is_err() {
        return Err(eyre!("JWT_SECRET is not set"));
    }

    let app = Router::new()
        .route("/api/v1/command", put(crate::http::command))
        .layer(
            tower::ServiceBuilder::new()
                .layer(axum::error_handling::HandleErrorLayer::new(|err: axum::BoxError| async move {
                    (
                    axum::http::StatusCode::INTERNAL_SERVER_ERROR,
                    format!("Unhandled internal error: {}", err),
                )
            }))
            .layer(tower::buffer::BufferLayer::new(100))
            .layer(tower::limit::RateLimitLayer::new(1, std::time::Duration::from_secs(10))),
        );

    let trace_resource = Resource::new(vec![semcov::resource::SERVICE_NAME.string("collector")]);
    let env_filter = EnvFilter::from_default_env();
    let tracing_layer = tracing_opentelemetry::layer().with_tracer(lib_tracing::otlp_with_resource(trace_resource));
    tracing_subscriber::registry()
        .with(env_filter)
        .with(tracing_subscriber::fmt::layer()) // required for the `tracing` macros to be logged to stdout
        .with(tracing_layer).init();

    let addr = SocketAddr::from(([0, 0, 0, 0], cli.port));
    tracing::info!("listening on {}", addr);

    axum_server::bind(addr)
        .serve(app.into_make_service())
        .await?;

    Ok(())
}

// Do heavy rate limiting if it is not a certain requestor :)
// Check the bearer token if the requestor is the right one