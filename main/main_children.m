% main_children.m
% ---------------
% Applies the MED algorithm to the CP Child Gait dataset (3-D marker
% positions), containing typically developing (TD) children.
%
% Dataset
%   Folder:    data/CP child gait data/td/ (all *.csv in that directory)
%   Structure: filenames follow the pattern TD<subject><trial>.csv
%              (e.g., TD12a.csv); first column is time [s], remaining
%              columns are positions in millimeters; sampling rate derived
%              from the time column.
%
% Requirements
%   pkg/MED_pkg.m must be on the MATLAB path (added automatically below).
%   Run from the repository root or ensure mfilename resolves correctly.
%
% Parameters
%   unit    mm | min_D 0.003 m | min_T 0.1 s | min_V 0.01 m/s
%   filter  lp 10 Hz, 4th-order Butterworth
%
% Output
%   output/children/output_children_matlab.csv — one row per trial, columns:
%   file, ind, task, trial, then D/V/T/N/Nt/W/R2/P and alpha/K/R2_alpha
%   for each dimension (suffix _all, _x, _y, _z).

clear

repo_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repo_root, 'pkg'));

min_D = 0.003;
min_T = 0.1;
min_V = 0.01;
lp = 10;
order = 4;

data_dir = fullfile(repo_root, 'data', 'CP child gait data', 'td');
output_dir = fullfile(repo_root, 'output', 'children');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

var_names = {'file', 'ind', 'task', 'trial'};
var_types = {'int16', 'string', 'string', 'string'};

files = dir(fullfile(data_dir, '*.csv'));
number_files = length(files);

tab = table('Size', [number_files length(var_types)], ...
    'VariableTypes', var_types, 'VariableNames', var_names);

for i = 1 : number_files

    file_path = [files(i).folder filesep files(i).name];
    [~, name, ~] = fileparts(files(i).name);

    tokens = regexp(name, 'TD(\d+)([a-z]?)', 'tokens');
    if ~isempty(tokens)
        subject = tokens{1}{1};
        trial = tokens{1}{2};
    end

    task = "walk";

    data = readmatrix(file_path);
    r = data(:, 2:end);
    sampleRate = 1 / mean(diff(data(:, 1)));

    output = MED_pkg(r, sampleRate, "mm", [min_D, min_T, min_V], [lp, order], ...
        ["scaling", "D", "V", "T", "N", "Nt", "W", "R2", "P", "ME", "timeSeries"]);

    tab.file(i)  = i;
    tab.ind(i)   = subject;
    tab.task(i)  = task;
    tab.trial(i) = trial;

    dims = {'all', 'x', 'y', 'z'};
    suffixes = {'_all', '_x', '_y', '_z'};
    directVars = {'D', 'V', 'T', 'N', 'Nt', 'W', 'R2', 'P'};
    scaleVars = {'alpha', 'K', 'R2_alpha'};

    if ~isempty(output) && isfield(output, 'D')
        fields = fieldnames(output.D);
    else
        fields = {};
    end

    for k = 1 : length(dims)
        d = dims{k};
        sfx = suffixes{k};
        hasData = any(strcmp(fields, d));

        for v = 1 : length(directVars)
            varName = directVars{v};
            targetField = [varName sfx];
            if hasData
                tab.(targetField)(i) = output.(varName).(d);
            else
                tab.(targetField)(i) = nan;
            end
        end

        for v = 1 : length(scaleVars)
            varName = scaleVars{v};
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
    writetable(tab, fullfile(output_dir, 'output_children_matlab.csv'));
end
