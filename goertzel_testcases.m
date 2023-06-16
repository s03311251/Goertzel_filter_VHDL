% Source: https://www.mathworks.com/help/signal/ref/goertzel.html

% 1. Define constants
Fs = 1e6; % sampling frequency
F_detect = 50e3; % frequency to detect
N = 100; % number of samples
INPUT_BIT_LEN = 14; % number of input bit length
INPUT_SWING = 14; % swing of input signal
OUTPUT_BIT_LEN = 18; % number of output bit length

% VHDL impelmentation related
% bit width of COEFF due to internal data bit width limitation
% 18 - 3 because there're 2 bits before decimal point, 15 after, 1 sign bit
COEFF_BW = OUTPUT_BIT_LEN - 3;
LSB_TRUNCATE = 5; % internal data's LSB truncated, as implemented in VHDL

% 2. Generate the waveforms
t = (0:N-1) / Fs;
phase_angles = [0, 30, 45, 90, 120];
% phase_angles = [0];

% Sine Waves
frequencies_sine = [50e3, 49e3, 51e3, 5e3, 200e3];
% frequencies_sine = [50e3];
sine_waves = zeros(length(frequencies_sine), length(phase_angles), N, "int32");

for i = 1:length(frequencies_sine)
    for j = 1:length(phase_angles)
        frequency = frequencies_sine(i);
        phase = phase_angles(j);
        sine_wave = sin(2*pi*frequency*t + deg2rad(phase));
        sine_waves(i, j, :) = scaleToInt(sine_wave, INPUT_BIT_LEN, INPUT_SWING);

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

sine_waves_dft = zeros(length(frequencies_sine), length(phase_angles), 2, "int32");
for i = 1:length(frequencies_sine)
    for j = 1:length(phase_angles)
        % freq_indices = round(F_detect/Fs*N) + 1;
        % % transform to single precision because goertzel only accepts single
        % dft_data = goertzel(single(sine_waves(i, j, :)),freq_indices);
        dft_input = reshape(sine_waves(i, j, :), 1, []);
        [s, s_prev] = goertzel_filter(dft_input, F_detect, Fs, COEFF_BW, LSB_TRUNCATE);
        sine_waves_dft(i, j, :) = [s, s_prev];
        % fprintf("freq: %d phase: %d magnitude: %d\n", i, j, abs(dft_data));
        fprintf("SIN freq: %d phase: %d s: %d %d\n", frequencies_sine(i), phase_angles(j), s, s_prev);
    end
end

% figure; % open a new figure window
% stem(F_detect,abs(dft_data))

% % Adjusting subplot spacing
% sgtitle('Waveform Plots');

% ax = gca;
% ax.XTick = F_detect;
% xlabel('Frequency (Hz)')
% ylabel('DFT Magnitude')

rectangular_waves_dft = zeros(length(frequencies_rectangular), length(phase_angles), 2, "int32");
for i = 1:length(frequencies_rectangular)
    for j = 1:length(phase_angles)
        dft_input = reshape(rectangular_waves(i, j, :), 1, []);
        [s, s_prev] = goertzel_filter(dft_input, F_detect, Fs, COEFF_BW, LSB_TRUNCATE);
        rectangular_waves_dft(i, j, :) = [s, s_prev];
        fprintf("RECT freq: %d phase: %d s: %d %d\n", frequencies_rectangular(i), phase_angles(j), s, s_prev);
    end
end

triangle_waves_dft = zeros(length(phase_angles_triangle), 2, "int32");
for i = 1:length(phase_angles_triangle)
    dft_input = reshape(triangle_waves(i, :), 1, []);
    [s, s_prev] = goertzel_filter(dft_input, F_detect, Fs, COEFF_BW, LSB_TRUNCATE);
    triangle_waves_dft(i, :) = [s, s_prev];
    fprintf("TRI phase: %d s: %d %d\n", phase_angles_triangle(i), s, s_prev);
end

% 5. Sanity Check: plot the result of Goertzel Filter
% TODO

% 6. Output the waveforms to a file
% each entity occupies a row in the file

% Create folders
mkdir test_cases/input
mkdir test_cases/expected

% Fixed width and padding with zeros
% in hex format, hence /4
sigLineWidth = ceil(INPUT_BIT_LEN / 4);
targetLineWidth = ceil(OUTPUT_BIT_LEN / 4);

% Loop through input signals & DFT results, and write each waveform to a separate file
filePrefix = 'sine_wave';
for i = 1:length(frequencies_sine)
    for j = 1:length(phase_angles)
        % Generate the file name
        nameFreq = sprintf('%.0f%sHz', frequencies_sine(i) / 10^(3 * floor(log10(abs(frequencies_sine(i)))/3)), suffix(frequencies_sine(i)));

        fileName = sprintf('test_cases/input/%s_%s_%ddeg.txt', filePrefix, nameFreq, phase_angles(j));
        write_to_file(reshape(sine_waves(i, j, :), 1, []), fileName, sigLineWidth);

        fileName = sprintf('test_cases/expected/%s_%s_%ddeg.txt', filePrefix, nameFreq, phase_angles(j));
        write_to_file(reshape(sine_waves_dft(i, j, :), 1, []), fileName, targetLineWidth);
    end
