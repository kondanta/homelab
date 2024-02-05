pub use opentelemetry;
pub use opentelemetry_sdk;

use opentelemetry_sdk::{propagation::TraceContextPropagator,  Resource};
use opentelemetry_otlp::WithExportConfig;

//
pub fn otlp_with_resource(trace_resource: Resource) -> opentelemetry_sdk::trace::Tracer {
    opentelemetry::global::set_text_map_propagator(TraceContextPropagator::new());

    let trace_config = opentelemetry_sdk::trace::config().with_resource(trace_resource);

    tracing::info!("Tracing initialized");
    opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint("http://localhost:4317")
        )
        .with_trace_config(trace_config)
        .install_batch(opentelemetry_sdk::runtime::Tokio).unwrap()
}