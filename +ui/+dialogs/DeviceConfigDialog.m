classdef DeviceConfigDialog
    % DeviceConfigDialog - 设备配置弹窗

    methods (Static)
        function config = show(parent, currentConfig)
            % 显示设备配置对话框
            import config.AppConstants

            dlg = uifigure('Name', '设备配置', ...
                'Position', [500, 400, 450, 350], ...
                'Resize', 'off', ...
                'WindowStyle', 'modal');

            grid = uigridlayout(dlg, [6, 2], ...
                'Padding', [20, 20, 20, 20], ...
                'RowSpacing', 15, 'ColumnSpacing', 10);

            uilabel(grid, 'Text', '设备类型:', 'FontName', AppConstants.FONT_NAME);
            ddType = uidropdown(grid, 'Items', {'HD-sEMG (128ch)', 'BioSemi (64ch)', '模拟设备'}, ...
                'Value', 'HD-sEMG (128ch)', 'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '采样率 (Hz):', 'FontName', AppConstants.FONT_NAME);
            spFS = uispinner(grid, 'Value', 2000, 'Limits', [500, 4000], 'Step', 100, ...
                'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', 'IP地址:', 'FontName', AppConstants.FONT_NAME);
            efIP = uieditfield(grid, 'Value', '192.168.1.100', 'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '端口:', 'FontName', AppConstants.FONT_NAME);
            efPort = uieditfield(grid, 'numeric', 'Value', 5000, 'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '缓冲区大小 (MB):', 'FontName', AppConstants.FONT_NAME);
            spBuffer = uispinner(grid, 'Value', 256, 'Limits', [64, 1024], 'Step', 64, ...
                'FontName', AppConstants.FONT_NAME);

            btnGrid = uigridlayout(grid, [1, 2], 'ColumnWidth', {'1x', '1x'});
            btnGrid.Layout.Column = [1, 2];

            uibutton(btnGrid, 'Text', '确定', ...
                'BackgroundColor', AppConstants.COLOR_PRIMARY, ...
                'FontColor', [1 1 1], 'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', 'uiresume(gcbf)');
            uibutton(btnGrid, 'Text', '取消', 'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', 'delete(gcbf)');

            uiwait(dlg);

            if isvalid(dlg)
                config = models.AcquisitionConfig();
                config.DeviceType = ddType.Value;
                config.Fs = spFS.Value;
                delete(dlg);
            else
                config = [];
            end
        end
    end
end
