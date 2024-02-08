use std::net::SocketAddr;
use std::thread;

use axum::{
    http::StatusCode, routing::get, Router
};
use axum_prometheus::PrometheusMetricLayer;
use axum_server;
use axum_tracing_opentelemetry::middleware::OtelAxumLayer;

use clap::{Parser, Subcommand};

use lib::tracing as lib_tracing;

use opentelemetry_sdk::Resource;
use opentelemetry_semantic_conventions as semcov;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

mod bus;

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
        .route("/", get(root))
        .route("/healthz", get(healthz))
        .route("/readyz", get(readyz))
        .layer(prometheus_layer)
        .layer(OtelAxumLayer::default());

    let trace_resource = Resource::new(vec![semcov::resource::SERVICE_NAME.string("collector")]);
    let env_filter = EnvFilter::from_default_env();
    let tracing_layer = tracing_opentelemetry::layer().with_tracer(lib_tracing::otlp_with_resource(trace_resource));
    tracing_subscriber::registry()
        .with(env_filter)
        .with(tracing_subscriber::fmt::layer()) // required for the `tracing` macros to be logged to stdout
        .with(tracing_layer).init();

    thread::spawn(move || {
        run_bus().unwrap();
    });

    let addr = SocketAddr::from(([0, 0, 0, 0], cli.port));
    tracing::info!("listening on {}", addr);

    axum_server::bind(addr)
        .serve(app.into_make_service())
        .await?;

    Ok(())
}

// todo(taylan): implement response struct
async fn healthz() -> impl axum::response::IntoResponse {
    tracing::info!("healthz");
    (StatusCode::OK, "ok")
}

// todo(taylan): implement response struct
async fn readyz() -> impl  axum::response::IntoResponse {
    tracing::info!("readyz");
    (StatusCode::OK, "ok")
}

async fn root() -> &'static str {
    tracing::info!("root");
    "Hello, World!"
}


fn run_bus() -> color_eyre::Result<()> {
    let cfg = bus::Config {
        amqp_url: "amqp://guest:guest@localhost:5672".to_string(),
        public_queue: Some("q1".to_string()),
        private_queue: None,
        channel_id: None,
    };
    let bus = bus::Bus::new(cfg);
    bus.listen().ok();

    Ok(())
}
