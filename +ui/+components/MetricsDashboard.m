classdef MetricsDashboard
    % MetricsDashboard - 角度+力双指标仪表盘组件

    properties (Access = private)
        Parent
        MainApp
        % 角度指标
        GaugeAngleRMSE
        GaugeAngleMAE
        GaugeAngleR2
        GaugeAngleCC
        LabelAngleRMSE
        LabelAngleR2
        % 力指标
        GaugeForceRMSE
        GaugeForceMAE
        GaugeForceR2
        GaugeForceCC
        LabelForceRMSE
        LabelForceR2
        % 对比表格
        ComparisonTable
    end

    methods
        function obj = MetricsDashboard(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.buildUI();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            mainGrid = uigridlayout(obj.Parent, [1, 3], ...
                'Padding', [2, 2, 2, 2], ...
                'ColumnWidth', {'1x', '1x', '1x'}, ...
                'ColumnSpacing', 10);

            % 第1列: 角度指标
            anglePanel = uipanel(mainGrid, 'Title', '角度预测指标', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildAngleGauges(anglePanel);

            % 第2列: 力指标
            forcePanel = uipanel(mainGrid, 'Title', '力预测指标', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildForceGauges(forcePanel);

            % 第3列: 方法对比表
            compPanel = uipanel(mainGrid, 'Title', '方法对比 (CNN-biLSTM vs RMS)', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildComparisonTable(compPanel);
        end

        function buildAngleGauges(obj, parent)
            import config.AppConstants

            ag = uigridlayout(parent, [4, 2], ...
                'Padding', [5, 5, 5, 5], ...
                'RowHeight', {'1x', 'fit', '1x', 'fit'});

            obj.GaugeAngleRMSE = uigauge(ag, 'limits', [0, 15], 'value', 0);
            obj.LabelAngleRMSE = uilabel(ag, 'Text', 'RMSE: --°', ...
                'HorizontalAlignment', 'center', 'FontName', AppConstants.FONT_NAME);

            obj.GaugeAngleMAE = uigauge(ag, 'limits', [0, 15], 'value', 0);
            uilabel(ag, 'Text', 'MAE: --°', ...
                'HorizontalAlignment', 'center', 'FontName', AppConstants.FONT_NAME);

            obj.GaugeAngleR2 = uigauge(ag, 'limits', [0, 1], 'value', 0);
            obj.LabelAngleR2 = uilabel(ag, 'Text', 'R²: --', ...
                'HorizontalAlignment', 'center', 'FontName', AppConstants.FONT_NAME);

            obj.GaugeAngleCC = uigauge(ag, 'limits', [0, 1], 'value', 0);
            uilabel(ag, 'Text', 'CC: --', ...
                'HorizontalAlignment', 'center', 'FontName', AppConstants.FONT_NAME);
        end

        function buildForceGauges(obj, parent)
            import config.AppConstants

            fg = uigridlayout(parent, [4, 2], ...
                'Padding', [5, 5, 5, 5], ...
                'RowHeight', {'1x', 'fit', '1x', 'fit'});

            obj.GaugeForceRMSE = uigauge(fg, 'limits', [0, 20], 'value', 0);
            obj.LabelForceRMSE = uilabel(fg, 'Text', 'RMSE: --%MVC', ...
                'HorizontalAlignment', 'center', 'FontName', AppConstants.FONT_NAME);

            obj.GaugeForceMAE = uigauge(fg, 'limits', [0, 20], 'value', 0);
            uilabel(fg, 'Text', 'MAE: --%MVC', ...
                'HorizontalAlignment', 'center', 'FontName', AppConstants.FONT_NAME);

            obj.GaugeForceR2 = uigauge(fg, 'limits', [0, 1], 'value', 0);
            obj.LabelForceR2 = uilabel(fg, 'Text', 'R²: --', ...
                'HorizontalAlignment', 'center', 'FontName', AppConstants.FONT_NAME);

            obj.GaugeForceCC = uigauge(fg, 'limits', [0, 1], 'value', 0);
            uilabel(fg, 'Text', 'CC: --', ...
                'HorizontalAlignment', 'center', 'FontName', AppConstants.FONT_NAME);
        end

        function buildComparisonTable(obj, parent)
            obj.ComparisonTable = uitable(parent, ...
                'ColumnName', {'指标', 'CNN-biLSTM', 'RMS基线', '提升'}, ...
                'ColumnWidth', {80, 90, 90, 60}, ...
                'FontName', config.AppConstants.FONT_NAME, ...
                'FontSize', config.AppConstants.FONT_SIZE_SMALL);
        end
    end

    methods (Access = public)
        function updateMetrics(obj, angleMetrics, forceMetrics)
            % 更新所有指标
            import config.AppConstants

            if nargin >= 2 && ~isempty(angleMetrics)
                obj.GaugeAngleRMSE.Value = min(angleMetrics.RMSE, 15);
                obj.LabelAngleRMSE.Text = sprintf('RMSE: %.2f°', angleMetrics.RMSE);
                obj.GaugeAngleR2.Value = max(0, min(angleMetrics.R2, 1));
                obj.LabelAngleR2.Text = sprintf('R²: %.3f', angleMetrics.R2);
                obj.GaugeAngleCC.Value = max(0, min(angleMetrics.CC, 1));
                if isfield(angleMetrics, 'MAE')
                    obj.GaugeAngleMAE.Value = min(angleMetrics.MAE, 15);
                end
            end

            if nargin >= 3 && ~isempty(forceMetrics)
                obj.GaugeForceRMSE.Value = min(forceMetrics.RMSE, 20);
                obj.LabelForceRMSE.Text = sprintf('RMSE: %.2f%%MVC', forceMetrics.RMSE);
                obj.GaugeForceR2.Value = max(0, min(forceMetrics.R2, 1));
                obj.LabelForceR2.Text = sprintf('R²: %.3f', forceMetrics.R2);
                obj.GaugeForceCC.Value = max(0, min(forceMetrics.CC, 1));
                if isfield(forceMetrics, 'MAE')
                    obj.GaugeForceMAE.Value = min(forceMetrics.MAE, 20);
                end
            end
        end

        function updateComparisonTable(obj, ourMetrics, rmsBaselineMetrics)
            % 更新对比表
            tableData = cell(4, 4);

            if ~isempty(ourMetrics) && ~isempty(rmsBaselineMetrics)
                % 角度RMSE
                tableData{1, 1} = '角度RMSE (°)';
                tableData{1, 2} = sprintf('%.2f', ourMetrics.Angle.RMSE);
                tableData{1, 3} = sprintf('%.2f', rmsBaselineMetrics.RMSE);
                improv = (rmsBaselineMetrics.RMSE - ourMetrics.Angle.RMSE) / rmsBaselineMetrics.RMSE * 100;
                tableData{1, 4} = sprintf('%.1f%%', improv);

                % 角度R²
                tableData{2, 1} = '角度 R²';
                tableData{2, 2} = sprintf('%.3f', ourMetrics.Angle.R2);
                tableData{2, 3} = sprintf('%.3f', rmsBaselineMetrics.R2);
                improv = (ourMetrics.Angle.R2 - rmsBaselineMetrics.R2) / rmsBaselineMetrics.R2 * 100;
                tableData{2, 4} = sprintf('%.1f%%', improv);

                % 力RMSE (如果可用)
                tableData{3, 1} = '力RMSE (%MVC)';
                tableData{3, 2} = sprintf('%.2f', ourMetrics.Force.RMSE);
                tableData{3, 3} = '-';
                tableData{3, 4} = '-';

                % 力R²
                tableData{4, 1} = '力 R²';
                tableData{4, 2} = sprintf('%.3f', ourMetrics.Force.R2);
                tableData{4, 3} = '-';
                tableData{4, 4} = '-';

                obj.ComparisonTable.Data = tableData;
            end
        end
    end
end
