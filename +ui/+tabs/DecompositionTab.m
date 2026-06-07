classdef DecompositionTab < handle
    % DecompositionTab - 肌电分解Tab（自动识别被试，动作选择，自动匹配模板）

    properties (Access = private)
        Parent
        MainApp
        DecompService

        % UI 组件
        FlexorAxes          matlab.ui.control.UIAxes   % 屈肌侧光栅图
        ExtensorAxes        matlab.ui.control.UIAxes   % 伸肌侧光栅图
        FlexorMuapAxes      matlab.ui.control.UIAxes   % 屈肌侧MUAP
        ExtensorMuapAxes    matlab.ui.control.UIAxes   % 伸肌侧MUAP
        FlexorMuDropdown    matlab.ui.control.DropDown
        ExtensorMuDropdown  matlab.ui.control.DropDown
        FlexorChDropdown    matlab.ui.control.DropDown
        ExtensorChDropdown  matlab.ui.control.DropDown
        FlexorOverlayCheck  matlab.ui.control.CheckBox
        ExtensorOverlayCheck matlab.ui.control.CheckBox

        % 状态标签
        UIEmgStatusLabel
        UIStatusSubject      matlab.ui.control.Label   % 被试编号显示
        UIActionDropdown     matlab.ui.control.DropDown % 动作选择
        UITemplateStatusLabel
        UIDecomposeButton    matlab.ui.control.Button    % 开始分解按钮

        % 参数控件（只保留Python路径）
        UIPythonEdit

        % 进度条
        ProgressBar

        % 存储数据
        FlexorMuapResults   cell = {}
        ExtensorMuapResults cell = {}
        CurrentSubject      string = ""    % 当前被试编号（如 S02）
        CurrentAction       string = "G01" % 当前动作
        TemplateReady       logical = false
    end

    methods
        function obj = DecompositionTab(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.DecompService = services.DecompositionService();
            obj.buildUI();
            obj.updateEMGStatus();  % 添加这一行
        end
    end

    methods (Access = private)

        function buildUI(obj)
            import config.AppConstants

            delete(obj.Parent.Children);

            mainGrid = uigridlayout(obj.Parent, [3, 2], ...
                'RowHeight', {'fit', '1x', '1x'}, ...
                'ColumnWidth', {'1x', '1x'}, ...
                'Padding', [AppConstants.PADDING, AppConstants.PADDING, ...
                AppConstants.PADDING, AppConstants.PADDING], ...
                'RowSpacing', AppConstants.ROW_SPACING, ...
                'ColumnSpacing', AppConstants.COL_SPACING);

            % ---- Row1: 数据与模板配置（简化）----
            configPanel = uipanel(mainGrid, 'Title', '数据与模板配置', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildConfigPanel(configPanel);

            % 右侧分解控制面板（只保留 Python 路径和开始按钮）
            controlPanel = uipanel(mainGrid, 'Title', '分解控制', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG);
            obj.buildControlPanel(controlPanel);

            % ---- Row2: 左侧屈肌发放，右侧屈肌 MUAP ----
            rasterFlex = uipanel(mainGrid, 'Title', '屈肌侧 MU发放序列', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG);
            obj.FlexorAxes = uiaxes(rasterFlex);
            obj.FlexorAxes.Units = 'normalized';
            obj.FlexorAxes.Position = [0.05 0.05 0.9 0.9];
            xlabel(obj.FlexorAxes, '时间 (s)');
            ylabel(obj.FlexorAxes, 'MU编号');
            title(obj.FlexorAxes, '屈肌侧 MU发放序列');
            grid(obj.FlexorAxes, 'on');
            hold(obj.FlexorAxes, 'on');

            muapFlexPanel = uipanel(mainGrid, 'Title', '屈肌侧 MUAP波形', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG);
            obj.buildMuapPanel(muapFlexPanel, 'flexor');

            % ---- Row3: 左侧伸肌发放，右侧伸肌 MUAP ----
            rasterExt = uipanel(mainGrid, 'Title', '伸肌侧 MU发放序列', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG);
            obj.ExtensorAxes = uiaxes(rasterExt);
            obj.ExtensorAxes.Units = 'normalized';
            obj.ExtensorAxes.Position = [0.05 0.05 0.9 0.9];
            xlabel(obj.ExtensorAxes, '时间 (s)');
            ylabel(obj.ExtensorAxes, 'MU编号');
            title(obj.ExtensorAxes, '伸肌侧 MU发放序列');
            grid(obj.ExtensorAxes, 'on');
            hold(obj.ExtensorAxes, 'on');

            muapExtPanel = uipanel(mainGrid, 'Title', '伸肌侧 MUAP波形', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG);
            obj.buildMuapPanel(muapExtPanel, 'extensor');
        end

        % 构建配置面板（自动识别被试 + 动作下拉框）
        function buildConfigPanel(obj, parent)
            import config.AppConstants

            lg = uigridlayout(parent, [5, 3], ...
                'Padding', [10, 10, 10, 10], ...
                'RowSpacing', 8, 'ColumnSpacing', 10);
            fnt = AppConstants.FONT_NAME;

            % Row1: EMG数据状态
            uilabel(lg, 'Text', 'EMG数据:', 'FontName', fnt, 'FontWeight', 'bold');
            obj.UIEmgStatusLabel = uilabel(lg, 'Text', '未加载', ...
                'FontName', fnt, 'FontColor', AppConstants.COLOR_DANGER);
            obj.UIEmgStatusLabel.Layout.Column = [2, 3];

            % Row2: 被试编号（自动识别）
            uilabel(lg, 'Text', '被试编号:', 'FontName', fnt, 'FontWeight', 'bold');
            obj.UIStatusSubject = uilabel(lg, 'Text', '未识别', ...
                'FontName', fnt, 'FontColor', AppConstants.COLOR_DANGER);
            obj.UIStatusSubject.Layout.Column = [2, 3];

            % Row3: 动作类型下拉框
            uilabel(lg, 'Text', '动作类型:', 'FontName', fnt, 'FontWeight', 'bold');
            obj.UIActionDropdown = uidropdown(lg, ...
                'Items', {'G01 侧捏屈伸', 'G02 侧捏旋转', 'G03 对捏屈伸', 'G04 对捏旋转'}, ...
                'Value', 'G01 侧捏屈伸', ...
                'FontName', fnt, ...
                'ValueChangedFcn', @(~,~) obj.onActionChanged());
            obj.UIActionDropdown.Layout.Column = [2, 3];

            % Row4: 模板状态
            uilabel(lg, 'Text', '模板状态:', 'FontName', fnt, 'FontWeight', 'bold');
            obj.UITemplateStatusLabel = uilabel(lg, 'Text', '待检测', ...
                'FontName', fnt, 'FontColor', AppConstants.COLOR_DANGER);
            obj.UITemplateStatusLabel.Layout.Column = [2, 3];

            % Row5: 提示信息（占位）
            uilabel(lg, 'Text', '', 'FontName', fnt, 'FontSize', 10);
        end

        function buildControlPanel(obj, parent)
            import config.AppConstants

            pg = uigridlayout(parent, [2, 1], ...
                'Padding', [10, 10, 10, 10], ...
                'RowSpacing', 10);

            % 开始分解按钮，初始禁用
            obj.UIDecomposeButton = uibutton(pg, 'Text', '▶ 开始在线分解', ...
                'BackgroundColor', AppConstants.COLOR_SECONDARY, ...
                'FontColor', [1 1 1], 'FontWeight', 'bold', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.runDecomposition());

            uibutton(pg, 'Text', '重置显示', ...
                'ButtonPushedFcn', @(~,~) obj.resetDisplay());
        end

        function buildMuapPanel(obj, parent, side)
            import config.AppConstants

            % 直接在传入的父容器（已经是带标题的 uipanel）上创建网格布局
            gridLayout = uigridlayout(parent, [3,1], ...
                'RowHeight', {'fit', 'fit', '1x'}, ...
                'Padding', [5,5,5,5], 'RowSpacing', 5);

            % 第一行：MU选择 + 通道选择
            selectRow = uigridlayout(gridLayout, [1,4], ...
                'ColumnWidth', {'fit', '1x', 'fit', '1x'}, ...
                'Padding', [0,0,0,0]);
            uilabel(selectRow, 'Text', 'MU:');
            if strcmp(side, 'flexor')
                obj.FlexorMuDropdown = uidropdown(selectRow, 'Items', {'MU 1'}, ...
                    'ValueChangedFcn', @(~,~) obj.updateFlexorMuapDisplay());
            else
                obj.ExtensorMuDropdown = uidropdown(selectRow, 'Items', {'MU 1'}, ...
                    'ValueChangedFcn', @(~,~) obj.updateExtensorMuapDisplay());
            end
            uilabel(selectRow, 'Text', '通道:');
            if strcmp(side, 'flexor')
                obj.FlexorChDropdown = uidropdown(selectRow, 'Items', obj.getChannelItems(), ...
                    'Value', 'CH01', ...
                    'ValueChangedFcn', @(~,~) obj.updateFlexorMuapDisplay());
            else
                obj.ExtensorChDropdown = uidropdown(selectRow, 'Items', obj.getChannelItems(), ...
                    'Value', 'CH01', ...
                    'ValueChangedFcn', @(~,~) obj.updateExtensorMuapDisplay());
            end

            % 第二行：叠加模式复选框
            if strcmp(side, 'flexor')
                obj.FlexorOverlayCheck = uicheckbox(gridLayout, ...
                    'Text', '叠加显著通道', 'Value', false, ...
                    'ValueChangedFcn', @(~,~) obj.updateFlexorMuapDisplay());
            else
                obj.ExtensorOverlayCheck = uicheckbox(gridLayout, ...
                    'Text', '叠加显著通道', 'Value', false, ...
                    'ValueChangedFcn', @(~,~) obj.updateExtensorMuapDisplay());
            end

            % 第三行：axes
            ax = uiaxes(gridLayout);
            xlabel(ax, '时间 (ms)');
            ylabel(ax, '幅值');
            % axes 的标题可以留空，或者改为具体说明（避免与外层 panel 标题重复）
            title(ax, '');
            grid(ax, 'on');
            hold(ax, 'on');
            if strcmp(side, 'flexor')
                obj.FlexorMuapAxes = ax;
            else
                obj.ExtensorMuapAxes = ax;
            end
        end

        function items = getChannelItems(obj)
            items = arrayfun(@(x) sprintf('CH%02d', x), 1:64, 'UniformOutput', false);
        end

        % ---------- 自动识别被试 ----------
        function refreshSubjectAndTemplate(obj)
            flexorPath = obj.MainApp.FlexorEMGPath;
            fprintf('refreshSubjectAndTemplate: flexorPath = %s\n', flexorPath);
            fprintf('FlexorEMGPath: %s\n', flexorPath);
            if isempty(flexorPath)
                obj.UIStatusSubject.Text = '未识别';
                obj.UIStatusSubject.FontColor = config.AppConstants.COLOR_DANGER;
                obj.CurrentSubject = "";
                obj.TemplateReady = false;
                obj.UIDecomposeButton.Enable = 'off';
                obj.UITemplateStatusLabel.Text = '无EMG数据';
                return;
            end
            [~, fname] = fileparts(flexorPath);
            % 通用解析：取第一个下划线之前的部分作为被试名
            parts = strsplit(fname, '_');
            if ~isempty(parts) && ~isempty(parts{1})
                subject = parts{1};
                obj.CurrentSubject = subject;
                obj.UIStatusSubject.Text = subject;
                obj.UIStatusSubject.FontColor = config.AppConstants.COLOR_SIG_GOOD;
                obj.MainApp.log(sprintf('自动识别被试: %s', subject));
            else
                % 如果没有下划线，则使用整个文件名（不含扩展名）
                subject = fname;
                if isempty(subject)
                    subject = "未知";
                end
                obj.CurrentSubject = subject;
                obj.UIStatusSubject.Text = subject;
                obj.UIStatusSubject.FontColor = config.AppConstants.COLOR_WARNING;  % 提示可能不规范
                obj.MainApp.log(sprintf('自动识别被试（无下划线）: %s', subject));
            end
            obj.MainApp.CurrentSubject = subject;   % subject 是从文件名解析出的 "S01"
            obj.detectTemplate();
            fprintf('MainApp.CurrentSubject 已设置为: %s\n', obj.MainApp.CurrentSubject);
        end

        function onActionChanged(obj)
            % 用户切换动作时更新
            actionStr = obj.UIActionDropdown.Value;
            action = regexp(actionStr, '^(G\d{2})', 'match', 'once');
            if isempty(action)
                obj.CurrentAction = "G01";
            else
                obj.CurrentAction = action;
            end
            obj.MainApp.CurrentAction = obj.CurrentAction;
            obj.detectTemplate();
        end

        function detectTemplate(obj)
            % 根据当前被试和动作检测模板文件是否存在
            import config.AppConstants

            if isempty(obj.CurrentSubject)
                obj.UITemplateStatusLabel.Text = '被试未识别';
                obj.UITemplateStatusLabel.FontColor = AppConstants.COLOR_DANGER;
                obj.TemplateReady = false;
                obj.UIDecomposeButton.Enable = 'off';
                return;
            end

            templateRoot = AppConstants.TEMPLATE_ROOT;
            actionDir = fullfile(templateRoot, obj.CurrentSubject, obj.CurrentAction);
            if ~exist(actionDir, 'dir')
                obj.UITemplateStatusLabel.Text = sprintf('模板目录不存在: %s', actionDir);
                obj.UITemplateStatusLabel.FontColor = AppConstants.COLOR_DANGER;
                obj.TemplateReady = false;
                obj.UIDecomposeButton.Enable = 'off';
                return;
            end

            % 检查必需的6个文件（注意 motionId 可能是 T234 等，需要动态解析）
            files = dir(fullfile(actionDir, '*_ica_model_*_dev0.pkl'));
            if isempty(files)
                obj.UITemplateStatusLabel.Text = '未找到 ICA 模型文件';
                obj.UITemplateStatusLabel.FontColor = AppConstants.COLOR_DANGER;
                obj.TemplateReady = false;
                obj.UIDecomposeButton.Enable = 'off';
                return;
            end
            % 提取 motionId（例如从 S02_ica_model_T234_dev0.pkl 提取 T234）
            firstFile = files(1).name;
            tokens = regexp(firstFile, '_ica_model_(T\d+)_dev0\.pkl', 'tokens');
            if isempty(tokens)
                motionId = 'T234'; % 默认
            else
                motionId = tokens{1}{1};
            end

            required = {sprintf('%s_ica_model_%s_dev0.pkl', obj.CurrentSubject, motionId), ...
                sprintf('%s_ica_model_%s_dev1.pkl', obj.CurrentSubject, motionId), ...
                sprintf('%s_center_%s_dev0.csv', obj.CurrentSubject, motionId), ...
                sprintf('%s_center_%s_dev1.csv', obj.CurrentSubject, motionId), ...
                sprintf('%s_valid_index_%s_dev0.csv', obj.CurrentSubject, motionId), ...
                sprintf('%s_valid_index_%s_dev1.csv', obj.CurrentSubject, motionId)};
            missing = {};
            for i = 1:length(required)
                if ~exist(fullfile(actionDir, required{i}), 'file')
                    missing{end+1} = required{i};
                end
            end

            if ~isempty(missing)
                obj.UITemplateStatusLabel.Text = sprintf('缺少 %d 个文件', length(missing));
                obj.UITemplateStatusLabel.FontColor = AppConstants.COLOR_DANGER;
                obj.TemplateReady = false;
                obj.UIDecomposeButton.Enable = 'off';
                obj.MainApp.log(sprintf('模板缺失: %s', strjoin(missing, ', ')));
                return;
            end

            % 模板齐全
            obj.UITemplateStatusLabel.Text = sprintf('模板齐全 (%s)', motionId);
            obj.UITemplateStatusLabel.FontColor = AppConstants.COLOR_SIG_GOOD;
            obj.TemplateReady = true;
            obj.UIDecomposeButton.Enable = 'on';
            obj.MainApp.log(sprintf('模板检测成功: %s/%s', obj.CurrentSubject, obj.CurrentAction));
            % 同时设置 DecompService 的模板目录
            obj.DecompService.TemplateDir = actionDir;
        end

        % ---------- MUAP 更新函数 ----------
        function updateFlexorMuapDisplay(obj)
            if isempty(obj.FlexorMuapResults)
                cla(obj.FlexorMuapAxes);
                text(obj.FlexorMuapAxes, 0.5, 0.5, '无屈肌侧MUAP数据', ...
                    'Units','normalized','HorizontalAlignment','center');
                return;
            end
            muStr = obj.FlexorMuDropdown.Value;
            muIdx = sscanf(muStr, 'MU %d');
            if isempty(muIdx) || muIdx < 1 || muIdx > length(obj.FlexorMuapResults)
                return;
            end
            chStr = obj.FlexorChDropdown.Value;
            chIdx = sscanf(chStr, 'CH%d');
            if isempty(chIdx), chIdx = 1; end
            overlay = obj.FlexorOverlayCheck.Value;

            muapStruct = obj.FlexorMuapResults{muIdx};
            if ~isstruct(muapStruct) || ~isfield(muapStruct, 'MUAP')
                return;
            end
            muapMat = muapStruct.MUAP;
            windowLen = size(muapMat, 2);
            fs = obj.MainApp.Fs;
            if isempty(fs) || fs <= 0, fs = 2000; end
            halfWin = (windowLen - 1) / 2;
            t = (-halfWin:halfWin) / fs * 1000;

            cla(obj.FlexorMuapAxes);
            hold(obj.FlexorMuapAxes, 'on');

            if overlay
                if isfield(muapStruct, 'channels') && ~isempty(muapStruct.channels)
                    sigChans = muapStruct.channels(:, 1);
                else
                    sigChans = (1:min(10,64))';
                end
                for i = 1:length(sigChans)
                    ch = sigChans(i);
                    wave = muapMat(ch, :);
                    plot(obj.FlexorMuapAxes, t, wave + (i-1)*0.5, 'LineWidth', 0.5);
                end
                title(obj.FlexorMuapAxes, sprintf('MU %d — %d个显著通道', muIdx, length(sigChans)));
            else
                wave = muapMat(chIdx, :);
                plot(obj.FlexorMuapAxes, t, wave, 'LineWidth', 1.5);
                title(obj.FlexorMuapAxes, sprintf('MU %d — CH%02d', muIdx, chIdx));
            end
            xlabel(obj.FlexorMuapAxes, '时间 (ms)');
            ylabel(obj.FlexorMuapAxes, '幅值');
            grid(obj.FlexorMuapAxes, 'on');
            hold(obj.FlexorMuapAxes, 'off');
            drawnow;
        end

        function updateExtensorMuapDisplay(obj)
            if isempty(obj.ExtensorMuapResults)
                cla(obj.ExtensorMuapAxes);
                text(obj.ExtensorMuapAxes, 0.5, 0.5, '无伸肌侧MUAP数据', ...
                    'Units','normalized','HorizontalAlignment','center');
                return;
            end
            muStr = obj.ExtensorMuDropdown.Value;
            muIdx = sscanf(muStr, 'MU %d');
            if isempty(muIdx) || muIdx < 1 || muIdx > length(obj.ExtensorMuapResults)
                return;
            end
            chStr = obj.ExtensorChDropdown.Value;
            chIdx = sscanf(chStr, 'CH%d');
            if isempty(chIdx), chIdx = 1; end
            overlay = obj.ExtensorOverlayCheck.Value;

            muapStruct = obj.ExtensorMuapResults{muIdx};
            if ~isstruct(muapStruct) || ~isfield(muapStruct, 'MUAP')
                return;
            end
            muapMat = muapStruct.MUAP;
            windowLen = size(muapMat, 2);
            fs = obj.MainApp.Fs;
            if isempty(fs) || fs <= 0, fs = 2000; end
            halfWin = (windowLen - 1) / 2;
            t = (-halfWin:halfWin) / fs * 1000;

            cla(obj.ExtensorMuapAxes);
            hold(obj.ExtensorMuapAxes, 'on');

            if overlay
                if isfield(muapStruct, 'channels') && ~isempty(muapStruct.channels)
                    sigChans = muapStruct.channels(:, 1);
                else
                    sigChans = (1:min(10,64))';
                end
                for i = 1:length(sigChans)
                    ch = sigChans(i);
                    wave = muapMat(ch, :);
                    plot(obj.ExtensorMuapAxes, t, wave + (i-1)*0.5, 'LineWidth', 0.5);
                end
                title(obj.ExtensorMuapAxes, sprintf('MU %d — %d个显著通道', muIdx, length(sigChans)));
            else
                wave = muapMat(chIdx, :);
                plot(obj.ExtensorMuapAxes, t, wave, 'LineWidth', 1.5);
                title(obj.ExtensorMuapAxes, sprintf('MU %d — CH%02d', muIdx, chIdx));
            end
            xlabel(obj.ExtensorMuapAxes, '时间 (ms)');
            ylabel(obj.ExtensorMuapAxes, '幅值');
            grid(obj.ExtensorMuapAxes, 'on');
            hold(obj.ExtensorMuapAxes, 'off');
            drawnow;
        end

        % ---------- 核心分解 ----------
        function runDecomposition(obj)
            if ~obj.TemplateReady
                uialert(ancestor(obj.Parent, 'figure'), '模板未就绪，请检查被试和动作', '提示');
                return;
            end

            flexorPath = obj.MainApp.FlexorEMGPath;
            extensorPath = obj.MainApp.ExtensorEMGPath;
            if isempty(flexorPath) || isempty(extensorPath)
                uialert(ancestor(obj.Parent, 'figure'), '请先在数据采集页加载屈肌和伸肌EMG', '缺少数据');
                return;
            end

            outputDir = fullfile(fileparts(flexorPath), 'decomp_results');
            if ~isempty(obj.UIPythonEdit) && isvalid(obj.UIPythonEdit)
                obj.DecompService.PythonExe = obj.UIPythonEdit.Value;
            end

            obj.MainApp.log('=== 开始在线分解 ===');
            try
                obj.ProgressBar = ui.components.ProgressBar('在线ICA分解', '正在调用Python...');
            catch
                obj.ProgressBar = [];
            end

            try
                result = obj.DecompService.decomposeWithPython(...
                    flexorPath, extensorPath, obj.DecompService.TemplateDir, outputDir);

                if ~isstruct(result) || ~isfield(result, 'spikeTrainMatrix')
                    error('返回结果无效: 缺少 spikeTrainMatrix');
                end

                % 保存到 MainApp
                obj.MainApp.SpikeTrainMatrix = result.spikeTrainMatrix;
                obj.MainApp.NMUs = size(result.spikeTrainMatrix,1);
                obj.MainApp.NFlexorMUs = result.nFlexorMUs;
                obj.MainApp.NExtensorMUs = result.nExtensorMUs;
                obj.MainApp.FiringRates = result.firingRates;
                obj.MainApp.FiringRateCV = result.firingRateCV;
                obj.MainApp.DecompQuality = struct('sil', result.sil, 'pnr', result.pnr);

                % 分离屈/伸数据
                flexorST = result.spikeTrainMatrix(1:result.nFlexorMUs, :);
                extensorST = result.spikeTrainMatrix(result.nFlexorMUs+1:end, :);
                fs = obj.MainApp.Fs;

                % 绘制发放序列
                obj.plotSpikeTrainOnAxes(obj.FlexorAxes, flexorST, fs, '屈肌侧');
                obj.plotSpikeTrainOnAxes(obj.ExtensorAxes, extensorST, fs, '伸肌侧');

                % 计算 MUAP（屈肌侧）
                try
                    nFlexSamp = min(size(flexorST,2), size(obj.MainApp.FlexorEMG,2));
                    flexEMG = obj.MainApp.FlexorEMG(:, 1:nFlexSamp);
                    if size(flexEMG,1) ~= 64, flexEMG = flexEMG'; end
                    flexorMuap = obj.DecompService.computeMuap(flexEMG, flexorST, 60);
                    obj.FlexorMuapResults = flexorMuap;
                    % 更新下拉菜单
                    nMU_flex = length(flexorMuap);
                    items = arrayfun(@(x) sprintf('MU %d', x), 1:nMU_flex, 'UniformOutput', false);
                    obj.FlexorMuDropdown.Items = items;
                    if nMU_flex > 0, obj.FlexorMuDropdown.Value = items{1}; end
                    obj.updateFlexorMuapDisplay();
                    obj.MainApp.log(sprintf('屈肌侧MUAP计算完成: %d MU', nMU_flex));
                catch e
                    obj.MainApp.log(sprintf('屈肌侧MUAP计算失败: %s', e.message));
                end

                % 计算 MUAP（伸肌侧）
                try
                    nExtSamp = min(size(extensorST,2), size(obj.MainApp.ExtensorEMG,2));
                    extEMG = obj.MainApp.ExtensorEMG(:, 1:nExtSamp);
                    if size(extEMG,1) ~= 64, extEMG = extEMG'; end
                    extensorMuap = obj.DecompService.computeMuap(extEMG, extensorST, 60);
                    obj.ExtensorMuapResults = extensorMuap;
                    nMU_ext = length(extensorMuap);
                    items = arrayfun(@(x) sprintf('MU %d', x), 1:nMU_ext, 'UniformOutput', false);
                    obj.ExtensorMuDropdown.Items = items;
                    if nMU_ext > 0, obj.ExtensorMuDropdown.Value = items{1}; end
                    obj.updateExtensorMuapDisplay();
                    obj.MainApp.log(sprintf('伸肌侧MUAP计算完成: %d MU', nMU_ext));
                catch e
                    obj.MainApp.log(sprintf('伸肌侧MUAP计算失败: %s', e.message));
                end

                if ~isempty(obj.ProgressBar); obj.ProgressBar.close(); end
                obj.MainApp.log(sprintf('分解完成: %d MU (屈肌%d+伸肌%d), 用时%.1fs', ...
                    obj.MainApp.NMUs, obj.MainApp.NFlexorMUs, obj.MainApp.NExtensorMUs, result.decompTime));
                uialert(ancestor(obj.Parent, 'figure'), ...
                    sprintf('在线分解完成!\n屈肌:%d MU, 伸肌:%d MU', result.nFlexorMUs, result.nExtensorMUs), ...
                    '成功', 'Icon','success');
            catch e
                if ~isempty(obj.ProgressBar); obj.ProgressBar.close(); end
                obj.MainApp.log(sprintf('分解失败: %s', e.message));
                for k = 1:length(e.stack)
                    obj.MainApp.log(sprintf('  %s (行 %d)', e.stack(k).name, e.stack(k).line));
                end
                fig = ancestor(obj.Parent, 'figure');
                if ~isempty(fig) && ishandle(fig)
                    uialert(fig, sprintf('分解失败:\n%s', e.message), '错误', 'Icon','error');
                end
            end
        end

        function plotSpikeTrainOnAxes(obj, ax, spikeTrain, fs, sideName)
            if ~ishandle(ax), return; end
            cla(ax);
            hold(ax, 'on');
            [nMU, nSamples] = size(spikeTrain);
            if nMU == 0
                text(ax, 0.5, 0.5, '无 MU 数据', 'HorizontalAlignment','center');
                hold(ax, 'off');
                return;
            end
            for mu = 1:nMU
                idx = find(spikeTrain(mu,:));
                if isempty(idx), continue; end
                t = idx / fs;
                plot(ax, t, mu * ones(size(t)), '.', 'MarkerSize', 4);
            end
            xlim(ax, [0, nSamples/fs]);
            ylim(ax, [0.5, nMU+0.5]);
            yticks(ax, 1:min(nMU,50));
            yticklabels(ax, arrayfun(@(x)sprintf('MU%d',x), 1:min(nMU,50), 'UniformOutput',false));
            xlabel(ax, '时间 (s)');
            ylabel(ax, 'MU编号');
            title(ax, [sideName ' MU发放序列']);
            grid(ax, 'on');
            hold(ax, 'off');
            drawnow;
        end

        function cancelDecomposition(obj)
            obj.DecompService.cancel();
            if ~isempty(obj.ProgressBar); obj.ProgressBar.close(); end
            obj.MainApp.log('分解已取消');
        end

        function resetDisplay(obj)
            cla(obj.FlexorAxes);
            cla(obj.ExtensorAxes);
            cla(obj.FlexorMuapAxes);
            cla(obj.ExtensorMuapAxes);
            obj.FlexorMuapResults = {};
            obj.ExtensorMuapResults = {};
            obj.FlexorMuDropdown.Items = {'MU 1'};
            obj.ExtensorMuDropdown.Items = {'MU 1'};
            obj.MainApp.log('显示已重置');
        end

    end
    methods (Access = public)
        function updateEMGStatus(obj)
            fprintf('updateEMGStatus called\n');
            import config.AppConstants

            flexorPath = obj.MainApp.FlexorEMGPath;
            extensorPath = obj.MainApp.ExtensorEMGPath;

            % 调试：打印路径
            fprintf('屈肌路径: %s\n', flexorPath);
            fprintf('伸肌路径: %s\n', extensorPath);

            if ~isempty(flexorPath) && ~isempty(extensorPath)
                obj.UIEmgStatusLabel.Text = '✓ 已加载';
                obj.UIEmgStatusLabel.FontColor = AppConstants.COLOR_SIG_GOOD;
            elseif ~isempty(flexorPath) || ~isempty(extensorPath)
                obj.UIEmgStatusLabel.Text = '⚠ 仅单侧加载';
                obj.UIEmgStatusLabel.FontColor = AppConstants.COLOR_WARNING;
            else
                obj.UIEmgStatusLabel.Text = '未加载';
                obj.UIEmgStatusLabel.FontColor = AppConstants.COLOR_DANGER;
                obj.TemplateReady = false;
                obj.UIDecomposeButton.Enable = 'off';
                return;
            end

            % 只要有屈肌路径，就尝试识别被试和检测模板
            if ~isempty(flexorPath)
                obj.refreshSubjectAndTemplate();
            end
        end
    end
end