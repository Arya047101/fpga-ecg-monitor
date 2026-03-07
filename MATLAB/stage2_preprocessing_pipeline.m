%% ============================================================
%  Pan-Tompkins Pre-Processing: Step-by-Step on MIT-BIH ECG Data
%  MIT-BIH Arrhythmia Database (physionet.org/content/mitdb/1.0.0/)
%  Requires: WFDB Toolbox for MATLAB
%  Install:  run wfdbloadlib, or download from:
%            https://physionet.org/content/wfdb-matlab/
%  Record 100 used as example (normal sinus rhythm)
%% ============================================================

clear; clc; close all;

%% ---------------------------------------------------------------
%  STEP 0: Load ECG Signal from MIT-BIH Database
%  rdsamp() downloads and reads PhysioNet record.
%  Record '100' has two channels; we use channel 1 (MLII lead).
%  fs = 360 Hz, 30-min recording; we take first 10 seconds.
%% ---------------------------------------------------------------

record = '100';                          % Record name from MIT-BIH DB
Fs     = 360;                            % Sampling rate (Hz)
N_sec  = 10;                             % Seconds to analyse
N_samp = N_sec * Fs;                     % Number of samples = 3600

fprintf('Loading MIT-BIH record %s from PhysioNet...\n', record);

% rdsamp returns: signal matrix (samples x channels), fs, units
[sig, fs_read, tm] = rdsamp(record, [], N_samp);  
% sig(:,1) = MLII lead; sig(:,2) = V5 lead
ecg = sig(:, 1);                         % Use channel 1 (MLII)
t   = (0 : length(ecg)-1) / Fs;         % Time axis in seconds

fprintf('Loaded %d samples at %d Hz (%.1f seconds)\n', ...
        length(ecg), Fs, length(ecg)/Fs);

%% ---------------------------------------------------------------
%  STEP 1: BANDPASS FILTER  (5–15 Hz, QRS band)
%  Low-Pass:  H_LP(z) = (1-z^-6)^2 / (1-z^-1)^2
%  High-Pass: H_HP(z) = -1/32 + delta(n-16) - z^-1 + z^-32/32
%  Cascaded:  BPF = LP * HP
%  Purpose:   Remove baseline wander (<5 Hz) and HF noise (>15 Hz)
%% ---------------------------------------------------------------

b_lp = zeros(1,13); b_lp(1)=1; b_lp(7)=-2; b_lp(13)=1;
a_lp = [1, -2, 1];

b_hp = zeros(1,33);
b_hp(1)=-1/32; b_hp(17)=1; b_hp(18)=-1; b_hp(33)=1/32;
a_hp = [1, -1];

b_bp = conv(b_lp, b_hp);
a_bp = conv(a_lp, a_hp);

ecg_bp = filter(b_bp, a_bp, ecg);       % Apply BPF to raw ECG
fprintf('Stage 1 (BPF) complete. Max amplitude: %.4f\n', max(abs(ecg_bp)));

%% ---------------------------------------------------------------
%  STEP 2: DERIVATIVE FILTER
%  H_D(z) = (1/8Ts)[1 + 2z^-1 - 2z^-3 - z^-4]
%  Purpose: Emphasise steep QRS slopes; suppresses P/T waves.
%% ---------------------------------------------------------------

Ts = 1/Fs;
b_d = (1/(8*Ts)) * [1, 2, 0, -2, -1];  % 5-point derivative coefficients
ecg_d = filter(b_d, 1, ecg_bp);         % Apply derivative (FIR, a=1)
fprintf('Stage 2 (Deriv) complete. Max amplitude: %.4f\n', max(abs(ecg_d)));

%% ---------------------------------------------------------------
%  STEP 3: SQUARING
%  y[n] = x[n]^2
%  Purpose: Makes all values positive; amplifies large peaks
%           non-linearly (R-peaks >> noise).
%% ---------------------------------------------------------------

ecg_sq = ecg_d .^ 2;                    % Element-wise squaring
fprintf('Stage 3 (Squaring) complete. Max amplitude: %.4f\n', max(ecg_sq));

%% ---------------------------------------------------------------
%  STEP 4: MOVING WINDOW INTEGRATOR (MWI)
%  y[n] = (1/N) * sum_{k=0}^{N-1} x[n-k]
%  N = 30 samples @ 360 Hz = 83.3 ms window
%  Purpose: Produce smooth envelope; group QRS energy into a
%           single broad feature for threshold detection.
%% ---------------------------------------------------------------

N_mwi = 30;                             % Window = 30 samples ≈ 83 ms
b_mwi = ones(1, N_mwi) / N_mwi;        % Moving average filter
ecg_mwi = filter(b_mwi, 1, ecg_sq);    % Apply MWI
fprintf('Stage 4 (MWI) complete. Max amplitude: %.4f\n', max(ecg_mwi));

