classdef DataManagementTab
    % DataManagementTab - 数据管理Tab

    properties (Access = private)
        Parent
        MainApp
        SessionBrowser
    end

    methods
        function obj = DataManagementTab(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.buildUI();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants
            import models.SessionData

            % 删除旧占位符
            delete(obj.Parent.Children);

            mainGrid = uigridlayout(obj.Parent, [2, 2], ...
                'RowHeight', {'1x', '1x'}, ...
                'ColumnWidth', {'3x', '2x'}, ...
                'Padding', [AppConstants.PADDING, AppConstants.PADDING, ...
                           AppConstants.PADDING, AppConstants.PADDING], ...
                'RowSpacing', AppConstants.ROW_SPACING, ...
                'ColumnSpacing', AppConstants.COL_SPACING);

            % ---- 左上: 会话浏览 ----
            sessionPanel = uipanel(mainGrid, 'Title', '会话浏览', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.SessionBrowser = ui.components.SessionBrowser(sessionPanel, obj.MainApp);

            % ---- 右上: 进度趋势 ----
            trendPanel = uipanel(mainGrid, 'Title', '康复趋势', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildTrendPanel(trendPanel);

            % ---- 左下: 数据导入导出 ----
            ioPanel = uipanel(mainGrid, 'Title', '数据导入导出', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildIOPanel(ioPanel);

            % ---- 右下: 数据统计 ----
            statPanel = uipanel(mainGrid, 'Title', '数据统计', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildStatPanel(statPanel);
        end

        function buildTrendPanel(obj, parent)
            import config.AppConstants

            tg = uigridlayout(parent, [3, 1], ...
                'Padding', [5, 5, 5, 5], 'RowSpacing', 2);

            ax1 = uiaxes(tg);
            title(ax1, '角度预测 RMSE 趋势', 'FontName', AppConstants.FONT_NAME);
            xlabel(ax1, '会话序号', 'FontName', AppConstants.FONT_NAME);
            ylabel(ax1, 'RMSE (°)', 'FontName', AppConstants.FONT_NAME);
            grid(ax1, 'on');

            ax2 = uiaxes(tg);
            title(ax2, '力预测 RMSE 趋势', 'FontName', AppConstants.FONT_NAME);
            xlabel(ax2, '会话序号', 'FontName', AppConstants.FONT_NAME);
            ylabel(ax2, 'RMSE (%MVC)', 'FontName', AppConstants.FONT_NAME);
            grid(ax2, 'on');

            ax3 = uiaxes(tg);
            title(ax3, '综合评分趋势', 'FontName', AppConstants.FONT_NAME);
            xlabel(ax3, '会话序号', 'FontName', AppConstants.FONT_NAME);
            ylabel(ax3, '得分', 'FontName', AppConstants.FONT_NAME);
            grid(ax3, 'on');
        end

        function buildIOPanel(obj, parent)
            import config.AppConstants

            ioGrid = uigridlayout(parent, [3, 2], ...
                'Padding', [10, 10, 10, 10], ...
                'RowSpacing', 10, 'ColumnSpacing', 10);

            uibutton(ioGrid, 'Text', '📥 导入 MAT 文件...', ...
                'ButtonPushedFcn', @(~,~) obj.importMAT(), ...
                'FontName', AppConstants.FONT_NAME);
            uibutton(ioGrid, 'Text', '📥 导入 CSV 文件...', ...
                'ButtonPushedFcn', @(~,~) obj.importCSV(), ...
                'FontName', AppConstants.FONT_NAME);

            uibutton(ioGrid, 'Text', '📤 导出为 MAT', ...
                'ButtonPushedFcn', @(~,~) obj.exportMAT(), ...
                'FontName', AppConstants.FONT_NAME);
            uibutton(ioGrid, 'Text', '📤 导出为 CSV', ...
                'ButtonPushedFcn', @(~,~) obj.exportCSV(), ...
                'FontName', AppConstants.FONT_NAME);

            uibutton(ioGrid, 'Text', '📤 批量导出...', ...
                'ButtonPushedFcn', @(~,~) obj.batchExport(), ...
                'FontName', AppConstants.FONT_NAME);
        end

        function buildStatPanel(obj, parent)
            import config.AppConstants

            statGrid = uigridlayout(parent, [4, 4], ...
                'Padding', [10, 10, 10, 10], ...
                'RowSpacing', 5, 'ColumnSpacing', 5);

            stats = {'总患者数', '0'; '总会话数', '0'; '总录制时长', '0 h'; ...
                     '平均MU数', '-'; '平均角度RMSE', '-'; '最佳R²', '-'; ...
                     '存储占用', '-'; '最近会话', '-'};

            for i = 1:8
                uilabel(statGrid, 'Text', stats{i, 1}, ...
                    'FontName', AppConstants.FONT_NAME, ...
                    'FontColor', AppConstants.COLOR_TEXT_LIGHT, ...
                    'FontSize', AppConstants.FONT_SIZE_SMALL);
                uilabel(statGrid, 'Text', stats{i, 2}, ...
                    'FontName', AppConstants.FONT_NAME, ...
                    'FontWeight', 'bold', ...
                    'FontSize', AppConstants.FONT_SIZE_NORMAL);
            end
        end
    end

    %% ---- 导入导出回调 ----
    methods (Access = private)
        function importMAT(obj)
            [file, path] = uigetfile('*.mat', '选择MAT数据文件');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);
            try
                loaded = load(fullPath);
                % 填充到MainApp数据总线
                if isfield(loaded, 'rawData')
                    obj.MainApp.RawEmgData = loaded.rawData;
                end
                if isfield(loaded, 'fs')
                    obj.MainApp.Fs = loaded.fs;
                end
                if isfield(loaded, 'spikeTrain')
                    obj.MainApp.SpikeTrainMatrix = loaded.spikeTrain;
                    obj.MainApp.NMUs = size(loaded.spikeTrain, 1);
                end
                if isfield(loaded, 'trueAngle')
                    obj.MainApp.GroundTruthAngle = loaded.trueAngle;
                end
                if isfield(loaded, 'trueForce')
                    obj.MainApp.GroundTruthForce = loaded.trueForce;
                end
                obj.MainApp.log(sprintf('数据加载成功: %s', fullPath));
                uialert(obj.Parent, '数据加载成功!', '导入成功', 'Icon', 'success');
            catch e
                uialert(obj.Parent, sprintf('加载失败: %s', e.message), '导入失败', 'Icon', 'error');
            end
        end

        function importCSV(obj)
            [file, path] = uigetfile('*.csv', '选择CSV数据文件');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);
            try
                T = readtable(fullPath);
                disp(T.Properties.VariableNames);
                obj.MainApp.log(sprintf('CSV加载成功: %s', fullPath));
                uialert(obj.Parent, 'CSV数据加载成功!', '导入成功', 'Icon', 'success');
            catch e
                uialert(obj.Parent, sprintf('加载失败: %s', e.message), '导入失败', 'Icon', 'error');
            end
        end

        function exportMAT(obj)
            if isempty(obj.MainApp.RawEmgData)
                uialert(obj.Parent, '没有可导出的数据', '导出失败', 'Icon', 'warning');
                return;
            end
            [file, path] = uiputfile('*.mat', '保存MAT文件');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);
            services.DataExportService.saveFullData(fullPath, ...
                obj.MainApp.RawEmgData, obj.MainApp.Fs, ...
                obj.MainApp.SpikeTrainMatrix, ...
                obj.MainApp.FeatureMatrix, obj.MainApp.TimeVector, ...
                obj.MainApp.PredictedAngle, obj.MainApp.PredictedForce, ...
                obj.MainApp.GroundTruthAngle, obj.MainApp.GroundTruthForce, ...
                obj.MainApp.CurrentSession);
            obj.MainApp.log(sprintf('数据导出成功: %s', fullPath));
            uialert(obj.Parent, '数据导出成功!', '导出成功', 'Icon', 'success');
        end

        function exportCSV(obj)
            if isempty(obj.MainApp.PredictedAngle)
                uialert(obj.Parent, '没有预测结果可导出, 请先进行角度预测', '导出失败', 'Icon', 'warning');
                return;
            end
            [file, path] = uiputfile('*.csv', '保存CSV文件');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);
            services.DataExportService.exportPredictionCSV(...
                obj.MainApp.TimeVector, ...
                obj.MainApp.PredictedAngle, obj.MainApp.GroundTruthAngle, ...
                obj.MainApp.PredictedForce, obj.MainApp.GroundTruthForce, ...
                fullPath);
            obj.MainApp.log(sprintf('CSV导出成功: %s', fullPath));
            uialert(obj.Parent, 'CSV导出成功!', '导出成功', 'Icon', 'success');
        end

        function batchExport(obj)
            uialert(obj.Parent, '批量导出功能将在后续版本中实现', '提示', 'Icon', 'info');
        end
    end
end
