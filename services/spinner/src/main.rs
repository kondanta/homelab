mod config;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = config::Config::from_file("infrastructure/metal/inventory/hardware.yaml")?;
    println!("{:#?}", config);

    Ok(())

}