%{
MED_pkg — Movement Element Decomposition Package
============================================

Overview
--------
This file implements the Movement Element Decomposition (MED) algorithm, a method
for decomposing continuous kinematic time-series data into discrete movement
elements (MEs). Each element is a bounded interval of movement (motor primitive),
identified by its velocity profile and validated against configurable thresholds
for displacement, duration, and velocity.

The algorithm supports positional data in one, two, or three spatial dimensions
and produces per-dimension and aggregate features for each detected ME.

Pipeline Summary
----------------
Raw position data undergoes the following sequential processing steps:

  1. Unit conversion    — input coordinates are normalised to metres.
  2. Low-pass filtering — a zero-phase Butterworth filter (default: 4th order,
     10 Hz cutoff) removes high-frequency noise while preserving movement
     kinematics. Border samples affected by filter edge effects are discarded
     unless trim_border is set to false.
  3. Velocity computation — instantaneous velocity is derived via first-order
     finite differences of the filtered position signal.
  4. Segmentation (segment_MED) — velocity peaks and zero-crossings are located
     per dimension to define candidate movement elements.
  5. Element validation — candidates failing minimum displacement (min_D),
     duration (min_T), or velocity (min_V) criteria are rejected.
  6. Feature extraction (analyze_elements_MED) — for each valid element, scalar
     features are computed: displacement D [m], mean velocity V [m/s], duration
     T [s], similarity index W relative to the Hoff bell-shaped profile,
     coefficient of determination R², and peak count P.
  7. Scaling analysis (scaling_MED) — a power-law relationship V = K · D^alpha
     is estimated via log-log regression per dimension.

Public API
----------
MED_pkg(movementData, FPS, ...)
  Main entry point. Accepts position data and processing parameters, and
  returns a struct of per-dimension and aggregate movement statistics.

  In MATLAB, this file's subfunctions (segment_MED, analyze_elements_MED,
  scaling_MED) are local to this file and are not callable from external
  scripts. Only MED_pkg is accessible.

Notes
-----
- The Hoff velocity profile used for similarity index (W) is the
  minimum-jerk bell-shaped curve: H(t) = V_mean · 30 · (t⁴ − 2t³ + t²),
  where t ∈ [0, 1] is normalised time.
- borderEffect = round(2 · FPS / lp · order / 4) frames are removed from
  each end of the signal after filtering to suppress edge artefacts. This
  behaviour can be disabled by passing trim_border = false.

How to cite
-----------
DOI: https://doi.org/10.5281/zenodo.20503393

%}

function output = MED_pkg(varargin)
% MED_pkg  Main entry point of the Movement Element Detection algorithm.
%
%   output = MED_pkg(movementData, FPS)
%   output = MED_pkg(movementData, FPS, unit, limits, filter, outputVar)
%   output = MED_pkg(movementData, FPS, unit, limits, filter, outputVar, ...
%                    scaling_plot_name, t, trim_border)
%
%   Arguments (all optional after FPS; pass [] to use the default):
%     movementData       — (N × dim) position matrix [m, cm, or mm]
%     FPS                — capture frequency in frames per second
%     unit               — 'm' (default) | 'cm' | 'mm'
%     limits             — [min_D, min_T, min_V]; defaults [0.003, 0.1, 0.01]
%     filter             — [lp, order]; defaults [10, 4]
%     outputVar          — string array of requested output fields
%     scaling_plot_name  — path for the scaling log-log plot (PNG)
%     t                  — custom time vector; if empty, derived from FPS
%     trim_border        — logical, default true; set false to retain the
%                          filter edge-effect samples

movementData = varargin{1};
FPS          = varargin{2};

unit            = "m";
min_D = 0.003; min_T = 0.1; min_V = 0.01;
lp = 10; order = 4;
outputVar       = ["scaling", "D", "V", "T", "N", "Nt", "W", ...
                   "R2", "P", "D_all", "V_all", "T_all", "W_all", "R2_all", ...
                   "P_all", "timeSeries", "ME"];
plot_scaling_name = [];
t_input         = [];
trim_border     = true;

if nargin > 2  && ~isempty(varargin{3}),  unit      = varargin{3};                              end
if nargin > 3  && ~isempty(varargin{4}),  lim       = varargin{4}; min_D = lim(1); min_T = lim(2); min_V = lim(3); end
if nargin > 4  && ~isempty(varargin{5}),  filt      = varargin{5}; lp = filt(1); order = filt(2);  end
if nargin >= 6,                            outputVar = varargin{6};                              end
if nargin >= 7  && ~isempty(varargin{7}), plot_scaling_name = varargin{7};                      end
if nargin >= 8,                            t_input   = varargin{8};                             end
if nargin >= 9  && ~isempty(varargin{9}), trim_border = logical(varargin{9});                   end

if isequal(unit, 'mm'),      movementData = movementData / 1000;
elseif isequal(unit, 'cm'),  movementData = movementData / 100;  end

[b, a] = butter(order, (2 * lp) / FPS, 'low');
movementData = filtfilt(b, a, movementData);

