%% ============================================================
%  Pan-Tompkins Pre-Processing Stage: Transfer Function Analysis
%  Generates frequency response and time response for each filter.
%  Sampling Frequency: 360 Hz (MIT-BIH standard, no downsampling)
%% ============================================================

clear; clc; close all;

fs = 360;          % Sampling frequency in Hz (MIT-BIH database standard)
Ts = 1/fs;         % Sampling period in seconds
N  = 4096;         % FFT length for frequency resolution

%% ---------------------------------------------------------------
%  1. BANDPASS FILTER
%  Pan-Tompkins uses a cascade of:
%    Low-Pass  H_LP(z) = (1 - z^-6)^2 / (1 - z^-1)^2  [cutoff ~12 Hz]
%    High-Pass H_HP(z) = (-1/32 + delta(n-16) - z^-1 + (1/32)z^-32)
%  Combined BPF passes QRS energy band (~5–15 Hz).
%  Reference: Pan & Tompkins, IEEE TBME 1985.
%% ---------------------------------------------------------------

% --- Low-Pass Filter coefficients (difference equation form) ---
% H_LP: y[n] = 2y[n-1] - y[n-2] + x[n] - 2x[n-6] + x[n-12]
% Numerator: 1 - 2z^-6 + z^-12  => b_lp
% Denominator: 1 - 2z^-1 + z^-2  => a_lp
b_lp = zeros(1, 13);   % 13 taps (delays 0..12)
b_lp(1)  =  1;         % x[n]
b_lp(7)  = -2;         % -2x[n-6]
b_lp(13) =  1;         % x[n-12]

a_lp = [1, -2, 1];     % 1 - 2z^-1 + z^-2  (recursive part)

% --- High-Pass Filter coefficients ---
% H_HP: y[n] = y[n-1] - x[n]/32 + x[n-16] - x[n-17] + x[n-32]/32
% Numerator taps (length 33)
b_hp = zeros(1, 33);
b_hp(1)  = -1/32;      % -x[n]/32
b_hp(17) =  1;         % +x[n-16] (delay 16 => index 17)
b_hp(18) = -1;         % -x[n-17]
b_hp(33) =  1/32;      % +x[n-32]/32
a_hp = [1, -1];        % 1 - z^-1  (recursive part)

% --- Cascade to get BPF ---
b_bp = conv(b_lp, b_hp);   % Convolve numerators
a_bp = conv(a_lp, a_hp);   % Convolve denominators

% --- Frequency Response ---
[H_lp, f] = freqz(b_lp, a_lp, N, fs);   % LP frequency response
[H_hp, ~] = freqz(b_hp, a_hp, N, fs);   % HP frequency response
[H_bp, ~] = freqz(b_bp, a_bp, N, fs);   % BPF = LP * HP

% --- Impulse Response (time domain) ---
imp = [1, zeros(1, 511)];               % Unit impulse, 512 samples
h_lp = filter(b_lp, a_lp, imp);        % LP impulse response
h_hp = filter(b_hp, a_hp, imp);        % HP impulse response
h_bp = filter(b_bp, a_bp, imp);        % BPF impulse response
t    = (0:511) * Ts * 1000;            % Time axis in ms

figure('Name','Bandpass Filter Analysis','NumberTitle','off');

subplot(3,2,1);
plot(f, 20*log10(abs(H_lp)+eps));      % Magnitude in dB vs Hz
title('Low-Pass Filter |H(f)|'); xlabel('Freq (Hz)'); ylabel('dB');
grid on; xlim([0 fs/2]);

subplot(3,2,2);
plot(t(1:100), h_lp(1:100));           % First 100 samples of impulse resp
title('Low-Pass Impulse Response'); xlabel('ms'); ylabel('Amplitude');
grid on;

subplot(3,2,3);
plot(f, 20*log10(abs(H_hp)+eps));
title('High-Pass Filter |H(f)|'); xlabel('Freq (Hz)'); ylabel('dB');
grid on; xlim([0 fs/2]);

subplot(3,2,4);
plot(t(1:100), h_hp(1:100));
title('High-Pass Impulse Response'); xlabel('ms'); ylabel('Amplitude');
grid on;

