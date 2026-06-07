classdef SpikeRasterPanel
    % SpikeRasterPanel - 运动单位发放光栅图组件（无排序，显示全部MU）

    properties (Access = private)
        Parent
        MainApp
        Axes
        CurrentSpikeTrain     double = []   % 发放矩阵 (MU × 样本)
        CurrentFlexorMUs      double = []   % 屈肌 MU 数量
        CurrentExtensorMUs    double = []   % 伸肌 MU 数量
        CurrentFs             double = []   % 采样率
    end

    properties (Access = private)
        UIExportBtn
    end

    methods
        function obj = SpikeRasterPanel(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.buildUI();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            mainGrid = uigridlayout(obj.Parent, [2, 1], ...
                'RowHeight', {'1x', 'fit'}, ...
                'Padding', [2, 2, 2, 2], ...
                'RowSpacing', 4);

            % 光栅图区域
            obj.Axes = uiaxes(mainGrid);
            xlabel(obj.Axes, '时间 (s)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.Axes, 'MU编号', 'FontName', AppConstants.FONT_NAME);
            title(obj.Axes, '运动单位发放序列 (Spike Raster)', ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            hold(obj.Axes, 'on');
            obj.Axes.YDir = 'reverse';
            grid(obj.Axes, 'on');
            obj.Axes.GridColor = AppConstants.COLOR_GRID;

            % 控制栏只保留导出按钮
            ctrlGrid = uigridlayout(mainGrid, [1, 1], ...
                'ColumnWidth', {'fit'}, ...
                'Padding', [2, 2, 2, 2]);

            obj.UIExportBtn = uibutton(ctrlGrid, 'Text', '导出发放序列', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.exportSpikeTrains());
        end
    end

    methods (Access = public)
        function setData(obj, spikeTrain, flexorMUs, extensorMUs, fs)
            obj.CurrentSpikeTrain = spikeTrain;
            obj.CurrentFlexorMUs = flexorMUs;
            obj.CurrentExtensorMUs = extensorMUs;
            obj.CurrentFs = fs;
            obj.refresh();
        end

        function clearData(obj)
            obj.CurrentSpikeTrain = [];
            obj.CurrentFlexorMUs = [];
            obj.CurrentExtensorMUs = [];
            obj.CurrentFs = [];
            cla(obj.Axes);
            legend(obj.Axes, 'off');
            colorbar(obj.Axes, 'off');
            drawnow;
        end

        function refresh(obj)
            % 决定数据来源
            if ~isempty(obj.CurrentSpikeTrain)
                spikeTrain = obj.CurrentSpikeTrain;
                fs = obj.CurrentFs;
                nFlexorMUs = obj.CurrentFlexorMUs;
                nExtensorMUs = obj.CurrentExtensorMUs;
            else
                spikeTrain = obj.MainApp.SpikeTrainMatrix;
                if isempty(spikeTrain)
                    cla(obj.Axes);
                    drawnow;
                    return;
                end
                fs = obj.MainApp.Fs;
                nFlexorMUs = obj.MainApp.NFlexorMUs;
                nExtensorMUs = obj.MainApp.NExtensorMUs;
            end

            [nMU, nSamples] = size(spikeTrain);
            if nMU == 0 || nSamples == 0
                cla(obj.Axes);
                drawnow;
                return;
            end

            cla(obj.Axes);
            hold(obj.Axes, 'on');

            % 使用 rug-plot 风格 (借鉴 plot_spikeTrain.m)
            barHeight = 0.2;
            rugCount = nMU;
            colors = turbo(rugCount);

            for r = 1:rugCount
                spikeSamples = find(spikeTrain(r, :));
                if isempty(spikeSamples)
                    continue;
                end
                xVals = [spikeSamples; spikeSamples];
                yBase = barHeight * (r - 1);
                yVals = [zeros(1, length(spikeSamples)); ...
                         ones(1, length(spikeSamples)) * barHeight * 0.7] + yBase;
                line(obj.Axes, xVals, yVals, 'Color', colors(r, :), 'LineWidth', 0.5);
            end

            % X 轴: 样本索引转时间 (秒)
            totalTimeSec = nSamples / fs;
            stepSec = max(1, round(totalTimeSec / 5));
            maxSec = floor(totalTimeSec);
            xtickLocs = (0:stepSec:maxSec) * fs;
            xtickLabels = 0:stepSec:maxSec;

            obj.Axes.XLim = [0, nSamples];
            obj.Axes.XTick = xtickLocs;
            obj.Axes.XTickLabel = xtickLabels;
            xlabel(obj.Axes, '时间 (s)');

            % Y 轴: MU 编号
            obj.Axes.YLim = [0, rugCount * barHeight];
            obj.Axes.YTick = barHeight * (0.5:1:rugCount);
            obj.Axes.YTickLabel = arrayfun(@(x) sprintf('MU%d', x), 1:rugCount, ...
                'UniformOutput', false);
            ylabel(obj.Axes, 'MU编号');

            % 屈肌/伸肌分界线
            hasFlexor = ~isempty(nFlexorMUs) && nFlexorMUs > 0;
            hasExtensor = ~isempty(nExtensorMUs) && nExtensorMUs > 0;
            if hasFlexor && hasExtensor && nFlexorMUs < rugCount
                yLine = nFlexorMUs * barHeight;
                yline(obj.Axes, yLine, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
                text(obj.Axes, nSamples * 0.02, nFlexorMUs * barHeight * 0.5, '屈肌', ...
                    'FontSize', 9, 'Color', config.AppConstants.COLOR_FLEXOR);
                text(obj.Axes, nSamples * 0.02, (nFlexorMUs + nExtensorMUs * 0.5) * barHeight, '伸肌', ...
                    'FontSize', 9, 'Color', config.AppConstants.COLOR_EXTENSOR);
            end

            grid(obj.Axes, 'on');
            drawnow;
        end

        function exportSpikeTrains(obj)
            if ~isempty(obj.CurrentSpikeTrain)
                spikeTrain = obj.CurrentSpikeTrain;
                fs = obj.CurrentFs;
                timeVector = (0:size(spikeTrain,2)-1) / fs;
            else
                spikeTrain = obj.MainApp.SpikeTrainMatrix;
                if isempty(spikeTrain)
                    uialert(ancestor(obj.Parent, 'figure', 'toplevel'), '无可导出的发放序列', '提示');
                    return;
                end
                fs = obj.MainApp.Fs;
                timeVector = obj.MainApp.TimeVector;
            end

            [file, path] = uiputfile('*.csv', '导出发放序列');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);
            services.DataExportService.exportSpikeTrainsCSV(spikeTrain, fs, timeVector, fullPath);
            obj.MainApp.log(sprintf('发放序列已导出: %s', fullPath));
        end
    end
end