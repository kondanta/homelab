import os
import sys
import yaml
from pathlib import Path
from typing import Tuple, Dict

PROJECT_NAME = "homelab"

def get_root_dir() -> Path:
    path = Path(os.path.dirname(os.path.abspath(__file__)))
    homedir = next((p for p in path.parents if p.name == PROJECT_NAME), None)

    if homedir is None:
        raise ValueError(f"Project root directory with name '{PROJECT_NAME}' not found.")

    return homedir

def check_python_version(required_version: str) -> None:
    if sys.version_info < tuple(map(int, required_version.split('.'))):
        raise Exception(f"Must be using Python >= {required_version}")

def parse_hardware() -> dict:
    path = str(get_root_dir()) + "/infrastructure/metal/inventory/hardware.yaml"
    with open(path) as f:
        data = yaml.safe_load(f)

    return data

def set_hardware_data() -> Tuple[Dict, Dict]:
    data = parse_hardware()

    control_planes = dict()
    workers = dict()

    cp = data.get('metal', {}).get('instances', {}).get('control_planes', {})
    workers = data.get('metal', {}).get('instances', {}).get('workers', {})

    for instance, details in cp.items():
        control_planes[instance] = details

    for instance, details in workers.items():
        workers[instance] = details

    return control_planes, workers

def echo(msg: str) -> None:
    print(msg)