end

filePrefix = 'rectangular_wave';
for i = 1:length(frequencies_rectangular)
    for j = 1:length(phase_angles)
        % Generate the file name
        nameFreq = sprintf('%.0f%sHz', frequencies_rectangular(i) / 10^(3 * floor(log10(abs(frequencies_rectangular(i)))/3)), suffix(frequencies_rectangular(i)));

        fileName = sprintf('test_cases/input/%s_%s_%ddeg.txt', filePrefix, nameFreq, phase_angles(j));
        write_to_file(reshape(rectangular_waves(i, j, :), 1, []), fileName, sigLineWidth);

        fileName = sprintf('test_cases/expected/%s_%s_%ddeg.txt', filePrefix, nameFreq, phase_angles(j));
        write_to_file(reshape(rectangular_waves_dft(i, j, :), 1, []), fileName, targetLineWidth);
    end
end

filePrefix = 'triangle_wave';
for i = 1:length(phase_angles)
    % Generate the file name
    nameFreq = sprintf('%.0f%sHz', frequencies_triangle(i) / 10^(3 * floor(log10(abs(frequencies_triangle(i)))/3)), suffix(frequencies_triangle(i)));

    fileName = sprintf('test_cases/input/%s_%ddeg.txt', filePrefix, phase_angles(j));
    write_to_file(triangle_waves(i, :), fileName, sigLineWidth);

    fileName = sprintf('test_cases/expected/%s_%ddeg.txt', filePrefix, phase_angles(j));
    write_to_file(triangle_waves_dft(i, :), fileName, targetLineWidth);
end

% TODO: filter output

% 99. Function definitions in a script must appear at the end of the file
% for waveform generation
% function output = scaleToInt(input, bit_len, input_swing)
%     % Scale the waveforms to the range of 0 to 2^bit_len-1
%     scaled = (input + 1) * (2^bit_len - 1) / 2;
%     % Convert the scaled waveforms to (bit_len)-bit unsigned integers
%     output = int32(scaled);
% end
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
function [sN, sNprev] = goertzel_filter(signal, targetFrequency, samplingRate, coeffBw, lsbTruncate)
    N = length(signal); % Length of the signal
    k = round(N * targetFrequency / samplingRate); % Bin frequency
    w = 2 * pi * k / N; % Angular frequency
    cosine = cos(w);
    coefficient = 2 * cosine;
    % fprintf("COEFF %.20f\n", coefficient);
    % round acconding to coeffBw
    coefficient = round(coefficient * 2 ^ coeffBw) / (2 ^ coeffBw);
    % fprintf("COEFF %.20f\n", coefficient); % 1.902099609375

    s = zeros(N, 1); % First intermediate variable
    sprev = 0; % Previous s[n-1]
    sprev2 = 0; % Previous s[n-2]

    % Iterate through the signal
    min = 0.0;
    max = 0.0;
    for n = 1:N
        % s(n) = signal(n) + coefficient * sprev - sprev2;

        % truncate according to lsbTruncate
        multi_prod_trunc = round(coefficient * sprev / 2 ^ lsbTruncate) * (2 ^ lsbTruncate);
        s(n) = round((signal(n) + multi_prod_trunc - sprev2) / 2 ^ lsbTruncate) * (2 ^ lsbTruncate);

        % % debug
        % fprintf("Prod_SO %d Sample_SI %d COEFF*Prod_q_D %d Prod_qq_D %d\n", s(n), signal(n), multi_prod_trunc, sprev2);
        % fprintf("n: %d Prod_SO %f Sample_SI %f COEFF*Prod_q_D %f %.20f %f Prod_qq_D %f\n", n, s(n), signal(n), multi_prod_trunc, coefficient, sprev, sprev2);        

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
    magnitude = sqrt(double(sN^2 + sNprev^2 - sN * sNprev * coefficient));
    disp(magnitude);

    % % Compute the FFT
    % f = (0:N-1) * (samplingRate / N);
    % fftSignal = abs(fft(signal));

    % % Plot the signal, intermediate values, and FFT
    % figure;
    % subplot(3, 1, 1);
    % plot(signal);
    % xlabel('Sample');
    % ylabel('Amplitude');
    % title('Input Signal');

    % subplot(3, 1, 2);
    % plot(s);
    % xlabel('Sample');
    % ylabel('s[n]');
    % title('Goertzel Algorithm - Intermediate Values');

    % subplot(3, 1, 3);
    % plot(f, fftSignal);
    % xlabel('Frequency (Hz)');
    % ylabel('Magnitude');
    % title('Frequency Spectrum (FFT)');
end

function write_to_file(signal, fileName, lineWidth)
    % Open the file for writing
    fileID = fopen(fileName, 'w');

    % Write each entity of the sine_wave to a line in the file
    for k = 1:length(signal)
        fprintf(fileID, '%0*X\n', lineWidth, signal(k));
    end

    % Close the file
    fclose(fileID);
end