borderEffect = round(2 * FPS / lp * order / 4);
if trim_border
    movementData = movementData(borderEffect + 1 : end - borderEffect, :);
end

v            = diff(movementData) * FPS;
movementData = movementData(1 : end - 1, :);

if isempty(t_input)
    t = (1 : size(v, 1))' / FPS;
else
    t = t_input;
end

timeSeries.r = movementData;
timeSeries.v = v;
timeSeries.t = t;

[~, nDim] = size(movementData);

if nDim == 1
    dimLabels = "all";
elseif nDim <= 3
    pool = ["x", "y", "z"];
    dimLabels = pool(1 : nDim);
else
    error('Dimensions greater than 3 are not supported.');
end

keepMask = false(1, nDim);

for i = 1 : nDim
    fieldName  = dimLabels(i);
    currentME  = segment_MED(timeSeries.t, timeSeries.r(:, i), timeSeries.v(:, i), min_D, min_T, min_V);
    ME.(fieldName) = currentME;
    if ~isempty(currentME)
        keepMask(i) = true;
    end
end

if ~any(keepMask)
    output = [];
    return;
end

timeSeries.r = timeSeries.r(:, keepMask);
timeSeries.v = timeSeries.v(:, keepMask);

fieldsToRemove = dimLabels(~keepMask);
if ~isempty(fieldsToRemove)
    ME = rmfield(ME, fieldsToRemove);
end

nDim      = sum(keepMask);
dimLabels = dimLabels(keepMask);

for i = 1 : nDim
    it = dimLabels(i);
    [N.(it), Nt.(it), D_all.(it), V_all.(it), T_all.(it), W_all.(it), R2_all.(it), P_all.(it)] = ...
        analyze_elements_MED(timeSeries.t, timeSeries.r(:, i), timeSeries.v(:, i), ME.(it));
end

D_all.all = []; V_all.all = []; T_all.all = [];
W_all.all = []; R2_all.all = []; P_all.all = [];
N.all = 0;

for i = 1 : nDim
    it = dimLabels(i);
    D_all.all   = [D_all.all;  D_all.(it)];
    V_all.all   = [V_all.all;  V_all.(it)];
    T_all.all   = [T_all.all;  T_all.(it)];
    W_all.all   = [W_all.all;  W_all.(it)];
    R2_all.all  = [R2_all.all; R2_all.(it)];
    P_all.all   = [P_all.all;  P_all.(it)];
    N.all       = N.all + N.(it);
end
Nt.all = N.all / (timeSeries.t(end) - timeSeries.t(1));

if ismember("scaling", outputVar)
    [scaling.alpha, scaling.K, scaling.R2_alpha] = scaling_MED(D_all, V_all, plot_scaling_name);
end

if sum(strcmp(dimLabels, 'all')) == 0
    dimLabels = [dimLabels, 'all'];
end

for it = dimLabels
    D.(it)  = mean(D_all.(it));
    V.(it)  = mean(V_all.(it));
    T.(it)  = mean(T_all.(it));
    W.(it)  = mean(W_all.(it));
    R2.(it) = mean(R2_all.(it));
    P.(it)  = mean(P_all.(it)); %#ok<*STRNU>
end

output = struct();
for i = 1 : length(outputVar)
    varName = char(outputVar(i));
    try
        output.(varName) = eval(varName);
    catch
    end
end

end % MED_pkg


function ME = segment_MED(t, r, v, min_D, min_T, min_V)

[~, pk_pos_index] = findpeaks(v);
[~, pk_neg_index] = findpeaks(-v);
pk_index = sort([pk_pos_index; pk_neg_index]);

pk_class = zeros(length(pk_index), 1);
pk_class(v(pk_index) >  min_V) =  1;
pk_class(v(pk_index) < -min_V) = -1;

if length(pk_class) < 3 || sum(abs(pk_class)) == 0
    ME = [];
    return;
end

buffer_index = zeros(1, length(pk_index) * 2);
buffer_class = zeros(1, length(pk_class) * 2);
j = 1;

if pk_class(1) ~= 0 && pk_index(1) > 1
    [min_val, loc] = min(abs(v(1 : pk_index(1) - 1)));
    if min_val <= min_V
        buffer_index(j) = loc;
        buffer_class(j) = 0;
        j = j + 1;
    end
end

for i = 1 : length(pk_class)
    buffer_index(j) = pk_index(i);
    buffer_class(j) = pk_class(i);
    j = j + 1;

    if i < length(pk_class)
        if abs(pk_class(i) - pk_class(i + 1)) == 2 && (pk_index(i + 1) - pk_index(i)) > 1
            range_idxs = pk_index(i) : pk_index(i + 1);
            [~, loc]   = min(abs(v(range_idxs)));
            buffer_index(j) = range_idxs(loc);
            buffer_class(j) = 0;
            j = j + 1;
        end
    end
end

if pk_class(end) ~= 0 && pk_index(end) < length(v)
    range_idxs = pk_index(end) + 1 : length(v);
    [min_val, loc] = min(abs(v(range_idxs)));
    if min_val <= min_V
        buffer_index(j) = range_idxs(loc);
        buffer_class(j) = 0;
        j = j + 1;
    end
