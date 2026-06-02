% comparison_table.m
% --------------------------------
% Computes pairwise absolute and relative differences between the outputs
% produced by MATLAB, Python, and R for each of the three datasets, across
% all kinematic variables. Variables related to the scaling model (alpha, K,
% R2_alpha) are additionally filtered by a minimum R2_alpha threshold.
%
% Requirements
%   Run from the repository root. The nine output CSVs must exist in
%   output/adult/, output/children/, and output/upper/ before running.
%
% Thresholds
%   min_N   2       — minimum number of movement elements per trial
%   min_R2  0.7     — minimum R2_alpha for scaling variables to be included
%
% Output
%   output/analysis/cross_platform_detailed_stats_filtered.csv
%     One row per variable per dataset plus one global summary row, with
%     columns: Dataset, Variable, and Mean/Max relative and absolute
%     differences for each of the three platform pairs (MatPy, MatR, RPy).

repo_root = fileparts(fileparts(mfilename('fullpath')));

min_N_threshold  = 2;
min_R2_threshold = 0.7;

out_dir = fullfile(repo_root, 'output', 'analysis');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

upper_R      = readtable(fullfile(repo_root, 'output', 'upper',    'output_upper_R.csv'));
upper_python = readtable(fullfile(repo_root, 'output', 'upper',    'output_upper_python.csv'));
upper_matlab = readtable(fullfile(repo_root, 'output', 'upper',    'output_upper_matlab.csv'));

children_R      = readtable(fullfile(repo_root, 'output', 'children', 'output_children_R.csv'));
children_python = readtable(fullfile(repo_root, 'output', 'children', 'output_children_python.csv'));
children_matlab = readtable(fullfile(repo_root, 'output', 'children', 'output_children_matlab.csv'));

adult_R      = readtable(fullfile(repo_root, 'output', 'adult',    'output_adult_R.csv'));
adult_python = readtable(fullfile(repo_root, 'output', 'adult',    'output_adult_python.csv'));
adult_matlab = readtable(fullfile(repo_root, 'output', 'adult',    'output_adult_matlab.csv'));

datasets(1).name = 'Upper';
datasets(1).R = upper_R; datasets(1).Py = upper_python; datasets(1).Mat = upper_matlab;
datasets(2).name = 'Children';
datasets(2).R = children_R; datasets(2).Py = children_python; datasets(2).Mat = children_matlab;
datasets(3).name = 'Adult';
datasets(3).R = adult_R; datasets(3).Py = adult_python; datasets(3).Mat = adult_matlab;

disp_rel         = table();
disp_abs         = table();
full_stats_table = [];
Difference_Struct = struct();

