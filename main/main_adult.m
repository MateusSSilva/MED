% main_adult.m
% ------------
% Applies the MED algorithm to the Adult Gait dataset (3-D marker positions).
%
% Dataset
%   Folder:    data/dataset_Adult_Gait/ (searched recursively for *_pos.csv)
%   that is the processed version with positional trajectories of the 
%   original IMU derived file
%   Structure: each CSV contains a header row, with columns
%              [ignored, X, Y, Z] in metres; sampling rate fixed at 100 Hz.
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
%   output/adult/output_adult_matlab.csv — one row per trial, columns: file,
%   ind, task, trial, then D/V/T/N/Nt/W/R2/P and alpha/K/R2_alpha for each
%   dimension (suffix _all, _x, _y, _z).

clear

repo_root  = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repo_root, 'pkg'));

min_D = 0.003;
min_T = 0.1;
min_V = 0.01;
lp    = 10;
order = 4;

data_dir   = fullfile(repo_root, 'data', 'dataset_Adult_Gait');
output_dir = fullfile(repo_root, 'output', 'adult');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

var_names = {'file', 'ind', 'task', 'trial'};
var_types = {'int16', 'string', 'string', 'string'};

files        = dir(fullfile(data_dir, '**', '*_pos.csv'));
number_files = length(files);

tab = table('Size', [number_files length(var_types)], ...
    'VariableTypes', var_types, 'VariableNames', var_names);

for i = 1 : number_files

    file_path = [files(i).folder filesep files(i).name];
    parts     = split(files(i).name, '_');

    r          = readmatrix(file_path);
    r          = r(:, 2:4);
    sampleRate = 100;

    output = MED_pkg(r, sampleRate, "m", [min_D, min_T, min_V], [lp, order], ...
        ["scaling", "D", "V", "T", "N", "Nt", "W", "R2", "P", "ME", "timeSeries"]);

    if isempty(output) || isempty(output.D.all)
        continue;
    end

    tab.file(i)  = i;
    tab.ind(i)   = parts(2);
    tab.task(i)  = 'walk';
    tab.trial(i) = parts(3);

    dims       = {'all', 'x', 'y', 'z'};
    suffixes   = {'_all', '_x', '_y', '_z'};
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
    writetable(tab, fullfile(output_dir, 'output_adult_matlab.csv'));
end
