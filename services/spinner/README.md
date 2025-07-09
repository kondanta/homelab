# Spinner

It is a service that manages the homelab installation and configuration process. It is responsible for reading the hardware inventory and generating the necessary configuration files for the homelab services.

---

## Features
- Reads hardware inventory from a YAML file.
- Generates configuration files for the homelab services.
    - Specifically, Talos configuration files.
- Apply the generated configuration files to the homelab machines.
- Provides a CLI interface for managing the homelab installation and configuration process.