subplot(3,2,5);
plot(f, 20*log10(abs(H_bp)+eps));
title('Bandpass Filter |H(f)|'); xlabel('Freq (Hz)'); ylabel('dB');
xline(5,'r--','5 Hz'); xline(15,'r--','15 Hz');  % QRS band markers
grid on; xlim([0 fs/2]);

subplot(3,2,6);
plot(t(1:100), h_bp(1:100));
title('Bandpass Impulse Response'); xlabel('ms'); ylabel('Amplitude');
grid on;

sgtitle('BPF Analysis (LP + HP Cascade) @ 360 Hz');

%% ---------------------------------------------------------------
%  2. DERIVATIVE FILTER
%  H_D(z) = (1/8Ts)[-z^-2 - 2z^-1 + 2z + z^2]  [Pan-Tompkins 1985]
%  In causal (delay-shifted) form (multiply by z^-2):
%  H_D(z) = (1/8Ts)[1 + 2z^-1 - 2z^-3 - z^-4]
%  This is a 5-point central difference approximator of the derivative.
%  Emphasises QRS slope (~10–25 Hz band).
%% ---------------------------------------------------------------

b_deriv = (1/(8*Ts)) * [1, 2, 0, -2, -1];  % Coefficients c0..c4
a_deriv = 1;                                 % FIR — no recursive part

[H_deriv, ~] = freqz(b_deriv, a_deriv, N, fs);   % Frequency response
h_deriv = filter(b_deriv, a_deriv, imp);           % Impulse response

% Ideal derivative for comparison: H_ideal = j*2*pi*f
H_ideal = 1j * 2 * pi * f;

figure('Name','Derivative Filter Analysis','NumberTitle','off');

subplot(2,2,1);
plot(f, abs(H_deriv));                          % Magnitude
hold on;
plot(f, abs(H_ideal),'r--');                    % Ideal magnitude
title('Derivative Filter Magnitude'); xlabel('Hz'); ylabel('|H|');
legend('Approx','Ideal'); grid on; xlim([0 fs/2]);

subplot(2,2,2);
plot(f, angle(H_deriv)*180/pi);                 % Phase in degrees
title('Phase Response'); xlabel('Hz'); ylabel('Degrees');
grid on; xlim([0 fs/2]);

subplot(2,2,3);
plot(t(1:20), h_deriv(1:20));                   % Short impulse response
title('Impulse Response'); xlabel('ms'); ylabel('Amplitude');
grid on;

subplot(2,2,4);
% Group delay to check linearity
[gd, f_gd] = grpdelay(b_deriv, a_deriv, N, fs);
plot(f_gd, gd);
title('Group Delay (samples)'); xlabel('Hz'); ylabel('Samples');
grid on; xlim([0 fs/2]);

sgtitle('Derivative Filter H_D(z) @ 360 Hz');

%% ---------------------------------------------------------------
%  3. MOVING WINDOW INTEGRATOR (MWI)
%  H_MWI(z) = (1/N) * sum_{k=0}^{N-1} z^-k  (rectangular window)
%  Window length N = 30 samples @ 360 Hz ≈ 83 ms
%  (Pan-Tompkins recommends ~150 ms for 200 Hz, scaled to 360 Hz)
%  Equivalent to: y[n] = (1/N)*[x[n] + x[n-1] + ... + x[n-N+1]]
%% ---------------------------------------------------------------

N_mwi = 30;                          % 30 samples ≈ 83 ms window @ 360 Hz
b_mwi = ones(1, N_mwi) / N_mwi;     % All-ones FIR, normalized by N
a_mwi = 1;                           % FIR — no feedback

[H_mwi, ~] = freqz(b_mwi, a_mwi, N, fs);   % Frequency response
h_mwi = filter(b_mwi, a_mwi, imp);           % Impulse response

figure('Name','Moving Window Integrator Analysis','NumberTitle','off');

subplot(2,2,1);
plot(f, 20*log10(abs(H_mwi)+eps));
title('MWI Magnitude (dB)'); xlabel('Hz'); ylabel('dB');
grid on; xlim([0 fs/2]);
% First null of MWI at fs/N_mwi
xline(fs/N_mwi,'r--',sprintf('Null @ %.1f Hz', fs/N_mwi));

