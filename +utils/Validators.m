classdef Validators
    % Validators - 输入验证工具

    methods (Static)
        function [isValid, msg] = validateEMGData(data, fs)
            isValid = true;
            msg = '';
            if isempty(data)
                isValid = false;
                msg = '数据为空';
                return;
            end
            [nCh, nSamples] = size(data);
            if nCh ~= 128
                isValid = false;
                msg = sprintf('通道数应为128, 当前为%d', nCh);
                return;
            end
            if nSamples < fs * 0.5
                isValid = false;
                msg = sprintf('数据时长不足, 至少需要0.5秒的数据');
                return;
            end
        end

        function [isValid, msg] = validateSpikeTrain(spikeTrain, fs)
            isValid = true;
            msg = '';
            if isempty(spikeTrain)
                isValid = false;
                msg = '分解结果为空, 请先进行肌电分解';
                return;
            end
            if size(spikeTrain, 2) < fs
                isValid = false;
                msg = '分解结果时长不足';
                return;
            end
        end

        function [isValid, msg] = validateFeatureMatrix(featureMatrix)
            isValid = true;
            msg = '';
            if isempty(featureMatrix)
                isValid = false;
                msg = '特征矩阵为空, 请先提取特征';
                return;
            end
            [nWindows, ~] = size(featureMatrix);
            if nWindows < 10
                isValid = false;
                msg = sprintf('时间窗数量不足(%d), 请检查窗长和步长设置', nWindows);
                return;
            end
        end

        function [isValid, msg] = validateModel(modelPath)
            isValid = true;
            msg = '';
            if ~isfile(modelPath)
                isValid = false;
                msg = sprintf('模型文件不存在: %s', modelPath);
                return;
            end
        end
    end
end
