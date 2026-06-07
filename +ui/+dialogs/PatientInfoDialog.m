classdef PatientInfoDialog
    % PatientInfoDialog - 患者信息编辑弹窗

    methods (Static)
        function patient = show(parent, existingPatient)
            import config.AppConstants

            dlg = uifigure('Name', '患者信息', ...
                'Position', [500, 400, 400, 450], ...
                'Resize', 'off', 'WindowStyle', 'modal');

            grid = uigridlayout(dlg, [7, 2], ...
                'Padding', [20, 20, 20, 20], ...
                'RowSpacing', 10, 'ColumnSpacing', 10);

            uilabel(grid, 'Text', '患者ID:', 'FontName', AppConstants.FONT_NAME);
            efID = uieditfield(grid, 'Value', '', 'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '姓名:', 'FontName', AppConstants.FONT_NAME);
            efName = uieditfield(grid, 'Value', '', 'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '性别:', 'FontName', AppConstants.FONT_NAME);
            ddGender = uidropdown(grid, 'Items', {'男', '女'}, 'Value', '男', ...
                'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '年龄:', 'FontName', AppConstants.FONT_NAME);
            spAge = uispinner(grid, 'Value', 30, 'Limits', [1, 120], ...
                'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '患侧:', 'FontName', AppConstants.FONT_NAME);
            ddSide = uidropdown(grid, 'Items', {'左侧', '右侧'}, 'Value', '右侧', ...
                'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '诊断:', 'FontName', AppConstants.FONT_NAME);
            efDiag = uieditfield(grid, 'Value', '', 'FontName', AppConstants.FONT_NAME);

            uilabel(grid, 'Text', '备注:', 'FontName', AppConstants.FONT_NAME);
            taNotes = uitextarea(grid, 'Value', '', ...
                'FontName', AppConstants.FONT_NAME);

            % 如果传入已有患者信息, 填充
            if nargin >= 2 && ~isempty(existingPatient)
                efID.Value = existingPatient.PatientID;
                efName.Value = existingPatient.Name;
                spAge.Value = existingPatient.Age;
                efDiag.Value = existingPatient.Diagnosis;
                taNotes.Value = existingPatient.Notes;
            end

            btnGrid = uigridlayout(grid, [1, 2]);
            btnGrid.Layout.Column = [1, 2];
            uibutton(btnGrid, 'Text', '确定', ...
                'BackgroundColor', AppConstants.COLOR_PRIMARY, ...
                'FontColor', [1 1 1], 'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', 'uiresume(gcbf)');
            uibutton(btnGrid, 'Text', '取消', 'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', 'delete(gcbf)');

            uiwait(dlg);

            if isvalid(dlg)
                patient = models.PatientInfo();
                patient.PatientID = efID.Value;
                patient.Name = efName.Value;
                patient.Gender = ddGender.Value;
                patient.Age = spAge.Value;
                patient.AffectedSide = ddSide.Value;
                patient.Diagnosis = efDiag.Value;
                patient.Notes = taNotes.Value;
                delete(dlg);
            else
                patient = [];
            end
        end
    end
end