subplot(2,2,2);
plot(f, angle(H_mwi)*180/pi);
title('MWI Phase Response'); xlabel('Hz'); ylabel('Degrees');
grid on; xlim([0 fs/2]);

subplot(2,2,3);
stem(0:N_mwi-1, h_mwi(1:N_mwi));
title(sprintf('Impulse Response (N=%d samples)', N_mwi));
xlabel('Sample'); ylabel('Amplitude'); grid on;

subplot(2,2,4);
[gd_mwi, f_gd] = grpdelay(b_mwi, a_mwi, N, fs);
plot(f_gd, gd_mwi);
title('Group Delay (samples)'); xlabel('Hz'); ylabel('Samples');
grid on; xlim([0 fs/2]);

sgtitle(sprintf('Moving Window Integrator (N=%d, ≈%.0f ms) @ 360 Hz', N_mwi, N_mwi*Ts*1000));

%% ---------------------------------------------------------------
%  4. LOW-PASS SMOOTHING FILTER (post-MWI)
%  Simple 2nd-order LP Butterworth to further smooth the envelope.
%  Cutoff at 8 Hz — removes residual high-freq noise post-integration.
%  H(z) obtained via bilinear transform of analog prototype.
%% ---------------------------------------------------------------

fc_lps = 8;                                           % Cutoff frequency (Hz)
[b_lps, a_lps] = butter(2, fc_lps/(fs/2), 'low');    % 2nd-order Butterworth LP

[H_lps, ~] = freqz(b_lps, a_lps, N, fs);
h_lps       = filter(b_lps, a_lps, imp);

% Print the transfer function coefficients for reference
fprintf('\n=== Low-Pass Smoothing Filter (Butterworth, fc=8 Hz) ===\n');
fprintf('b = ['); fprintf('%.6f ', b_lps); fprintf(']\n');
fprintf('a = ['); fprintf('%.6f ', a_lps); fprintf(']\n');

figure('Name','Low-Pass Smoothing Filter Analysis','NumberTitle','off');

subplot(2,2,1);
plot(f, 20*log10(abs(H_lps)+eps));
title('LP Smoothing Magnitude (dB)'); xlabel('Hz'); ylabel('dB');
xline(fc_lps,'r--','8 Hz cutoff'); grid on; xlim([0 fs/2]);

subplot(2,2,2);
plot(f, angle(H_lps)*180/pi);
title('Phase Response'); xlabel('Hz'); ylabel('Degrees');
grid on; xlim([0 fs/2]);

subplot(2,2,3);
plot(t(1:150), h_lps(1:150));
title('Impulse Response'); xlabel('ms'); ylabel('Amplitude');
grid on;

subplot(2,2,4);
zplane(b_lps, a_lps);
title('Pole-Zero Plot');

sgtitle('Low-Pass Smoothing Filter (Butterworth 8 Hz) @ 360 Hz');

%% ---------------------------------------------------------------
%  5. COMBINED PIPELINE OVERVIEW — all stages cascaded
%  Shows how ECG energy is shaped through the full preprocessing chain.
%% ---------------------------------------------------------------

% Cascade all stages (BPF -> Deriv -> MWI -> LPS)
% Note: squaring is nonlinear so it is excluded from linear cascade.
b_all = conv(conv(b_bp, b_deriv), conv(b_mwi, b_lps));
a_all = conv(conv(a_bp, a_deriv), conv(a_mwi, a_lps));

[H_all, ~] = freqz(b_all, a_all, N, fs);

figure('Name','Full Pipeline Frequency Response','NumberTitle','off');
plot(f, 20*log10(abs(H_all)+eps));
title('Cascaded Preprocessing Pipeline Frequency Response');
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
xline(5,'g--','5 Hz'); xline(15,'g--','15 Hz');
xline(fs/N_mwi,'r--',sprintf('MWI null %.1f Hz', fs/N_mwi));
grid on; xlim([0 fs/2]);
sgtitle('Full Pre-Processing Cascade @ 360 Hz');

fprintf('\nAll filter plots generated. Review each figure window.\n');
