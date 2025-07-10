use color_eyre::Result;
use serde::Deserialize;
use serde_yaml::from_reader;

#[derive(Debug, Deserialize)]
pub(crate) struct Config {
    pub metadata: Metadata,
    pub components: Components,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Metadata {
    pub name: String,
    pub version: String,
    pub description: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Components {
    pub servers: Servers,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Servers {
    pub control_planes: Vec<ControlPlane>,
    pub workers: Vec<Worker>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct ControlPlane {
    pub name: String,
    pub ip_address: String,
    pub hardware: Hardware,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Worker {
    pub name: String,
    pub ip_address: String,
    pub hardware: Hardware,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Hardware {
    pub cpu: String,
    pub gpu: String,
    pub memory: u32,
    pub disks: Vec<Disk>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct Disk {
    pub path: String,
    pub size: u32,
    #[serde(rename = "type")]
    pub type_: String,
}

impl Config {
    pub fn from_file(path: &str) -> Result<Self> {
        let file = std::fs::File::open(path)?;
        let reader = std::io::BufReader::new(file);
        let config = from_reader(reader)?;

        Ok(config)
    }
}
