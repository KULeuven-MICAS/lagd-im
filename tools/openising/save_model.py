from pathlib import Path
import numpy as np
from typing import Any

from openising.ising.utils.HDF5Logger import return_data
from openising.ising.stages.model import IsingModel
from openising.ising.stages.simulation_stage import Ans

def store_run(ans: Ans, save_folder:Path) -> None:
    """Save the model and solver parameters in binary format.
    
    @type ans: Ans
    @param ans: return ans of the run
    @type save_folder: str
    @param save_folder: folder in which to save the results
    """

    for i, logfile in enumerate(ans.logfiles):
        folder_run = save_folder / f"run_{i}"
        Path.mkdir(folder_run, exist_ok=True)
        store_results_logfile(logfile, "cluster", folder_run, "clusters.txt")
        store_results_logfile(logfile, "state_in", folder_run, "initial_state.txt")    

    
    quantized_model:IsingModel = ans.quantized_model
    quantized_model_J = np.zeros_like(quantized_model.J, dtype="<U4")
    quantized_model_h = np.zeros_like(quantized_model.h, dtype="<U4")
    for i in range(quantized_model.num_variables):
        quantized_model_h[i] = np.binary_repr(int(quantized_model.h[i]), width=4)
        for j in range(i, quantized_model.num_variables):
            quantized_model_J[i, j] = np.binary_repr(int(quantized_model.J[i, j]), width=4)
            quantized_model_J[j, i] = quantized_model_J[i, j]
    
    with (save_folder / "model.txt").open("w") as f:
        f.write("# J matrix\n")
        np.savetxt(f, quantized_model_J, fmt="%4s")
        f.write("# h vector\n")
        np.savetxt(f, quantized_model_h, fmt="%4s")
        f.write(f"# offset\n{quantized_model.c}\n")
        f.write(f"# scaling factor h: {ans.config.h_scale_factor}\n")
    
    
def store_results_logfile(logfile: Path, data_name: str, save_folder:Path, file_name: str) -> None:
    """Loads and stores the data from the given logfile

    @type logfile: pathlib.Path
    @param logfile: the logfile from where to retrieve the data
    @type data_name: str
    @param data_name: name of the data that will be retrieved.
    @type save_folder: pathlib.Path
    @param save_folder: folder where to save the data
    @type file_name: str
    @param file_name: name of the file to save.
    """
    data = return_data(logfile, data=data_name)
    save_path = save_folder / file_name

    if data_name == "state_in":
        new_data = np.where(data[0, :] <= 0, 0, 1).reshape((1,-1))
    else:
        new_data = data
        if data.shape[0] < 513:
            padding = np.full((513 - data.shape[0], data.shape[1]), 0)
            new_data = np.append(new_data, padding, axis=0)       
    with save_path.open("w") as f:
        np.savetxt(f, new_data, fmt="%1u", delimiter="")