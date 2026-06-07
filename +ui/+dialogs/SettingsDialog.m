classdef SettingsDialog
    % SettingsDialog - 通用设置弹窗

    methods (Static)
        function show(parent, mainApp)
            import config.AppConstants

            dlg = uifigure('Name', '系统设置', ...
                'Position', [500, 400, 450, 350], ...
                'Resize', 'off', 'WindowStyle', 'modal');

            grid = uigridlayout(dlg, [6, 2], ...
                'Padding', [20, 20, 20, 20], ...
                'RowSpacing', 12, 'ColumnSpacing', 10);

            uilabel(grid, 'Text', '默认采样率 (Hz):', 'FontName', AppConstants.FONT_NAME);
            spFS = uispinner(grid, 'Value', 2000, 'Limits', [500, 4000], ...
                'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '默认窗长 (ms):', 'FontName', AppConstants.FONT_NAME);
            spWin = uispinner(grid, 'Value', 200, 'Limits', [50, 1000], 'Step', 50, ...
                'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '默认步长 (ms):', 'FontName', AppConstants.FONT_NAME);
            spStep = uispinner(grid, 'Value', 100, 'Limits', [10, 500], 'Step', 10, ...
                'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '数据保存路径:', 'FontName', AppConstants.FONT_NAME);
            efPath = uieditfield(grid, 'Value', pwd, 'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '语言:', 'FontName', AppConstants.FONT_NAME);
            ddLang = uidropdown(grid, 'Items', {'中文', 'English'}, 'Value', '中文', ...
                'FontName', AppConstants.FONT_NAME);

            btnGrid = uigridlayout(grid, [1, 2]);
            btnGrid.Layout.Column = [1, 2];
            uibutton(btnGrid, 'Text', '保存设置', ...
                'BackgroundColor', AppConstants.COLOR_PRIMARY, ...
                'FontColor', [1 1 1], 'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', 'uiresume(gcbf)');
            uibutton(btnGrid, 'Text', '取消', 'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', 'delete(gcbf)');

            uiwait(dlg);
            if isvalid(dlg), delete(dlg); end
        end
    end
end
