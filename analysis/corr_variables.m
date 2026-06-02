% corr_variables.m
% ------------------------------------------
% Computes Pearson correlation coefficients between the kinematic variable
% outputs of MATLAB, Python, and R for each dataset, and saves one
% scatter-plot figure per dataset.
%
% Requirements
%   Run from the repository root. The nine output CSVs must exist in
%   output/adult/, output/children/, and output/upper/ before running.
%
% Thresholds
%   min_N   2    — minimum number of movement elements per trial
%   min_R2  0.7  — minimum R2_alpha for scaling variables to be included
%
% Output
%   output/analysis/figures/corr_<Dataset>.png — one figure per dataset
%   Console table of Pearson r for each variable and platform pair.

repo_root  = fileparts(fileparts(mfilename('fullpath')));
fig_dir    = fullfile(repo_root, 'output', 'analysis', 'figures');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

datasets(1).name  = 'Upper';
datasets(1).files = { ...
    fullfile(repo_root, 'output', 'upper', 'output_upper_R.csv'), ...
    fullfile(repo_root, 'output', 'upper', 'output_upper_python.csv'), ...
    fullfile(repo_root, 'output', 'upper', 'output_upper_matlab.csv')};

datasets(2).name  = 'Children';
datasets(2).files = { ...
    fullfile(repo_root, 'output', 'children', 'output_children_R.csv'), ...
    fullfile(repo_root, 'output', 'children', 'output_children_python.csv'), ...
    fullfile(repo_root, 'output', 'children', 'output_children_matlab.csv')};

datasets(3).name  = 'Adult';
datasets(3).files = { ...
    fullfile(repo_root, 'output', 'adult', 'output_adult_R.csv'), ...
    fullfile(repo_root, 'output', 'adult', 'output_adult_python.csv'), ...
    fullfile(repo_root, 'output', 'adult', 'output_adult_matlab.csv')};

min_N  = 2;
min_R2 = 0.7;

for d = 1 : length(datasets)
    fprintf('Processing Dataset: %s...\n', datasets(d).name);

    tR = readtable(datasets(d).files{1});
    tP = readtable(datasets(d).files{2});
    tM = readtable(datasets(d).files{3});

    sortKeys = {'ind'};
    if all(ismember({'trial', 'task', 'ind'}, tR.Properties.VariableNames))
        sortKeys = {'trial', 'task', 'ind'};
    end
    tR = sortrows(tR, sortKeys);
    tP = sortrows(tP, sortKeys);
    tM = sortrows(tM, sortKeys);

    vars        = tP.Properties.VariableNames;
    target_vars = vars(~cellfun(@isempty, regexp(vars, '_all$')));
    res_cell    = cell(length(target_vars), 4);

    fig = figure('Name', sprintf('Correlation — %s', datasets(d).name), ...
        'Color', 'w', 'Units', 'normalized', 'Position', [0.05, 0.05, 0.9, 0.8], ...
        'Visible', 'off');
    tlo = tiledlayout(length(target_vars), 3, 'TileSpacing', 'Compact', 'Padding', 'Compact');
    title(tlo, sprintf('Correlation Analysis — Dataset: %s', datasets(d).name), ...
        'FontSize', 14, 'FontWeight', 'bold');

    for v = 1 : length(target_vars)
        varName = target_vars{v};
        nName   = 'N_all';
        r2Name  = 'R2_alpha_all';

        vR = str2double(string(tR.(varName)));
        vP = tP.(varName);
        vM = tM.(varName);

        mMP = (tM.(nName) > min_N) & (tP.(nName) > min_N);
        mMR = (tM.(nName) > min_N) & (str2double(string(tR.(nName))) > min_N);
        mRP = (str2double(string(tR.(nName))) > min_N) & (tP.(nName) > min_N);

        if contains(varName, {'alpha', 'K', 'R2_alpha'})
            r2M = tM.(r2Name);
            r2P = tP.(r2Name);
            r2R = str2double(string(tR.(r2Name)));

            mMP = mMP & (r2M >= min_R2) & (r2P >= min_R2);
            mMR = mMR & (r2M >= min_R2) & (r2R >= min_R2);
            mRP = mRP & (r2R >= min_R2) & (r2P >= min_R2);
        end

        comps = {vM(mMP), vP(mMP), 'Matlab vs Python';
                 vM(mMR), vR(mMR), 'Matlab vs R';
                 vR(mRP), vP(mRP), 'R vs Python'};

        res_cell{v, 1} = varName;

        for c = 1 : 3
            X = comps{c, 1}; Y = comps{c, 2}; pairLabel = comps{c, 3};
            nexttile;

            valid = ~isnan(X) & ~isnan(Y);
            X = X(valid); Y = Y(valid);

            if length(X) > 1
                r_val = corr(X, Y);
                res_cell{v, c + 1} = r_val;

                scatter(X, Y, 30, 'filled', 'MarkerFaceAlpha', 0.5); hold on;
                coeffs = polyfit(X, Y, 1);
                x_fit  = linspace(min(X), max(X), 100);
                plot(x_fit, polyval(coeffs, x_fit), 'r-', 'LineWidth', 1.5);
                grid on;
                title(sprintf('%s (r=%.3f)', pairLabel, r_val), 'FontSize', 9);
            else
                res_cell{v, c + 1} = NaN;
                title('N/A');
            end

            if c == 1
                ylabel(varName, 'Interpreter', 'none', 'FontWeight', 'bold');
            end
        end
    end

    fig_path = fullfile(fig_dir, sprintf('corr_%s.png', datasets(d).name));
    exportgraphics(fig, fig_path, 'Resolution', 300);
    close(fig);

    local_results = cell2table(res_cell, ...
        'VariableNames', {'Variable', 'Matlab_vs_Python', 'Matlab_vs_R', 'R_vs_Python'});
    fprintf('Results for %s:\n', datasets(d).name);
    disp(local_results);
end
