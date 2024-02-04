use clap::Parser;

#[derive(Parser)]
struct Opts {
    #[clap(subcommand)]
    command: Command,
}

#[derive(Parser)]
enum Command {
}


fn main() -> color_eyre::Result<()> {
    color_eyre::install()?;

    let _opts = Opts::parse();

    println!("Hello, world!");

    Ok(())
}
