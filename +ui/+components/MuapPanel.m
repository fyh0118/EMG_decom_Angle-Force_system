classdef MuapPanel < handle   % 关键：继承 handle
    % MuapPanel - 运动单位动作电位波形显示组件
    %   支持屈肌侧/伸肌侧独立的MUAP波形展示

    properties (Access = private)
        Parent
        MainApp
        Axes
        Side            char = ''       % 'flexor' or 'extensor'
        SelectedMU      double = 1
        SelectedChannel double = 1
        OverlayMode     logical = false
        MuapResults     cell = {}       % {nMU x 1} struct array from MUAP_IQR
    end

    properties (Access = private)
        UIMUDropdown
        UIChannelDropdown
        UIOverlayCheck
    end

    methods
        function obj = MuapPanel(parent, mainApp, side)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.Side = side;
            obj.buildUI();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            if strcmp(obj.Side, 'flexor')
                sideLabel = '屈肌侧';
            else
                sideLabel = '伸肌侧';
            end

            mainGrid = uigridlayout(obj.Parent, [2, 1], ...
                'RowHeight', {'1x', 'fit'}, ...
                'Padding', [2, 2, 2, 2], ...
                'RowSpacing', 4);

            obj.Axes = uiaxes(mainGrid);
            xlabel(obj.Axes, '时间 (ms)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.Axes, '幅值', 'FontName', AppConstants.FONT_NAME);
            title(obj.Axes, [sideLabel ' MUAP波形'], 'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            hold(obj.Axes, 'on');
            grid(obj.Axes, 'on');

            ctrlGrid = uigridlayout(mainGrid, [1, 4], ...
                'ColumnWidth', {'fit', 'fit', 'fit', 'fit'}, ...
                'Padding', [2, 2, 2, 2]);

            uilabel(ctrlGrid, 'Text', 'MU选择:', 'FontName', AppConstants.FONT_NAME);
            obj.UIMUDropdown = uidropdown(ctrlGrid, ...
                'Items', {'MU 1'}, 'Value', 'MU 1', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ValueChangedFcn', @(~,~) obj.onSelectionChanged());

            uilabel(ctrlGrid, 'Text', '通道:', 'FontName', AppConstants.FONT_NAME);
            obj.UIChannelDropdown = uidropdown(ctrlGrid, ...
                'Items', obj.getChannelItems(), 'Value', 'CH01', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ValueChangedFcn', @(~,~) obj.onSelectionChanged());

            obj.UIOverlayCheck = uicheckbox(ctrlGrid, ...
                'Text', '叠加显著通道', ...
                'Value', false, 'FontName', AppConstants.FONT_NAME, ...
                'ValueChangedFcn', @(~,~) obj.onSelectionChanged());
        end

        function items = getChannelItems(obj)
            items = arrayfun(@(x) sprintf('CH%02d', x), 1:64, 'UniformOutput', false);
        end

        function onSelectionChanged(obj)
            muStr = obj.UIMUDropdown.Value;
            obj.SelectedMU = sscanf(muStr, 'MU %d');
            chStr = obj.UIChannelDropdown.Value;
            obj.SelectedChannel = sscanf(chStr, 'CH%d');
            obj.OverlayMode = obj.UIOverlayCheck.Value;
            obj.updateDisplay();
        end
    end

    methods (Access = public)
        function setMuapData(obj, muapResults)
            obj.MuapResults = muapResults;
            nMU = length(muapResults);

            % 安全更新下拉菜单（使用 ishhandle 而非 isvalid，避免 double 输入错误）
            if ~isempty(obj.UIMUDropdown) && ishandle(obj.UIMUDropdown)
                oldFcn = obj.UIMUDropdown.ValueChangedFcn;
                obj.UIMUDropdown.ValueChangedFcn = [];
                if nMU == 0
                    obj.UIMUDropdown.Items = {'(无MU)'};
                    obj.UIMUDropdown.Value = '(无MU)';
                else
                    items = arrayfun(@(x) sprintf('MU %d', x), 1:nMU, 'UniformOutput', false);
                    obj.UIMUDropdown.Items = items;
                    obj.UIMUDropdown.Value = items{1};
                end
                obj.UIMUDropdown.ValueChangedFcn = oldFcn;
            end

            % 默认选中第一个 MU 和第一个通道
            obj.SelectedMU = 1;
            obj.SelectedChannel = 1;
            obj.OverlayMode = false;

            obj.updateDisplay();
        end

        function updateDisplay(obj)
            if ~ishandle(obj.Axes)     % 使用 ishandle 安全
                return;
            end
            cla(obj.Axes);

            if isempty(obj.MuapResults)
                msg = sprintf('%s侧无MUAP数据', upper(obj.Side(1)));
                text(obj.Axes, 0.5, 0.5, msg, ...
                    'Units','normalized','HorizontalAlignment','center', ...
                    'FontSize',14, 'Color',[0.6 0.6 0.6]);
                drawnow;
                return;
            end

            muIdx = obj.SelectedMU;
            if muIdx < 1 || muIdx > length(obj.MuapResults)
                return;
            end

            muapStruct = obj.MuapResults{muIdx};
            if ~isstruct(muapStruct) || ~isfield(muapStruct, 'MUAP')
                text(obj.Axes, 0.5, 0.5, '数据格式错误', ...
                    'Units','normalized','HorizontalAlignment','center');
                drawnow;
                return;
            end

            muapMatrix = muapStruct.MUAP;
            if isempty(muapMatrix)
                return;
            end

            windowLen = size(muapMatrix, 2);
            fs = obj.MainApp.Fs;
            if isempty(fs) || fs <= 0, fs = 2000; end
            halfWin = (windowLen - 1) / 2;
            t = (-halfWin:halfWin) / fs * 1000;  % ms

            hold(obj.Axes, 'on');

            if obj.OverlayMode
                if isfield(muapStruct, 'channels') && ~isempty(muapStruct.channels)
                    sigChannels = muapStruct.channels(:, 1);
                else
                    sigChannels = (1:min(10,64))';
                end
                for i = 1:length(sigChannels)
                    ch = sigChannels(i);
                    if ch >= 1 && ch <= 64
                        wave = muapMatrix(ch, :);
                        plot(obj.Axes, t, wave + (i-1)*0.5, 'LineWidth', 0.5);
                    end
                end
                title(obj.Axes, sprintf('MU %d — %d个显著通道', muIdx, length(sigChannels)));
            else
                chIdx = obj.SelectedChannel;
                if chIdx < 1 || chIdx > 64, chIdx = 1; end
                wave = muapMatrix(chIdx, :);
                plot(obj.Axes, t, wave, 'LineWidth', 1.5);
                title(obj.Axes, sprintf('MU %d — CH%02d', muIdx, chIdx));
            end

            xlabel(obj.Axes, '时间 (ms)');
            ylabel(obj.Axes, '幅值');
            grid(obj.Axes, 'on');
            drawnow;
        end

        function clearData(obj)
            if ~ishandle(obj.Axes), return; end
            obj.MuapResults = {};
            if ~isempty(obj.UIMUDropdown) && ishandle(obj.UIMUDropdown)
                oldFcn = obj.UIMUDropdown.ValueChangedFcn;
                obj.UIMUDropdown.ValueChangedFcn = [];
                obj.UIMUDropdown.Items = {'MU 1'};
                obj.UIMUDropdown.Value = 'MU 1';
                obj.UIMUDropdown.ValueChangedFcn = oldFcn;
            end
            obj.SelectedMU = 1;
            obj.SelectedChannel = 1;
            obj.OverlayMode = false;
            cla(obj.Axes);
            msg = sprintf('%s侧无MUAP数据', upper(obj.Side(1)));
            text(obj.Axes, 0.5, 0.5, msg, ...
                'Units','normalized','HorizontalAlignment','center', ...
                'FontSize',14, 'Color',[0.6 0.6 0.6]);
            drawnow;
        end
    end
end