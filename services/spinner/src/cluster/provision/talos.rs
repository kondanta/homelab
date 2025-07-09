use crate::cluster::{self, provision::talos::eyre::eyre};
use crate::config::Config;
use crate::exec::shell;
use color_eyre::{Result, eyre};

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
        // 1. Load the configuration file
        // 2. Get Name, IP, and Hardware information
        // 3. Create the installation media
        // 4. Generate the Talos configuration
        // 5. Provision the nodes with Talos, a.k.a. `talosctl apply-config`
        // 6. Reboot the nodes to apply the configuration
        // 7. Wait for the nodes to come back online
        self.generate_talos_config()
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

        if self.force {
            shell::exec(cmd, &args)
                .map_err(|e| eyre!("Failed to execute command '{}': {}", cmd, e))?;
        }

        Ok(())
    }

    fn apply_config(&self) -> Result<()> {
        // Apply the Talos configuration to the nodes
        // This will involve running the `talosctl apply-config` command
        Ok(())
    }

    fn wait_for_nodes(&self) -> Result<()> {
        // Wait for the nodes to come back online after applying the configuration
        // This will involve checking the status of the nodes and waiting until they are reachable
        Ok(())
    }

    fn reboot_nodes(&self) -> Result<()> {
        // Reboot the nodes to apply the Talos configuration
        // This will involve running the `talosctl reboot` command
        Ok(())
    }

    fn get_node_info(&self) -> Result<()> {
        // Get the Name, IP, and Hardware information from the configuration
        // This will involve parsing the configuration file and extracting the necessary information
        Ok(())
    }

    fn get_cluster_name(&self) -> Result<String> {
        Ok(self.config.metadata.name.clone())
    }
}
