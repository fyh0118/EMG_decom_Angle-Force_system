classdef DecompositionService < handle
    % DecompositionService - 肌电分解算法适配器
    %   集成在线ICA快速分解 (基于预存分离向量/聚类中心)
    %
    %   两种模式:
    %     'online'  - 在线快速分解 (用模板, 快, ~1-2min)
    %     'offline' - 离线完整ICA分解 (不用模板, 慢, ~10-30min)
    %
    %   在线模式管线 (匹配 step2_fyh_onlineICA_piliang.m):
    %     1. 加载模板: newInd_B, newInd_C, E, D
    %     2. 对每个窗口: extend → whiteesig(E,D) → icasig=w'*X → 聚类检测spikes
    %     3. 合并所有窗口 → spike train matrix

    properties
        Config          models.DecompConfig
        IsRunning       logical = false
        Progress        double = 0       % 0-100

        % 在线分解参数
        ExtendFactor    double = 10      % 扩展阶数 (对应 exFactor=10)
        WindowLengthMs  double = 200     % 窗长 (ms)
        PeakThreshold   double = 60      % 静息/运动筛选阈值 (60适合真实数据)
        MinPeakDistanceMs double = 20    % 最小峰间距 (ms)

        % 模板数据
        FlexorTemplate  struct           % 屈肌侧模板 (newInd_B, newInd_C, E, D)
        ExtensorTemplate struct          % 伸肌侧模板

        % Python bridge 配置
        TemplateDir     string = ""      % 模板目录 (save_bc/)
        OutputDir       string = ""      % 分解结果输出目录
        PythonExe       string = "python" % Python 可执行文件路径
    end

    events
        ProgressUpdate
        DecompositionComplete
    end

    methods
        function obj = DecompositionService(config)
            if nargin < 1
                config = models.DecompConfig();
            end
            obj.Config = config;
        end

        %% ===== 模板加载 =====
        function loadFlexorTemplate(obj, templatePath)
            % 加载屈肌侧 (dev0) 在线分解模板
            % 模板文件包含: newInd_B, newInd_C, E, D
            t = load(templatePath);
            obj.FlexorTemplate = obj.extractTemplateVars(t, templatePath);
            nMU = size(obj.FlexorTemplate.newInd_B, 2);
            fprintf('[分解服务] 屈肌模板已加载: %d MUs (%s)\n', nMU, templatePath);
        end

        function loadExtensorTemplate(obj, templatePath)
            % 加载伸肌侧 (dev1) 在线分解模板
            t = load(templatePath);
            obj.ExtensorTemplate = obj.extractTemplateVars(t, templatePath);
            nMU = size(obj.ExtensorTemplate.newInd_B, 2);
            fprintf('[分解服务] 伸肌模板已加载: %d MUs (%s)\n', nMU, templatePath);
        end

        function tmpl = extractTemplateVars(~, data, path)
            % 从加载的结构体中提取模板变量
            required = {'newInd_B', 'newInd_C', 'E', 'D'};
            for k = 1:length(required)
                if ~isfield(data, required{k})
                    error('模板文件缺少变量: %s (文件: %s)', required{k}, path);
                end
            end
            tmpl.newInd_B = data.newInd_B;
            tmpl.newInd_C = data.newInd_C;
            tmpl.E = data.E;
            tmpl.D = data.D;
        end

        function [isReady, msg] = isOnlineDecompReady(obj)
            % 检查在线分解是否准备就绪
            if isempty(obj.FlexorTemplate)
                isReady = false;
                msg = '屈肌侧模板未加载';
                return;
            end
            if isempty(obj.ExtensorTemplate)
                isReady = false;
                msg = '伸肌侧模板未加载';
                return;
            end
            isReady = true;
            msg = '';
        end

        %% ===== 在线ICA分解 =====
        function [result] = onlineDecompose(obj, flexorEMG, extensorEMG, fs)
            % 在线ICA快速分解 (用模板)
            %
            % INPUT:
            %   flexorEMG   - (64, N1) 屈肌侧EMG信号
            %   extensorEMG - (64, N2) 伸肌侧EMG信号
            %   fs          - 采样率
            %
            % OUTPUT:
            %   result - 包含合并发放矩阵和统计信息

            [isReady, msg] = obj.isOnlineDecompReady();
            if ~isReady, error(msg); end

            obj.IsRunning = true;
            obj.Progress = 0;
            tStart = tic;

            fprintf('[分解服务] 开始在线ICA分解...\n');

            % 分解屈肌侧
            obj.Progress = 5;
            flexorResult = obj.decomposeOneSide(flexorEMG, obj.FlexorTemplate, fs, '屈肌');

            % 分解伸肌侧
            obj.Progress = 50;
            extensorResult = obj.decomposeOneSide(extensorEMG, obj.ExtensorTemplate, fs, '伸肌');

            % 合并结果
            obj.Progress = 90;
            result = obj.mergeResults(flexorResult, extensorResult, fs);
            result.decompTime = toc(tStart);

            obj.IsRunning = false;
            obj.Progress = 100;

            fprintf('[分解服务] 在线分解完成! 屈肌:%dMU 伸肌:%dMU 总:%dMU 用时:%.1fs\n', ...
                result.nFlexorMUs, result.nExtensorMUs, ...
                result.nFlexorMUs + result.nExtensorMUs, result.decompTime);

            notify(obj, 'DecompositionComplete');
        end

        function sideResult = decomposeOneSide(obj, EMG, template, fs, sideName)
            % 对单侧进行在线ICA分解 (匹配 step2 逻辑)
            %
            % INPUT:
            %   EMG      - (64, Nsamples) 原始EMG
            %   template - struct with newInd_B, newInd_C, E, D
            %   fs       - 采样率
            %
            % OUTPUT:
            %   sideResult.spikeTrain - (nMU, Nsamples) 二值发放矩阵
            %   sideResult.nMU        - MU数量
            %   sideResult.must_online - cell of spike indices

            % 统一为 [通道 × 采样点]
            if size(EMG, 1) > size(EMG, 2)
                EMG = EMG';
            end

            newInd_B = template.newInd_B;
            newInd_C = template.newInd_C;
            E = template.E;
            D = template.D;

            nMU = size(newInd_B, 2);
            totalSamples = size(EMG, 2);
            windowSamples = round(fs * obj.WindowLengthMs / 1000);
            nWindows = floor(totalSamples / windowSamples);

            fprintf('[分解服务] %s侧: %d samples, %d 窗口, %d MUs\n', ...
                sideName, totalSamples, nWindows, nMU);

            % 缓存每个窗口的发放
            muSpikesCell = cell(nMU, nWindows);

            for winIdx = 1:nWindows
                startIdx = (winIdx - 1) * windowSamples + 1;
                endIdx   = winIdx * windowSamples;
                segment  = EMG(:, startIdx:endIdx);

                % 扩展
                extended = extend(segment, obj.ExtendFactor);

                % 白化 (用模板的E, D)
                [wSIG, ~, ~] = whiteesig(extended, E, D);

                % 在线检测 spikes
                spikes = obj.detectSpikesOnline(newInd_B, wSIG, newInd_C, fs, winIdx);

                % 局部索引 → 全局索引
                for muIdx = 1:length(spikes)
                    if ~isempty(spikes{muIdx})
                        muSpikesCell{muIdx, winIdx} = spikes{muIdx} + (startIdx - 1);
                    end
                end

                % 进度更新
                if mod(winIdx, max(1, floor(nWindows/10))) == 0
                    pct = round(winIdx / nWindows * 100);
                    fprintf('[分解服务] %s侧进度: %d/%d 窗口 (%d%%)\n', ...
                        sideName, winIdx, nWindows, pct);
                end
            end

            % 重组发放序列
            mustOnline = cell(nMU, 1);
            for muIdx = 1:nMU
                tmp = [muSpikesCell{muIdx, :}];
                tmp = unique(tmp(:)');
                tmp(tmp < 1 | tmp > totalSamples) = [];
                mustOnline{muIdx} = tmp;
            end

            % 生成二值发放矩阵
            spikeTrain = zeros(nMU, totalSamples);
            for muIdx = 1:nMU
                if ~isempty(mustOnline{muIdx})
                    spikeTrain(muIdx, mustOnline{muIdx}) = 1;
                end
            end

            sideResult.spikeTrain = spikeTrain;
            sideResult.nMU = nMU;
            sideResult.mustOnline = mustOnline;
            sideResult.sideName = sideName;

            fprintf('[分解服务] %s侧完成: %d MU × %d samples\n', ...
                sideName, nMU, totalSamples);
        end

        function spikes = detectSpikesOnline(obj, B, X, C, fs, ~)
            % 在线spike检测 (匹配 step2 的 getspikes_online 逻辑)
            %
            % INPUT:
            %   B  - (nExtended, nMU) 分离向量矩阵
            %   X  - (nExtended, nSamples) 白化后信号
            %   C  - 聚类中心 cell array
            %   fs - 采样率
            %
            % OUTPUT:
            %   spikes - {nMU × 1} cell, 每个元素是该MU在当前窗的spike索引

            % 计算每个MU的源信号: icasig = (w' * X) .* |w' * X|
            icasig = (B' * X) .* abs(B' * X);
            nMU = size(icasig, 1);
            spikes = cell(nMU, 1);

            minPeakDist = round(fs * obj.MinPeakDistanceMs / 1000);

            for i = 1:nMU
                tmpIcasig = icasig(i, :);

                % 找峰
                try
                    [~, tmpSpikes1] = findpeaks(tmpIcasig, 'MinPeakDistance', minPeakDist);
                catch
                    tmpSpikes1 = [];
                end

                if isempty(tmpSpikes1)
                    spikes{i} = [];
                    continue;
                end

                % 静息/运动筛选 (阈值60适合真实数据)
                if mean(maxk(tmpIcasig, min(1, numel(tmpIcasig)))) > obj.PeakThreshold

                    peakVals = tmpIcasig(tmpSpikes1);

                    if length(peakVals) >= 3
                        normFactor = mean(maxk(peakVals, 3));
                    else
                        normFactor = mean(peakVals);
                    end

                    if normFactor == 0 || isnan(normFactor)
                        spikes{i} = tmpSpikes1;
                        continue;
                    end

                    icasigNorm = tmpIcasig / normFactor;
                    peakValsNorm = icasigNorm(tmpSpikes1);

                    % 用聚类中心区分spike和非spike
                    if length(tmpSpikes1) > 1 && i <= length(C) && ~isempty(C{i})
                        tmpC = C{i};
                        centerSmall = min(tmpC);
                        centerLarge = max(tmpC);

                        distSmall = abs(peakValsNorm - centerSmall);
                        distLarge = abs(peakValsNorm - centerLarge);

                        isSpike = distLarge < distSmall;
                        tmpSpikes2 = tmpSpikes1(isSpike);

                        % 去除异常大值
                        if ~isempty(tmpSpikes2)
                            vals2 = icasigNorm(tmpSpikes2);
                            thr = mean(vals2) + 3 * std(vals2);
                            tmpSpikes2(vals2 > thr) = [];
                        end
                    else
                        tmpSpikes2 = tmpSpikes1;
                    end

                    spikes{i} = tmpSpikes2;
                else
                    spikes{i} = [];
                end
            end
        end

        function result = mergeResults(obj, flexorResult, extensorResult, fs)
            % 合并屈肌和伸肌分解结果
            %
            % 数据矩阵排列:
            %   行 1:nFlexorMU           = 屈肌侧MU
            %   行 nFlexorMU+1:end       = 伸肌侧MU

            nFlexorMU = flexorResult.nMU;
            nExtensorMU = extensorResult.nMU;
            nTotalMU = nFlexorMU + nExtensorMU;

            % 对齐采样点数 (取较小值)
            nFlexorSamples = size(flexorResult.spikeTrain, 2);
            nExtensorSamples = size(extensorResult.spikeTrain, 2);
            nSamples = min(nFlexorSamples, nExtensorSamples);

            % 合并发放矩阵
            spikeTrainMatrix = zeros(nTotalMU, nSamples);
            spikeTrainMatrix(1:nFlexorMU, :) = flexorResult.spikeTrain(:, 1:nSamples);
            spikeTrainMatrix(nFlexorMU + 1:end, :) = extensorResult.spikeTrain(:, 1:nSamples);

            % 计算放电率
            durationSec = nSamples / fs;
            firingRates = sum(spikeTrainMatrix, 2) / durationSec;

            % 计算放电率CV
            firingRateCV = zeros(nTotalMU, 1);
            for mu = 1:nTotalMU
                spikeIdx = find(spikeTrainMatrix(mu, :));
                if length(spikeIdx) >= 2
                    isi = diff(spikeIdx) / fs;
                    firingRateCV(mu) = std(isi) / mean(isi);
                end
            end

            result.spikeTrainMatrix = spikeTrainMatrix;
            result.nFlexorMUs = nFlexorMU;
            result.nExtensorMUs = nExtensorMU;
            result.muapWaveforms = {};
            result.firingRates = firingRates;
            result.firingRateCV = firingRateCV;
            result.sil = zeros(nTotalMU, 1);
            result.pnr = zeros(nTotalMU, 1);
            result.flexorSpikes = flexorResult.mustOnline;
            result.extensorSpikes = extensorResult.mustOnline;
        end

        %% ===== 模拟分解 (无模板时用于测试) =====
        function [result] = simulateDecomposition(obj, data, fs)
            % 模拟分解 - 生成仿真MU发放序列用于系统测试
            [~, nSamples] = size(data);
            nFlexorMUs = 50;
            nExtensorMUs = 50;
            NMU = nFlexorMUs + nExtensorMUs;

            spikeTrainMatrix = zeros(NMU, nSamples);
            firingRates = zeros(NMU, 1);
            firingRateCV = zeros(NMU, 1);
            sil = zeros(NMU, 1);
            pnr = zeros(NMU, 1);

            durationSec = nSamples / fs;
            for mu = 1:NMU
                fr = 5 + 30 * rand();
                firingRates(mu) = fr;
                firingRateCV(mu) = 0.1 + 0.3 * rand();

                isi = exprnd(1/fr, round(fr * durationSec * 1.5), 1);
                spikeTimesSec = cumsum(isi);
                spikeTimesSec(spikeTimesSec > durationSec) = [];
                spikeSamples = round(spikeTimesSec * fs);
                spikeSamples(spikeSamples < 1 | spikeSamples > nSamples) = [];
                spikeTrainMatrix(mu, spikeSamples) = 1;

                sil(mu) = 0.85 + 0.14 * rand();
                pnr(mu) = 20 + 15 * rand();
            end

            result.spikeTrainMatrix = spikeTrainMatrix;
            result.nFlexorMUs = nFlexorMUs;
            result.nExtensorMUs = nExtensorMUs;
            result.muapWaveforms = {};
            result.firingRates = firingRates;
            result.firingRateCV = firingRateCV;
            result.sil = sil;
            result.pnr = pnr;
            result.decompTime = 0;
        end

        %% ===== Python Bridge 在线分解 =====
        function [result] = decomposeWithPython(obj, flexorEMGPath, extensorEMGPath, ...
                templateDir, outputDir)
            % 调用 Python bridge 进行真实在线 ICA 分解
            %
            % INPUT:
            %   flexorEMGPath   - 屈肌侧 EMG .mat 文件路径
            %   extensorEMGPath - 伸肌侧 EMG .mat 文件路径
            %   templateDir     - 模板目录 (save_bc/)
            %   outputDir       - 结果输出目录
            %
            % OUTPUT:
            %   result - 包含合并发放矩阵和统计信息

            if nargin < 5 || isempty(outputDir)
                outputDir = tempdir;
            end

            obj.IsRunning = true;
            obj.Progress = 0;
            tStart = tic;

            % 定位 Python bridge (部署模式用 EXE, 开发模式用 .py)
            if isdeployed
                bridgeExe = fullfile(ctfroot, 'EMGDecom', 'decompose_python_bridge.exe');
                cmd = sprintf('"%s" "%s" "%s" "%s" "%s"', ...
                    bridgeExe, flexorEMGPath, extensorEMGPath, ...
                    templateDir, outputDir);
                fprintf('[分解服务] Bridge (部署): %s\n', bridgeExe);
            else
                bridgeScript = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                    'decompose_python_bridge.py');
                cmd = sprintf('"%s" "%s" "%s" "%s" "%s" "%s"', ...
                    obj.PythonExe, bridgeScript, flexorEMGPath, ...
                    extensorEMGPath, templateDir, outputDir);
                fprintf('[分解服务] Bridge (开发): %s\n', bridgeScript);
            end

            fprintf('[分解服务] Flexor EMG: %s\n', flexorEMGPath);
            fprintf('[分解服务] Extensor EMG: %s\n', extensorEMGPath);
            fprintf('[分解服务] Template dir: %s\n', templateDir);
            fprintf('[分解服务] Output dir: %s\n', outputDir);
            fprintf('[分解服务] 执行: %s\n', cmd);

            obj.Progress = 10;

            % 执行 Python 桥
            [status, cmdout] = system(cmd);
            if status ~= 0
                obj.IsRunning = false;
                error('Python分解失败:\n%s', cmdout);
            end

            obj.Progress = 70;

            % 解析 JSON 结果
            jsonStr = strtrim(cmdout);
            % 提取最后一行 JSON (忽略之前的打印输出)
            lines = strsplit(jsonStr, '\n');
            jsonStr = '';
            for i = length(lines):-1:1
                trimmed = strtrim(lines{i});
                if startsWith(trimmed, '{')
                    jsonStr = trimmed;
                    break;
                end
            end

            if isempty(jsonStr)
                obj.IsRunning = false;
                error('无法解析Python输出: %s', cmdout);
            end

            pyResult = jsondecode(jsonStr);

            if ~strcmp(pyResult.status, 'success')
                obj.IsRunning = false;
                error('Python分解失败: %s', pyResult.message);
            end

            fprintf('[分解服务] %s\n', pyResult.message);

            % 加载 CSV 结果 (使用 dlmread 兼容 R2018a+)
            flexorST = dlmread(pyResult.spike_train_flexor_path, ',');
            extensorST = dlmread(pyResult.spike_train_extensor_path, ',');

            nFlexorMU = pyResult.n_flexor_mu;
            nExtensorMU = pyResult.n_extensor_mu;
            nTotalMU = nFlexorMU + nExtensorMU;

            % 合并发放矩阵
            if size(flexorST, 1) ~= nFlexorMU
                flexorST = flexorST';  % 转置确保 (nMU x nSamples)
            end
            if size(extensorST, 1) ~= nExtensorMU
                extensorST = extensorST';
            end

            nSamples = min(size(flexorST, 2), size(extensorST, 2));
            spikeTrainMatrix = zeros(nTotalMU, nSamples);
            spikeTrainMatrix(1:nFlexorMU, :) = flexorST(:, 1:nSamples);
            spikeTrainMatrix(nFlexorMU + 1:end, :) = extensorST(:, 1:nSamples);

            obj.Progress = 85;

            % 计算放电率 (fs=2000Hz 默认)
            fs = 2000;
            durationSec = nSamples / fs;
            firingRates = sum(spikeTrainMatrix, 2) / durationSec;

            % 计算放电率 CV
            firingRateCV = zeros(nTotalMU, 1);
            for mu = 1:nTotalMU
                spikeIdx = find(spikeTrainMatrix(mu, :));
                if length(spikeIdx) >= 2
                    isi = diff(spikeIdx) / fs;
                    firingRateCV(mu) = std(isi) / mean(isi);
                end
            end

            result.spikeTrainMatrix = spikeTrainMatrix;
            result.nFlexorMUs = nFlexorMU;
            result.nExtensorMUs = nExtensorMU;
            result.muapWaveforms = {};
            result.firingRates = firingRates;
            result.firingRateCV = firingRateCV;
            result.sil = zeros(nTotalMU, 1);
            result.pnr = zeros(nTotalMU, 1);
            result.decompTime = toc(tStart);

            obj.IsRunning = false;
            obj.Progress = 100;

            fprintf('[分解服务] Python分解完成! 屈肌:%dMU 伸肌:%dMU 总:%dMU 用时:%.1fs\n', ...
                nFlexorMU, nExtensorMU, nTotalMU, result.decompTime);
        end

        function cancel(obj)
            obj.IsRunning = false;
            obj.Progress = 0;
        end
    end

    methods (Static)
        function muapResults = computeMuap(EMG, spikeTrain, windowSize)
            % 计算MUAP波形 (基于STA + IQR通道筛选)
            %
            % INPUT:
            %   EMG        - (64, N) 原始EMG信号
            %   spikeTrain - (nMU, N) 二值发放矩阵
            %   windowSize -  STA窗口大小 (默认60 → 61个采样点)
            %
            % OUTPUT:
            %   muapResults - {nMU x 1} cell array of structs
            %       .MUAP     - (64, windowSize+1) 波形矩阵
            %       .channels - IQR筛选的显著通道 [通道号, 峰值幅值]

            if nargin < 3, windowSize = 60; end

            % 64通道网格重映射 (从采集顺序到物理电极网格布局)
            channelMap = [34, 31, 32, 29, 30, 27, 28, 25, ...
                          17, 18, 21, 22, 19, 24, 23, 26, ...
                          20, 15, 16, 13, 14, 11, 12,  9, ...
                           1,  4,  3,  6,  5,  8,  7, 10, ...
                           2, 63, 64, 61, 62, 59, 60, 57, ...
                          50, 51, 52, 54, 53, 56, 55, 58, ...
                          49, 45, 48, 47, 46, 43, 44, 41, ...
                          33, 36, 35, 38, 37, 40, 39, 42];

            % 对齐采样点数
            nEMGSamples = size(EMG, 2);
            nSTSamples = size(spikeTrain, 2);
            nSamples = min(nEMGSamples, nSTSamples);

            EMG_aligned = EMG(:, 1:nSamples);
            ST_aligned = spikeTrain(:, 1:nSamples);

            % 通道重映射
            EMG_remapped = EMG_aligned(channelMap, :);

            % 调用MUAP_IQR计算
            muapResults = MUAP_IQR(EMG_remapped, ST_aligned, windowSize);
        end
    end
end
