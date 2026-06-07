classdef AcquisitionTab < handle
    % AcquisitionTab - 数据采集Tab (离线模式)
    %   加载: 屈肌EMG, 伸肌EMG, 角度标签(angle_raw), 力标签(force_clean)

    properties (Access = private)
        Parent
        MainApp
        PreviewAxes        % [屈肌轴, 伸肌轴]

        % 状态标签
        UIFlexorEMGStatus
        UIExtensorEMGStatus
        UIAngleStatus
        UIForceStatus
        UIAllLoadedLamp

        % 预览按钮
        UIPreviewBtn
    end

    methods
        function obj = AcquisitionTab(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.buildUI();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            delete(obj.Parent.Children);

            mainGrid = uigridlayout(obj.Parent, [3, 1], ...
                'RowHeight', {'fit', 'fit', '1x'}, ...
                'Padding', [AppConstants.PADDING, AppConstants.PADDING, ...
                           AppConstants.PADDING, AppConstants.PADDING], ...
                'RowSpacing', AppConstants.ROW_SPACING);

            % ---- Row 1: 标题栏 ----
            titleGrid = uigridlayout(mainGrid, [1, 3], ...
                'RowHeight', {40}, ...
                'ColumnWidth', {'fit', '1x', 'fit'}, ...
                'Padding', [0, 0, 0, 0]);

            uilabel(titleGrid, 'Text', '数据采集 - 加载EMG信号与真实标签', ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold', ...
                'FontColor', AppConstants.COLOR_PRIMARY);

            obj.UIAllLoadedLamp = uilamp(titleGrid, ...
                'Color', [0.7 0.7 0.7]);

            % ---- Row 2: 文件加载面板 ----
            loadPanel = uipanel(mainGrid, ...
                'Title', '数据文件加载', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildLoadPanel(loadPanel);

            % ---- Row 3: 波形预览（自适应高度）----
            wavePanel = uipanel(mainGrid, 'Title', '信号预览 (加载EMG后可预览)', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);

            previewGrid = uigridlayout(wavePanel, [2, 1], ...
                'RowHeight', {'1x', '1x'}, ...
                'Padding', [5, 5, 5, 5]);

            axFlexor = uiaxes(previewGrid);
            axFlexor.Layout.Row = 1;
            ylabel(axFlexor, '屈肌CH1 (\muV)', 'FontName', AppConstants.FONT_NAME);
            title(axFlexor, '屈肌侧 EMG 通道1', 'FontName', AppConstants.FONT_NAME);
            grid(axFlexor, 'on');
            axFlexor.XLabel.String = '时间 (s)';
            axFlexor.XLabel.FontName = AppConstants.FONT_NAME;

            axExtensor = uiaxes(previewGrid);
            axExtensor.Layout.Row = 2;
            ylabel(axExtensor, '伸肌CH1 (\muV)', 'FontName', AppConstants.FONT_NAME);
            title(axExtensor, '伸肌侧 EMG 通道1', 'FontName', AppConstants.FONT_NAME);
            grid(axExtensor, 'on');
            axExtensor.XLabel.String = '时间 (s)';
            axExtensor.XLabel.FontName = AppConstants.FONT_NAME;

            obj.PreviewAxes = [axFlexor, axExtensor];
        end

        function buildLoadPanel(obj, parent)
            import config.AppConstants

            offGrid = uigridlayout(parent, [5, 3], ...
                'RowHeight', repmat({32}, 1, 5), ...
                'ColumnWidth', {'fit', '1x', 'fit'}, ...
                'Padding', [12, 8, 12, 8], ...
                'RowSpacing', 5, 'ColumnSpacing', 8);

            fnt = AppConstants.FONT_NAME;
            red = AppConstants.COLOR_DANGER;

            % --- 1. 屈肌EMG (dev0) ---
            uilabel(offGrid, 'Text', '1. 屈肌EMG:', 'FontName', fnt, 'FontWeight', 'bold');
            obj.UIFlexorEMGStatus = uilabel(offGrid, 'Text', '未加载', ...
                'FontName', fnt, 'FontColor', red);
            uibutton(offGrid, 'Text', '选择文件...', 'FontName', fnt, ...
                'ButtonPushedFcn', @(~,~) obj.selectEMG('flexor'));

            % --- 2. 伸肌EMG (dev1) ---
            uilabel(offGrid, 'Text', '2. 伸肌EMG:', 'FontName', fnt, 'FontWeight', 'bold');
            obj.UIExtensorEMGStatus = uilabel(offGrid, 'Text', '未加载', ...
                'FontName', fnt, 'FontColor', red);
            uibutton(offGrid, 'Text', '选择文件...', 'FontName', fnt, ...
                'ButtonPushedFcn', @(~,~) obj.selectEMG('extensor'));

            % --- 3. 角度数据 ---
            uilabel(offGrid, 'Text', '3. 角度数据:', 'FontName', fnt, 'FontWeight', 'bold');
            obj.UIAngleStatus = uilabel(offGrid, 'Text', '未加载', ...
                'FontName', fnt, 'FontColor', red);
            uibutton(offGrid, 'Text', '选择文件...', 'FontName', fnt, ...
                'ButtonPushedFcn', @(~,~) obj.selectGroundTruth('angle'));

            % --- 4. 力数据 ---
            uilabel(offGrid, 'Text', '4. 力数据:', 'FontName', fnt, 'FontWeight', 'bold');
            obj.UIForceStatus = uilabel(offGrid, 'Text', '未加载', ...
                'FontName', fnt, 'FontColor', red);
            uibutton(offGrid, 'Text', '选择文件...', 'FontName', fnt, ...
                'ButtonPushedFcn', @(~,~) obj.selectGroundTruth('force'));

            % --- 操作行 ---
            uibutton(offGrid, 'Text', '一键加载全部', ...
                'BackgroundColor', AppConstants.COLOR_PRIMARY, ...
                'FontColor', [1 1 1], 'FontWeight', 'bold', ...
                'FontName', fnt, ...
                'ButtonPushedFcn', @(~,~) obj.loadAllFiles());

            uilabel(offGrid, 'Text', '', 'FontName', fnt);

            obj.UIPreviewBtn = uibutton(offGrid, 'Text', '预览信号波形', ...
                'FontName', fnt, ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.previewSignals());
        end
    end

    %% ---- 数据加载核心方法 ----
    methods (Access = private)
        function EMG = extractEMGVariable(~, data)
            EMG = [];
            candidateVars = {'EMG', 'filtered_EMG', 'filtered_data', 'data', 'filtered_e', 'filtered_f'};
            for v = 1:length(candidateVars)
                if isfield(data, candidateVars{v})
                    EMG = data.(candidateVars{v});
                    break;
                end
            end
            if isempty(EMG)
                fn = fieldnames(data);
                for i = 1:length(fn)
                    tmp = data.(fn{i});
                    if isnumeric(tmp) && ismatrix(tmp) && min(size(tmp)) > 1
                        EMG = tmp;
                        break;
                    end
                end
            end
            if ~isempty(EMG) && size(EMG, 1) > size(EMG, 2)
                EMG = EMG';
            end
        end

        function labelData = extractLabelVariable(obj, data, labelType)
            % 根据类型优先提取特定变量名
            labelData = [];
            if strcmp(labelType, 'angle')
                if isfield(data, 'angle_raw')
                    labelData = data.angle_raw;
                elseif isfield(data, 'Angle')
                    labelData = data.Angle;
                end
            elseif strcmp(labelType, 'force')
                if isfield(data, 'force_clean')
                    labelData = data.force_clean;
                elseif isfield(data, 'Force')
                    labelData = data.Force;
                end
            end
            % 如果未找到，尝试自动识别第一个数值向量
            if isempty(labelData)
                fn = fieldnames(data);
                for i = 1:length(fn)
                    tmp = data.(fn{i});
                    if isnumeric(tmp) && isvector(tmp)
                        labelData = tmp(:)';
                        break;
                    end
                end
            end
        end

        function selectEMG(obj, side)
    sideLabel = obj.getSideLabel(side);
    [file, path] = uigetfile('*.mat', sprintf('选择%s侧EMG文件', sideLabel));
    if isequal(file, 0), return; end
    fullPath = fullfile(path, file);

    try
        loaded = load(fullPath);
        EMG = obj.extractEMGVariable(loaded);
        if isempty(EMG)
            uialert(obj.Parent, '文件中未找到EMG变量', '加载失败', 'Icon', 'error');
            return;
        end
        [nCh, nSamp] = size(EMG);
        if strcmp(side, 'flexor')
            obj.MainApp.FlexorEMG = EMG;
            obj.MainApp.FlexorEMGPath = fullPath;
            obj.UIFlexorEMGStatus.Text = sprintf('✓ %s (%dch x %d)', file, nCh, nSamp);
            obj.UIFlexorEMGStatus.FontColor = config.AppConstants.COLOR_SECONDARY;
            
            % ===== 添加以下两行：刷新预测页 =====
            if ~isempty(obj.MainApp.PredictionTabObj)
                obj.MainApp.PredictionTabObj.refresh();
            end
            % ===================================
        else
            obj.MainApp.ExtensorEMG = EMG;
            obj.MainApp.ExtensorEMGPath = fullPath;
            obj.UIExtensorEMGStatus.Text = sprintf('✓ %s (%dch x %d)', file, nCh, nSamp);
            obj.UIExtensorEMGStatus.FontColor = config.AppConstants.COLOR_SECONDARY;
        end
        obj.MainApp.log(sprintf('%s侧EMG已加载: %s', sideLabel, fullPath));
        obj.checkAllLoaded();
        obj.updatePreviewButtonState();
        fprintf('MainApp.FlexorEMGPath 已设置为: %s\n', obj.MainApp.FlexorEMGPath);
    catch e
        uialert(obj.Parent, sprintf('加载失败: %s', e.message), '错误', 'Icon', 'error');
    end
end

        function selectGroundTruth(obj, labelType)
            [file, path] = uigetfile({'*.mat;*.csv', '标签文件'}, ...
                sprintf('选择%s标签文件', labelType));
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);

            try
                [~, ~, ext] = fileparts(file);
                if strcmp(ext, '.csv')
                    data = readmatrix(fullPath);
                    data = data(:)';
                else
                    loaded = load(fullPath);
                    data = obj.extractLabelVariable(loaded, labelType);
                    if isempty(data)
                        uialert(obj.Parent, sprintf('未找到%s变量', labelType), '加载失败', 'Icon', 'error');
                        return;
                    end
                end
                data = data(:)';
                if strcmp(labelType, 'angle')
                    obj.MainApp.GroundTruthAngle = data;
                    obj.UIAngleStatus.Text = sprintf('✓ %s (%d点)', file, length(data));
                    obj.UIAngleStatus.FontColor = config.AppConstants.COLOR_SECONDARY;
                else
                    obj.MainApp.GroundTruthForce = data;
                    obj.UIForceStatus.Text = sprintf('✓ %s (%d点)', file, length(data));
                    obj.UIForceStatus.FontColor = config.AppConstants.COLOR_SECONDARY;
                end
                obj.MainApp.log(sprintf('真实%s标签已加载: %s (%d点)', labelType, fullPath, length(data)));
            catch e
                uialert(obj.Parent, sprintf('加载失败: %s', e.message), '错误', 'Icon', 'error');
            end
        end

        function loadAllFiles(obj)
    selPath = uigetdir(pwd, '选择包含所有数据文件的文件夹');
    if selPath == 0, return; end
    files = dir(fullfile(selPath, '*.mat'));
    % 清空现有
    obj.MainApp.FlexorEMG = [];
    obj.MainApp.ExtensorEMG = [];
    obj.MainApp.GroundTruthAngle = [];
    obj.MainApp.GroundTruthForce = [];
    obj.UIFlexorEMGStatus.Text = '未加载'; obj.UIFlexorEMGStatus.FontColor = config.AppConstants.COLOR_DANGER;
    obj.UIExtensorEMGStatus.Text = '未加载'; obj.UIExtensorEMGStatus.FontColor = config.AppConstants.COLOR_DANGER;
    obj.UIAngleStatus.Text = '未加载'; obj.UIAngleStatus.FontColor = config.AppConstants.COLOR_DANGER;
    obj.UIForceStatus.Text = '未加载'; obj.UIForceStatus.FontColor = config.AppConstants.COLOR_DANGER;

    for i = 1:length(files)
        fname = files(i).name;
        fullP = fullfile(selPath, fname);
        lowerName = lower(fname);
        if contains(lowerName, 'dev0') && ~contains(lowerName, 'ica') && ~contains(lowerName, 'template')
            obj.quickLoadEMG(fullP, 'flexor', fname);
            % ===== 添加刷新预测页 =====
            if ~isempty(obj.MainApp.PredictionTabObj)
                obj.MainApp.PredictionTabObj.refresh();
            end
            % ==========================
        elseif contains(lowerName, 'dev1') && ~contains(lowerName, 'ica') && ~contains(lowerName, 'template')
            obj.quickLoadEMG(fullP, 'extensor', fname);
        elseif contains(lowerName, 'angle')
            obj.quickLoadLabel(fullP, 'angle', fname);
        elseif contains(lowerName, 'force')
            obj.quickLoadLabel(fullP, 'force', fname);
        end
    end
    obj.checkAllLoaded();
    obj.updatePreviewButtonState();
    obj.MainApp.log('一键加载完成');
end

        function quickLoadEMG(obj, fullPath, side, fname)
            loaded = load(fullPath);
            EMG = obj.extractEMGVariable(loaded);
            if isempty(EMG), return; end
            [nCh, nSamp] = size(EMG);
            if strcmp(side, 'flexor')
                obj.MainApp.FlexorEMG = EMG;
                obj.MainApp.FlexorEMGPath = fullPath;
                obj.UIFlexorEMGStatus.Text = sprintf('✓ %s (%dch x %d)', fname, nCh, nSamp);
                obj.UIFlexorEMGStatus.FontColor = config.AppConstants.COLOR_SECONDARY;
            else
                obj.MainApp.ExtensorEMG = EMG;
                obj.MainApp.ExtensorEMGPath = fullPath;
                obj.UIExtensorEMGStatus.Text = sprintf('✓ %s (%dch x %d)', fname, nCh, nSamp);
                obj.UIExtensorEMGStatus.FontColor = config.AppConstants.COLOR_SECONDARY;
            end
        end

        function quickLoadLabel(obj, fullPath, labelType, fname)
            loaded = load(fullPath);
            data = obj.extractLabelVariable(loaded, labelType);
            if isempty(data), return; end
            data = data(:)';
            if strcmp(labelType, 'angle')
                obj.MainApp.GroundTruthAngle = data;
                obj.UIAngleStatus.Text = sprintf('✓ %s (%d点)', fname, length(data));
                obj.UIAngleStatus.FontColor = config.AppConstants.COLOR_SECONDARY;
            else
                obj.MainApp.GroundTruthForce = data;
                obj.UIForceStatus.Text = sprintf('✓ %s (%d点)', fname, length(data));
                obj.UIForceStatus.FontColor = config.AppConstants.COLOR_SECONDARY;
            end
        end

        function checkAllLoaded(obj)
            allEMG = ~isempty(obj.MainApp.FlexorEMG) && ~isempty(obj.MainApp.ExtensorEMG);
            if allEMG
                obj.UIAllLoadedLamp.Color = config.AppConstants.COLOR_SIG_GOOD;
            else
                obj.UIAllLoadedLamp.Color = [0.7 0.7 0.7];
            end
        end

        function updatePreviewButtonState(obj)
            if ~isempty(obj.MainApp.FlexorEMG) && ~isempty(obj.MainApp.ExtensorEMG)
                obj.UIPreviewBtn.Enable = 'on';
                obj.UIPreviewBtn.BackgroundColor = config.AppConstants.COLOR_SECONDARY;
                obj.UIPreviewBtn.FontColor = [1 1 1];
            else
                obj.UIPreviewBtn.Enable = 'off';
                obj.UIPreviewBtn.BackgroundColor = [0.9 0.9 0.9];
                obj.UIPreviewBtn.FontColor = [0 0 0];
            end
        end

        function previewSignals(obj)
            flexor = obj.MainApp.FlexorEMG;
            extensor = obj.MainApp.ExtensorEMG;
            if isempty(flexor) || isempty(extensor)
                uialert(obj.Parent, '请先加载屈肌和伸肌EMG数据', '无数据', 'Icon', 'warning');
                return;
            end

            fs = obj.MainApp.Fs;
            if isempty(fs) || fs <= 0, fs = 2000; end

            axF = obj.PreviewAxes(1);
            axE = obj.PreviewAxes(2);

            if size(flexor,1) >= 1
                ch1 = flexor(1, :);
                t = (0:length(ch1)-1) / fs;
                plot(axF, t, ch1, 'b', 'LineWidth', 1);
                ylim(axF, [-700 700]);
                xlim(axF, [t(1), t(end)]);
                ylabel(axF, '屈肌CH1 (\muV)');
                grid(axF, 'on');
            else
                cla(axF); text(axF, 0.5, 0.5, '无屈肌数据', 'HorizontalAlignment','center');
            end

            if size(extensor,1) >= 1
                ch1 = extensor(1, :);
                t = (0:length(ch1)-1) / fs;
                plot(axE, t, ch1, 'r', 'LineWidth', 1);
                ylim(axE, [-1000 1000]);
                xlim(axE, [t(1), t(end)]);
                ylabel(axE, '伸肌CH1 (\muV)');
                grid(axE, 'on');
            else
                cla(axE); text(axE, 0.5, 0.5, '无伸肌数据', 'HorizontalAlignment','center');
            end
        end

        function label = getSideLabel(~, side)
            if strcmp(side, 'flexor'), label = '屈肌'; else, label = '伸肌'; end
        end
    end
end