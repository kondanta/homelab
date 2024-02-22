use std::net::SocketAddr;

use axum::{
    routing::{get, post}, Router
};
use axum_prometheus::PrometheusMetricLayer;
use axum_server;
use axum_tracing_opentelemetry::middleware::OtelAxumLayer;

use clap::{Parser, Subcommand};

use lib::tracing as lib_tracing;

use opentelemetry_sdk::Resource;
use opentelemetry_semantic_conventions as semcov;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

mod http;
mod routes;
mod queue;

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
async fn main() -> color_eyre::Result<()>{
    color_eyre::install()?;
    let cli = Cli::parse();

    let (prometheus_layer, metric_handle) = PrometheusMetricLayer::pair();
    let app = Router::new()
        .route("/metrics", get(|| async move { metric_handle.render() }))
        .route("/", get(crate::routes::root))
        .route("/api/v1/command", post(crate::routes::command))
        .route("/healthz", get(crate::routes::healthz))
        .route("/readyz", get(crate::routes::readyz))
        .layer(prometheus_layer)
        .layer(OtelAxumLayer::default());

    let trace_resource = Resource::new(vec![semcov::resource::SERVICE_NAME.string("collector")]);
    let env_filter = EnvFilter::from_default_env();
    let tracing_layer = tracing_opentelemetry::layer().with_tracer(lib_tracing::otlp_with_resource(trace_resource));
    tracing_subscriber::registry()
        .with(env_filter)
        .with(tracing_subscriber::fmt::layer()) // required for the `tracing` macros to be logged to stdout
        .with(tracing_layer).init();

    crate::queue::Queue::init(); // create the queues

    let addr = SocketAddr::from(([0, 0, 0, 0], cli.port));
    tracing::info!("listening on {}", addr);

    axum_server::bind(addr)
        .serve(app.into_make_service())
        .await?;

    Ok(())
}

