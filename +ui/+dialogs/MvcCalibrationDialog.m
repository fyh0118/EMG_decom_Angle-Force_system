classdef MvcCalibrationDialog
    % MvcCalibrationDialog - MVC校准弹窗

    methods (Static)
        function [mvcFlexor, mvcExtensor] = show(parent)
            import config.AppConstants

            dlg = uifigure('Name', 'MVC校准', ...
                'Position', [500, 400, 400, 250], ...
                'Resize', 'off', 'WindowStyle', 'modal');

            grid = uigridlayout(dlg, [4, 1], ...
                'Padding', [20, 20, 20, 20], ...
                'RowSpacing', 15);

            uilabel(grid, 'Text', '最大随意收缩 (MVC) 校准', ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center');

            uilabel(grid, 'Text', ['请做拇指食指侧捏动作，用最大力保持3秒。' newline ...
                '系统将自动记录并计算MVC值。'], ...
                'FontName', AppConstants.FONT_NAME, ...
                'HorizontalAlignment', 'center');

            gauge = uigauge(grid, 'limits', [0, 100], 'value', 0);

            btnGrid = uigridlayout(grid, [1, 2]);
            uibutton(btnGrid, 'Text', '开始校准', ...
                'BackgroundColor', AppConstants.COLOR_PRIMARY, ...
                'FontColor', [1 1 1], 'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) MvcCalibrationDialog.startCalibration(gauge));
            uibutton(btnGrid, 'Text', '完成', 'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', 'uiresume(gcbf)');

            uiwait(dlg);

            if isvalid(dlg)
                mvcFlexor = 1.0;
                mvcExtensor = 1.0;
                delete(dlg);
            else
                mvcFlexor = [];
                mvcExtensor = [];
            end
        end

        function startCalibration(gauge)
            % 模拟MVC校准过程
            for i = 0:10:100
                gauge.Value = i;
                pause(0.1);
            end
            gauge.Value = 100;
        end
    end
end
