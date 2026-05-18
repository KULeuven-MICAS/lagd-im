import argparse
import yaml
import logging
from __init__ import toppath, current_dir

from openising.ising.api import get_hamiltonian_energy
from save_model import store_run

parser = argparse.ArgumentParser()
parser.add_argument("-config_file", help="directory to yaml file for experiment.", type=str)
parser.add_argument("--logging_level", help="level of logging. Defaults to INFO", default=logging.WARNING)

args = parser.parse_args()

# Load base and experiment config files and store them in the correct folder in openising
base_config_dir = current_dir / "base_experiment.yaml"
experiment_config_dir = current_dir / args.config_file / "config_experiment.yaml"

with base_config_dir.open("r") as f:
    base_config = yaml.safe_load(f)
with experiment_config_dir.open("r") as f:
    experiment_config = yaml.safe_load(f)

experiment_config.update(base_config)
save_folder = current_dir / args.config_file

config_path = "./ising/inputs/config/config_experiment.yaml"
openising_config = toppath / config_path
with openising_config.open("w") as f:
    yaml.safe_dump(experiment_config, f)
problem_type = experiment_config["problem_type"]
# Start openising run
ans,_ = get_hamiltonian_energy(problem_type, config_path, args.logging_level)

# Store everything
store_run(ans, save_folder)