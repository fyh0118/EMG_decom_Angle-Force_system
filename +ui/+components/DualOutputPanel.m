classdef DualOutputPanel
    % DualOutputPanel - 角度+力双输出预测曲线对比组件
    %   核心展示组件: 上方角度对比, 下方力对比, 可叠加RMS基线

    properties (Access = private)
        Parent
        MainApp
        AxAngle
        AxAngleError
        AxForce
        AxForceError
    end

    properties
        ShowRMSComparison logical = false
        DisplayRangeSec   double  = 10
    end

    methods
        function obj = DualOutputPanel(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.buildUI();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            mainGrid = uigridlayout(obj.Parent, [2, 2], ...
                'RowHeight', {'1x', '1x'}, ...
                'ColumnWidth', {'2x', '1x'}, ...
                'Padding', [2, 2, 2, 2], ...
                'RowSpacing', 4, 'ColumnSpacing', 4);

            % 左上: 角度预测曲线
            anglePanel = uipanel(mainGrid, 'Title', '腕关节角度预测', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.AxAngle = uiaxes(anglePanel);
            xlabel(obj.AxAngle, '时间 (s)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.AxAngle, '角度 (°)', 'FontName', AppConstants.FONT_NAME);
            title(obj.AxAngle, '真实值 vs 预测值', 'FontName', AppConstants.FONT_NAME);
            hold(obj.AxAngle, 'on');
            grid(obj.AxAngle, 'on');

            % 右上: 角度误差分布
            angleErrPanel = uipanel(mainGrid, 'Title', '角度误差分布', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.AxAngleError = uiaxes(angleErrPanel);
            xlabel(obj.AxAngleError, '误差 (°)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.AxAngleError, '频次', 'FontName', AppConstants.FONT_NAME);
            title(obj.AxAngleError, '角度误差直方图', 'FontName', AppConstants.FONT_NAME);
            grid(obj.AxAngleError, 'on');

            % 左下: 力预测曲线
            forcePanel = uipanel(mainGrid, 'Title', '力输出预测 (%MVC)', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.AxForce = uiaxes(forcePanel);
            xlabel(obj.AxForce, '时间 (s)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.AxForce, '力 (%MVC)', 'FontName', AppConstants.FONT_NAME);
            title(obj.AxForce, '真实值 vs 预测值', 'FontName', AppConstants.FONT_NAME);
            hold(obj.AxForce, 'on');
            grid(obj.AxForce, 'on');

            % 右下: 力误差分布
            forceErrPanel = uipanel(mainGrid, 'Title', '力误差分布', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.AxForceError = uiaxes(forceErrPanel);
            xlabel(obj.AxForceError, '误差 (%MVC)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.AxForceError, '频次', 'FontName', AppConstants.FONT_NAME);
            title(obj.AxForceError, '力误差直方图', 'FontName', AppConstants.FONT_NAME);
            grid(obj.AxForceError, 'on');
        end
    end

    methods (Access = public)
        function refresh(obj)
            import config.AppConstants

            timeVec = obj.MainApp.TimeVector;
            predAngle = obj.MainApp.PredictedAngle;
            predForce = obj.MainApp.PredictedForce;
            trueAngle = obj.MainApp.GroundTruthAngle;
            trueForce = obj.MainApp.GroundTruthForce;

            if isempty(timeVec) || isempty(predAngle)
                return;
            end

            % ---- 角度预测曲线 ----
            cla(obj.AxAngle);
            hold(obj.AxAngle, 'on');

            % 降采样标签数据以匹配预测时间点
            if ~isempty(trueAngle)
                nPred = length(predAngle);
                nTrue = length(trueAngle);
                if nTrue > nPred
                    % 从原始标签降采样以匹配预测窗口
                    factor = round(nTrue / nPred);
                    trueAngleDS = trueAngle(round(factor/2):factor:end);
                    trueAngleDS = trueAngleDS(1:min(nPred, length(trueAngleDS)));
                else
                    trueAngleDS = trueAngle(1:min(nPred, nTrue));
                end
                plot(obj.AxAngle, timeVec, trueAngleDS, ...
                    'Color', AppConstants.COLOR_TRUE_ANGLE, 'LineWidth', 1.5, ...
                    'DisplayName', '真实角度');
            end

            plot(obj.AxAngle, timeVec, predAngle, ...
                'Color', AppConstants.COLOR_PRED_ANGLE, 'LineWidth', 1.5, ...
                'DisplayName', '预测角度 (CNN-biLSTM)');

            legend(obj.AxAngle, 'Location', 'best');
            xlabel(obj.AxAngle, '时间 (s)');
            ylabel(obj.AxAngle, '角度 (°)');
            grid(obj.AxAngle, 'on');

            % ---- 角度误差直方图 ----
            cla(obj.AxAngleError);
            if ~isempty(trueAngle) && exist('trueAngleDS', 'var')
                angleError = predAngle - trueAngleDS(:);
                histogram(obj.AxAngleError, angleError, 30, ...
                    'FaceColor', AppConstants.COLOR_PRIMARY, ...
                    'EdgeColor', 'none');
                xline(obj.AxAngleError, mean(angleError), 'r--', 'LineWidth', 1.5);
                xline(obj.AxAngleError, 0, 'k-');
                xlabel(obj.AxAngleError, '误差 (°)');
                ylabel(obj.AxAngleError, '频次');
                title(obj.AxAngleError, sprintf('角度误差 (Mean=%.2f°, Std=%.2f°)', ...
                    mean(angleError), std(angleError)));
            end

            % ---- 力预测曲线 ----
            cla(obj.AxForce);
            hold(obj.AxForce, 'on');

            if ~isempty(trueForce)
                nPred = length(predForce);
                nTrue = length(trueForce);
                if nTrue > nPred
                    factor = round(nTrue / nPred);
                    trueForceDS = trueForce(round(factor/2):factor:end);
                    trueForceDS = trueForceDS(1:min(nPred, length(trueForceDS)));
                else
                    trueForceDS = trueForce(1:min(nPred, nTrue));
                end
                plot(obj.AxForce, timeVec, trueForceDS, ...
                    'Color', AppConstants.COLOR_TRUE_FORCE, 'LineWidth', 1.5, ...
                    'DisplayName', '真实力');
            end

            plot(obj.AxForce, timeVec, predForce, ...
                'Color', AppConstants.COLOR_PRED_FORCE, 'LineWidth', 1.5, ...
                'DisplayName', '预测力 (CNN-biLSTM)');

            legend(obj.AxForce, 'Location', 'best');
            xlabel(obj.AxForce, '时间 (s)');
            ylabel(obj.AxForce, '力 (%MVC)');
            grid(obj.AxForce, 'on');

            % ---- 力误差直方图 ----
            cla(obj.AxForceError);
            if ~isempty(trueForce) && exist('trueForceDS', 'var')
                forceError = predForce - trueForceDS(:);
                histogram(obj.AxForceError, forceError, 30, ...
                    'FaceColor', AppConstants.COLOR_SECONDARY, ...
                    'EdgeColor', 'none');
                xline(obj.AxForceError, mean(forceError), 'r--', 'LineWidth', 1.5);
                xline(obj.AxForceError, 0, 'k-');
                xlabel(obj.AxForceError, '误差 (%MVC)');
                ylabel(obj.AxForceError, '频次');
                title(obj.AxForceError, sprintf('力误差 (Mean=%.2f, Std=%.2f)', ...
                    mean(forceError), std(forceError)));
            end
        end
    end
end
