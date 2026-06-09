"""
figure_features.py
---------------------------------
Generates a single figure with one 2×5 grid of boxplots per
dataset, comparing the distribution of each kinematic variable across the
three analysis platforms (MATLAB, Python, R).

Requirements
------------
Run from the repository root, or ensure __file__ resolves to
analysis/boxplots_features_with_adults.py within the repository.
The nine output CSVs must exist in output/adult/, output/children/,
and output/upper/ before running.

Thresholds
----------
min_N   2    — minimum number of movement elements; trials below this are
               set to NaN for all variables.
min_R2  0.7  — minimum R2_alpha; trials below this are set to NaN for
               alpha, K, and R2_alpha.

Output
------
output/analysis/figures/combined_dataset_boxplots.png
"""

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fig_dir   = os.path.join(repo_root, 'output', 'analysis', 'figures')
os.makedirs(fig_dir, exist_ok=True)

datasets = [
    {
        'name': 'Health Adults - Upper-Limb Movements',
        'subdir': 'upper',
        'files': {
            'MATLAB': 'output_upper_matlab.csv',
            'Python': 'output_upper_python.csv',
            'R': 'output_upper_R.csv'
        }
    },
    {
        'name': 'Typically Developed Children - Gait',
        'subdir': 'children',
        'files': {
            'MATLAB': 'output_children_matlab.csv',
            'Python': 'output_children_python.csv',
            'R': 'output_children_R.csv'
        }
    },
    {
        'name': 'Health Adults - IMU based - Gait',
        'subdir': 'adult',
        'files': {
            'MATLAB': 'output_adult_matlab.csv',
            'Python': 'output_adult_python.csv',
            'R': 'output_adult_R.csv'
        }
    }
]

base_features  = ['D', 'V', 'T', 'N', 'Nt', 'W', 'R2', 'P', 'alpha', 'K']
features = [f"{feat}_all" for feat in base_features]
platforms = ['MATLAB', 'Python', 'R']
custom_palette = ["#b0d0b7", "#6ea7b1", "#5579a4"]
min_N = 2
min_R2 = 0.7

fig    = plt.figure(figsize=(20, 24))
subfigs = fig.subfigures(nrows=len(datasets), ncols=1, hspace=0.05)

for ds_idx, ds in enumerate(datasets):
    print(f"Processing Dataset: {ds['name']}...")

    subfig = subfigs[ds_idx]
    subfig.suptitle(f"Dataset: {ds['name']}", fontsize=16, fontweight='bold')
    axes = subfig.subplots(nrows=2, ncols=5).flatten()

    df_list = []

    for platform in platforms:
        csv_path = os.path.join(repo_root, 'output', ds['subdir'], ds['files'][platform])

        if not os.path.exists(csv_path):
            print(f"  Warning: {csv_path} not found.")
            continue

        df = pd.read_csv(csv_path)
        cols_keep = [col for col in features if col in df.columns]
        df_sub = df[cols_keep].copy()

        for col in cols_keep:
            df_sub[col] = pd.to_numeric(df_sub[col], errors='coerce')

        if 'N_all' in df_sub.columns:
            valid_N = df_sub['N_all'] > min_N
            df_sub.loc[~valid_N, cols_keep] = np.nan

        if 'R2_alpha_all' in df_sub.columns:
            valid_R2 = df_sub['R2_alpha_all'] > min_R2
            for col in [c for c in ['alpha_all', 'K_all', 'R2_alpha_all'] if c in df_sub.columns]:
                df_sub.loc[~valid_R2, col] = np.nan

        df_sub['Platform'] = platform
        df_list.append(df_sub)

    if not df_list:
        for ax in axes:
            ax.set_visible(False)
        axes[0].set_visible(True)
        axes[0].text(0.5, 0.5, 'Dataset files missing', ha='center', va='center', fontsize=12)
        continue

    combined_df = pd.concat(df_list, ignore_index=True)
    melted_df   = combined_df.melt(
        id_vars=['Platform'],
        value_vars=[col for col in features if col in combined_df.columns],
        var_name='Feature', value_name='Value')
    melted_df['Platform'] = pd.Categorical(melted_df['Platform'], categories=platforms, ordered=True)

    for i, feature in enumerate(features):
        ax           = axes[i]
        feature_data = melted_df[melted_df['Feature'] == feature].dropna(subset=['Value'])
        clean_title  = feature.replace('_all', '')

        if not feature_data.empty:
            sns.boxplot(data=feature_data, x='Platform', y='Value', hue='Platform',
                        palette=custom_palette, ax=ax, order=platforms,
                        showfliers=False, legend=False)
            ax.set_title(clean_title, fontsize=12, fontweight='bold')
            ax.set_xlabel('')
            ax.set_ylabel('Value' if i % 5 == 0 else '')
        else:
            ax.text(0.5, 0.5, 'No valid data\n(filtered out)',
                    ha='center', va='center', fontsize=10, color='gray')
            ax.set_title(clean_title, fontsize=12, fontweight='bold')
            ax.set_xticks([])
            ax.set_yticks([])

output_path = os.path.join(fig_dir, 'combined_dataset_boxplots.png')
plt.savefig(output_path, dpi=300, bbox_inches='tight')
print(f"Saved: {output_path}")
