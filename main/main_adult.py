"""
main_adult.py
-------------
Applies the MED algorithm to the Adult Gait dataset (3-D marker positions).

Dataset
-------
Folder:    data/dataset_Adult_Gait/ (searched recursively for *pos.csv)
Folder:    data/dataset_Adult_Gait/ (searched recursively for *_pos.csv)
           that is the processed version with positional trajectories of the 
           original IMU derived file
Structure: each CSV contains a header row; columns are [ignored, X, Y, Z]
           in metres; sampling rate is fixed at 100 Hz. Filename format:
           <prefix>_<subject>_<trial>_pos.csv.

Requirements
------------
pkg/MED_pkg.py (profile_MED, rescaling_MED, and cost_e removed).

Parameters
----------
unit    m  |  min_D 0.003 m  |  min_T 0.1 s  |  min_V 0.01 m/s
filter  lp 10 Hz, 4th-order Butterworth

Output
------
output/adult/output_adult_python.csv — one row per trial, columns: file,
ind, task, trial, then D/V/T/N/Nt/W/R2/P and alpha/K/R2_alpha for each
dimension (suffix _all, _x, _y, _z).
"""

import os
import sys
import glob
import pandas as pd
import numpy as np

repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(repo_root, 'pkg'))
import MED_pkg as m

data_dir   = os.path.join(repo_root, 'data', 'dataset_Adult_Gait')
output_dir = os.path.join(repo_root, 'output', 'adult')
os.makedirs(output_dir, exist_ok=True)

tab   = pd.DataFrame(columns=["file", "ind", "task", "trial"])
files = glob.glob(os.path.join(data_dir, "**", "*pos.csv"), recursive=True)

for i, file_path in enumerate(files):
    file_name = os.path.basename(file_path)
    parts     = file_name.split("_")
    subject   = parts[1]
    trial     = parts[2]
    task      = "walk"

    print(f"Processing: {file_name} | Subject: {subject} | Task: {task} | Trial: {trial}")

    try:
        data = pd.read_csv(file_path, header=0).values
        r    = data[:, 1:4]
    except Exception as e:
        print(f"Error reading {file_name}: {e}")
        continue

    output = m.MED(r, 100, 'm',
                   np.array([0.003, 0.1, 0.01]),
                   np.array([10, 4]),
                   ["scaling", "D", "V", "T", "N", "Nt", "W", "R2", "P", "ME", "timeSeries"])

    dims        = {'all': '_all', 'x': '_x', 'y': '_y', 'z': '_z'}
    direct_vars = ['D', 'V', 'T', 'N', 'Nt', 'W', 'R2', 'P']
    scale_vars  = ['alpha', 'K', 'R2_alpha']
    row_data    = {"file": i, "ind": subject, "task": task, "trial": trial}

    for d, suffix in dims.items():
        if d in output.index:
            for var in direct_vars:
                row_data[f"{var}{suffix}"] = output.loc[d, var]
            scaling_obj = output.loc[d, "scaling"]
            for var in scale_vars:
                try:
                    row_data[f"{var}{suffix}"] = scaling_obj[var]
                except (KeyError, TypeError):
                    row_data[f"{var}{suffix}"] = np.nan
        else:
            for var in direct_vars + scale_vars:
                row_data[f"{var}{suffix}"] = np.nan

    tab = pd.concat([tab, pd.DataFrame([row_data])], ignore_index=True)
    print(i)

tab.to_csv(os.path.join(output_dir, 'output_adult_python.csv'), index=False)
