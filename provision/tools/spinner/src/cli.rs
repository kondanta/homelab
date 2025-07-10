// CLI Parser for the Spinner Service
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "spinner", version, about = "Spinner CLI")]
pub struct Cli {
    #[clap(subcommand)]
    pub command: Option<Command>,
}

#[derive(Subcommand)]
pub enum Command {
    /// Provisions the whole cluster with the given configuration.
    #[command(verbatim_doc_comment)]
    Provision {
        /// Force the provisioning of the node. By default, it will work on Dry Run mode.
        #[arg(short, long, default_value_t = false)]
        force: bool,

        /// Config file to use for provisioning.
        #[arg(short, long)]
        config_file: String,

        /// Patch file to use for provisioning.
        /// I.E. `"infrastructure/metal/tasks/provision/patch.yaml"`
        #[arg(long)]
        patch_file: Option<String>,

        /// Skip the installation media creation.
        #[arg(long)]
        skip_installation_media: bool,

        /// Override protection for previous installation.
        /// By default it will override the existing installation's output directory.
        #[arg(long = "override")]
        override_protection: bool,

        /// Output directory for the installation output.
        #[arg(short, long = "output")]
        output_directory: String,
    },

    /// Lists the available nodes in the cluster
    /// This command will list all the nodes in the cluster.
    List {},

    /// Runs the Spinner in server mode. It'll automatically reconcile
    /// the cluster state with the desired state.
    Server {},
}

impl Cli {
    pub fn parse() -> Self {
        Parser::parse()
    }
}
