classdef WaveformPanel < handle
    % WaveformPanel - 128通道实时波形显示组件

    properties (Access = private)
        Parent
        MainApp
        Axes
        PlotLines       
        DisplayWindowSec double = 5
        IsFrozen        logical = false
        ShowEnvelope    logical = false
    end

    properties (Access = private)
        UIFreezeCheck
        UIWindowSpinner
        UIEnvelopeCheck
        UIScreenshotBtn
    end

    methods
        function obj = WaveformPanel(parent, mainApp)
            try
                obj.Parent = parent;
                obj.MainApp = mainApp;
                obj.buildUI();
                fprintf('WaveformPanel 构造成功\n');
            catch ME
                fprintf('========== WaveformPanel 构造失败 ==========\n');
                fprintf('错误消息: %s\n', ME.message);
                for k = 1:length(ME.stack)
                    fprintf('文件: %s, 行: %d, 函数: %s\n', ME.stack(k).file, ME.stack(k).line, ME.stack(k).name);
                end
                rethrow(ME);
            end
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            mainGrid = uigridlayout(obj.Parent, [2, 1], ...
                'RowHeight', {'1x', 'fit'}, ...
                'Padding', [0, 0, 0, 0], ...
                'RowSpacing', 4);

            % ---- 波形显示区域 ----
            obj.Axes = uiaxes(mainGrid);
            hold(obj.Axes, 'on');
            xlabel(obj.Axes, '时间 (s)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.Axes, '通道', 'FontName', AppConstants.FONT_NAME);
            title(obj.Axes, '128通道 HD-sEMG 波形', 'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.Axes.YDir = 'reverse';
            obj.Axes.YLim = [0.5, 128.5];
            obj.Axes.YTick = [1,  65];
            obj.Axes.YTickLabel = {'屈肌CH1', '伸肌CH1'};
            obj.Axes.XLim = [0, obj.DisplayWindowSec];
            grid(obj.Axes, 'on');
            obj.Axes.GridColor = AppConstants.COLOR_GRID;

            % 初始化128条空曲线
            tempLines = gobjects(128, 1);
            for ch = 1:128
                tempLines(ch) = plot(obj.Axes, NaN, NaN, ...
                    'Color', obj.getChannelDisplayColor(ch), ...
                    'LineWidth', 0.5);
            end
            obj.PlotLines = tempLines;

            % ---- 控制栏 ----
            ctrlGrid = uigridlayout(mainGrid, [1, 5], ...
                'ColumnWidth', {'fit', 'fit', 'fit', '1x', 'fit'}, ...
                'Padding', [2, 2, 2, 2]);

            obj.UIFreezeCheck = uicheckbox(ctrlGrid, 'Text', '冻结显示', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ValueChangedFcn', @(~,~) obj.toggleFreeze());

            uilabel(ctrlGrid, 'Text', '时间窗(s):', ...
                'FontName', AppConstants.FONT_NAME);
            obj.UIWindowSpinner = uispinner(ctrlGrid, ...
                'Value', 5, 'Limits', [1, 30], 'Step', 1, ...
                'ValueChangedFcn', @(~,~) obj.updateWindow());

            obj.UIEnvelopeCheck = uicheckbox(ctrlGrid, 'Text', '显示包络', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ValueChangedFcn', @(~,~) obj.toggleEnvelope());

            obj.UIScreenshotBtn = uibutton(ctrlGrid, 'Text', '截图', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.takeScreenshot());
        end

        function color = getChannelDisplayColor(obj, ch)
            import config.AppConstants
            if ch <= 64
                base = AppConstants.COLOR_FLEXOR;
            else
                base = AppConstants.COLOR_EXTENSOR;
            end
            factor = 0.5 + 0.5 * ((mod(ch - 1, 64) + 1) / 64);
            color = base * factor;
        end
    end

    methods (Access = public)
        function updateWaveform(obj, data, fs)
            % 更新波形显示
            % data: (nCh, N) EMG数据
            % fs: 采样率
            if obj.IsFrozen || isempty(data)
                return;
            end

            [nCh, nSamples] = size(data);
            nDisplaySamples = round(obj.DisplayWindowSec * fs);
            if nSamples > nDisplaySamples
                displayData = data(:, end - nDisplaySamples + 1:end);
            else
                displayData = data;
            end

            t = (0:size(displayData, 2) - 1) / fs;

            % 显示参数配置（可根据需要调整）
            channelSpacing = 1.2;   % 通道间垂直间距
            signalScale = 0.4;      % 信号幅度缩放
            baseOffset = 1;         % 第一个通道的Y坐标起始值

            for ch = 1:min(nCh, 128)
                yData = displayData(ch, :) * signalScale + baseOffset + (ch-1) * channelSpacing;
                set(obj.PlotLines(ch), 'XData', t, 'YData', yData);
            end

            % 重置Y轴范围
            maxY = baseOffset + (min(nCh,128)-1) * channelSpacing + 0.5;
            obj.Axes.YLim = [baseOffset - 0.5, maxY];
            obj.Axes.XLim = [t(1), t(end)];
        end

        function updateWindow(obj)
            obj.DisplayWindowSec = obj.UIWindowSpinner.Value;
        end

        function toggleFreeze(obj)
            obj.IsFrozen = obj.UIFreezeCheck.Value;
        end

        function toggleEnvelope(obj)
            obj.ShowEnvelope = obj.UIEnvelopeCheck.Value;
        end

        function takeScreenshot(obj)
            [file, path] = uiputfile({'*.png', 'PNG图片'; '*.svg', 'SVG矢量图'}, '保存截图');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);
            exportgraphics(obj.Axes, fullPath, 'Resolution', 150);
            obj.MainApp.log(sprintf('波形截图已保存: %s', fullPath));
        end
    end
end
