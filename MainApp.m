classdef MainApp < handle
    % MainApp - 肌电慧控主应用类
    %   单模式五Tab界面: 数据采集 | 肌电分解 | 双输出预测 | 康复评估 | 数据管理

    %% ---- 数据总线属性 (各模块共享) ----
    properties (Access = public)
        % 当前患者和会话
        CurrentSubject   string = ""   % 当前被试编号（例如 "S01"）
        CurrentPatient      models.PatientInfo
        CurrentSession      models.SessionData

        % 原始数据
        RawEmgData          double          % (128, N) 原始肌电数据
        FlexorEMG           double          % (64, N) 屈肌侧EMG
        ExtensorEMG         double          % (64, N) 伸肌侧EMG
        Fs                  double = 2000   % 采样率
        GroundTruthAngle    double          % (1, N) 真实角度
        GroundTruthForce    double          % (1, N) 真实力

        % 文件路径
        FlexorEMGPath       string = ""
        ExtensorEMGPath     string = ""
        FlexorTemplatePath  string = ""
        ExtensorTemplatePath string = ""
        ModelPath           string = ""     % net.mat 模型路径

        % 分解结果
        SpikeTrainMatrix    double          % (NMU, N) 二值发放矩阵
        NMUs                double = 0      % 运动单位总数
        NFlexorMUs          double = 0      % 屈肌MU数
        NExtensorMUs        double = 0      % 伸肌MU数
        MuapWaveforms       cell            % MUAP波形
        FlexorMuapWaveforms cell            % 屈肌侧MUAP波形
        ExtensorMuapWaveforms cell          % 伸肌侧MUAP波形
        FiringRates         double          % (NMU, 1) 平均放电率
        FiringRateCV        double          % (NMU, 1) 放电率变异系数
        DecompQuality       struct          % SIL, PNR

        % 预测结果
        FeatureMatrix       double          % (nWindows, NMU) 特征矩阵
        TimeVector          double          % (nWindows, 1) 时间向量
        PredictedAngle      double          % (nWindows, 1) 预测角度
        PredictedForce      double          % (nWindows, 1) 预测力
        PredictionMetrics   struct          % RMSE, MAE, R2, CC

        % 评估结果
        AssessmentResults   models.AssessmentResult

        % 状态
        IsRecording         logical = false

        CurrentAction   string = "G01"   % 当前动作（G01~G04）
    end

    properties (SetAccess = private, GetAccess = public)
        ReturnToLogin   logical = false
    end

    %% ---- UI组件属性 ----
    properties (Access = private)
        UIFigure            matlab.ui.Figure
        StatusLabel_Mode
        StatusLabel_Recording
        StatusLabel_Clock
        ClockTimer          timer
        TabGroup            matlab.ui.container.TabGroup
    end

    properties (Access = public)
        % Tab控制器实例
        AcquisitionTabObj
        DecompositionTabObj
        PredictionTabObj
        AssessmentTabObj
        DataManagementTabObj
        Mode                string = "model_validation"
    end

    %% ---- 生命周期 ----
    methods
        function obj = MainApp(mode)
            if nargin < 1
                mode = "model_validation";
            end
            obj.Mode = mode;
            obj.CurrentPatient = models.PatientInfo();
            obj.CurrentSession = models.SessionData();
        end

        function launch(obj)
            obj.buildUI();
            obj.updateStatusBar();
            obj.updateClock();
        end

        function fig = getFigure(obj)
            fig = obj.UIFigure;
        end
    end

    %% ---- UI构建 ----
    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            screenSize = get(0, 'ScreenSize');
            x = max(1, (screenSize(3) - AppConstants.WINDOW_WIDTH) / 2);
            y = max(1, (screenSize(4) - AppConstants.WINDOW_HEIGHT) / 2);

            if obj.Mode == "rehab_assessment"
                windowTitle = '肌电慧控 - 康复评估系统';
            else
                windowTitle = '肌电慧控 - 模型验证系统';
            end

            obj.UIFigure = uifigure(...
                'Name', windowTitle, ...
                'Position', [x, y, AppConstants.WINDOW_WIDTH, AppConstants.WINDOW_HEIGHT], ...
                'Color', AppConstants.COLOR_BG, ...
                'Resize', 'on', ...
                'CloseRequestFcn', @(~,~) obj.onClose());

            mainGrid = uigridlayout(obj.UIFigure, [2, 1], ...
                'RowHeight', {AppConstants.STATUS_BAR_HEIGHT, '1x'}, ...
                'Padding', [0, 0, 0, 0], ...
                'RowSpacing', 0);

            obj.buildStatusBar(mainGrid);
            obj.buildTabGroup(mainGrid);
        end

        function buildStatusBar(obj, parentGrid)
            import config.AppConstants

            statusGrid = uigridlayout(parentGrid, [1, 6], ...
                'BackgroundColor', [0.15 0.15 0.15], ...
                'Padding', [10, 2, 10, 2], ...
                'ColumnWidth', {'fit', 'fit', 'fit', 'fit', '1x', 'fit'});

            uibutton(statusGrid, ...
                'Text', '← 返回登录', ...
                'FontSize', AppConstants.FONT_SIZE_SMALL, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontColor', [0.8 0.8 0.8], ...
                'BackgroundColor', [0.25 0.25 0.25], ...
                'ButtonPushedFcn', @(~,~) obj.onReturnToLogin());

            obj.StatusLabel_Mode = uilabel(statusGrid, ...
                'Text', '肌电慧控 v1.0', ...
                'FontColor', [1 1 1], ...
                'FontWeight', 'bold', ...
                'FontSize', AppConstants.FONT_SIZE_SMALL, ...
                'FontName', AppConstants.FONT_NAME);

            obj.StatusLabel_Recording = uilabel(statusGrid, ...
                'Text', '', ...
                'FontColor', [1 0.4 0.4], ...
                'FontSize', AppConstants.FONT_SIZE_SMALL, ...
                'FontName', AppConstants.FONT_NAME);

            uilabel(statusGrid, 'Text', '', 'FontSize', 1);

            uilabel(statusGrid, 'Text', '', 'FontSize', 1);

            obj.StatusLabel_Clock = uilabel(statusGrid, ...
                'Text', '', ...
                'FontColor', [0.7 0.7 0.7], ...
                'FontSize', AppConstants.FONT_SIZE_SMALL, ...
                'FontName', AppConstants.FONT_NAME, ...
                'HorizontalAlignment', 'right');
        end

        function buildTabGroup(obj, parentGrid)
            import config.AppConstants

            obj.TabGroup = uitabgroup(parentGrid, ...
                'SelectionChangedFcn', @(~, evt) obj.onTabChanged(evt));

            % 核心三Tab（两个系统都包含）
            tab1 = uitab(obj.TabGroup, 'Title', '数据采集');
            tab2 = uitab(obj.TabGroup, 'Title', '肌电分解');
            tab3 = uitab(obj.TabGroup, 'Title', '双输出预测');

            obj.AcquisitionTabObj = ui.tabs.AcquisitionTab(tab1, obj);
            obj.DecompositionTabObj = ui.tabs.DecompositionTab(tab2, obj);
            obj.PredictionTabObj = ui.tabs.PredictionTab(tab3, obj);

            % 康复评估系统额外包含评估和管理两个Tab
            if obj.Mode == "rehab_assessment"
                tab4 = uitab(obj.TabGroup, 'Title', '康复评估');
                tab5 = uitab(obj.TabGroup, 'Title', '数据管理');

                obj.AssessmentTabObj = ui.tabs.AssessmentTab(tab4, obj);
                obj.DataManagementTabObj = ui.tabs.DataManagementTab(tab5, obj);
            end
        end
    end

    %% ---- 状态栏更新 ----
    methods (Access = public)
        function updateStatusBar(obj)
            if obj.IsRecording
                obj.StatusLabel_Recording.Text = '● 录制中...';
            else
                obj.StatusLabel_Recording.Text = '';
            end
        end

        function updateClock(obj)
            obj.StatusLabel_Clock.Text = datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS');
            if ~isempty(obj.ClockTimer) && isvalid(obj.ClockTimer)
                stop(obj.ClockTimer);
                delete(obj.ClockTimer);
            end
            obj.ClockTimer = timer('Period', 1, 'ExecutionMode', 'fixedRate', ...
                'TimerFcn', @(~,~) obj.clockTick(), ...
                'ObjectVisibility', 'off');
            start(obj.ClockTimer);
        end

        function clockTick(obj)
            if isvalid(obj) && isvalid(obj.StatusLabel_Clock)
                obj.StatusLabel_Clock.Text = datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS');
            end
        end
    end

    %% ---- Tab切换 ----
    methods (Access = private)
        function onTabChanged(obj, evt)
            tabTitle = evt.NewValue.Title;
            fprintf('[肌电慧控] 切换到: %s\n', tabTitle);
            % 当切换到“肌电分解”页时，刷新该页面的 EMG 状态
            if strcmp(tabTitle, '肌电分解') && ~isempty(obj.DecompositionTabObj)
                obj.DecompositionTabObj.updateEMGStatus();
            end
            if strcmp(tabTitle, '双输出预测') && ~isempty(obj.PredictionTabObj)
                obj.PredictionTabObj.refresh();
            end
        end
    end

    %% ---- 数据管理公共方法 ----
    methods (Access = public)
        function setRecording(obj, isRecording)
            obj.IsRecording = isRecording;
            obj.updateStatusBar();
        end

        function clearData(obj)
            obj.RawEmgData = [];
            obj.GroundTruthAngle = [];
            obj.GroundTruthForce = [];
            obj.SpikeTrainMatrix = [];
            obj.NMUs = 0;
            obj.NFlexorMUs = 0;
            obj.NExtensorMUs = 0;
            obj.FeatureMatrix = [];
            obj.TimeVector = [];
            obj.PredictedAngle = [];
            obj.PredictedForce = [];
            obj.PredictionMetrics = struct();
            obj.CurrentSession = models.SessionData();
        end

        function log(obj, message, level)
            if nargin < 3, level = 'INFO'; end
            timestamp = datestr(datetime('now'), 'HH:MM:SS');
            fprintf('[%s] [%s] %s\n', timestamp, level, message);
        end
    end

    %% ---- 关闭处理 ----
    methods (Access = private)
        function onReturnToLogin(obj)
            obj.ReturnToLogin = true;
            if ~isempty(obj.ClockTimer) && isvalid(obj.ClockTimer)
                stop(obj.ClockTimer);
                delete(obj.ClockTimer);
            end
            if isvalid(obj.UIFigure)
                delete(obj.UIFigure);
            end
        end

        function onClose(obj)
            obj.ReturnToLogin = false;
            if ~isempty(obj.ClockTimer) && isvalid(obj.ClockTimer)
                stop(obj.ClockTimer);
                delete(obj.ClockTimer);
            end
            if isvalid(obj.UIFigure)
                delete(obj.UIFigure);
            end
        end
    end
end
