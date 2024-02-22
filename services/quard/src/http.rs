use std::str::FromStr;

use axum::{
    extract::Json,
    http::StatusCode,
    response::Json as JsonResponse,
};
use color_eyre::{eyre::eyre, Result};
use lib::dto::{QueueType, BusRequest};


#[derive(serde::Deserialize)]
pub struct Request {
    body: Body,
}

#[derive(serde::Deserialize)]
struct Body {
    command: String,
    requestee: String,
    requestor: String,
}

#[derive(serde::Serialize, Clone, Debug)]
struct R {
    body: String,
    requestee: QueueType,
    requestor: String,
}

impl From<Request> for R {
    fn from(request: Request) -> Self {
        let body = request.body.command;
        let requestee = QueueType::from_str(&request.body.requestee).unwrap();
        let requestor = request.body.requestor;

        Self {
            body,
            requestee,
            requestor,
        }
    }
}

impl BusRequest for R {
    fn requestee(&self) -> QueueType {
        self.requestee.clone()
    }

    fn requestor(&self) -> &str {
        &self.requestor
    }

    fn payload(&self) -> &str {
        &self.body
    }

    fn to_json(&self) -> serde_json::Value {
        serde_json::json!({
            "requestee": self.requestee.to_string(),
            "requestor": self.requestor,
            "body": self.body,
        })
    }
}


pub(crate) async fn command(Json(request): Json<Request>) -> impl axum::response::IntoResponse {
    // You can access the deserialized struct here
    tracing::debug!("Received command: {}", request.body.command);
    tracing::debug!("Received device_id: {}", request.body.requestee);
    tracing::debug!("Received requestor: {}", request.body.requestor);

    match dispatch_command(request).await {
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

async fn dispatch_command(request: Request) -> Result<reqwest::Response> {
    let body = serde_json::to_string(&R::from(request))?;
    tracing::debug!("request serialized as: {:?}", body);
    // send http request to the collector service localhost:4000
    let request = reqwest::Client::new()
        .post("http://localhost:4000/api/v1/command")
        .header("Content-Type", "application/json")
        .body(body);

    tracing::debug!("sending request: {:?}", request);
    let response = request.send().await.map_err(|e| eyre!(e))?;

    Ok(response)
}
