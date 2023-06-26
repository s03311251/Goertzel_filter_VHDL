% Source: https://www.mathworks.com/help/signal/ref/goertzel.html

% 1. Define constants
Fs = 1e6; % sampling frequency
Fk = 50e3; % frequency to detect
N = 100; % number of samples
INPUT_BIT_LEN = 14; % number of input bit length
INPUT_SWING = 14; % swing of input signal
INT_BIT_LEN = 18; % number of internal bit length

% VHDL impelmentation related
% bit width of COEFF due to internal data bit width limitation
% 18 - 2 = 16 bits for fractional part
COEFF_BW = INT_BIT_LEN - 2;
LSB_TRUNC = 5; % internal data's LSB truncated, as implemented in VHDL
MAG_TRUNC = 11; % truncate final result (magnitude^2)

% 2. Generate the waveforms
t = (0:N-1) / Fs;
phase_angles = [0, 30, 45, 90, 120];
% phase_angles = [0];

% Sine Waves
frequencies_sine = [50e3, 49e3, 51e3, 5e3, 200e3];
% frequencies_sine = [50e3];
sine_waves = zeros(length(frequencies_sine), length(phase_angles), N, "int32");
sine_waves_combined_single = zeros(length(phase_angles), N, "single");
sine_waves_combined = zeros(length(phase_angles), N, "int32");

for i = 1:length(frequencies_sine)
    for j = 1:length(phase_angles)
        frequency = frequencies_sine(i);
        phase = phase_angles(j);
        sine_wave = sin(2*pi*frequency*t + deg2rad(phase));
        sine_waves(i, j, :) = scaleToInt(sine_wave, INPUT_BIT_LEN, INPUT_SWING);
        sine_waves_combined_single(j, :) = sine_waves_combined_single(j, :) + sine_wave / length(frequencies_sine);

        % % Sanity Check for scaleToInt()
        % disp(['Frequency: ', num2str(frequency), ', phase: ', num2str(phase)]);
        % min_value = min(sine_wave);
        % index = find(sine_wave == min_value);
        % disp(['Min: ', num2str(min_value), ', scaled: ', num2str(sine_waves(i, j, index)), ', index: ', num2str(index)]);
        % max_value = max(sine_wave);
        % index = find(sine_wave == max_value);
        % disp(['Max: ', num2str(max_value), ', scaled: ', num2str(sine_waves(i, j, index)), ', index: ', num2str(index)]);
        % index = find(sine_wave == 0.0);
        % disp(['Zero: ', num2str(0.0), ', scaled: ', num2str(sine_waves(i, j, index)), ', index: ', num2str(index)]);
    end
end

for j = 1:length(phase_angles)
    phase = phase_angles(j);
    sine_waves_combined(j, :) = scaleToInt(sine_waves_combined_single(j, :), INPUT_BIT_LEN, INPUT_SWING);

    % % Sanity Check for sine_waves_combined
    % disp(['Phase: ', num2str(phase)]);
    % min_value = min(sine_waves_combined(j, :));
    % index = find(sine_waves_combined(j, :) == min_value);
    % disp(['Min: ', num2str(min_value), ', scaled: ', num2str(sine_waves_combined(j, index)), ', index: ', num2str(index)]);
    % max_value = max(sine_waves_combined(j, :));
    % index = find(sine_waves_combined(j, :) == max_value);
    % disp(['Max: ', num2str(max_value), ', scaled: ', num2str(sine_waves_combined(j, index)), ', index: ', num2str(index)]);
    % index = find(sine_waves_combined(j, :) == 0.0);
    % disp(['Zero: ', num2str(0.0), ', scaled: ', num2str(sine_waves_combined(j, index)), ', index: ', num2str(index)]);
end

% Rectangular Waves
frequencies_rectangular = [50e3, 16e3, 10e3, 200e3];
rectangular_waves = zeros(length(frequencies_rectangular), length(phase_angles), N);

for i = 1:length(frequencies_rectangular)
    for j = 1:length(phase_angles)
        frequency = frequencies_rectangular(i);
        phase = phase_angles(j);
        rectangular_wave = square(2*pi*frequency*t + deg2rad(phase));
        rectangular_waves(i, j, :) = scaleToInt(rectangular_wave, INPUT_BIT_LEN, INPUT_SWING);
    end
