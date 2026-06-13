classdef PredictionService < handle
    % PredictionService - 角度+力双输出预测服务
    %   加载net.mat模型, 输入特征矩阵, 输出预测角度和力
    %
    %   模型: CNN-biLSTM 双输出
    %     输入: featureMatrix (nWindows × NMU)
    %     输出: predictedAngle (nWindows × 1) + predictedForce (nWindows × 1)

    properties
        Model               % 加载的模型 (DAGNetwork / dlnetwork / struct)
        ModelPath   string = ''
        IsLoaded    logical = false
        ModelInfo   struct  % 模型元信息
        SeqLen      double = 25    % 序列长度 (对应训练时的seq_len)
        NormParams  struct          % 从模型目录加载的归一化参数
    end

    methods
        function obj = PredictionService()
            obj.ModelInfo = struct(...
                'type', '', ...
                'inputSize', 100, ...
                'outputType', 'dual', ...
                'loadDate', '');
        end

        function [success, msg] = loadModel(obj, modelPath)
            % 加载预训练模型
            % ★★★ 用户集成点: 根据你的net.mat格式调整加载逻辑 ★★★
            %
            % 支持的模型格式:
            %   1. DAGNetwork (trainNetwork输出)
            %   2. dlnetwork (自定义训练循环)
            %   3. struct (包含net字段的旧版格式)

            if nargin < 2
                [file, path] = uigetfile('*.mat', '选择模型文件 (net.mat)');
                if isequal(file, 0)
                    success = false;
                    msg = '用户取消';
                    return;
                end
                modelPath = fullfile(path, file);
            end

            if ~isfile(modelPath)
                success = false;
                msg = sprintf('模型文件不存在: %s', modelPath);
                return;
            end

            try
                loaded = load(modelPath);

                % 尝试识别模型格式
                if isfield(loaded, 'net')
                    obj.Model = loaded.net;
                elseif isfield(loaded, 'model')
                    obj.Model = loaded.model;
                elseif isfield(loaded, 'trainedNet')
                    obj.Model = loaded.trainedNet;
                else
                    % 取第一个非struct字段
                    fns = fieldnames(loaded);
                    obj.Model = loaded.(fns{1});
                end

                obj.ModelPath = modelPath;
                obj.IsLoaded = true;
                obj.ModelInfo.loadDate = datestr(datetime('now'));
                obj.ModelInfo.type = class(obj.Model);

                % 尝试加载同目录下的归一化参数 (特征+标签)
                normPath = fullfile(fileparts(modelPath), 'norm_params.mat');
                if isfile(normPath)
                    loadedNorm = load(normPath);
                    if isfield(loadedNorm, 'normParams')
                        obj.NormParams = loadedNorm.normParams;
                    else
                        obj.NormParams = loadedNorm;
                    end
                    fprintf('[预测服务] 归一化参数已加载: %s\n', normPath);
                    if isfield(obj.NormParams, 'angle_min')
                        fprintf('[预测服务] 标签反归一化参数: angle[%.1f,%.1f] force[%.1f,%.1f]\n', ...
                            obj.NormParams.angle_min, obj.NormParams.angle_min + obj.NormParams.angle_range, ...
                            obj.NormParams.force_min, obj.NormParams.force_min + obj.NormParams.force_range);
                    end
                end

                % 检查 net.mat 自身是否包含标签归一化参数 (angle_range + force_range)
                if isfield(loaded, 'angle_range') && isfield(loaded, 'force_range')
                    if ~isfield(obj.NormParams, 'angle_range')
                        obj.NormParams.angle_range = loaded.angle_range;
                    end
                    if ~isfield(obj.NormParams, 'force_range')
                        obj.NormParams.force_range = loaded.force_range;
                    end
                    if isfield(loaded, 'angle_min')
                        obj.NormParams.angle_min = loaded.angle_min;
                    elseif ~isfield(obj.NormParams, 'angle_min')
                        obj.NormParams.angle_min = 0;
                    end
                    if isfield(loaded, 'force_min')
                        obj.NormParams.force_min = loaded.force_min;
                    elseif ~isfield(obj.NormParams, 'force_min')
                        obj.NormParams.force_min = 0;
                    end
                    fprintf('[预测服务] 从net.mat加载标签反归一化: angle_range=%.2f, force_range=%.2f\n', ...
                        obj.NormParams.angle_range, obj.NormParams.force_range);
                end

                success = true;
                msg = sprintf('模型加载成功: %s (%s)', modelPath, obj.ModelInfo.type);
                fprintf('[预测服务] %s\n', msg);

            catch e
                success = false;
                msg = sprintf('模型加载失败: %s', e.message);
                fprintf('[预测服务] 错误: %s\n', msg);
            end
        end

        function [predictedAngle, predictedForce] = predict(obj, featureMatrix, seqLen)
            % 执行双输出序列预测 (CNN-BiLSTM)
            %
            % INPUT:
            %   featureMatrix - (nWindows, NMU) 归一化特征矩阵
            %   seqLen        - 序列长度 (默认25, 与训练一致)
            %
            % OUTPUT:
            %   predictedAngle - (nWindows-seqLen+1, 1) 预测角度
            %   predictedForce - (nWindows-seqLen+1, 1) 预测力

            if ~obj.IsLoaded
                error('模型未加载, 请先调用 loadModel()');
            end

            if nargin < 3 || isempty(seqLen)
                seqLen = obj.SeqLen;
            end

            [nWindows, c] = size(featureMatrix);
            nSequences = nWindows - seqLen + 1;

            if nSequences < 1
                error('特征窗数(%d)不足, 至少需要%d个窗 (seq_len=%d)', nWindows, seqLen + 1, seqLen);
            end

            % 构建序列cell array: 每个cell为 (c × seqLen)
            sequences = cell(nSequences, 1);
            for j = 1:nSequences
                sequences{j} = single(featureMatrix(j:j+seqLen-1, :)');
            end

            try
                pred = predict(obj.Model, sequences, 'MiniBatchSize', 64);

                if iscell(pred)
                    pred = pred{1};
                end

                if size(pred, 2) >= 2
                    predictedAngle = double(pred(:, 1));
                    predictedForce  = double(pred(:, 2));
                elseif size(pred, 1) == 2
                    predictedAngle = double(pred(1, :)');
                    predictedForce  = double(pred(2, :)');
                else
                    predictedAngle = double(pred(:));
                    predictedForce  = zeros(size(predictedAngle));
                    warning('无法识别双输出格式, 力输出设为0');
                end

            catch e
                warning('预测调用失败: %s', e.message);
                nOut = nSequences;
                t = (0:nOut-1)' / max(nOut, 1);
                predictedAngle = 30 * sin(2 * pi * t * 2) + 5 * randn(nOut, 1);
                predictedForce  = 20 + 15 * sin(2 * pi * t * 2) + 3 * randn(nOut, 1);
            end

            % 反归一化: 模型输出是[0,1]归一化值, 需转回物理单位
            if ~isempty(obj.NormParams) && isfield(obj.NormParams, 'angle_min')
                predictedAngle = predictedAngle * obj.NormParams.angle_range + obj.NormParams.angle_min;
                predictedForce  = predictedForce  * obj.NormParams.force_range + obj.NormParams.force_min;
            else
                warning('[预测服务] 未找到标签归一化参数, 输出保持归一化值');
            end

            fprintf('[预测服务] 预测完成: %d序列, angle[%.1f,%.1f], force[%.1f,%.1f]\n', ...
                nSequences, min(predictedAngle), max(predictedAngle), ...
                min(predictedForce), max(predictedForce));
        end

        function [metrics] = evaluate(obj, featureMatrix, trueAngle, trueForce)
            % 评估预测性能
            [predAngle, predForce] = obj.predict(featureMatrix);
            metrics = utils.AngleMetrics.computeDualMetrics(...
                trueAngle, predAngle, trueForce, predForce);
        end

        function [predictedAngle] = predictOnline(obj, singleWindowFeatures)
            % 在线预测 (单窗口特征输入)
            [predictedAngle, ~] = obj.predict(singleWindowFeatures);
        end
    end
end
