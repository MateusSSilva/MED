"""
figure_cross_plataform.py
------------------------------
Generates bar plots and summary plots of mean and maximum cross-platform
differences (relative and absolute) per variable and per dataset, using the
output of comparison_table_3_with_Adult.m as input.

Requirements
------------
Run from the repository root, or ensure __file__ resolves to
analysis/figure_barplot_with_adults.py within the repository.
output/analysis/cross_platform_detailed_stats_filtered.csv must exist.

Output
------
output/analysis/figures/bar_plot_all_Rel.pdf
output/analysis/figures/bar_plot_all_Abs.pdf
output/analysis/figures/summary_bar_outliers_all_Rel.pdf
output/analysis/figures/summary_bar_outliers_all_Abs.pdf
"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

repo_root    = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
analysis_dir = os.path.join(repo_root, 'output', 'analysis')
fig_dir      = os.path.join(analysis_dir, 'figures')
os.makedirs(fig_dir, exist_ok=True)

df = pd.read_csv(os.path.join(analysis_dir, 'cross_platform_detailed_stats_filtered.csv'))

plt.rcParams.update({
    "font.family": "serif",
    "font.size":   10,
    "axes.labelsize": 12,
    "figure.dpi":  200
})
sns.set_style("whitegrid")

custom_palette = ["#b0d0b7", "#6ea7b1", "#5579a4"]
summary_palette = ["#b0d0b7", "#5579a4"]


def clean_var_names(name):
    return name.replace('_all', '').replace('_x', '').replace('_y', '').replace('_z', '')


def prepare_and_plot(df, var_type='all', metric='Rel'):
    mask       = df['Variable'].str.contains('_all') if var_type == 'all' \
                 else df['Variable'].str.contains('_x|_y|_z')
    df_f       = df[mask].copy()
    df_f['Variable_Clean'] = df_f['Variable'].apply(clean_var_names)

    platforms = {'MatPy': 'MAT vs Py', 'MatR': 'MAT vs R', 'RPy': 'R vs Py'}
    long_list = []

    for plat, name in platforms.items():
        for stat in ['Mean', 'Max']:
            col = f"{plat}_{stat}{metric}"
            if col in df_f.columns:
                temp = df_f[['Dataset', 'Variable_Clean', 'Variable', col]].copy()
                temp['Platform'] = name
                temp['StatType'] = stat
                temp['Value']    = temp[col]
                long_list.append(temp)

    df_long = pd.concat(long_list)

    plt.figure(figsize=(10, 5))
    ax1 = sns.barplot(data=df_long[df_long['StatType'] == 'Mean'],
                      x='Variable_Clean', y='Value', hue='Platform',
                      palette=custom_palette, capsize=.05, errwidth=1.2)
    ax1.set_yscale('log')
    plt.ylabel(f"{metric} Error")
    plt.xlabel("Variable")
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.tight_layout()
    out1 = os.path.join(fig_dir, f"bar_plot_{var_type}_{metric}.pdf")
    plt.savefig(out1, dpi=600, bbox_inches='tight')
    plt.close()
    print(f"Saved: {out1}")

    plt.figure(figsize=(8, 5))
    ax2 = sns.barplot(data=df_long, x='Dataset', y='Value', hue='StatType',
                      palette=summary_palette, alpha=0.7, capsize=.05, errorbar=None)
    sns.stripplot(data=df_long, x='Dataset', y='Value', hue='StatType',
                  palette=summary_palette, dodge=True, jitter=True,
                  size=4, alpha=0.6, ax=ax2, legend=False)
    ax2.set_yscale('log')
    plt.ylabel(f"{metric} Error")
    ax2.set_xticklabels([
        'Health Adults -\nUpper-Limb Movements',
        'Typically Developed Children -\nGait',
        'Health Adults - IMU based -\nGait'
    ])
    plt.legend(bbox_to_anchor=(1.02, 1), loc='upper left', borderaxespad=0.)
    plt.tight_layout()
    out2 = os.path.join(fig_dir, f"summary_bar_outliers_{var_type}_{metric}.pdf")
    plt.savefig(out2, dpi=600, bbox_inches='tight')
    plt.close()
    print(f"Saved: {out2}")


prepare_and_plot(df, var_type='all', metric='Rel')
prepare_and_plot(df, var_type='all', metric='Abs')