end

% Triangle Waves
phase_angles_triangle = [0, 90];
triangle_waves = zeros(length(phase_angles_triangle), N);

for i = 1:length(phase_angles_triangle)
    phase = phase_angles_triangle(i);
    triangle_wave = sawtooth(2*pi*50e3*t + deg2rad(phase), 0.5);
    triangle_waves(i, :) = scaleToInt(triangle_wave, INPUT_BIT_LEN, INPUT_SWING);
end

% % 3. Sanity Check: plot the waveforms
% % Plotting sine_waves
% figure;
% t = (0:N-1) / Fs;
% for i = 1:size(sine_waves, 1)
%     subplot(size(sine_waves, 1), 1, i);
%     % Extract a row from the 3D array as a 1D array
%     wave = reshape(sine_waves(i, 1, :), 1, []);
%     plot(t, wave);
%     title(['Sine Wave ', num2str(i)]);
%     xlabel('Time (s)');
%     ylabel('Amplitude');
% end

% % Plotting sine_waves_combined
% figure;
% t = (0:N-1) / Fs;
% for i = 1:size(sine_waves_combined, 1)
%     figure;
%     % subplot(size(sine_waves_combined, 1), 1, i);
%     % Extract a row from the 3D array as a 1D array
%     wave = reshape(sine_waves_combined(i, :), 1, []);
%     plot(t, wave);
%     title(['Sine Wave (Combined) ', num2str(i)]);
%     xlabel('Time (s)');
%     ylabel('Amplitude');
% end

% % Plotting rectangular_waves
% figure;
% for i = 1:size(rectangular_waves, 1)
%     subplot(size(rectangular_waves, 1), 1, i);
%     % Extract a row from the 3D array as a 1D array
%     wave = reshape(rectangular_waves(i, 1, :), 1, []);
%     plot(t, wave);
%     title(['Rectangular Wave ', num2str(i)]);
%     xlabel('Time (s)');
%     ylabel('Amplitude');
% end

% % Plotting triangle_wave
% figure;
% for i = 1:size(triangle_waves, 1)
%     subplot(size(triangle_waves, 1), 1, i);
%     plot(t, triangle_waves(i, :));
%     title(['Triangle Wave ', num2str(i)]);
%     xlabel('Time (s)');
%     ylabel('Amplitude');
% end

% 4. Goertzel Filter

sine_waves_dft = zeros(length(frequencies_sine), length(phase_angles), "int32");
for i = 1:length(frequencies_sine)
    for j = 1:length(phase_angles)
        % freq_indices = round(Fk/Fs*N) + 1;
        % % transform to single precision because goertzel only accepts single
        % dft_data = goertzel(single(sine_waves(i, j, :)),freq_indices);
        dft_input = reshape(sine_waves(i, j, :), 1, []);
        magnitude_sq = goertzel_filter(dft_input, Fk, Fs, COEFF_BW, LSB_TRUNC, MAG_TRUNC);
        sine_waves_dft(i, j) = magnitude_sq;
        % fprintf("freq: %d phase: %d magnitude: %d\n", i, j, abs(dft_data));
        fprintf("SIN freq: %d phase: %d s: %d %d\n", frequencies_sine(i), phase_angles(j), s, s_prev);
    end
end

% figure; % open a new figure window
% stem(Fk,abs(dft_data))

% % Adjusting subplot spacing
% sgtitle('Waveform Plots');

% ax = gca;
% ax.XTick = Fk;
% xlabel('Frequency (Hz)')
% ylabel('DFT Magnitude')

sine_waves_combined_dft = zeros(length(phase_angles), 1, "int32");
for i = 1:length(phase_angles)
    dft_input = reshape(sine_waves_combined(i, :), 1, []);
    magnitude_sq = goertzel_filter(dft_input, Fk, Fs, COEFF_BW, LSB_TRUNC, MAG_TRUNC);
    sine_waves_combined_dft(i) = magnitude_sq;
    fprintf("SIN_COMB phase: %d s: %d %d\n", phase_angles(i), s, s_prev);