end

pk_class = abs(buffer_class(1 : j - 1));
pk_index = buffer_index(1 : j - 1);

seg_class = diff(pk_class);
seg_i     = pk_index(seg_class ==  1)';
seg_f     = pk_index(find(seg_class == -1) + 1)';

if isempty(seg_i) || isempty(seg_f)
    ME = [];
    return;
end

if isscalar(seg_i) && isscalar(seg_f)
    if seg_i(1) >= seg_f(1)
        ME = [];
        return;
    end
end

if pk_class(end) == 1,  seg_i = seg_i(1 : end - 1);  end
if pk_class(1)   == 1,  seg_f = seg_f(2 : end);       end

if numel(seg_f) > numel(seg_i)
    seg_f = seg_f(1 : numel(seg_i));
elseif numel(seg_f) < numel(seg_i)
    seg_i = seg_i(1 : numel(seg_f));
end

exclude = seg_f == seg_i;
seg_i(exclude) = [];
seg_f(exclude) = [];

ME = [seg_i, seg_f];

for i = 1 : size(ME, 1)
    displacement = abs(r(ME(i, 2)) - r(ME(i, 1)));
    duration     = t(ME(i, 2)) - t(ME(i, 1));
    if displacement < min_D || duration < min_T
        ME(i, :) = nan(1, 2);
    end
end

ME(isnan(ME(:, 1)), :) = [];

if isempty(ME)
    ME = [];
end

end % segment_MED


function [N, Nt, D, V, T, W, R2, peak] = analyze_elements_MED(t, r, v, ME)

N  = size(ME, 1);
Nt = N / (t(end) - t(1));

zero = zeros(N, 1);
D = zero; V = zero; T = zero; W = zero; R2 = zero; peak = zero;

for i = 1 : N
    v_i = v(ME(i, 1) : ME(i, 2));
    t_i = t(ME(i, 1) : ME(i, 2));

    D(i) = abs(r(ME(i, 2)) - r(ME(i, 1)));
    T(i) = t_i(end) - t_i(1);
    V(i) = abs(mean(v_i));

    t_Hoff = linspace(0, 1, length(t_i));
    Hoff   = V(i) * 30 * ((t_Hoff.^4) - 2*(t_Hoff.^3) + (t_Hoff.^2));

    dvHoff = Hoff' - v_i;
    if V(i) ~= 0
        W(i) = std(dvHoff) / V(i);
    else
        W(i) = 0;
    end

    corr    = corrcoef(Hoff, v_i);
    R2(i)   = corr(1, 2).^2;

    [~, pk] = findpeaks(abs(v_i));
    peak(i) = length(pk);
end

end % analyze_elements_MED


function [alpha, K, R2] = scaling_MED(varargin)

D           = varargin{1};
V           = varargin{2};
flag_figure = ~isempty(varargin{3});

if flag_figure
    name = varargin{3};
    figure(1);
end

dim = fieldnames(D);

for i = 1 : length(dim)
    it   = dim{i};
    logD = log(D.(it));
    logV = log(V.(it));

    [p, S]     = polyfit(logD, logV, 1);
    alpha.(it) = p(1);
    K.(it)     = exp(p(2));
    R2.(it)    = S.rsquared;

    if flag_figure
        x_fit = linspace(min(logD), max(logD), 100);
        y_fit = polyval(p, x_fit);

        if isscalar(dim)
            loglog(D.(it), V.(it), 'o', 'MarkerFaceColor', "#0072BD");
            hold on;
            loglog(exp(x_fit), exp(y_fit), '-', 'LineWidth', 1.5);
            hold off;
            xlabel("Displacement (m)");
            ylabel("Mean Velocity (m/s)");

        elseif length(dim) == 3
            subplot(1, 3, i);
            loglog(D.(it), V.(it), 'o');
            hold on;
            loglog(exp(x_fit), exp(y_fit), '-', 'LineWidth', 1.5);
            hold off;
            switch i
                case 1; title_sub = "X"; xlabel("Displacement (m)"); ylabel("Mean Velocity (m/s)");
                case 2; title_sub = "Y"; xlabel("Displacement (m)");
                case 3; title_sub = "X and Y"; xlabel("Displacement (m)");
            end

        else
            subplot(2, 2, i);
            loglog(D.(it), V.(it), 'o');
            hold on;
            loglog(exp(x_fit), exp(y_fit), '-', 'LineWidth', 1.5);
            hold off;
            switch i
                case 1; title_sub = "X"; ylabel("Mean Velocity (m/s)");
                case 2; title_sub = "Y";
                case 3; title_sub = "Z"; xlabel("Displacement (m)"); ylabel("Mean Velocity (m/s)");
                case 4; title_sub = "X, Y and Z"; xlabel("Displacement (m)");
            end
        end
        title(title_sub);
    end
end

if flag_figure
    sgtitle('Scaling of V x D');
    saveas(gcf, name);
end

end % scaling_MED

