#![allow(dead_code)]

use color_eyre::Result;
use tracing_subscriber::FmtSubscriber;

mod cli;
mod cluster;
mod config;
mod exec;

fn main() -> Result<()> {
    color_eyre::install()?;
    let cli = cli::Cli::parse();

    let subscriber = FmtSubscriber::builder()
        .with_max_level(tracing::Level::DEBUG)
        .finish();
    tracing::subscriber::set_global_default(subscriber).expect("Failed to set global subscriber");

    tracing::info!("Starting Spinner...");

    match cli.command {
        Some(cli::Command::Provision {
            force,
            config_file,
            patch_file,
            skip_installation_media,
            override_protection,
            output_directory,
        }) => {
            let config = config::Config::from_file(&config_file)?;
            let provisioner = cluster::provision::talos::TalosProvisioner::new(
                config,
                output_directory,
                patch_file,
                force,
                skip_installation_media,
                override_protection,
            );
            provisioner.provision()?;
        }

        Some(cli::Command::List {}) => {
            tracing::info!("Listing nodes in the cluster...");
            // Here you would implement the logic to list the nodes in the cluster.
        }

        Some(cli::Command::Server {}) => {
            tracing::info!("Starting Spinner in server mode...");
        }

        None => {
            tracing::info!("No command provided. Use --help to see available commands.");
        }
    }

    Ok(())
}
