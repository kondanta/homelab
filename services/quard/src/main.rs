use std::net::SocketAddr;
use std::str::FromStr;

use axum::{
    extract::Json,
    http::StatusCode,
    response::Json as JsonResponse,
    routing::{get, put},
    Router
};
use axum_server;
use clap::{Parser, Subcommand};
use color_eyre::{eyre::eyre, Result};
use lib::{dto::QueueType, tracing as lib_tracing};

use opentelemetry_sdk::Resource;
use opentelemetry_semantic_conventions as semcov;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

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

#[derive(serde::Deserialize)]
struct Request {
    body: Body,
}

#[derive(serde::Deserialize)]
struct Body {
    command: String,
    requestee: String,
    requestor: String,
}

#[tokio::main]
async fn main() -> Result<()>{
    color_eyre::install()?;
    let cli = Cli::parse();

    let app = Router::new()
        .route("/api/v1/command", put(command))
        .route("/check", get(check_health));

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
// Axum handler for the PUT /api/v1/command route
async fn command(Json(request): Json<Request>) -> impl axum::response::IntoResponse {
    // You can access the deserialized struct here
    tracing::debug!("Received command: {}", request.body.command);
    tracing::debug!("Received device_id: {}", request.body.requestee);
    tracing::debug!("Received requestor: {}", request.body.requestor);

    let command = find_command(&request.body.requestee);

    match command {
        Ok(command) => {
            let collector_request = CollectorRequest {
                body: "".to_string(),
                requestee: command,
                requestor: request.body.requestor,
            };

            match dispatch_command(collector_request).await {
                Ok(response) => {
                    tracing::info!("Command dispatched: {:?}", response);
                    (StatusCode::OK, JsonResponse("Command dispatched"))
                }
                Err(e) => {
                    tracing::error!("Failed to dispatch command: {}", e);
                    (StatusCode::INTERNAL_SERVER_ERROR, JsonResponse("Failed to dispatch command"))
                }
            }
        }
        Err(e) => {
            tracing::error!("Invalid command: {}", e);
            return (StatusCode::BAD_REQUEST, JsonResponse("Invalid command"));
        }
    }
}

fn find_command(command: &str) -> Result<QueueType>{
    QueueType::from_str(command).map_err(|_| {
        eyre!("Invalid command")
    })
}

#[derive(serde::Serialize)]
struct CollectorRequest {
    body: String,
    requestee: QueueType,
    requestor: String,
}

async fn dispatch_command(request: CollectorRequest) -> Result<reqwest::Response> {
    let body = serde_json::to_string(&request)?;
    tracing::debug!("request serialized as: {:?}", body);
    // send http request to the collector service localhost:4000
    let request = reqwest::Client::new()
        .post("http://localhost:4000/api/v1/command")
        .header("Content-Type", "application/json")
        .body(body);

    tracing::debug!("sending request: {:?}", request);
    let response = request.send().await?;

    Ok(response)
}

async fn check_health() -> impl axum::response::IntoResponse {
    let response = reqwest::get("http://localhost:4000/healthz").await.unwrap();
    if response.status().is_success() {
        (StatusCode::OK, JsonResponse("Collector is healthy"))
    } else {
        (StatusCode::INTERNAL_SERVER_ERROR, JsonResponse("Collector is unhealthy"))
    }
}
