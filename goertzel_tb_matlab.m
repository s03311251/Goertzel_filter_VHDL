% Source: https://www.mathworks.com/help/signal/ref/goertzel.html

% 1. Define constants
Fs = 1e6; % sampling frequency
F_detect = 50e3; % frequency to detect
N = 100; % number of samples
INPUT_BIT_LEN = 14; % number of input bit length

% 2. Generate the waveforms
t = (0:N-1) / Fs;
phase_angles = [0, 30, 45, 90, 120];

% Sine Waves
frequencies_sine = [50e3, 49e3, 51e3, 5e3, 200e3];
sine_waves = zeros(length(frequencies_sine), length(phase_angles), N);

for i = 1:length(frequencies_sine)
    for j = 1:length(phase_angles)
        frequency = frequencies_sine(i);
        phase = phase_angles(j);
        sine_wave = sin(2*pi*frequency*t + deg2rad(phase));
        sine_waves(i, j, :) = scaleToUint(sine_wave, INPUT_BIT_LEN);

        % % Sanity Check for scaleToUint()
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
        phase = phase_angles(i);
        rectangular_wave = square(2*pi*frequency*t + deg2rad(phase));
        rectangular_waves(i, j, :) = scaleToUint(rectangular_wave, INPUT_BIT_LEN);
    end
end

% Triangle Waves
phase_angles_triangle = [0, 90];
triangle_waves = zeros(length(phase_angles_triangle), N);

for i = 1:length(phase_angles_triangle)
    phase = phase_angles_triangle(i);
    triangle_wave = sawtooth(2*pi*50e3*t + deg2rad(phase), 0.5);
    triangle_waves(i, :) = scaleToUint(triangle_wave, INPUT_BIT_LEN);
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

% TODO

% 4. Goertzel Filter

% f = [697 770 852 941 1209 1336 1477];
freq_indices = round(F_detect/Fs*N) + 1;
% % transform to single precision because goertzel only accepts single
% dft_data = goertzel(single(data),freq_indices);

% figure; % open a new figure window
% stem(f,abs(dft_data))

% % Adjusting subplot spacing
% sgtitle('Waveform Plots');

% ax = gca;
% ax.XTick = f;
% xlabel('Frequency (Hz)')
% ylabel('DFT Magnitude')

% 5. Sanity Check: plot the result of Goertzel Filter

% 6. Output the waveforms to a file
% each entity occupies a row in the file

% 99. Function definitions in a script must appear at the end of the file
% for waveform generation
function output = scaleToUint(input, bit_len)
    % Scale the waveforms to the range of 0 to 2^bit_len-1
    scaled = (input + 1) * (2^bit_len - 1) / 2;
    % Convert the scaled waveforms to (bit_len)-bit unsigned integers
    output = uint16(scaled);
end