%% ---------------------------------------------------------------
%  STEP 5: LOW-PASS SMOOTHING (Butterworth 2nd order, fc=8 Hz)
%  Removes residual ripple in the integrated envelope.
%  Purpose: Cleaner envelope for thresholding; reduces false peaks.
%% ---------------------------------------------------------------

[b_lps, a_lps] = butter(2, 8/(Fs/2), 'low');   % 2nd-order LP at 8 Hz
ecg_lps = filter(b_lps, a_lps, ecg_mwi);        % Apply LP smoothing
fprintf('Stage 5 (LP Smooth) complete. Max amplitude: %.4f\n', max(ecg_lps));

%% ---------------------------------------------------------------
%  PLOTTING — show output of each stage
%  Normalise each stage for visual comparison on same y-scale.
%% ---------------------------------------------------------------

normalize = @(x) x / (max(abs(x)) + eps);  % Normalise helper (avoids /0)

figure('Name','ECG Preprocessing Pipeline Stages','NumberTitle','off', ...
       'Position',[100,50,1400,900]);

% --- Raw ECG ---
subplot(6,1,1);
plot(t, normalize(ecg), 'b');
title('Stage 0: Raw ECG (Record 100, MLII)');
ylabel('Norm. Amp'); xlabel('Time (s)'); grid on; xlim([0 N_sec]);

% --- After BPF ---
subplot(6,1,2);
plot(t, normalize(ecg_bp), 'k');
title('Stage 1: After Bandpass Filter (5–15 Hz)');
ylabel('Norm. Amp'); xlabel('Time (s)'); grid on; xlim([0 N_sec]);

% --- After Derivative ---
subplot(6,1,3);
plot(t, normalize(ecg_d), 'm');
title('Stage 2: After Derivative Filter');
ylabel('Norm. Amp'); xlabel('Time (s)'); grid on; xlim([0 N_sec]);

% --- After Squaring ---
subplot(6,1,4);
plot(t, normalize(ecg_sq), 'r');
title('Stage 3: After Squaring');
ylabel('Norm. Amp'); xlabel('Time (s)'); grid on; xlim([0 N_sec]);

% --- After MWI ---
subplot(6,1,5);
plot(t, normalize(ecg_mwi), [0.8 0.4 0]);   % Orange
title(sprintf('Stage 4: After MWI (N=%d, %.0f ms)', N_mwi, N_mwi*Ts*1000));
ylabel('Norm. Amp'); xlabel('Time (s)'); grid on; xlim([0 N_sec]);

% --- After LP Smoothing ---
subplot(6,1,6);
plot(t, normalize(ecg_lps), 'g');
title('Stage 5: After LP Smoothing (8 Hz Butterworth)');
ylabel('Norm. Amp'); xlabel('Time (s)'); grid on; xlim([0 N_sec]);

sgtitle(sprintf('Pan-Tompkins Preprocessing — MIT-BIH Record %s @ %d Hz', ...
                record, Fs));

%% ---------------------------------------------------------------
%  ZOOMED VIEW — 3 heartbeats for detailed inspection
%% ---------------------------------------------------------------

t_zoom = [1.5, 3.0];                    % 1.5 s window with ~3 beats
idx    = t >= t_zoom(1) & t <= t_zoom(2);

figure('Name','Zoomed Pipeline (3 Beats)','NumberTitle','off', ...
       'Position',[100,50,1400,900]);

stages = {normalize(ecg), normalize(ecg_bp), normalize(ecg_d), ...
          normalize(ecg_sq), normalize(ecg_mwi), normalize(ecg_lps)};
names  = {'Raw ECG','Post-BPF','Post-Deriv','Post-Sq','Post-MWI','Post-LPS'};
colors = {'b','k','m','r',[0.8 0.4 0],'g'};

for k = 1:6
    subplot(6,1,k);
    plot(t(idx), stages{k}(idx), 'Color', colors{k});
    title(names{k}); ylabel('Norm.'); xlabel('Time (s)');
    grid on;
end
sgtitle('Zoomed View (1.5 – 3.0 s)');

%% ---------------------------------------------------------------
%  SAVE PROCESSED SIGNALS to .mat for further use
%% ---------------------------------------------------------------

save('ecg_preprocessed.mat', 'ecg', 'ecg_bp', 'ecg_d', 'ecg_sq', ...
     'ecg_mwi', 'ecg_lps', 'Fs', 'record');
fprintf('\nSaved preprocessed signals to ecg_preprocessed.mat\n');
fprintf('Done! Review the two figure windows.\n');