end

rectangular_waves_dft = zeros(length(frequencies_rectangular), length(phase_angles), "int32");
for i = 1:length(frequencies_rectangular)
    for j = 1:length(phase_angles)
        dft_input = reshape(rectangular_waves(i, j, :), 1, []);
        magnitude_sq = goertzel_filter(dft_input, Fk, Fs, COEFF_BW, LSB_TRUNC, MAG_TRUNC);
        rectangular_waves_dft(i, j) = magnitude_sq;
        fprintf("RECT freq: %d phase: %d s: %d %d\n", frequencies_rectangular(i), phase_angles(j), s, s_prev);
    end
end

triangle_waves_dft = zeros(length(phase_angles_triangle), 1, "int32");
for i = 1:length(phase_angles_triangle)
    dft_input = reshape(triangle_waves(i, :), 1, []);
    magnitude_sq = goertzel_filter(dft_input, Fk, Fs, COEFF_BW, LSB_TRUNC, MAG_TRUNC);
    triangle_waves_dft(i) = magnitude_sq;
    fprintf("TRI phase: %d s: %d %d\n", phase_angles_triangle(i), s, s_prev);
end

% 5. Output the waveforms to a file
% each entity occupies a row in the file

% Create folders
mkdir test_cases/input
mkdir test_cases/expected

% Fixed width and padding with zeros
% in hex format, hence /4
sigLineWidth = ceil(INPUT_BIT_LEN / 4);
targetLineWidth = 5;

% Loop through input signals & DFT results, and write each waveform to a separate file
filePrefix = 'sine_wave';
for i = 1:length(frequencies_sine)
    for j = 1:length(phase_angles)
        nameFreq = sprintf('%.0f%sHz', frequencies_sine(i) / 10^(3 * floor(log10(abs(frequencies_sine(i)))/3)), suffix(frequencies_sine(i)));

        fileName = sprintf('test_cases/input/%s_%s_%ddeg.txt', filePrefix, nameFreq, phase_angles(j));
        write_to_file(reshape(sine_waves(i, j, :), 1, []), fileName, sigLineWidth);

        fileName = sprintf('test_cases/expected/%s_%s_%ddeg.txt', filePrefix, nameFreq, phase_angles(j));
        write_to_file(reshape(sine_waves_dft(i, j, :), 1, []), fileName, targetLineWidth);
    end
end

filePrefix = 'sine_wave_combined';
for i = 1:length(phase_angles)
    fileName = sprintf('test_cases/input/%s_%ddeg.txt', filePrefix, phase_angles(i));
    write_to_file(sine_waves_combined(i, :), fileName, sigLineWidth);

    fileName = sprintf('test_cases/expected/%s_%ddeg.txt', filePrefix, phase_angles(i));
    write_to_file(sine_waves_combined_dft(i, :), fileName, targetLineWidth);
end

filePrefix = 'rectangular_wave';
for i = 1:length(frequencies_rectangular)
    for j = 1:length(phase_angles)
        nameFreq = sprintf('%.0f%sHz', frequencies_rectangular(i) / 10^(3 * floor(log10(abs(frequencies_rectangular(i)))/3)), suffix(frequencies_rectangular(i)));

        fileName = sprintf('test_cases/input/%s_%s_%ddeg.txt', filePrefix, nameFreq, phase_angles(j));
        write_to_file(reshape(rectangular_waves(i, j, :), 1, []), fileName, sigLineWidth);

        fileName = sprintf('test_cases/expected/%s_%s_%ddeg.txt', filePrefix, nameFreq, phase_angles(j));
        write_to_file(reshape(rectangular_waves_dft(i, j, :), 1, []), fileName, targetLineWidth);
    end
end

filePrefix = 'triangle_wave';
for i = 1:length(phase_angles_triangle)
    fileName = sprintf('test_cases/input/%s_50kHz_%ddeg.txt', filePrefix, phase_angles_triangle(i));
    write_to_file(triangle_waves(i, :), fileName, sigLineWidth);

    fileName = sprintf('test_cases/expected/%s_50kHz_%ddeg.txt', filePrefix, phase_angles_triangle(i));
    write_to_file(triangle_waves_dft(i, :), fileName, targetLineWidth);
