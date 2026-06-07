classdef SignalQualityService < handle
    % SignalQualityService - 信号质量评估服务

    methods (Static)
        function snrDb = computeChannelSNR(data, fs)
            % 计算每个通道的信噪比
            % data: (nCh, nSamples)
            [nCh, ~] = size(data);
            snrDb = zeros(nCh, 1);
            for ch = 1:nCh
                chData = data(ch, :);
                signalPower = rms(chData)^2;
                % 使用高频段 (>400Hz) 作为噪声估计
                nyquist = fs / 2;
                try
                    [b, a] = butter(4, 400 / nyquist, 'high');
                    noiseData = filtfilt(b, a, chData);
                    noisePower = rms(noiseData)^2;
                    if noisePower > 0
                        snrDb(ch) = 10 * log10(signalPower / noisePower);
                    else
                        snrDb(ch) = 40; % 理想情况
                    end
                catch
                    snrDb(ch) = 20; % 默认值
                end
            end
        end

        function quality = classifyQuality(snrValue)
            % 根据SNR分类信号质量
            import config.AppConstants
            if snrValue >= AppConstants.SNR_GOOD_THRESHOLD
                quality = 'good';
            elseif snrValue >= AppConstants.SNR_MARGINAL_THRESHOLD
                quality = 'marginal';
            else
                quality = 'poor';
            end
        end

        function color = getQualityColor(snrValue)
            import config.AppConstants
            q = services.SignalQualityService.classifyQuality(snrValue);
            switch q
                case 'good'
                    color = AppConstants.COLOR_SIG_GOOD;
                case 'marginal'
                    color = AppConstants.COLOR_SIG_MARGINAL;
                case 'poor'
                    color = AppConstants.COLOR_SIG_POOR;
            end
        end

        function badChannels = findBadChannels(data, fs, snrThreshold)
            % 找到质量差的通道
            if nargin < 3
                snrThreshold = 10; % dB
            end
            snrDb = services.SignalQualityService.computeChannelSNR(data, fs);
            badChannels = find(snrDb < snrThreshold);
        end

        function [contactOK, impedanceEstimate] = checkContact(data, fs)
            % 估计电极接触阻抗 (基于60Hz工频干扰强度)
            nyquist = fs / 2;
            try
                [b, a] = butter(2, [48, 52] / nyquist, 'bandpass');
                lineNoise = filtfilt(b, a, data')';
                noisePower = rms(lineNoise, 2);
                impedanceEstimate = noisePower * 1000; % 近似阻抗估计
                contactOK = impedanceEstimate < 500;   % 阈值
            catch
                contactOK = true(size(data, 1), 1);
                impedanceEstimate = zeros(size(data, 1), 1);
            end
        end
    end
end
