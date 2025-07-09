use crate::cluster::provision::talos::eyre::eyre;
use crate::config::Config;
use crate::exec::shell;
use color_eyre::{Result, eyre};
use std::thread;
use std::time::Duration;

#[derive(Debug)]
pub struct TalosProvisioner {
    config: Config,
    output: String,
    patch_file: Option<String>,
    force: bool,
    skip_installation_media: bool,
    override_protection: bool,
}

impl TalosProvisioner {
    pub fn new(
        config: Config,
        output_directory: String,
        patch_file: Option<String>,
        force: bool,
        skip_installation_media: bool,
        override_protection: bool,
    ) -> Self {
        TalosProvisioner {
            config,
            output: output_directory,
            patch_file,
            force,
            skip_installation_media,
            override_protection,
        }
    }

    pub fn provision(&self) -> Result<()> {
        if self.skip_installation_media {
            tracing::info!("Skipping installation media creation");
        } else {
            self.create_installation_media()?;
        }

        self.generate_talos_config()
            .and_then(|_| self.apply_config())
            .and_then(|_| self.wait_for_nodes())
            .and_then(|_| self.talosctl_bootstrap())
    }

    fn create_installation_media(&self) -> Result<()> {
        // Create the installation media for the nodes
        // This will involve creating a bootable USB or ISO image
        Ok(())
    }

    fn generate_talos_config(&self) -> Result<()> {
        let ip = format!(
            "https://{}:6443",
            self.config.components.servers.control_planes[0].ip_address
        );

        let should_patch = self.patch_file.is_some();
        let patch_file = if should_patch {
            self.patch_file
                .as_ref()
                .ok_or(eyre!("Patch file is required but not provided"))?
        } else {
            "" // we do not care about patching if should_patch is false
        };

        let cmd = "talosctl";
        let cluster_name = self.get_cluster_name()?;
        let output_dir = format!("--output-dir={}", &self.output);
        let mut args = [
            "gen",
            "config",
            cluster_name.as_str(),
            ip.as_str(),
            output_dir.as_str(),
            "--with-examples=false",
            "--with-docs=false",
        ]
        .to_vec();

        if should_patch {
            args.push("--patch");
            args.push(patch_file);
        }

        tracing::debug!("Running command: {} {}", cmd, args.join(" "));

        self.talosctl_command(&args)
            .map_err(|e| eyre!("Failed to execute command '{}': {}", cmd, e))?;

        Ok(())
    }

    fn apply_config(&self) -> Result<()> {
        let control_plane_nodes = &self.config.components.servers.control_planes;
        let worker_nodes = &self.config.components.servers.workers;

        let control_plane_yaml = format!("{}/control-plane.yaml", self.output);
        let worker_yaml = format!("{}/worker.yaml", self.output);

        for node in control_plane_nodes {
            let cmd = "talosctl";
            let args = [
                "apply-config",
                "--insecure",
                "--nodes",
                node.ip_address.as_str(),
                "--file",
                control_plane_yaml.as_str(),
            ];

            tracing::debug!("Running command: {} {}", cmd, args.join(" "));
            self.talosctl_command(&args).map_err(|e| {
                eyre!(
                    "Failed to apply config to control plane node '{}': {}",
                    node.name,
                    e
                )
            })?;
        }

        for node in worker_nodes {
            let cmd = "talosctl";
            let args = [
                "apply-config",
                "--insecure",
                "--nodes",
                node.ip_address.as_str(),
                "--file",
                worker_yaml.as_str(),
            ];

            tracing::debug!("Running command: {} {}", cmd, args.join(" "));
            self.talosctl_command(&args).map_err(|e| {
                eyre!(
                    "Failed to apply config to worker node '{}': {}",
                    node.name,
                    e
                )
            })?;
        }

        Ok(())
    }

    fn talosctl_command(&self, args: &[&str]) -> Result<()> {
        let cmd = "talosctl";
        // tracing::debug!("Running command: {} {}", cmd, args.join(" "));
        if self.force {
            shell::exec(cmd, args)
                .map_err(|e| eyre!("Failed to execute command '{}': {}", cmd, e))?;
        }
        Ok(())
    }

    fn talosctl_bootstrap(&self) -> Result<()> {
        let args = [
            "bootstrap",
            "--insecure",
            "--nodes",
            &self.config.components.servers.control_planes[0].ip_address,
        ];

        tracing::debug!("Running command: talosctl {}", args.join(" "));
        self.talosctl_command(&args)
    }

    fn wait_for_nodes(&self) -> Result<()> {
        thread::sleep(Duration::from_secs(60)); // arbitrary wait time to allow nodes to come up
        Ok(())
    }

    fn get_cluster_name(&self) -> Result<String> {
        Ok(self.config.metadata.name.clone())
    }
}
