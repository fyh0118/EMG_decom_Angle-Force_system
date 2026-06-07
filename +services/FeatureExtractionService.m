classdef FeatureExtractionService < handle
    % FeatureExtractionService - 滑动窗特征提取服务
    %   从MU发放序列矩阵中提取累计脉冲数特征
    %
    %   数据流 (按用户描述):
    %     输入: spikeTrainMatrix (NMU × Nsamples) 二值发放矩阵
    %     参数: 200ms窗, 100ms步长, fs=2kHz
    %     输出: featureMatrix (nWindows × NMU) 每窗每MU的累计脉冲数

    properties
        WindowMs    double = 200    % 滑动窗长度 (ms)
        StepMs      double = 100    % 滑动窗步长 (ms)
        Fs          double = 2000   % 采样率
        ApplySqrtTransform logical = true   % 是否应用sqrt变换 (ST特征需要)
        NormParams   struct          % 归一化参数 (ch_min, ch_range)
    end

    methods
        function obj = FeatureExtractionService(windowMs, stepMs, fs)
            if nargin >= 1, obj.WindowMs = windowMs; end
            if nargin >= 2, obj.StepMs = stepMs; end
            if nargin >= 3, obj.Fs = fs; end
        end

        function [featureMatrix, timeVector] = extractCumulativeSpikeCount(obj, spikeTrainMatrix)
            % 提取累计脉冲数特征
            %
            % INPUT:
            %   spikeTrainMatrix - (NMU, Nsamples) 二值发放矩阵
            %
            % OUTPUT:
            %   featureMatrix - (nWindows, NMU) 每窗每MU的累计脉冲数
            %   timeVector    - (nWindows, 1) 每窗中心时间点 (秒)

            [nMU, nSamples] = size(spikeTrainMatrix);
            winSamples = round(obj.WindowMs / 1000 * obj.Fs);
            stepSamples = round(obj.StepMs / 1000 * obj.Fs);

            % 计算窗口数
            nWindows = floor((nSamples - winSamples) / stepSamples) + 1;

            if nWindows < 1
                error('数据长度不足: 需要至少%d个样本, 当前%d个', winSamples, nSamples);
            end

            featureMatrix = zeros(nWindows, nMU);
            timeVector = zeros(nWindows, 1);

            % 滑动窗累计脉冲计数
            for w = 1:nWindows
                startIdx = (w - 1) * stepSamples + 1;
                endIdx = startIdx + winSamples - 1;

                % 累计窗内每个MU的发放次数
                featureMatrix(w, :) = sum(spikeTrainMatrix(:, startIdx:endIdx), 2)';

                % 窗中心时间 (秒)
                timeVector(w) = (startIdx + winSamples / 2 - 1) / obj.Fs;
            end

            obj.log(sprintf('特征提取完成: %d个MU × %d个时间窗 = %d×%d特征矩阵', ...
                nMU, nWindows, nWindows, nMU));
        end

        function [featureMatrix, timeVector, normParams] = extractSTFeatures(obj, spikeTrainMatrix)
            % 完整ST特征提取管线 (匹配训练脚本 step6)
            %   Step 1: 累计脉冲计数
            %   Step 2: sqrt变换
            %   Step 3: 通道min-max归一化
            %
            % OUTPUT:
            %   featureMatrix - (nWindows, NMU) 归一化特征矩阵
            %   timeVector    - (nWindows, 1) 窗中心时间
            %   normParams    - 归一化参数 struct(ch_min, ch_range)

            [rawFeatures, timeVector] = obj.extractCumulativeSpikeCount(spikeTrainMatrix);

            if obj.ApplySqrtTransform
                featureMatrix = sqrt(rawFeatures);
            else
                featureMatrix = rawFeatures;
            end

            [featureMatrix, normParams] = obj.normalizePerChannel(featureMatrix);
            obj.NormParams = normParams;

            obj.log(sprintf('ST特征提取完成: %d窗 × %dMU (sqrt=%d)', ...
                size(featureMatrix,1), size(featureMatrix,2), obj.ApplySqrtTransform));
        end

        function [normalized, params] = normalizePerChannel(obj, featureMatrix)
            % 通道min-max归一化 (0-1)
            ch_min = min(featureMatrix, [], 1);
            ch_max = max(featureMatrix, [], 1);
            ch_range = ch_max - ch_min;
            ch_range(ch_range == 0) = 1;
            normalized = (featureMatrix - ch_min) ./ ch_range;
            params = struct('ch_min', ch_min, 'ch_range', ch_range);
        end

        function normalized = applyNormParams(obj, featureMatrix, params)
            % 用已有参数归一化
            normalized = (featureMatrix - params.ch_min) ./ params.ch_range;
        end

        function [featureMatrix, timeVector] = extractSpikeDensity(obj, spikeTrainMatrix, kernelSigma)
            % 提取脉冲密度特征 (高斯核平滑)
            if nargin < 3, kernelSigma = 0.05; end  % 50ms默认

            [nMU, nSamples] = size(spikeTrainMatrix);
            stepSamples = round(obj.StepMs / 1000 * obj.Fs);

            % 高斯核
            kernelWidth = round(4 * kernelSigma * obj.Fs);
            kernelWidth = kernelWidth + mod(kernelWidth, 2); % 确保奇数
            tKernel = (-kernelWidth/2:kernelWidth/2) / obj.Fs;
            gaussKernel = exp(-tKernel.^2 / (2 * kernelSigma^2));
            gaussKernel = gaussKernel / sum(gaussKernel);

            % 对所有MU并行卷积
            smoothed = zeros(size(spikeTrainMatrix));
            for mu = 1:nMU
                smoothed(mu, :) = conv(spikeTrainMatrix(mu, :), gaussKernel, 'same');
            end

            % 降采样到窗口步长
            sampleIdx = round(obj.WindowMs / 1000 * obj.Fs / 2):stepSamples:nSamples;
            nWindows = length(sampleIdx);

            featureMatrix = smoothed(:, sampleIdx)';
            timeVector = (sampleIdx - 1)' / obj.Fs;
        end

        function [rmsFeatures, timeVector] = extractRMSFeatures(obj, rawEMG, fs)
            % 提取传统RMS特征 (用于对比)
            % rawEMG: (nCh, Nsamples)
            winSamples = round(obj.WindowMs / 1000 * fs);
            stepSamples = round(obj.StepMs / 1000 * fs);
            [nCh, nSamples] = size(rawEMG);
            nWindows = floor((nSamples - winSamples) / stepSamples) + 1;

            rmsFeatures = zeros(nWindows, nCh);
            timeVector = zeros(nWindows, 1);

            for w = 1:nWindows
                startIdx = (w - 1) * stepSamples + 1;
                endIdx = startIdx + winSamples - 1;
                rmsFeatures(w, :) = rms(rawEMG(:, startIdx:endIdx), 2)';
                timeVector(w) = (startIdx + winSamples / 2 - 1) / fs;
            end
        end
    end

    methods (Access = private)
        function log(~, msg)
            fprintf('[特征提取] %s\n', msg);
        end
    end
end