end

% 99. Function definitions in a script must appear at the end of the file

function output = scaleToInt(input, bit_len, input_swing)
    % Scale the waveforms to the range of 2^(bit_len - 1) +/- 2^input_swing
    scaled = (2 ^ bit_len - 1) / 2 + input * (2 ^ input_swing - 1) / 2;
    % Convert the scaled waveforms to (bit_len)-bit unsigned integers
    output = int32(round(scaled));
end

% Function to generate SI unit suffix
function s = suffix(num)
    units = {'', 'k', 'M', 'G', 'T', 'P', 'E'};
    exponent = log10(abs(num));
    exponent = floor(exponent / 3);
    exponent = max(min(exponent, numel(units)-1), 0);
    s = units{exponent+1};
end

% Luca's Filter
% function magnitude = goertzel_filter(signal, targetFrequency, samplingRate)
function magnitude_sq_trunc = goertzel_filter(signal, targetFrequency, samplingRate, coeffBw, lsbTrunc, magTrunc)
    N = length(signal); % Length of the signal
    k = round(N * targetFrequency / samplingRate); % Bin frequency
    w = 2 * pi * k / N; % Angular frequency
    cosine = cos(w);
    coefficient = 2 * cosine;
    % round acconding to coeffBw
    coefficient = convergent(coefficient * 2 ^ coeffBw) / (2 ^ coeffBw);
    % fprintf("COEFF %.20f\n", coefficient); % 1.9021148681640625

    s = zeros(N, 1); % First intermediate variable
    sprev = 0; % Previous s[n-1]
    sprev2 = 0; % Previous s[n-2]

    % Iterate through the signal
    % min = 0.0;
    % max = 0.0;
    for n = 1:N
        % s(n) = signal(n) + coefficient * sprev - sprev2;

        % truncate according to lsbTrunc
        % multi_prod_trunc = round(coefficient * sprev / 2 ^ lsbTrunc) * (2 ^ lsbTrunc);
        multi_prod = floor(coefficient * sprev);
        % s_tmp = signal(n) + multi_prod - sprev2;
        % remove LSB instead of rounding, hence floor() instead of convergent()
        s(n) = floor(double(signal(n) + multi_prod - sprev2) / 2 ^ lsbTrunc) * (2 ^ lsbTrunc);

        % debug
        % fprintf("Prod_SO %d Sample_SI %d COEFF*Prod_q_D %d Prod_qq_D %d\n", s(n), signal(n), multi_prod, sprev2);
        % fprintf("Prod_SO %d Sample_SI %d COEFF*Prod_q_D %d Prod_qq_D %d s_tmp %f\n", s(n), signal(n), multi_prod, sprev2, s_tmp);
        % fprintf("n: %d Prod_SO %f Sample_SI %f COEFF*Prod_q_D %f %.20f %f Prod_qq_D %f\n", n, s(n), signal(n), multi_prod, coefficient, sprev, sprev2);        

        sprev2 = sprev;
        sprev = s(n);

        % % debug
        % fprintf("n: %d s(n): %f\n", n, s(n));
        % if s(n) < min
        %     min = s(n);
        % elseif s(n) > max
        %     max = s(n);
        % end
    end
    % % debug
    % fprintf("min: %f max: %f\n", min, max);

    % Compute the magnitude
    sN = s(N);
    sNprev = s(N-1);
    magnitude_sq = double(sN^2 + sNprev^2 - sN * sNprev * coefficient);
    % take the integer part of (sN * sNprev * coefficient) only
    bit_shift = lsbTrunc * 2 + magTrunc;
    magnitude_sq_trunc = floor(magnitude_sq / 2 ^ bit_shift);
end

function write_to_file(signal, fileName, lineWidth)
    % Open the file for writing
    fileID = fopen(fileName, 'w');

    % Write each entity of the sine_wave to a line in the file
    for k = 1:length(signal)
        % fprintf(fileID, '%0*X\n', lineWidth, signal(k));
        % dec2hex() can handle negative numbers
        fprintf(fileID, '%s\n', dec2hex(signal(k), lineWidth));
    end

    % Close the file
    fclose(fileID);
end
