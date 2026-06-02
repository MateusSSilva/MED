% main_upper.m
% ------------
% Applies the MED algorithm to the Complex Upper Limb Movements dataset
% (2-D or 3-D marker positions).
%
% Dataset
%   Folder:    data/complex-upper-limb-movements-1.0.0/*/ (all *.csv therein)
%   Structure: each subfolder is named after the subject; filenames encode
%              task and trial (e.g., reach0a.csv → task "reach", trial "a");
%              first column is time [s], remaining columns are positions in
%              metres; CSV fields are semicolon-separated.
%
% Requirements
%   pkg/MED_pkg.m must be on the MATLAB path (added automatically below).
%   Run from the repository root or ensure mfilename resolves correctly.
%
% Parameters
%   unit    m | min_D 0.003 m | min_T 0.1 s | min_V 0.01 m/s
%   filter  lp 10 Hz, 4th-order Butterworth
%
% Output
%   output/upper/output_upper_matlab.csv — one row per trial, columns: file,
%   ind, task, trial, then D/V/T/N/Nt/W/R2/P and alpha/K/R2_alpha for each
%   dimension (suffix _all, _x, _y).

clear

repo_root  = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repo_root, 'pkg'));

min_D = 0.003;
min_T = 0.1;
min_V = 0.01;
lp    = 10;
order = 4;

data_dir   = fullfile(repo_root, 'data', 'complex-upper-limb-movements-1.0.0', '*');
output_dir = fullfile(repo_root, 'output', 'upper');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

var_names = {'file', 'ind', 'task', 'trial'};
var_types = {'int16', 'string', 'string', 'string'};

files        = dir(fullfile(data_dir, '*.csv'));
number_files = length(files);

tab = table('Size', [number_files length(var_types)], ...
    'VariableTypes', var_types, 'VariableNames', var_names);

for i = 1 : number_files

    file_path  = [files(i).folder filesep files(i).name];
    name       = files(i).name;
    parts      = split(name, '0');
    parts_fold = split(files(i).folder, '\');

    subject = parts_fold(end);
    task    = parts(1);
    trial   = char(parts(2));
    trial   = trial(1);

    data       = readmatrix(file_path);
    r          = data(:, 2:end);
    sampleRate = 1 / mean(diff(data(:, 1)));

    output = MED_pkg(r, sampleRate, "m", [min_D, min_T, min_V], [lp, order], ...
        ["scaling", "D", "V", "T", "N", "Nt", "W", "R2", "P", "ME", "timeSeries"]);

    if isempty(output) || isempty(output.D.all)
        continue;
    end

    tab.file(i)  = i;
    tab.ind(i)   = subject;
    tab.task(i)  = task;
    tab.trial(i) = trial;

    dims       = {'all', 'x', 'y'};
    suffixes   = {'_all', '_x', '_y'};
    directVars = {'D', 'V', 'T', 'N', 'Nt', 'W', 'R2', 'P'};
    scaleVars  = {'alpha', 'K', 'R2_alpha'};
    fields     = fieldnames(output.D);

    for k = 1 : length(dims)
        d       = dims{k};
        sfx     = suffixes{k};
        hasData = any(strcmp(fields, d));

        for v = 1 : length(directVars)
            varName     = directVars{v};
            targetField = [varName sfx];
            if hasData
                tab.(targetField)(i) = output.(varName).(d);
            else
                tab.(targetField)(i) = nan;
            end
        end

        for v = 1 : length(scaleVars)
            varName     = scaleVars{v};
            targetField = [varName sfx];
            if hasData
                tab.(targetField)(i) = output.scaling.(varName).(d);
            else
                tab.(targetField)(i) = nan;
            end
        end
    end

    disp(i / number_files);
end

if ~isempty(tab)
    writetable(tab, fullfile(output_dir, 'output_upper_matlab.csv'));
end
