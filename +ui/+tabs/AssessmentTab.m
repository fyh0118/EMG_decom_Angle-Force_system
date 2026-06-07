classdef AssessmentTab
    % AssessmentTab - 康复评估Tab（角度+力双反馈）

    properties (Access = private)
        Parent
        MainApp
        BiofeedbackPanel
        RadarAxes
        % 患者信息
        UIPatientName
        UIPatientID
        UIAffectedSide
        UIDiagnosis
        % 评估方案
        UIMovementType
        UITargetForce
        UIRepetitions
        UITargetROM
        UITargetTrajectory
        UITargetCycle
        % 评估结果
        UIRomLabel
        UISmoothnessLabel
        UIForceAccuracyLabel
        UIAngleRMSELabel
        UIForceRMSELabel
        UIOverallScore
        UIRecommendation
    end

    methods
        function obj = AssessmentTab(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.buildUI();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            delete(obj.Parent.Children);

            mainGrid = uigridlayout(obj.Parent, [3, 2], ...
                'RowHeight', {'fit', '2x', '1x'}, ...
                'ColumnWidth', {'1x', '1x'}, ...
                'Padding', [AppConstants.PADDING, AppConstants.PADDING, ...
                           AppConstants.PADDING, AppConstants.PADDING], ...
                'RowSpacing', AppConstants.ROW_SPACING, ...
                'ColumnSpacing', AppConstants.COL_SPACING);

            % ---- Row1 Col1: 患者信息 ----
            patientPanel = uipanel(mainGrid, 'Title', '患者信息', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildPatientPanel(patientPanel);

            % ---- Row1 Col2: 评估方案 ----
            protocolPanel = uipanel(mainGrid, 'Title', '评估方案配置', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildProtocolPanel(protocolPanel);

            % ---- Row2: 生物反馈 ----
            bioPanel = uipanel(mainGrid, 'Title', '生物反馈 (角度+力双追踪)', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            bioPanel.Layout.Column = [1, 2];
            obj.BiofeedbackPanel = ui.components.BiofeedbackPanel(bioPanel, obj.MainApp);

            % ---- Row3: 评估结果 + 雷达图 + 操作按钮 ----
            resultPanel = uipanel(mainGrid, 'Title', '评估结果', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildResultPanel(resultPanel);

            actionPanel = uipanel(mainGrid, 'Title', '操作', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildActionPanel(actionPanel);
        end

        function buildPatientPanel(obj, parent)
            import config.AppConstants

            pg = uigridlayout(parent, [4, 2], ...
                'Padding', [10, 8, 10, 8], ...
                'RowSpacing', 5, 'ColumnSpacing', 5);

            uilabel(pg, 'Text', '姓名:', 'FontName', AppConstants.FONT_NAME);
            obj.UIPatientName = uieditfield(pg, 'Value', '', 'FontName', AppConstants.FONT_NAME);
            uilabel(pg, 'Text', 'ID:', 'FontName', AppConstants.FONT_NAME);
            obj.UIPatientID = uieditfield(pg, 'Value', '', 'FontName', AppConstants.FONT_NAME);
            uilabel(pg, 'Text', '患侧:', 'FontName', AppConstants.FONT_NAME);
            obj.UIAffectedSide = uidropdown(pg, ...
                'Items', {'左侧', '右侧'}, 'Value', '右侧', 'FontName', AppConstants.FONT_NAME);
            uilabel(pg, 'Text', '诊断:', 'FontName', AppConstants.FONT_NAME);
            obj.UIDiagnosis = uieditfield(pg, 'Value', '', 'FontName', AppConstants.FONT_NAME);

            uibutton(pg, 'Text', '新建患者', 'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.newPatient());
            uibutton(pg, 'Text', '加载患者', 'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.loadPatient());
        end

        function buildProtocolPanel(obj, parent)
            import config.AppConstants

            pg = uigridlayout(parent, [3, 4], ...
                'Padding', [10, 8, 10, 8], ...
                'RowSpacing', 5, 'ColumnSpacing', 5);

            uilabel(pg, 'Text', '动作:', 'FontName', AppConstants.FONT_NAME);
            obj.UIMovementType = uidropdown(pg, ...
                'Items', {'屈腕', '伸腕'}, 'Value', '屈腕', 'FontName', AppConstants.FONT_NAME);
            uilabel(pg, 'Text', '目标力 (%MVC):', 'FontName', AppConstants.FONT_NAME);
            obj.UITargetForce = uispinner(pg, 'Value', 20, ...
                'Limits', [10, 50], 'Step', 5, 'FontName', AppConstants.FONT_NAME);
            uilabel(pg, 'Text', '重复次数:', 'FontName', AppConstants.FONT_NAME);
            obj.UIRepetitions = uispinner(pg, 'Value', 5, ...
                'Limits', [1, 30], 'FontName', AppConstants.FONT_NAME);
            uilabel(pg, 'Text', 'ROM目标 (°):', 'FontName', AppConstants.FONT_NAME);
            obj.UITargetROM = uispinner(pg, 'Value', 60, ...
                'Limits', [10, 90], 'Step', 5, 'FontName', AppConstants.FONT_NAME);

            uilabel(pg, 'Text', '轨迹:', 'FontName', AppConstants.FONT_NAME);
            obj.UITargetTrajectory = uidropdown(pg, ...
                'Items', {'正弦', '斜坡', '自由'}, 'Value', '正弦', 'FontName', AppConstants.FONT_NAME);
            uilabel(pg, 'Text', '周期(s):', 'FontName', AppConstants.FONT_NAME);
            obj.UITargetCycle = uispinner(pg, 'Value', 5, ...
                'Limits', [2, 30], 'FontName', AppConstants.FONT_NAME);

            uibutton(pg, 'Text', '▶ 开始评估', ...
                'BackgroundColor', AppConstants.COLOR_SECONDARY, ...
                'FontColor', [1 1 1], 'FontWeight', 'bold', ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'ButtonPushedFcn', @(~,~) obj.runAssessment());
            uibutton(pg, 'Text', '模拟数据评估', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.runDemoAssessment());
        end

        function buildResultPanel(obj, parent)
            import config.AppConstants

            rg = uigridlayout(parent, [1, 2], ...
                'Padding', [5, 5, 5, 5]);

            % 左侧: 数值结果
            leftGrid = uigridlayout(rg, [6, 1], ...
                'Padding', [5, 5, 5, 5], 'RowSpacing', 3);

            obj.UIRomLabel = uilabel(leftGrid, 'Text', 'ROM: --° / --°', ...
                'FontName', AppConstants.FONT_NAME);
            obj.UISmoothnessLabel = uilabel(leftGrid, 'Text', '平滑度: --', ...
                'FontName', AppConstants.FONT_NAME);
            obj.UIForceAccuracyLabel = uilabel(leftGrid, 'Text', '力跟踪精度: --%', ...
                'FontName', AppConstants.FONT_NAME);
            obj.UIAngleRMSELabel = uilabel(leftGrid, 'Text', '角度预测RMSE: --°', ...
                'FontName', AppConstants.FONT_NAME);
            obj.UIForceRMSELabel = uilabel(leftGrid, 'Text', '力预测RMSE: --% MVC', ...
                'FontName', AppConstants.FONT_NAME);
            obj.UIOverallScore = uilabel(leftGrid, 'Text', '综合得分: --/100', ...
                'FontName', AppConstants.FONT_NAME, 'FontWeight', 'bold', ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);

            % 右侧: 雷达图
            obj.RadarAxes = uiaxes(rg);
            title(obj.RadarAxes, '五维评估', 'FontName', AppConstants.FONT_NAME);
        end

        function buildActionPanel(obj, parent)
            import config.AppConstants

            ag = uigridlayout(parent, [5, 1], ...
                'Padding', [10, 10, 10, 10], 'RowSpacing', 8);

            uibutton(ag, 'Text', '📊 生成评估报告', ...
                'BackgroundColor', AppConstants.COLOR_PRIMARY, ...
                'FontColor', [1 1 1], ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.generateReport());

            uibutton(ag, 'Text', '📋 导出HTML报告', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.exportHTMLReport());

            uibutton(ag, 'Text', '💾 保存评估结果', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.saveResults());

            uibutton(ag, 'Text', '📷 导出图表', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.exportFigures());

            obj.UIRecommendation = uitextarea(ag, ...
                'Editable', 'off', ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_SMALL, ...
                'Value', '康复建议: 请先进行评估');
        end
    end

    %% ---- 评估流程 ----
    methods (Access = private)
        function newPatient(obj)
            obj.MainApp.CurrentPatient = models.PatientInfo();
            obj.MainApp.CurrentPatient.PatientID = obj.UIPatientID.Value;
            obj.MainApp.CurrentPatient.Name = obj.UIPatientName.Value;
            obj.MainApp.log('已创建新患者档案');
        end

        function loadPatient(obj)
            % 简化版: 从Session中选择
            uialert(obj.Parent, '请从数据管理Tab加载患者数据', '提示', 'Icon', 'info');
        end

        function config = getAssessmentConfig(obj)
            config = models.AssessConfig();
            config.MovementType = obj.UIMovementType.Value;
            config.TargetForce = obj.UITargetForce.Value;
            config.Repetitions = obj.UIRepetitions.Value;
            config.TargetROM = obj.UITargetROM.Value;
            config.TargetTrajectory = obj.UITargetTrajectory.Value;
            config.CycleSec = obj.UITargetCycle.Value;
            config.EnableBiofeedback = true;
        end

        function runAssessment(obj)
            predictedAngle = obj.MainApp.PredictedAngle;
            predictedForce = obj.MainApp.PredictedForce;
            timeVector = obj.MainApp.TimeVector;

            if isempty(predictedAngle)
                uialert(obj.Parent, '请先在双输出预测Tab中进行角度+力预测', '无预测数据', 'Icon', 'warning');
                return;
            end

            obj.MainApp.log('开始康复评估...');
            config = obj.getAssessmentConfig();

            % 更新患者信息
            obj.MainApp.CurrentPatient.PatientID = obj.UIPatientID.Value;
            obj.MainApp.CurrentPatient.Name = obj.UIPatientName.Value;
            obj.MainApp.CurrentPatient.AffectedSide = obj.UIAffectedSide.Value;

            % 运行评估
            trueAngle = obj.MainApp.GroundTruthAngle;
            trueForce = obj.MainApp.GroundTruthForce;
            nWindows = length(predictedAngle);

            trueAngleDS = obj.downsampleLabel(trueAngle, nWindows);
            trueForceDS  = obj.downsampleLabel(trueForce, nWindows);

            result = services.AssessmentService.runFullAssessment(...
                predictedAngle, predictedForce, ...
                trueAngleDS, trueForceDS, ...
                timeVector, config, obj.MainApp.CurrentPatient);

            obj.MainApp.AssessmentResults = result;
            obj.displayResults(result);

            % 生成生物反馈显示（使用预测结果作为"实际"值）
            [targetAngle, targetForce] = utils.MovementAnalysis.generateTargetTrajectory(...
                config.TargetTrajectory, timeVector(end), ...
                round(length(timeVector) / timeVector(end)), ...
                config.TargetROM, config.TargetForce, config.CycleSec);

            % 截取/插值以匹配
            targetAngle = targetAngle(1:min(nWindows, length(targetAngle)));
            targetForce  = targetForce(1:min(nWindows, length(targetForce)));

            obj.BiofeedbackPanel.updateTracking(...
                timeVector, predictedAngle, targetAngle(:), ...
                predictedForce, targetForce(:), ...
                config.ToleranceDeg, config.ToleranceForce);

            % 更新仪表
            angleAcc = result.AngleTrackingAccuracy;
            forceAcc = result.ForceTrackingAccuracy;
            if isnan(angleAcc), angleAcc = 0; end
            if isnan(forceAcc), forceAcc = 0; end

            forceLevel = config.TargetForce;
            obj.BiofeedbackPanel.updateGauges(angleAcc, forceAcc, forceLevel, result.OverallScore);

            obj.MainApp.log(sprintf('评估完成: 综合得分 %.0f/100', result.OverallScore));
        end

        function runDemoAssessment(obj)
            % 生成模拟评估数据用于演示
            obj.MainApp.log('生成模拟评估数据...');

            nWindows = 200;
            t = (0:nWindows-1)' / 10;

            % 模拟预测值和真实值
            simulatedAngle = 30 * sin(2 * pi * t / 5) + 3 * randn(nWindows, 1);
            simulatedForce  = 20 + 15 * sin(2 * pi * t / 5) + 2 * randn(nWindows, 1);

            obj.MainApp.PredictedAngle = simulatedAngle;
            obj.MainApp.PredictedForce = simulatedForce;
            obj.MainApp.TimeVector = t;

            % 模拟真实标签
            trueAngle = 30 * sin(2 * pi * t / 5);
            trueForce  = 20 + 15 * sin(2 * pi * t / 5);

            config = obj.getAssessmentConfig();
            result = services.AssessmentService.runFullAssessment(...
                simulatedAngle, simulatedForce, ...
                trueAngle, trueForce, ...
                t, config, obj.MainApp.CurrentPatient);

            obj.MainApp.AssessmentResults = result;
            obj.displayResults(result);

            % 更新生物反馈
            [targetAngle, targetForce] = utils.MovementAnalysis.generateTargetTrajectory(...
                config.TargetTrajectory, t(end), 10, config.TargetROM, ...
                config.TargetForce, config.CycleSec);
            targetAngle = targetAngle(1:min(nWindows, length(targetAngle)));
            targetForce  = targetForce(1:min(nWindows, length(targetForce)));

            obj.BiofeedbackPanel.updateTracking(...
                t, simulatedAngle, targetAngle(:), ...
                simulatedForce, targetForce(:), ...
                config.ToleranceDeg, config.ToleranceForce);

            angleAcc = result.AngleTrackingAccuracy;
            forceAcc = result.ForceTrackingAccuracy;
            if isnan(angleAcc), angleAcc = 85; end
            if isnan(forceAcc), forceAcc = 80; end
            obj.BiofeedbackPanel.updateGauges(angleAcc, forceAcc, config.TargetForce, result.OverallScore);

            obj.MainApp.log(sprintf('模拟评估完成: 得分 %.0f/100', result.OverallScore));
        end

        function ds = downsampleLabel(obj, original, targetLen)
            if isempty(original)
                ds = [];
                return;
            end
            original = original(:);
            nOrig = length(original);
            if nOrig <= targetLen
                ds = original;
            else
                factor = nOrig / targetLen;
                indices = round((1:targetLen)' * factor);
                indices = min(max(indices, 1), nOrig);
                ds = original(indices);
            end
        end

        function displayResults(obj, result)
            obj.UIRomLabel.Text = sprintf('ROM: %.1f° / %.0f° (%.0f%%)', ...
                result.ROM, result.ROMTarget, result.ROMPercent);
            obj.UISmoothnessLabel.Text = sprintf('平滑度: %.2f (%.0f分)', ...
                result.NormalizedJerk, result.SmoothnessScore);
            obj.UIForceAccuracyLabel.Text = sprintf('力跟踪精度: %.1f%%', ...
                result.ForceTrackingAccuracy);
            obj.UIAngleRMSELabel.Text = sprintf('角度预测 RMSE: %.2f°', result.PredAngleRMSE);
            obj.UIForceRMSELabel.Text = sprintf('力预测 RMSE: %.2f%% MVC', result.PredForceRMSE);
            obj.UIOverallScore.Text = sprintf('综合得分: %.0f / 100', result.OverallScore);

            % 雷达图
            obj.drawRadarChart(result);

            % 康复建议
            rec = services.AssessmentService.generateRecommendation(result);
            obj.UIRecommendation.Value = sprintf('康复建议:\n%s', rec);
        end

        function drawRadarChart(obj, result)
            import config.AppConstants

            cla(obj.RadarAxes);
            dimNames = {'ROM', '平滑度', '角度跟踪', '力跟踪', '一致性'};
            scores = [
                result.DimensionScores.ROM
                result.DimensionScores.Smoothness
                result.DimensionScores.AngleTracking
                result.DimensionScores.ForceTracking
                result.DimensionScores.Consistency
            ];
            scores(isnan(scores)) = 0;

            nDim = length(dimNames);
            angles = linspace(0, 2*pi, nDim + 1);
            angles = angles(1:end-1);

            % 背景网
            hold(obj.RadarAxes, 'on');
            for level = 20:20:100
                x = level * cos(angles);
                y = level * sin(angles);
                patch(obj.RadarAxes, [x, x(1)], [y, y(1)], 'none', ...
                    'FaceColor', [0.8 0.8 0.8], 'FaceAlpha', 0.1);
            end

            % 数据多边形
            x = scores(:)' .* cos(angles);
            y = scores(:)' .* sin(angles);
            patch(obj.RadarAxes, [x, x(1)], [y, y(1)], ...
                AppConstants.COLOR_PRIMARY, 'FaceAlpha', 0.3, ...
                'EdgeColor', AppConstants.COLOR_PRIMARY, 'LineWidth', 2);

            % 标签
            for i = 1:nDim
                text(obj.RadarAxes, 110 * cos(angles(i)), 110 * sin(angles(i)), ...
                    dimNames{i}, 'HorizontalAlignment', 'center', ...
                    'FontName', AppConstants.FONT_NAME, 'FontSize', 9);
            end

            axis(obj.RadarAxes, 'equal');
            obj.RadarAxes.XLim = [-120, 120];
            obj.RadarAxes.YLim = [-120, 120];
            obj.RadarAxes.Visible = 'off';
            hold(obj.RadarAxes, 'off');
        end
    end

    %% ---- 报告导出 ----
    methods (Access = private)
        function generateReport(obj)
            result = obj.MainApp.AssessmentResults;
            if isempty(result) || isnan(result.OverallScore)
                uialert(obj.Parent, '请先进行评估', '无评估结果', 'Icon', 'warning');
                return;
            end

            msg = sprintf(['=== 康复评估报告 ===\n\n', ...
                '患者: %s (%s)\n', ...
                '日期: %s\n\n', ...
                '--- 评估结果 ---\n', ...
                '关节活动度 ROM: %.1f° / %.0f° (%.0f%%)\n', ...
                '运动平滑度: %.2f (%.0f分)\n', ...
                '角度跟踪精度: %.1f%%\n', ...
                '力跟踪精度: %.1f%%\n', ...
                '角度预测 RMSE: %.2f°\n', ...
                '力预测 RMSE: %.2f%% MVC\n', ...
                '角度预测 R²: %.3f\n', ...
                '力预测 R²: %.3f\n\n', ...
                '★ 综合得分: %.0f / 100 ★\n\n', ...
                '康复建议: %s'], ...
                obj.UIPatientName.Value, obj.UIPatientID.Value, ...
                datestr(result.Date), ...
                result.ROM, result.ROMTarget, result.ROMPercent, ...
                result.NormalizedJerk, result.SmoothnessScore, ...
                result.AngleTrackingAccuracy, result.ForceTrackingAccuracy, ...
                result.PredAngleRMSE, result.PredForceRMSE, ...
                result.PredAngleR2, result.PredForceR2, ...
                result.OverallScore, ...
                services.AssessmentService.generateRecommendation(result));

            msgbox(msg, '评估报告');
            obj.MainApp.log('评估报告已生成');
        end

        function exportHTMLReport(obj)
            result = obj.MainApp.AssessmentResults;
            if isempty(result) || isnan(result.OverallScore)
                uialert(obj.Parent, '请先进行评估', '无评估结果', 'Icon', 'warning');
                return;
            end

            [file, path] = uiputfile('*.html', '导出HTML报告');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);

            patient = obj.MainApp.CurrentPatient;
            services.DataExportService.exportReportHTML(result, patient, fullPath);
            obj.MainApp.log(sprintf('HTML报告已导出: %s', fullPath));
            uialert(obj.Parent, 'HTML报告导出成功!', '导出成功', 'Icon', 'success');
        end

        function saveResults(obj)
            [file, path] = uiputfile('*.mat', '保存评估结果');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);
            result = obj.MainApp.AssessmentResults; %#ok<NASGU>
            save(fullPath, 'result');
            obj.MainApp.log(sprintf('评估结果已保存: %s', fullPath));
        end

        function exportFigures(obj)
            uialert(obj.Parent, '图表导出功能将在后续版本完善', '提示', 'Icon', 'info');
        end
    end
end
