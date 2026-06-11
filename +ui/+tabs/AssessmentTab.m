classdef AssessmentTab < handle
    % AssessmentTab - 康复评估Tab
    %   五区域布局: 患者信息 | 运动曲线 | 指标卡片 | 综合评分 | 报告导出

    properties (Access = private)
        Parent
        MainApp

        % 患者信息
        UIPatientName
        UIPatientID
        UIAffectedSide
        UINotes
        UIDateLabel
        UIActionType
        UITrainingCount
        UITrainingDuration
        UITargetROM
        UITargetForce

        % 曲线轴
        AngleAxes
        ForceAxes

        % ROM卡片
        UIMaxFlexion
        UIMaxExtension
        UIROMValue
        UIROMLamp
        UIROMScore

        % 力量卡片
        UIMeanForce
        UIPeakForce
        UIFluctuationRate
        UIForceLamp
        UIForceGrade

        % 稳定性卡片
        UISmoothness
        UIFluctuationCoeff
        UITremorIndex
        UIStabilityLamp
        UIStabilityGrade

        % 综合评分
        UICompositeScore
        UICompositeGrade
        UIWeightInfo

        % 详细结果
        UIDetailGrid

        % 康复建议
        UIRecommendation

        % 当前评估结果
        CurrentResult
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

            scrollGrid = uigridlayout(obj.Parent, [5, 1], ...
                'RowHeight', {'fit', 180, 'fit', 'fit', 'fit'}, ...
                'Padding', [AppConstants.PADDING, AppConstants.PADDING, ...
                AppConstants.PADDING, AppConstants.PADDING], ...
                'RowSpacing', AppConstants.ROW_SPACING);

            % 区域1: 患者信息
            patientPanel = uipanel(scrollGrid, 'Title', '患者信息', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildPatientPanel(patientPanel);

            % 区域2: 运动结果展示
            motionPanel = uipanel(scrollGrid, 'Title', '运动结果展示', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildMotionPanel(motionPanel);

            % 区域3: 三项指标卡片
            cardsPanel = uipanel(scrollGrid, 'Title', '康复指标评估', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildCardsPanel(cardsPanel);

            % 区域4: 综合评分 + 详细结果
            scorePanel = uipanel(scrollGrid, 'Title', '综合评分与详细结果', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildScorePanel(scorePanel);

            % 区域5: 操作按钮
            actionPanel = uipanel(scrollGrid, 'Title', '报告导出', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildActionPanel(actionPanel);
        end

        % ==================== 区域1: 患者信息 ====================
        function buildPatientPanel(obj, parent)
            import config.AppConstants

            pg = uigridlayout(parent, [3, 8], ...
                'RowHeight', repmat({30}, 1, 3), ...
                'ColumnWidth', {'fit', '1x', 'fit', '1x', 'fit', '1x', 'fit', '1x'}, ...
                'Padding', [10, 8, 10, 8], ...
                'RowSpacing', 5, 'ColumnSpacing', 6);

            fnt = AppConstants.FONT_NAME;
            fsz = AppConstants.FONT_SIZE_SMALL;

            % Row 1
            uilabel(pg, 'Text', '姓名:', 'FontName', fnt, 'FontSize', fsz);
            obj.UIPatientName = uieditfield(pg, 'Value', '', 'FontName', fnt, 'FontSize', fsz);
            uilabel(pg, 'Text', 'ID:', 'FontName', fnt, 'FontSize', fsz);
            obj.UIPatientID = uieditfield(pg, 'Value', '', 'FontName', fnt, 'FontSize', fsz);
            uilabel(pg, 'Text', '患侧:', 'FontName', fnt, 'FontSize', fsz);
            obj.UIAffectedSide = uidropdown(pg, 'Items', {'左侧', '右侧'}, 'Value', '右侧', ...
                'FontName', fnt, 'FontSize', fsz);
            uilabel(pg, 'Text', '备注:', 'FontName', fnt, 'FontSize', fsz);
            obj.UINotes = uieditfield(pg, 'Value', '', 'FontName', fnt, 'FontSize', fsz);

            % Row 2
            uilabel(pg, 'Text', '评估日期:', 'FontName', fnt, 'FontSize', fsz);
            obj.UIDateLabel = uilabel(pg, 'Text', datestr(datetime('now'), 'yyyy-mm-dd'), ...
                'FontName', fnt, 'FontSize', fsz);
            uilabel(pg, 'Text', '动作类型:', 'FontName', fnt, 'FontSize', fsz);
            obj.UIActionType = uidropdown(pg, 'Items', {'屈伸动作', '旋转动作'}, 'Value', '屈伸动作', ...
                'FontName', fnt, 'FontSize', fsz);
            uilabel(pg, 'Text', '训练次数:', 'FontName', fnt, 'FontSize', fsz);
            obj.UITrainingCount = uispinner(pg, 'Value', 5, 'Limits', [1, 30], ...
                'FontName', fnt, 'FontSize', fsz);
            uilabel(pg, 'Text', '训练时长(s):', 'FontName', fnt, 'FontSize', fsz);
            obj.UITrainingDuration = uispinner(pg, 'Value', 30, 'Limits', [5, 300], 'Step', 5, ...
                'FontName', fnt, 'FontSize', fsz);

            % Row 3: 目标值 + 操作按钮
            uilabel(pg, 'Text', '目标ROM(°):', 'FontName', fnt, 'FontSize', fsz, 'FontWeight', 'bold');
            obj.UITargetROM = uispinner(pg, 'Value', 60, 'Limits', [0, 360], 'Step', 5, ...
                'FontName', fnt, 'FontSize', fsz);
            uilabel(pg, 'Text', '目标力量(N):', 'FontName', fnt, 'FontSize', fsz, 'FontWeight', 'bold');
            obj.UITargetForce = uispinner(pg, 'Value', 50, 'Limits', [0, 100], 'Step', 5, ...
                'FontName', fnt, 'FontSize', fsz);

            uibutton(pg, 'Text', '保存档案', 'FontName', fnt, ...
                'BackgroundColor', AppConstants.COLOR_PRIMARY, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) obj.savePatientProfile());
            uibutton(pg, 'Text', '读取档案', 'FontName', fnt, ...
                'ButtonPushedFcn', @(~,~) obj.loadPatientProfile());
            uibutton(pg, 'Text', '刷新评估', 'FontName', fnt, ...
                'BackgroundColor', AppConstants.COLOR_SECONDARY, 'FontColor', [1 1 1], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.runAssessment());
        end

        % ==================== 区域2: 运动结果展示 ====================
        function buildMotionPanel(obj, parent)
            import config.AppConstants

            motionGrid = uigridlayout(parent, [1, 2], ...
                'ColumnWidth', {'1x', '1x'}, ...
                'Padding', [5, 5, 5, 5], ...
                'ColumnSpacing', AppConstants.COL_SPACING);

            obj.AngleAxes = uiaxes(motionGrid);
            title(obj.AngleAxes, '角度预测结果', 'FontName', AppConstants.FONT_NAME);
            xlabel(obj.AngleAxes, '时间 (s)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.AngleAxes, '角度 (°)', 'FontName', AppConstants.FONT_NAME);
            grid(obj.AngleAxes, 'on');

            obj.ForceAxes = uiaxes(motionGrid);
            title(obj.ForceAxes, '力量预测结果', 'FontName', AppConstants.FONT_NAME);
            xlabel(obj.ForceAxes, '时间 (s)', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.ForceAxes, '力 (N)', 'FontName', AppConstants.FONT_NAME);
            grid(obj.ForceAxes, 'on');
        end

        % ==================== 区域3: 三项指标卡片 ====================
        function buildCardsPanel(obj, parent)
            import config.AppConstants

            cardsGrid = uigridlayout(parent, [1, 3], ...
                'ColumnWidth', {'1x', '1x', '1x'}, ...
                'Padding', [5, 5, 5, 5], ...
                'ColumnSpacing', AppConstants.COL_SPACING);

            obj.buildROMCard(cardsGrid);
            obj.buildForceCard(cardsGrid);
            obj.buildStabilityCard(cardsGrid);
        end

        function buildROMCard(obj, parent)
            import config.AppConstants

            card = uipanel(parent, 'Title', 'ROM 运动能力', ...
                'BackgroundColor', [0.96 0.98 1.00], ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);

            cg = uigridlayout(card, [5, 1], ...
                'RowHeight', repmat({'fit'}, 1, 5), ...
                'Padding', [10, 8, 10, 8], 'RowSpacing', 4);

            obj.UIMaxFlexion = uilabel(cg, 'Text', '最大屈曲/旋前: --°', ...
                'FontName', AppConstants.FONT_NAME, 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold');
            obj.UIMaxExtension = uilabel(cg, 'Text', '最大伸展/旋后: --°', ...
                'FontName', AppConstants.FONT_NAME, 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold');
            obj.UIROMValue = uilabel(cg, 'Text', 'ROM: --°', ...
                'FontName', AppConstants.FONT_NAME, 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold');
            obj.UIROMLamp = uilamp(cg, 'Color', [0.7 0.7 0.7]);
            obj.UIROMScore = uilabel(cg, 'Text', 'ROM得分: --/100', ...
                'FontName', AppConstants.FONT_NAME, 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold', 'FontColor', AppConstants.COLOR_PRIMARY);
        end

        function buildForceCard(obj, parent)
            import config.AppConstants

            card = uipanel(parent, 'Title', '力量能力', ...
                'BackgroundColor', [0.96 1.00 0.98], ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);

            cg = uigridlayout(card, [5, 1], ...
                'RowHeight', repmat({'fit'}, 1, 5), ...
                'Padding', [10, 8, 10, 8], 'RowSpacing', 4);

            obj.UIMeanForce = uilabel(cg, 'Text', '平均力量: -- N', ...
                'FontName', AppConstants.FONT_NAME, 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold');
            obj.UIPeakForce = uilabel(cg, 'Text', '峰值力量: -- N', ...
                'FontName', AppConstants.FONT_NAME, 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold');
            obj.UIFluctuationRate = uilabel(cg, 'Text', '波动率: --', ...
                'FontName', AppConstants.FONT_NAME, 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold');
            obj.UIForceLamp = uilamp(cg, 'Color', [0.7 0.7 0.7]);
            obj.UIForceGrade = uilabel(cg, 'Text', '等级: --', ...
                'FontName', AppConstants.FONT_NAME, 'FontWeight', 'bold', ...
                'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontColor', AppConstants.COLOR_PRIMARY);
        end

        function buildStabilityCard(obj, parent)
            import config.AppConstants

            card = uipanel(parent, 'Title', '动作稳定性', ...
                'BackgroundColor', [1.00 0.98 0.96], ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);

            cg = uigridlayout(card, [5, 1], ...
                'RowHeight', repmat({'fit'}, 1, 5), ...
                'Padding', [10, 8, 10, 8], 'RowSpacing', 4);

            obj.UISmoothness = uilabel(cg, 'Text', '平滑度: --', ...
                'FontName', AppConstants.FONT_NAME, 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold');
            obj.UIFluctuationCoeff = uilabel(cg, 'Text', '波动系数: --', ...
                'FontName', AppConstants.FONT_NAME, 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold');
            obj.UITremorIndex = uilabel(cg, 'Text', 'Tremor指数: --', ...
                'FontName', AppConstants.FONT_NAME, 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontWeight', 'bold');
            obj.UIStabilityLamp = uilamp(cg, 'Color', [0.7 0.7 0.7]);
            obj.UIStabilityGrade = uilabel(cg, 'Text', '等级: --', ...
                'FontName', AppConstants.FONT_NAME, 'FontWeight', 'bold', ...
                'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontColor', AppConstants.COLOR_PRIMARY);
        end

        % ==================== 区域4: 综合评分 + 详细结果 ====================
        function buildScorePanel(obj, parent)
            import config.AppConstants

            scoreGrid = uigridlayout(parent, [1, 2], ...
                'ColumnWidth', {200, '1x'}, ...
                'Padding', [5, 5, 5, 5], ...
                'ColumnSpacing', AppConstants.COL_SPACING);

            % 左侧: 综合评分 (大字)
            leftPanel = uipanel(scoreGrid, 'Title', '综合评分', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);

            lg = uigridlayout(leftPanel, [3, 1], ...
                'RowHeight', {'1x', 'fit', 'fit'}, ...
                'Padding', [10, 10, 10, 10], 'RowSpacing', 5);

            obj.UICompositeScore = uilabel(lg, 'Text', '--', ...
                'FontSize', 52, 'FontWeight', 'bold', ...
                'FontColor', AppConstants.COLOR_SECONDARY, ...
                'HorizontalAlignment', 'center', ...
                'FontName', AppConstants.FONT_NAME);

            obj.UICompositeGrade = uilabel(lg, 'Text', '请先进行评估', ...
                'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontColor', AppConstants.COLOR_TEXT_LIGHT, ...
                'HorizontalAlignment', 'center', ...
                'FontName', AppConstants.FONT_NAME);

            obj.UIWeightInfo = uilabel(lg, 'Text', 'ROM(30%)+力量(25%)+稳定性(25%)+完成度(20%)', ...
                'FontSize', 8, 'FontColor', [0.7 0.7 0.7], ...
                'HorizontalAlignment', 'center', ...
                'FontName', AppConstants.FONT_NAME);

            % 右侧: 详细结果 + 康复建议
            rightPanel = uipanel(scoreGrid, 'Title', '详细评估结果', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);

            rg = uigridlayout(rightPanel, [2, 1], ...
                'RowHeight', {'1x', 'fit'}, ...
                'Padding', [8, 8, 8, 8], 'RowSpacing', 5);

            obj.UIDetailGrid = uigridlayout(rg, [6, 2], ...
                'RowHeight', repmat({22}, 1, 6), ...
                'ColumnWidth', {'1x', '1x'}, ...
                'Padding', [0, 0, 0, 0], 'RowSpacing', 2, 'ColumnSpacing', 10);

            fnt = AppConstants.FONT_NAME;
            fsz = AppConstants.FONT_SIZE_NORMAL;
            uilabel(obj.UIDetailGrid, 'Text', '最大屈曲/旋前: --°', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', '最大伸展/旋后: --°', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', 'ROM: --°', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', '平均力量: -- N', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', '峰值力量: -- N', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', '力量波动率: --', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', '稳定性评分: --/100', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', '综合评分: --/100', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', '评估等级: --', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', '动作完成度: --%', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', '力量得分: --/100', 'FontName', fnt, 'FontSize', fsz);
            uilabel(obj.UIDetailGrid, 'Text', 'ROM得分: --/100', 'FontName', fnt, 'FontSize', fsz);

            obj.UIRecommendation = uitextarea(rg, ...
                'Editable', 'off', ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_SMALL, ...
                'Value', '康复建议: 请先在双输出预测页面完成预测，然后点击刷新评估');
        end

        % ==================== 区域5: 操作按钮 ====================
        function buildActionPanel(obj, parent)
            import config.AppConstants

            btnRow = uigridlayout(parent, [1, 4], ...
                'ColumnWidth', {'1x', '1x', '1x', '1x'}, ...
                'Padding', [10, 10, 10, 10], ...
                'ColumnSpacing', 12);

            uibutton(btnRow, 'Text', '生成评估报告', ...
                'BackgroundColor', AppConstants.COLOR_SECONDARY, ...
                'FontColor', [1 1 1], ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.generateReport());

            uibutton(btnRow, 'Text', '保存评估结果', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.saveResults());

            uibutton(btnRow, 'Text', '导出图表', ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.exportScreenshot());

            uibutton(btnRow, 'Text', '保存评估报告', ...
                'BackgroundColor', AppConstants.COLOR_DANGER, ...
                'FontColor', [1 1 1], ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.exportReportWithFigures());
        end

        % ==================== 评估流程 ====================
        function runAssessment(obj)
            predictedAngle = obj.MainApp.PredictedAngle;
            predictedForce = obj.MainApp.PredictedForce;
            timeVector = obj.MainApp.TimeVector;

            if isempty(predictedAngle) || isempty(predictedForce)
                uialert(obj.Parent, '请先在双输出预测Tab中完成角度和力预测', '无预测数据', 'Icon', 'warning');
                return;
            end

            obj.MainApp.log('开始康复评估...');

            targetROM = obj.UITargetROM.Value;
            targetForce = obj.UITargetForce.Value;

            patient = obj.MainApp.CurrentPatient;
            patient.PatientID = obj.UIPatientID.Value;
            patient.Name = obj.UIPatientName.Value;
            patient.AffectedSide = obj.UIAffectedSide.Value;

            result = services.AssessmentService.runRehabAssessment(...
                predictedAngle, predictedForce, timeVector, ...
                targetROM, targetForce, patient);

            obj.CurrentResult = result;
            obj.MainApp.AssessmentResults = result;
            obj.displayResults(result);
            obj.updateCurves();
            obj.autoSaveRecord(result);

            obj.MainApp.log(sprintf('康复评估完成: 综合评分 %.0f/100 (%s)', ...
                result.OverallScore, result.RehabGrade));
        end

        function autoSaveRecord(obj, result)
            recordsPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'records');
            if ~exist(recordsPath, 'dir'), mkdir(recordsPath); end

            rec.PatientName = obj.UIPatientName.Value;
            rec.PatientID = obj.UIPatientID.Value;
            rec.AffectedSide = obj.UIAffectedSide.Value;
            rec.Date = datestr(result.Date, 'yyyy-mm-dd');
            rec.DateNum = datenum(result.Date);
            rec.ActionType = obj.UIActionType.Value;
            rec.DurationSec = obj.UITrainingDuration.Value;
            rec.MaxFlexion = result.MaxFlexion;
            rec.MaxExtension = result.MaxExtension;
            rec.ROM = result.ROM;
            rec.TargetROM = result.TargetROM;
            rec.ROMScore = result.ROMScore;
            rec.PeakForce = result.PeakForce;
            rec.MeanForce = result.MeanForce;
            rec.TargetForce = result.TargetForce;
            rec.ForceScore = result.ForceScore;
            rec.StabilityScore = result.StabilityScore;
            rec.StabilityGrade = result.StabilityGrade;
            rec.CompletionScore = result.CompletionScore;
            rec.OverallScore = result.OverallScore;
            rec.RehabGrade = result.RehabGrade;
            rec.Rec = result.RehabRecommendation;
            rec.PredAngle = obj.MainApp.PredictedAngle;
            rec.PredForce = obj.MainApp.PredictedForce;
            rec.TimeVector = obj.MainApp.TimeVector;

            fname = sprintf('%s_%s.mat', rec.PatientID, rec.Date);
            save(fullfile(recordsPath, fname), 'rec');
            obj.MainApp.log(sprintf('记录已自动保存: %s', fname));
        end

        function updateCurves(obj)
            predictedAngle = obj.MainApp.PredictedAngle;
            predictedForce = obj.MainApp.PredictedForce;
            timeVector = obj.MainApp.TimeVector;

            if isempty(predictedAngle) || ~isvalid(obj.AngleAxes), return; end

            cla(obj.AngleAxes);
            plot(obj.AngleAxes, timeVector, predictedAngle, 'b-', 'LineWidth', 1.5);
            xlabel(obj.AngleAxes, '时间 (s)');
            ylabel(obj.AngleAxes, '角度 (°)');
            title(obj.AngleAxes, '角度预测结果');
            grid(obj.AngleAxes, 'on');

            cla(obj.ForceAxes);
            plot(obj.ForceAxes, timeVector, predictedForce, 'r-', 'LineWidth', 1.5);
            xlabel(obj.ForceAxes, '时间 (s)');
            ylabel(obj.ForceAxes, '力 (N)');
            title(obj.ForceAxes, '力量预测结果');
            grid(obj.ForceAxes, 'on');
        end

        function displayResults(obj, result)
            % ROM卡片
            obj.UIMaxFlexion.Text = sprintf('最大屈曲/旋前: %.1f°', result.MaxFlexion);
            obj.UIMaxExtension.Text = sprintf('最大伸展/旋后: %.1f°', result.MaxExtension);
            obj.UIROMValue.Text = sprintf('ROM: %.1f° / %.0f°', result.ROM, result.TargetROM);
            obj.UIROMScore.Text = sprintf('ROM得分: %.0f/100', result.ROMScore);

            % ROM指示灯
            if result.ROMScore >= 80
                obj.UIROMLamp.Color = [0.20 0.75 0.40];
            elseif result.ROMScore >= 60
                obj.UIROMLamp.Color = [0.95 0.70 0.20];
            else
                obj.UIROMLamp.Color = [0.90 0.25 0.25];
            end

            % 力量卡片
            obj.UIMeanForce.Text = sprintf('平均力量: %.1f N', result.MeanForce);
            obj.UIPeakForce.Text = sprintf('峰值力量: %.1f N', result.PeakForce);
            obj.UIFluctuationRate.Text = sprintf('波动率: %.2f', result.ForceFluctuation);
            obj.UIForceGrade.Text = sprintf('等级: %s', obj.scoreToGrade(result.ForceScore));
            if result.ForceScore >= 80
                obj.UIForceLamp.Color = [0.20 0.75 0.40];
            elseif result.ForceScore >= 60
                obj.UIForceLamp.Color = [0.95 0.70 0.20];
            else
                obj.UIForceLamp.Color = [0.90 0.25 0.25];
            end

            % 稳定性卡片
            obj.UISmoothness.Text = sprintf('平滑度: %.2f', result.SmoothnessIdx);
            obj.UIFluctuationCoeff.Text = sprintf('波动系数: %.2f', result.FluctuationCoeff);
            obj.UITremorIndex.Text = sprintf('Tremor指数: %.3f', result.TremorIndex);
            obj.UIStabilityGrade.Text = sprintf('等级: %s', result.StabilityGrade);
            if result.StabilityScore >= 80
                obj.UIStabilityLamp.Color = [0.20 0.75 0.40];
            elseif result.StabilityScore >= 60
                obj.UIStabilityLamp.Color = [0.95 0.70 0.20];
            else
                obj.UIStabilityLamp.Color = [0.90 0.25 0.25];
            end

            % 综合评分
            obj.UICompositeScore.Text = sprintf('%.0f', result.OverallScore);
            obj.UICompositeGrade.Text = result.RehabGrade;
            obj.UICompositeGrade.FontColor = obj.gradeColor(result.RehabGrade);
            obj.UICompositeScore.FontColor = obj.gradeColor(result.RehabGrade);

            % 详细结果 (12个标签)
            detailLabels = obj.UIDetailGrid.Children;
            texts = {
                sprintf('最大屈曲/旋前: %.1f°', result.MaxFlexion), ...
                sprintf('最大伸展/旋后: %.1f°', result.MaxExtension), ...
                sprintf('ROM: %.1f°', result.ROM), ...
                sprintf('平均力量: %.1f N', result.MeanForce), ...
                sprintf('峰值力量: %.1f N', result.PeakForce), ...
                sprintf('力量波动率: %.2f', result.ForceFluctuation), ...
                sprintf('稳定性评分: %.0f/100', result.StabilityScore), ...
                sprintf('综合评分: %.0f/100', result.OverallScore), ...
                sprintf('评估等级: %s', result.RehabGrade), ...
                sprintf('动作完成度: %.0f%%', result.CompletionScore), ...
                sprintf('力量得分: %.0f/100', result.ForceScore), ...
                sprintf('ROM得分: %.0f/100', result.ROMScore) ...
                };
            for i = 1:min(length(detailLabels), length(texts))
                detailLabels(i).Text = texts{i};
            end

            % 康复建议
            obj.UIRecommendation.Value = sprintf('康复建议:\n%s', result.RehabRecommendation);
        end

        function grade = scoreToGrade(~, score)
            if score >= 90, grade = '优秀';
            elseif score >= 80, grade = '良好';
            elseif score >= 70, grade = '合格';
            elseif score >= 60, grade = '待提高';
            else, grade = '较差'; end
        end

        function c = gradeColor(~, grade)
            switch grade
                case '优秀', c = [0.15 0.65 0.15];
                case '良好', c = [0.20 0.65 0.45];
                case '合格', c = [0.95 0.60 0.20];
                case '待提高', c = [0.90 0.40 0.20];
                case '较差', c = [0.85 0.25 0.25];
                otherwise, c = [0.5 0.5 0.5];
            end
        end

        % ==================== 患者档案保存/读取 ====================
        function savePatientProfile(obj)
            profile.PatientName = obj.UIPatientName.Value;
            profile.PatientID = obj.UIPatientID.Value;
            profile.AffectedSide = obj.UIAffectedSide.Value;
            profile.Notes = obj.UINotes.Value;
            profile.ActionType = obj.UIActionType.Value;
            profile.TrainingCount = obj.UITrainingCount.Value;
            profile.TrainingDuration = obj.UITrainingDuration.Value;
            profile.TargetROM = obj.UITargetROM.Value;
            profile.TargetForce = obj.UITargetForce.Value;
            profile.SaveDate = datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS');

            [file, path] = uiputfile('*.mat', '保存患者档案');
            if isequal(file, 0), return; end
            save(fullfile(path, file), 'profile');
            obj.MainApp.log(sprintf('患者档案已保存: %s', file));
        end

        function loadPatientProfile(obj)
            [file, path] = uigetfile('*.mat', '读取患者档案');
            if isequal(file, 0), return; end
            loaded = load(fullfile(path, file), 'profile');
            if ~isfield(loaded, 'profile')
                uialert(obj.Parent, '无效的患者档案文件', '加载失败', 'Icon', 'error');
                return;
            end
            p = loaded.profile;
            obj.UIPatientName.Value = p.PatientName;
            obj.UIPatientID.Value = p.PatientID;
            obj.UIAffectedSide.Value = p.AffectedSide;
            if isfield(p, 'Notes'), obj.UINotes.Value = p.Notes; end
            if isfield(p, 'ActionType'), obj.UIActionType.Value = p.ActionType; end
            if isfield(p, 'TrainingCount'), obj.UITrainingCount.Value = p.TrainingCount; end
            if isfield(p, 'TrainingDuration'), obj.UITrainingDuration.Value = p.TrainingDuration; end
            if isfield(p, 'TargetROM'), obj.UITargetROM.Value = p.TargetROM; end
            if isfield(p, 'TargetForce'), obj.UITargetForce.Value = p.TargetForce; end
            obj.MainApp.log(sprintf('患者档案已加载: %s (%s)', p.PatientName, p.PatientID));
        end

        % ==================== 报告导出 ====================
        function generateReport(obj)
            if isempty(obj.CurrentResult)
                uialert(obj.Parent, '请先进行评估', '无评估结果', 'Icon', 'warning');
                return;
            end
            r = obj.CurrentResult;

            msg = sprintf(['=== 康复评估报告 ===\n\n', ...
                '患者: %s (%s)\n患侧: %s\n日期: %s\n动作: %s\n\n', ...
                '--- 评估结果 ---\n', ...
                'ROM: %.1f° / 目标%.0f° (得分 %.0f/100)\n', ...
                '峰值力量: %.1f / 目标%.0f N (得分 %.0f/100)\n', ...
                '力量波动率: %.2f\n', ...
                '运动平滑度: %.2f\n', ...
                'Tremor指数: %.3f\n', ...
                '稳定性评分: %.0f/100 (%s)\n', ...
                '动作完成度: %.0f%%\n\n', ...
                '★ 综合评分: %.0f/100 (%s) ★\n\n', ...
                '康复建议: %s'], ...
                obj.UIPatientName.Value, obj.UIPatientID.Value, ...
                obj.UIAffectedSide.Value, datestr(r.Date), ...
                obj.UIActionType.Value, ...
                r.ROM, r.TargetROM, r.ROMScore, ...
                r.PeakForce, r.TargetForce, r.ForceScore, ...
                r.ForceFluctuation, ...
                r.SmoothnessIdx, r.TremorIndex, ...
                r.StabilityScore, r.StabilityGrade, ...
                r.CompletionScore, ...
                r.OverallScore, r.RehabGrade, ...
                r.RehabRecommendation);

            msgbox(msg, '康复评估报告');
            obj.MainApp.log('评估报告已生成');
        end

        function saveResults(obj)
            if isempty(obj.CurrentResult)
                uialert(obj.Parent, '请先进行评估', '无评估结果', 'Icon', 'warning');
                return;
            end
            [file, path] = uiputfile('*.mat', '保存评估结果');
            if isequal(file, 0), return; end
            result = obj.CurrentResult; %#ok<NASGU>
            save(fullfile(path, file), 'result');
            obj.MainApp.log(sprintf('评估结果已保存: %s', file));
        end

        function exportScreenshot(obj)
            % 导出整个系统主界面的截图
            [file, path] = uiputfile({'*.png', 'PNG图像'; '*.jpg', 'JPEG图像'}, '保存系统截图');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);

            try
                % 获取主图窗句柄
                fig = obj.MainApp.getFigure();
                % 捕获当前窗口的图像（包含所有 UI 组件）
                frame = getframe(fig);
                img = frame.cdata;
                % 保存为图像文件
                imwrite(img, fullPath);
                uialert(obj.MainApp.getFigure(), sprintf('系统截图已保存: %s', file), '成功', 'Icon', 'success');
            catch e
                uialert(obj.MainApp.getFigure(), sprintf('截图失败: %s', e.message), '错误', 'Icon', 'error');
            end
        end

        function exportReportWithFigures(obj)
            if isempty(obj.CurrentResult)
                uialert(obj.MainApp.getFigure(), '请先进行评估', '无评估结果', 'Icon', 'warning');
                return;
            end

            [file, path] = uiputfile('*.pdf', '保存评估报告');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);

            r = obj.CurrentResult;

            try
                % 1. 捕获主界面截图
                mainFig = obj.MainApp.getFigure();
                frame = getframe(mainFig);
                screenshot = frame.cdata;

                % 2. 准备文字报告内容
                reportText = sprintf(['患者: %s (%s)\n', ...
                    '患侧: %s\n', ...
                    '日期: %s\n', ...
                    '动作: %s\n\n', ...
                    '--- 评估结果 ---\n', ...
                    'ROM: %.1f° / 目标%.0f° (得分 %.0f/100)\n', ...
                    '峰值力量: %.1f / 目标%.0f N (得分 %.0f/100)\n', ...
                    '力量波动率: %.2f\n', ...
                    '运动平滑度: %.2f\n', ...
                    'Tremor指数: %.3f\n', ...
                    '稳定性评分: %.0f/100 (%s)\n', ...
                    '动作完成度: %.0f%%\n\n', ...
                    '★ 综合评分: %.0f/100 (%s) ★\n\n', ...
                    '康复建议: %s'], ...
                    obj.UIPatientName.Value, obj.UIPatientID.Value, ...
                    obj.UIAffectedSide.Value, datestr(r.Date), ...
                    obj.UIActionType.Value, ...
                    r.ROM, r.TargetROM, r.ROMScore, ...
                    r.PeakForce, r.TargetForce, r.ForceScore, ...
                    r.ForceFluctuation, ...
                    r.SmoothnessIdx, r.TremorIndex, ...
                    r.StabilityScore, r.StabilityGrade, ...
                    r.CompletionScore, ...
                    r.OverallScore, r.RehabGrade, ...
                    r.RehabRecommendation);

                % 3. 创建 PDF 图窗
                pdfFig = figure('Visible', 'off', 'Position', [100, 100, 800, 1000], ...
                    'PaperUnits', 'points', 'PaperSize', [600, 800], ...
                    'PaperPosition', [0, 0, 600, 800]);

                % 获取中文字体
                if ispc
                    fontName = '微软雅黑';
                    list = listfonts;
                    if ~any(strcmpi(list, fontName))
                        fontName = 'SimHei';
                    end
                else
                    fontName = 'Helvetica';
                end

                % 3.1 标题（顶部）
                titleAx = axes('Parent', pdfFig, 'Position', [0, 0.92, 1, 0.08], 'Visible', 'off');
                text(0.5, 0.5, '康复评估报告', 'FontSize', 24, 'FontWeight', 'bold', ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized', 'FontName', fontName);

                % 3.2 截图位置：标题下方留出足够空间（距顶部 120 点）
                imgHeight = size(screenshot, 1);
                imgWidth = size(screenshot, 2);
                maxWidth = 500;
                scale = maxWidth / imgWidth;
                newWidth = imgWidth * scale;
                newHeight = imgHeight * scale;
                left = (600 - newWidth) / 2;
                topMargin = 120;   % 距离页面顶部的点数（留出标题区域）
                top = 800 - topMargin;
                bottom = top - newHeight;
                % 确保截图底部不侵入文字区域（文字区域从底部向上 300 点）
                if bottom < 300
                    bottom = 300;
                    top = bottom + newHeight;
                end
                axImg = axes('Parent', pdfFig, 'Units', 'points', 'Position', [left, bottom, newWidth, newHeight]);
                imshow(screenshot, 'Parent', axImg);
                axis(axImg, 'off');
                title(axImg, '系统界面截图', 'FontSize', 10, 'FontWeight', 'normal', 'FontName', fontName);

                % 3.3 文字区域（位于截图下方）
                textAx = axes('Parent', pdfFig, 'Position', [0.05, 0.05, 0.9, 0.35], 'Visible', 'off');
                lines = strsplit(reportText, '\n');
                fontSize = 9;
                lineHeight = 0.045;
                yStart = 0.9;
                for i = 1:length(lines)
                    yPos = yStart - (i-1) * lineHeight;
                    if yPos < 0.05, break; end
                    text(0.05, yPos, lines{i}, 'FontSize', fontSize, 'FontName', fontName, ...
                        'Units', 'normalized', 'HorizontalAlignment', 'left');
                end

                exportgraphics(pdfFig, fullPath, 'ContentType', 'vector');
                close(pdfFig);
                uialert(obj.MainApp.getFigure(), '评估报告保存成功!', '保存成功', 'Icon', 'success');
            catch e
                if exist('pdfFig', 'var') && isvalid(pdfFig), close(pdfFig); end
                uialert(obj.MainApp.getFigure(), sprintf('保存失败: %s', e.message), '错误', 'Icon', 'error');
            end
        end
    end
end
