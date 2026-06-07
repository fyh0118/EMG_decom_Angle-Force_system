classdef SignalProcessing
    % SignalProcessing - 肌电信号预处理工具

    methods (Static)
        function filteredData = bandpassFilter(data, fs, lowCut, highCut)
            % 带通滤波 (20-500Hz, 4阶Butterworth)
            if nargin < 3, lowCut = 20; end
            if nargin < 4, highCut = 500; end
            nyquist = fs / 2;
            [b, a] = butter(4, [lowCut, highCut] / nyquist, 'bandpass');
            filteredData = filtfilt(b, a, data')';
        end

        function filteredData = notchFilter(data, fs, notchFreq, qFactor)
            % 陷波滤波 (50Hz工频)
            if nargin < 3, notchFreq = 50; end
            if nargin < 4, qFactor = 35; end
            wo = notchFreq / (fs / 2);
            bw = wo / qFactor;
            [b, a] = iirnotch(wo, bw);
            filteredData = filtfilt(b, a, data')';
        end

        function filteredData = preprocessEMG(data, fs)
            % 标准EMG预处理管线: 带通 → 陷波
            filteredData = utils.SignalProcessing.bandpassFilter(data, fs);
            filteredData = utils.SignalProcessing.notchFilter(filteredData, fs);
        end

        function envelope = computeEnvelope(data, fs, lowPassCut)
            % 计算信号包络 (整流 + 低通)
            if nargin < 3, lowPassCut = 6; end
            rectified = abs(data);
            nyquist = fs / 2;
            [b, a] = butter(2, lowPassCut / nyquist, 'low');
            envelope = filtfilt(b, a, rectified')';
        end

        function normalizedData = normalizeData(data)
            % Min-Max归一化到[0, 1]
            minVal = min(data, [], 2);
            maxVal = max(data, [], 2);
            range = maxVal - minVal;
            range(range < eps) = 1;
            normalizedData = (data - minVal) ./ range;
        end

        function downsampled = downsample(data, originalFs, targetFs)
            % 降采样
            factor = round(originalFs / targetFs);
            if factor > 1
                downsampled = data(:, 1:factor:end);
            else
                downsampled = data;
            end
        end
    end
end
