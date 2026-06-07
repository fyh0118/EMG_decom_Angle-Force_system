classdef BiofeedbackPanel
    % BiofeedbackPanel - 实时生物反馈面板（角度追踪 + 力追踪）

    properties (Access = private)
        Parent
        MainApp
        AxAngle
        AxForce
        GaugeAngleTracking
        GaugeForceTracking
        GaugeLiveScore
        GaugeForceLevel
    end

    methods
        function obj = BiofeedbackPanel(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.buildUI();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            mainGrid = uigridlayout(obj.Parent, [2, 2], ...
                'RowHeight', {'2x', '1x'}, ...
                'ColumnWidth', {'1x', '1x'}, ...
                'Padding', [2, 2, 2, 2], ...
                'RowSpacing', 4, 'ColumnSpacing', 4);

            % 左上: 角度追踪
            anglePanel = uipanel(mainGrid, 'Title', '角度追踪反馈', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.AxAngle = uiaxes(anglePanel);
            xlabel(obj.AxAngle, '时间 (s)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.AxAngle, '角度 (°)', 'FontName', AppConstants.FONT_NAME);
            title(obj.AxAngle, '实际 vs 目标轨迹', 'FontName', AppConstants.FONT_NAME);
            hold(obj.AxAngle, 'on');
            grid(obj.AxAngle, 'on');

            % 右上: 力追踪
            forcePanel = uipanel(mainGrid, 'Title', '力追踪反馈', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.AxForce = uiaxes(forcePanel);
            xlabel(obj.AxForce, '时间 (s)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.AxForce, '力 (%MVC)', 'FontName', AppConstants.FONT_NAME);
            title(obj.AxForce, '实际 vs 目标力', 'FontName', AppConstants.FONT_NAME);
            hold(obj.AxForce, 'on');
            grid(obj.AxForce, 'on');

            % 左下: 实时仪表
            gaugeGrid = uigridlayout(mainGrid, [1, 4], ...
                'Padding', [5, 5, 5, 5], 'ColumnSpacing', 5);

            obj.GaugeAngleTracking = obj.makeGauge(gaugeGrid, '角度跟踪 (%)', 100);
            obj.GaugeForceTracking = obj.makeGauge(gaugeGrid, '力跟踪 (%)', 100);
            obj.GaugeForceLevel = obj.makeGauge(gaugeGrid, '力水平 (%MVC)', 50);
            obj.GaugeLiveScore = obj.makeGauge(gaugeGrid, '实时得分', 100);
        end

        function g = makeGauge(~, parent, title, limit)
            import config.AppConstants
            panel = uipanel(parent, 'BorderType', 'none', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG);
            gGrid = uigridlayout(panel, [2, 1], ...
                'Padding', [2, 2, 2, 2], 'RowSpacing', 2);
            g = uigauge(gGrid, 'limits', [0, limit], 'value', 0);
            uilabel(gGrid, 'Text', title, 'HorizontalAlignment', 'center', ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_SMALL);
        end
    end

    methods (Access = public)
        function updateTracking(obj, timeVector, predictedAngle, targetAngle, ...
                predictedForce, targetForce, toleranceDeg, toleranceForce)
            % 更新追踪显示
            import config.AppConstants

            % ---- 角度追踪曲线 ----
            cla(obj.AxAngle);
            hold(obj.AxAngle, 'on');

            if ~isempty(targetAngle)
                plot(obj.AxAngle, timeVector, targetAngle, '--', ...
                    'Color', AppConstants.COLOR_TARGET, 'LineWidth', 1.5, ...
                    'DisplayName', '目标轨迹');
                % 容差带
                patch(obj.AxAngle, ...
                    [timeVector; flipud(timeVector)], ...
                    [targetAngle - toleranceDeg; flipud(targetAngle + toleranceDeg)], ...
                    AppConstants.COLOR_ERROR_BAND, 'FaceAlpha', 0.15, ...
                    'EdgeColor', 'none', 'DisplayName', '容差带');
            end

            if ~isempty(predictedAngle)
                plot(obj.AxAngle, timeVector, predictedAngle, '-', ...
                    'Color', AppConstants.COLOR_PRED_ANGLE, 'LineWidth', 2, ...
                    'DisplayName', '预测角度');
            end

            legend(obj.AxAngle, 'Location', 'best');
            xlabel(obj.AxAngle, '时间 (s)');
            ylabel(obj.AxAngle, '角度 (°)');
            grid(obj.AxAngle, 'on');

            % ---- 力追踪曲线 ----
            cla(obj.AxForce);
            hold(obj.AxForce, 'on');

            if ~isempty(targetForce)
                plot(obj.AxForce, timeVector, targetForce, '--', ...
                    'Color', AppConstants.COLOR_TARGET, 'LineWidth', 1.5, ...
                    'DisplayName', '目标力');
                patch(obj.AxForce, ...
                    [timeVector; flipud(timeVector)], ...
                    [targetForce - toleranceForce; flipud(targetForce + toleranceForce)], ...
                    AppConstants.COLOR_ERROR_BAND, 'FaceAlpha', 0.15, ...
                    'EdgeColor', 'none', 'DisplayName', '容差带');
            end

            if ~isempty(predictedForce)
                plot(obj.AxForce, timeVector, predictedForce, '-', ...
                    'Color', AppConstants.COLOR_PRED_FORCE, 'LineWidth', 2, ...
                    'DisplayName', '预测力');
            end

            legend(obj.AxForce, 'Location', 'best');
            xlabel(obj.AxForce, '时间 (s)');
            ylabel(obj.AxForce, '力 (%MVC)');
            grid(obj.AxForce, 'on');
        end

        function updateGauges(obj, angleAccuracy, forceAccuracy, forceLevel, liveScore)
            if nargin >= 2, obj.GaugeAngleTracking.Value = angleAccuracy; end
            if nargin >= 3, obj.GaugeForceTracking.Value = forceAccuracy; end
            if nargin >= 4, obj.GaugeForceLevel.Value = min(forceLevel, 100); end
            if nargin >= 5, obj.GaugeLiveScore.Value = liveScore; end
        end
    end
end