for i = 1 : length(datasets)
    name  = datasets(i).name;
    T_R   = datasets(i).R;
    T_Py  = datasets(i).Py;
    T_Mat = datasets(i).Mat;

    Difference_Struct(i).DatasetName = name;

    cols = T_R.Properties.VariableNames;
    if all(ismember({'trial', 'task', 'ind'}, cols))
        sortKeys = {'trial', 'task', 'ind'};
    else
        sortKeys = {'ind'};
    end
    T_R   = sortrows(T_R,   sortKeys);
    T_Py  = sortrows(T_Py,  sortKeys);
    T_Mat = sortrows(T_Mat, sortKeys);

    nRows     = height(T_R);
    all_vars  = T_Py.Properties.VariableNames;
    var_names = all_vars(~cellfun(@isempty, regexp(all_vars, '_(x|y|z|all)$')));

    g_MatPy_A = []; g_MatPy_B = [];
    g_MatR_A  = []; g_MatR_B  = [];
    g_RPy_A   = []; g_RPy_B   = [];

    for v = 1 : length(var_names)
        varName = var_names{v};

        suffixMatch = regexp(varName, '_(x|y|z|all)$', 'match');
        suffix = suffixMatch{1};
        nName  = ['N' suffix];
        r2Name = ['R2_alpha' suffix];

        mask_MatPy = true(nRows, 1);
        mask_MatR  = true(nRows, 1);
        mask_RPy   = true(nRows, 1);

        if ismember(nName, T_R.Properties.VariableNames)
            n_R_vec   = str2double(string(T_R.(nName)));
            n_Py_vec  = T_Py.(nName);
            n_Mat_vec = T_Mat.(nName);

            mask_MatPy = mask_MatPy & (n_Mat_vec > min_N_threshold) & (n_Py_vec > min_N_threshold);
            mask_MatR  = mask_MatR  & (n_Mat_vec > min_N_threshold) & (n_R_vec  > min_N_threshold);
            mask_RPy   = mask_RPy   & (n_R_vec   > min_N_threshold) & (n_Py_vec > min_N_threshold);
        end

        is_sensitive = contains(varName, {'alpha_', 'K_', 'R2_alpha_'});
        if is_sensitive && ismember(r2Name, T_Py.Properties.VariableNames)
            r2_R_vec   = str2double(string(T_R.(r2Name)));
            r2_Py_vec  = T_Py.(r2Name);
            r2_Mat_vec = T_Mat.(r2Name);

            mask_MatPy = mask_MatPy & (r2_Mat_vec >= min_R2_threshold) & (r2_Py_vec >= min_R2_threshold);
            mask_MatR  = mask_MatR  & (r2_Mat_vec >= min_R2_threshold) & (r2_R_vec  >= min_R2_threshold);
            mask_RPy   = mask_RPy   & (r2_R_vec   >= min_R2_threshold) & (r2_Py_vec >= min_R2_threshold);
        end

        col_R   = str2double(string(T_R.(varName)));
        col_Py  = T_Py.(varName);
        col_Mat = T_Mat.(varName);

        mp_A = col_Mat(mask_MatPy); mp_B = col_Py(mask_MatPy);
        mr_A = col_Mat(mask_MatR);  mr_B = col_R(mask_MatR);
        rp_A = col_R(mask_RPy);     rp_B = col_Py(mask_RPy);

        [s_MatPy, diff_MatPy] = calculate_stats(mp_A, mp_B);
        [s_MatR,  diff_MatR]  = calculate_stats(mr_A, mr_B);
        [s_RPy,   diff_RPy]   = calculate_stats(rp_A, rp_B);

        Difference_Struct(i).Variables(v).Name       = varName;
        Difference_Struct(i).Variables(v).diff_MatPy = diff_MatPy;
        Difference_Struct(i).Variables(v).diff_MatR  = diff_MatR;
        Difference_Struct(i).Variables(v).diff_RPy   = diff_RPy;

        new_row          = create_summary_row(name, varName, s_MatPy, s_MatR, s_RPy);
        full_stats_table = [full_stats_table; new_row]; %#ok<AGROW>

        g_MatPy_A = [g_MatPy_A; mp_A]; g_MatPy_B = [g_MatPy_B; mp_B]; %#ok<AGROW>
        g_MatR_A  = [g_MatR_A;  mr_A]; g_MatR_B  = [g_MatR_B;  mr_B]; %#ok<AGROW>
        g_RPy_A   = [g_RPy_A;   rp_A]; g_RPy_B   = [g_RPy_B;   rp_B]; %#ok<AGROW>
    end

    stats_MatPy = calculate_stats(g_MatPy_A, g_MatPy_B);
    stats_MatR  = calculate_stats(g_MatR_A,  g_MatR_B);
    stats_RPy   = calculate_stats(g_RPy_A,   g_RPy_B);

    full_stats_table = [full_stats_table; ...
        create_summary_row(name, 'GLOBAL (Filtered)', stats_MatPy, stats_MatR, stats_RPy)]; %#ok<AGROW>

    disp_rel = [disp_rel; table({name}, ...
        stats_MatPy.max_rel, stats_MatPy.mean_rel, ...
        stats_MatR.max_rel,  stats_MatR.mean_rel, ...
        stats_RPy.max_rel,   stats_RPy.mean_rel, ...
        'VariableNames', {'Dataset', 'MatPy_Max_Rel', 'MatPy_Mean_Rel', ...
                          'MatR_Max_Rel', 'MatR_Mean_Rel', 'RPy_Max_Rel', 'RPy_Mean_Rel'})]; %#ok<AGROW>

    disp_abs = [disp_abs; table({name}, ...
        stats_MatPy.max_abs, stats_MatPy.mean_abs, ...
        stats_MatR.max_abs,  stats_MatR.mean_abs, ...
        stats_RPy.max_abs,   stats_RPy.mean_abs, ...
        'VariableNames', {'Dataset', 'MatPy_Max_Abs', 'MatPy_Mean_Abs', ...
                          'MatR_Max_Abs', 'MatR_Mean_Abs', 'RPy_Max_Abs', 'RPy_Mean_Abs'})]; %#ok<AGROW>
end

fprintf('------------------------------------------------------------\n');
fprintf('RELATIVE DIFFERENCE (%%) — filtered (N > %d, R2 > %.2f for scaling vars)\n', ...
    min_N_threshold, min_R2_threshold);
disp(disp_rel);
fprintf('------------------------------------------------------------\n');
disp('ABSOLUTE DIFFERENCE — filtered');
disp(disp_abs);

writetable(full_stats_table, fullfile(out_dir, 'cross_platform_detailed_stats_filtered.csv'));

function [s, diff_abs] = calculate_stats(A, B)
    if isempty(A)
        s.max_abs = NaN; s.mean_abs = NaN; s.max_rel = NaN; s.mean_rel = NaN;
        diff_abs = []; return;
    end
    diff_abs   = abs(A - B);
    s.max_abs  = max(diff_abs(:));
    s.mean_abs = mean(diff_abs(:), "omitnan");
    diff_rel   = 100 * diff_abs ./ (abs(A) + eps);
    s.max_rel  = max(diff_rel(:));
    s.mean_rel = mean(diff_rel(:), "omitnan");
end

function T = create_summary_row(d_name, v_name, s1, s2, s3)
    T = table({d_name}, {v_name}, ...
        s1.max_rel, s1.mean_rel, s1.max_abs, s1.mean_abs, ...
        s2.max_rel, s2.mean_rel, s2.max_abs, s2.mean_abs, ...
        s3.max_rel, s3.mean_rel, s3.max_abs, s3.mean_abs, ...
        'VariableNames', {'Dataset', 'Variable', ...
        'MatPy_MaxRel', 'MatPy_MeanRel', 'MatPy_MaxAbs', 'MatPy_MeanAbs', ...
        'MatR_MaxRel',  'MatR_MeanRel',  'MatR_MaxAbs',  'MatR_MeanAbs', ...
        'RPy_MaxRel',   'RPy_MeanRel',   'RPy_MaxAbs',   'RPy_MeanAbs'});
end
