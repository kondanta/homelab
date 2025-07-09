use serde::Deserialize;
use serde_yaml::from_reader;

#[derive(Debug, Deserialize)]
pub(crate) struct Config {
    metadata: Metadata,
    components: Components,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Metadata {
    name: String,
    version: String,
    description: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Components {
    servers: Servers,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Servers {
    control_planes: Vec<ControlPlane>,
    workers: Vec<Worker>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct ControlPlane {
    name: String,
    #[serde(rename = "ip_address")]
    ip_address: String,
    hardware: Hardware,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Worker {
    name: String,
    #[serde(rename = "ip_address")]
    ip_address: String,
    hardware: Hardware,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Hardware {
    cpu: String,
    gpu: String,
    memory: u32,
    disks: Vec<Disk>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Disk {
    path: String,
    size: u32,
    #[serde(rename = "type")]
    type_: String,
}

impl Config {
    pub fn from_file(path: &str) -> Result<Self, Box<dyn std::error::Error>> {
        let file = std::fs::File::open(path)?;
        let reader = std::io::BufReader::new(file);
        let config = from_reader(reader)?;

        Ok(config)
    }
}