classdef PredictionTab < handle
    % PredictionTab - 双输出角度+力预测Tab（左右对称布局）

    properties (Access = private)
        Parent
        MainApp
        FeatureService
        PredictionService

        % 顶部控件
        UISubjectLabel          % 被试/动作
        UIModelStatusLabel      % 模型状态
        UITemplateStatusLabel   % 模板状态
        UIExtractBtn
        UIPredictBtn

        % 角度面板组件
        AngleAxes
        AngleErrorAxes
        AngleMetricsGrid

        % 力面板组件
        ForceAxes
        ForceErrorAxes
        ForceMetricsGrid

        % 存储中间结果
        FeatureMatrix double = []
        TimeVector double = []
        PredictedAngle double = []
        PredictedForce double = []
        IsFeatureReady logical = false

        % 特征提取与预测参数
        SeqLen double = 25          % 序列长度 (与训练一致)
        FeatureNormParams struct    % 特征归一化参数
        AlignedAngle double = []    % 对齐后的角度标签
        AlignedForce double = []    % 对齐后的力标签

        % 指标标签句柄
        angleRMSE, angleMAE, angleR2, angleCC
        forceRMSE, forceMAE, forceR2, forceCC
    end

    methods
        function obj = PredictionTab(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.FeatureService = services.FeatureExtractionService();
            obj.PredictionService = services.PredictionService();
            obj.buildUI();
            obj.autoLoadModel();
            obj.updateTemplateStatus();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants
            delete(obj.Parent.Children);

            mainGrid = uigridlayout(obj.Parent, [2, 1], ...
                'RowHeight', {'fit', '1x'}, ...
                'Padding', [AppConstants.PADDING, AppConstants.PADDING, ...
                           AppConstants.PADDING, AppConstants.PADDING], ...
                'RowSpacing', AppConstants.ROW_SPACING);

            % 顶部配置面板
            topPanel = uipanel(mainGrid, 'Title', '模型与特征配置', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG);
            obj.buildTopPanel(topPanel);

            % 下方左右预测面板
            bottomGrid = uigridlayout(mainGrid, [1, 2], ...
                'ColumnWidth', {'1x', '1x'}, ...
                'Padding', [0,0,0,0], 'ColumnSpacing', AppConstants.COL_SPACING);

            leftPanel = uipanel(bottomGrid, 'Title', '角度预测', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG);
            obj.buildPredictionPanel(leftPanel, 'angle');

            rightPanel = uipanel(bottomGrid, 'Title', '力预测', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG);
            obj.buildPredictionPanel(rightPanel, 'force');
        end

        function buildTopPanel(obj, parent)
            import config.AppConstants
            topGrid = uigridlayout(parent, [1, 2], ...
                'ColumnWidth', {'1x', 'fit'}, ...
                'Padding', [10, 8, 10, 8], 'ColumnSpacing', 20);

            % 左侧文本信息
            leftGrid = uigridlayout(topGrid, [3, 2], ...
                'RowHeight', repmat({'fit'},1,3), ...
                'ColumnWidth', {'fit', '1x'}, ...
                'Padding', [0,0,0,0], 'RowSpacing', 5);

            uilabel(leftGrid, 'Text', '被试/动作:', 'FontName', AppConstants.FONT_NAME, 'FontWeight', 'bold');
            obj.UISubjectLabel = uilabel(leftGrid, 'Text', '--', ...
                'FontName', AppConstants.FONT_NAME, 'FontColor', AppConstants.COLOR_PRIMARY);

            uilabel(leftGrid, 'Text', '模型状态:', 'FontName', AppConstants.FONT_NAME, 'FontWeight', 'bold');
            obj.UIModelStatusLabel = uilabel(leftGrid, 'Text', '未加载', ...
                'FontName', AppConstants.FONT_NAME, 'FontColor', AppConstants.COLOR_DANGER);

            uilabel(leftGrid, 'Text', '模板状态:', 'FontName', AppConstants.FONT_NAME, 'FontWeight', 'bold');
            obj.UITemplateStatusLabel = uilabel(leftGrid, 'Text', '待检测', ...
                'FontName', AppConstants.FONT_NAME, 'FontColor', AppConstants.COLOR_DANGER);

            % 右侧按钮
            rightGrid = uigridlayout(topGrid, [2, 1], ...
                'RowHeight', {'fit', 'fit'}, ...
                'Padding', [0,0,0,0], 'RowSpacing', 10);

            obj.UIExtractBtn = uibutton(rightGrid, 'Text', '提取特征', ...
                'BackgroundColor', AppConstants.COLOR_PRIMARY, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) obj.extractFeatures());

            obj.UIPredictBtn = uibutton(rightGrid, 'Text', '开始预测', ...
                'BackgroundColor', AppConstants.COLOR_SECONDARY, 'FontColor', [1 1 1], 'FontWeight', 'bold', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.runPrediction());
        end

        function buildPredictionPanel(obj, parent, type)
            import config.AppConstants

            grid = uigridlayout(parent, [3, 1], ...
                'RowHeight', {'1x', '1x', 'fit'}, ...
                'Padding', [5,5,5,5], 'RowSpacing', 8);

            axCurve = uiaxes(grid);
            axCurve.XLabel.String = '时间 (s)';
            if strcmp(type, 'angle')
                axCurve.YLabel.String = '角度 (°)';
                axCurve.Title.String = '角度预测曲线';
            else
                axCurve.YLabel.String = '力 (%MVC)';
                axCurve.Title.String = '力预测曲线';
            end
            axCurve.XGrid = 'on';
            axCurve.YGrid = 'on';
            hold(axCurve, 'on');

            axError = uiaxes(grid);
            axError.XLabel.String = '时间 (s)';
            axError.YLabel.String = '误差';
            axError.Title.String = '预测误差';
            axError.XGrid = 'on';
            axError.YGrid = 'on';
            hold(axError, 'on');

            metricsPanel = uipanel(grid, 'Title', '性能指标', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG);
            metGrid = uigridlayout(metricsPanel, [2, 2], ...
                'Padding', [8,8,8,8], 'RowSpacing', 5, 'ColumnSpacing', 10);

            uilabel(metGrid, 'Text', 'RMSE:', 'FontWeight', 'bold');
            rmseLabel = uilabel(metGrid, 'Text', '--');
            uilabel(metGrid, 'Text', 'MAE:', 'FontWeight', 'bold');
            maeLabel = uilabel(metGrid, 'Text', '--');
            uilabel(metGrid, 'Text', 'R²:', 'FontWeight', 'bold');
            r2Label = uilabel(metGrid, 'Text', '--');
            uilabel(metGrid, 'Text', 'CC:', 'FontWeight', 'bold');
            ccLabel = uilabel(metGrid, 'Text', '--');

            if strcmp(type, 'angle')
                obj.AngleAxes = axCurve;
                obj.AngleErrorAxes = axError;
                obj.AngleMetricsGrid = metGrid;
                obj.angleRMSE = rmseLabel;
                obj.angleMAE = maeLabel;
                obj.angleR2 = r2Label;
                obj.angleCC = ccLabel;
            else
                obj.ForceAxes = axCurve;
                obj.ForceErrorAxes = axError;
                obj.ForceMetricsGrid = metGrid;
                obj.forceRMSE = rmseLabel;
                obj.forceMAE = maeLabel;
                obj.forceR2 = r2Label;
                obj.forceCC = ccLabel;
            end
        end

        % ---------- 自动模型加载 ----------
        function autoLoadModel(obj)

            subject = obj.MainApp.CurrentSubject;
            action = obj.MainApp.CurrentAction;
            
            if isempty(subject) || isempty(action)
                obj.UIModelStatusLabel.Text = '未识别被试/动作';
                obj.UIModelStatusLabel.FontColor = config.AppConstants.COLOR_DANGER;
                return;
            end
            obj.UISubjectLabel.Text = sprintf('%s / %s', subject, action);

            templateRoot = config.AppConstants.TEMPLATE_ROOT;
            modelPath = fullfile(templateRoot, subject, action, 'net.mat');
            if ~exist(modelPath, 'file')
                obj.UIModelStatusLabel.Text = '模型文件不存在';
                obj.UIModelStatusLabel.FontColor = config.AppConstants.COLOR_DANGER;
                return;
            end

            [success, msg] = obj.PredictionService.loadModel(modelPath);
            if success
                obj.UIModelStatusLabel.Text = sprintf('已加载: %s', subject);
                obj.UIModelStatusLabel.FontColor = config.AppConstants.COLOR_SIG_GOOD;
                obj.appendLog(sprintf('自动加载模型成功: %s', modelPath));
            else
                obj.UIModelStatusLabel.Text = '加载失败';
                obj.UIModelStatusLabel.FontColor = config.AppConstants.COLOR_DANGER;
                obj.appendLog(sprintf('模型加载失败: %s', msg));
            end
            fprintf('TEMPLATE_ROOT = %s\n', config.AppConstants.TEMPLATE_ROOT);
            fprintf('subject = %s\n', subject);
            fprintf('action = %s\n', action);
            fprintf('modelPath = %s\n', modelPath);
        end

        function updateTemplateStatus(obj)
            subject = obj.MainApp.CurrentSubject;
            action = obj.MainApp.CurrentAction;
            if isempty(subject) || isempty(action)
                obj.UITemplateStatusLabel.Text = '未识别';
                obj.UITemplateStatusLabel.FontColor = config.AppConstants.COLOR_DANGER;
                return;
            end
            templateRoot = config.AppConstants.TEMPLATE_ROOT;
            actionDir = fullfile(templateRoot, subject, action);
            if exist(actionDir, 'dir')
                obj.UITemplateStatusLabel.Text = '齐全';
                obj.UITemplateStatusLabel.FontColor = config.AppConstants.COLOR_SIG_GOOD;
            else
                obj.UITemplateStatusLabel.Text = '目录缺失';
                obj.UITemplateStatusLabel.FontColor = config.AppConstants.COLOR_DANGER;
            end
        end

        % ---------- 特征提取 ----------
        function extractFeatures(obj)
            % 完整ST特征提取管线 (匹配训练脚本 step6):
            %   累计脉冲计数 → sqrt变换 → 通道归一化 → 标签对齐

            spikeTrain = obj.MainApp.SpikeTrainMatrix;
            if isempty(spikeTrain)
                uialert(obj.Parent, '请先进行肌电分解，或加载已分解数据', '无发放序列', 'Icon', 'warning');
                return;
            end

            trueAngle = obj.MainApp.GroundTruthAngle;
            trueForce = obj.MainApp.GroundTruthForce;
            if isempty(trueAngle) || isempty(trueForce)
                uialert(obj.Parent, '请先在数据采集页加载角度和力标签数据', '缺少标签', 'Icon', 'warning');
                return;
            end

            obj.appendLog('===== 开始特征提取 =====');
            try
                windowMs = 200;
                stepMs = 100;
                fs = obj.MainApp.Fs;
                if isempty(fs) || fs <= 0, fs = 2000; end

                obj.FeatureService.WindowMs = windowMs;
                obj.FeatureService.StepMs = stepMs;
                obj.FeatureService.Fs = fs;
                obj.FeatureService.ApplySqrtTransform = true;

                % Step 1: 累计脉冲计数
                [rawFeatures, timeVector] = obj.FeatureService.extractCumulativeSpikeCount(spikeTrain);
                nWindows = size(rawFeatures, 1);
                nMU = size(rawFeatures, 2);
                obj.appendLog(sprintf('Step1 累计脉冲计数: %d窗 × %dMU', nWindows, nMU));

                % Step 2: sqrt变换
                featureMatrix = sqrt(rawFeatures);
                obj.appendLog('Step2 sqrt变换完成');

                % Step 3: 通道归一化 (优先用模型自带参数, 否则在线计算)
                if ~isempty(obj.PredictionService.NormParams) ...
                        && isfield(obj.PredictionService.NormParams, 'ch_min') ...
                        && length(obj.PredictionService.NormParams.ch_min) == nMU
                    normParams = obj.PredictionService.NormParams;
                    featureMatrix = obj.FeatureService.applyNormParams(featureMatrix, normParams);
                    obj.appendLog('Step3 归一化 (使用模型参数)');
                else
                    [featureMatrix, normParams] = obj.FeatureService.normalizePerChannel(featureMatrix);
                    obj.appendLog('Step3 归一化 (在线计算, 建议保存norm_params.mat到模型目录)');
                end
                obj.FeatureNormParams = normParams;

                % Step 4: 标签对齐 — 角度和力降采样到特征窗数
                obj.AlignedAngle = obj.downsampleToMatch(trueAngle, nWindows);
                obj.AlignedForce = obj.downsampleToMatch(trueForce, nWindows);

                obj.FeatureMatrix = featureMatrix;
                obj.TimeVector = timeVector;
                obj.IsFeatureReady = true;
                obj.UIPredictBtn.Enable = 'on';

                obj.appendLog(sprintf('特征提取成功: %d窗 × %dMU (sqrt+归一化)', nWindows, nMU));
                obj.appendLog(sprintf('标签对齐: 角度%d点→%d窗, 力%d点→%d窗', ...
                    length(trueAngle), nWindows, length(trueForce), nWindows));
            catch e
                obj.appendLog(sprintf('特征提取失败: %s', e.message));
                obj.IsFeatureReady = false;
                obj.UIPredictBtn.Enable = 'off';
                uialert(obj.Parent, e.message, '特征提取错误', 'Icon', 'error');
            end
            obj.appendLog('===== 特征提取结束 =====');
        end

        % ---------- 预测主流程 ----------
        function runPrediction(obj)
            if ~obj.IsFeatureReady
                uialert(obj.Parent, '请先提取特征', '特征未就绪', 'Icon', 'warning');
                return;
            end
            if ~obj.PredictionService.IsLoaded
                obj.autoLoadModel();
                if ~obj.PredictionService.IsLoaded
                    uialert(obj.Parent, '模型未加载，请检查模板文件夹', '模型缺失', 'Icon', 'warning');
                    return;
                end
            end

            obj.appendLog('===== 开始预测 =====');
            tTotal = tic;
            try
                seqLen = obj.SeqLen;
                if ~isempty(obj.PredictionService.SeqLen)
                    seqLen = obj.PredictionService.SeqLen;
                end

                nWindows = size(obj.FeatureMatrix, 1);
                if nWindows < seqLen + 1
                    uialert(obj.Parent, ...
                        sprintf('特征窗数(%d)不足, 至少需要%d个窗 (seq_len=%d)', nWindows, seqLen+1, seqLen), ...
                        '数据不足', 'Icon', 'warning');
                    return;
                end

                % 序列预测: 输入(c×seqLen)序列, 输出[angle, force]
                [predAngle, predForce] = obj.PredictionService.predict(obj.FeatureMatrix, seqLen);
                obj.PredictedAngle = predAngle;
                obj.PredictedForce = predForce;

                % 标签对齐: 序列预测输出对应第seqLen个窗之后的标签
                trueAngleDS = obj.AlignedAngle(seqLen:end);
                trueForceDS = obj.AlignedForce(seqLen:end);

                % 对齐时间向量
                tPred = obj.TimeVector(seqLen:end);

                % 计算真实指标
                angleMetrics = utils.AngleMetrics.computeAll(trueAngleDS, predAngle, '角度');
                forceMetrics = utils.AngleMetrics.computeAll(trueForceDS, predForce, '力');

                obj.updatePlotAndMetrics('angle', trueAngleDS, predAngle, angleMetrics, tPred);
                obj.updatePlotAndMetrics('force', trueForceDS, predForce, forceMetrics, tPred);

                elapsed = toc(tTotal);
                obj.appendLog(sprintf('预测完成, 用时 %.2fs', elapsed));
                obj.appendLog(sprintf('角度: RMSE=%.2f, MAE=%.2f, R²=%.3f, CC=%.3f', ...
                    angleMetrics.RMSE, angleMetrics.MAE, angleMetrics.R2, angleMetrics.CC));
                obj.appendLog(sprintf('力:   RMSE=%.2f, MAE=%.2f, R²=%.3f, CC=%.3f', ...
                    forceMetrics.RMSE, forceMetrics.MAE, forceMetrics.R2, forceMetrics.CC));
                obj.appendLog('===== 预测结束 =====');
            catch e
                obj.appendLog(sprintf('预测失败: %s', e.message));
                uialert(obj.Parent, e.message, '预测错误', 'Icon', 'error');
            end
        end

        function updatePlotAndMetrics(obj, type, trueVals, predVals, metrics, tPred)
            if nargin < 6, tPred = []; end

            if strcmp(type, 'angle')
                axCurve = obj.AngleAxes;
                axError = obj.AngleErrorAxes;
                rmseLabel = obj.angleRMSE;
                maeLabel  = obj.angleMAE;
                r2Label   = obj.angleR2;
                ccLabel   = obj.angleCC;
            else
                axCurve = obj.ForceAxes;
                axError = obj.ForceErrorAxes;
                rmseLabel = obj.forceRMSE;
                maeLabel  = obj.forceMAE;
                r2Label   = obj.forceR2;
                ccLabel   = obj.forceCC;
            end

            if ~isempty(tPred)
                t = tPred;
            else
                t = obj.TimeVector;
                if isempty(t)
                    t = (1:length(predVals))';
                end
            end

            cla(axCurve);
            hold(axCurve, 'on');
            plot(axCurve, t, trueVals, 'b-', 'LineWidth', 1.5, 'DisplayName', '真实值');
            plot(axCurve, t, predVals, 'r--', 'LineWidth', 1.5, 'DisplayName', '预测值');
            legend(axCurve, 'show', 'Location', 'best');
            xlabel(axCurve, '时间 (s)');
            if strcmp(type, 'angle')
                ylabel(axCurve, '角度 (°)');
                title(axCurve, '角度预测曲线');
            else
                ylabel(axCurve, '力 (%MVC)');
                title(axCurve, '力预测曲线');
            end
            axCurve.XGrid = 'on';
            axCurve.YGrid = 'on';
            hold(axCurve, 'off');

            cla(axError);
            errorVals = trueVals - predVals;
            plot(axError, t, errorVals, 'k-', 'LineWidth', 1);
            xlabel(axError, '时间 (s)');
            ylabel(axError, '误差');
            title(axError, '预测误差');
            axError.XGrid = 'on';
            axError.YGrid = 'on';

            rmseLabel.Text = sprintf('%.2f', metrics.RMSE);
            maeLabel.Text  = sprintf('%.2f', metrics.MAE);
            r2Label.Text   = sprintf('%.3f', metrics.R2);
            ccLabel.Text   = sprintf('%.3f', metrics.CC);
        end

        function ds = downsampleToMatch(~, original, targetLen)
            if isempty(original)
                ds = zeros(targetLen, 1);
                return;
            end
            original = original(:);
            nOrig = length(original);
            if nOrig <= targetLen
                ds = interp1(1:nOrig, original, linspace(1, nOrig, targetLen), 'linear');
            else
                indices = round(linspace(1, nOrig, targetLen));
                ds = original(indices);
            end
        end

        function appendLog(obj, msg)
            fprintf('[%s] %s\n', datestr(now, 'HH:MM:SS'), msg);
        end
    end
    methods (Access = public)
        function refresh(obj)
            % 外部调用此方法，强制重新加载被试信息和模型
            obj.autoLoadModel();
            obj.updateTemplateStatus();
        end
    end
end