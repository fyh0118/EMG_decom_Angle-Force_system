classdef DataManagementTab < handle
    % DataManagementTab - 康复档案与趋势分析中心
    %   记录管理 | 趋势图表 | 导入导出 | 数据统计

    properties (Access = private)
        Parent
        MainApp
        RecordsPath   string
        Records       cell = {}      % 已加载的评估记录 (struct array in cell)

        % 记录表格
        UITable
        UIDetailGrid

        % 查询控件
        UIFilterPatient
        UIFilterAction
        UIFilterGrade
        UIDateFrom
        UIDateTo

        % 趋势图
        TrendAxesROM
        TrendAxesForce
        TrendAxesScore

        % 统计标签
        StatTotalPatients
        StatTotalAssess
        StatTotalDuration
        StatAvgROM
        StatAvgForce
        StatAvgScore
        StatBestScore
        StatLastDate
    end

    methods
        function obj = DataManagementTab(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.RecordsPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'records');
            if ~exist(obj.RecordsPath, 'dir')
                mkdir(obj.RecordsPath);
            end
            obj.buildUI();
            obj.scanRecords();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            delete(obj.Parent.Children);

            mainGrid = uigridlayout(obj.Parent, [2, 2], ...
                'RowHeight', {'3x', '1x'}, ...
                'ColumnWidth', {'3x', '2x'}, ...
                'Padding', [AppConstants.PADDING, AppConstants.PADDING, ...
                AppConstants.PADDING, AppConstants.PADDING], ...
                'RowSpacing', AppConstants.ROW_SPACING, ...
                'ColumnSpacing', AppConstants.COL_SPACING);

            % 左上: 评估记录管理
            recordPanel = uipanel(mainGrid, 'Title', '评估记录管理', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildRecordPanel(recordPanel);

            % 右上: 趋势分析
            trendPanel = uipanel(mainGrid, 'Title', '康复趋势分析', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildTrendPanel(trendPanel);

            % 左下: 导入导出
            ioPanel = uipanel(mainGrid, 'Title', '数据导入导出', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildIOPanel(ioPanel);

            % 右下: 数据统计
            statPanel = uipanel(mainGrid, 'Title', '数据统计', ...
                'BackgroundColor', AppConstants.COLOR_PANEL_BG, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_HEADING);
            obj.buildStatPanel(statPanel);
        end

        % ==================== 记录管理区 ====================
        function buildRecordPanel(obj, parent)
            import config.AppConstants

            rg = uigridlayout(parent, [2, 1], ...
                'RowHeight', {'fit', '1x'}, ...
                'Padding', [5, 5, 5, 5], 'RowSpacing', 4);

            % 查询过滤栏
            filterGrid = uigridlayout(rg, [1, 10], ...
                'ColumnWidth', {'fit', '1x', 'fit', '1x', 'fit', '1x', 'fit', 'fit', 'fit', 'fit'}, ...
                'Padding', [0, 0, 0, 0], 'ColumnSpacing', 4);

            fnt = AppConstants.FONT_NAME;
            fsz = AppConstants.FONT_SIZE_SMALL;

            uilabel(filterGrid, 'Text', '患者:', 'FontName', fnt, 'FontSize', fsz);
            obj.UIFilterPatient = uidropdown(filterGrid, 'Items', {'全部'}, 'Value', '全部', ...
                'FontName', fnt, 'FontSize', fsz);

            uilabel(filterGrid, 'Text', '动作:', 'FontName', fnt, 'FontSize', fsz);
            obj.UIFilterAction = uidropdown(filterGrid, ...
                'Items', {'全部', '屈伸动作', '旋转动作'}, 'Value', '全部', ...
                'FontName', fnt, 'FontSize', fsz);

            uilabel(filterGrid, 'Text', '等级:', 'FontName', fnt, 'FontSize', fsz);
            obj.UIFilterGrade = uidropdown(filterGrid, ...
                'Items', {'全部', '优秀', '良好', '合格', '待提高', '较差'}, 'Value', '全部', ...
                'FontName', fnt, 'FontSize', fsz);

            uibutton(filterGrid, 'Text', '查询', 'FontName', fnt, ...
                'BackgroundColor', AppConstants.COLOR_PRIMARY, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) obj.refreshTable());
            uibutton(filterGrid, 'Text', '刷新', 'FontName', fnt, ...
                'ButtonPushedFcn', @(~,~) obj.scanRecords());
            uibutton(filterGrid, 'Text', '删除', 'FontName', fnt, ...
                'BackgroundColor', AppConstants.COLOR_DANGER, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) obj.deleteSelected());
            uibutton(filterGrid, 'Text', '演示数据', 'FontName', fnt, ...
                'BackgroundColor', AppConstants.COLOR_SECONDARY, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) obj.generateDemoData());

            % 记录表格
            colNames = {'日期', '患者ID', '姓名', '患侧', '动作', '时长(s)', ...
                'ROM(°)', '峰值力(N)', '稳定性', '综合分', '等级'};
            obj.UITable = uitable(rg, ...
                'ColumnName', colNames, ...
                'ColumnWidth', {90, 65, 55, 40, 60, 55, 55, 65, 45, 50, 50}, ...
                'RowName', {}, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_SMALL, ...
                'CellSelectionCallback', @(~, evt) obj.onRecordSelected(evt));
        end

        function onRecordSelected(obj, evt)
            if isempty(evt.Indices), return; end
            row = evt.Indices(1);
            % 双击检测：连续两次点击同一行
            persistent lastClick
            if isempty(lastClick), lastClick = struct('row', 0, 'time', 0); end
            now = tic;
            if row == lastClick.row && toc(lastClick.time) < 0.5
                obj.showRecordDetail(row);
                lastClick.row = 0;
            else
                lastClick.row = row;
                lastClick.time = tic;
            end
        end

        function showRecordDetail(obj, row)
            rec = obj.Records{row};
            import config.AppConstants

            dlg = uifigure('Name', sprintf('评估详情 - %s (%s)', rec.PatientName, rec.Date), ...
                'Position', [200, 150, 750, 600], ...
                'Color', AppConstants.COLOR_BG, ...
                'Resize', 'off');

            dg = uigridlayout(dlg, [2, 1], ...
                'RowHeight', {'fit', '1x'}, ...
                'Padding', [10, 10, 10, 10], 'RowSpacing', 8);

            % 患者信息 + 指标
            infoGrid = uigridlayout(dg, [1, 2], ...
                'ColumnWidth', {'1x', '1x'}, 'Padding', [0,0,0,0], 'ColumnSpacing', 10);

            infoLeft = uigridlayout(infoGrid, [10, 1], ...
                'RowHeight', repmat({22}, 1, 10), 'Padding', [5,5,5,5], 'RowSpacing', 2);
            fnt = AppConstants.FONT_NAME;

            uilabel(infoLeft, 'Text', sprintf('患者: %s  |  ID: %s  |  患侧: %s', ...
                rec.PatientName, rec.PatientID, rec.AffectedSide), ...
                'FontName', fnt, 'FontWeight', 'bold');
            uilabel(infoLeft, 'Text', sprintf('日期: %s  |  动作: %s  |  时长: %ds', ...
                rec.Date, rec.ActionType, rec.DurationSec), 'FontName', fnt);
            uilabel(infoLeft, 'Text', '', 'FontSize', 1);
            uilabel(infoLeft, 'Text', sprintf('最大屈曲/旋前: %.1f°', rec.MaxFlexion), 'FontName', fnt);
            uilabel(infoLeft, 'Text', sprintf('最大伸展/旋后: %.1f°', rec.MaxExtension), 'FontName', fnt);
            uilabel(infoLeft, 'Text', sprintf('ROM: %.1f° / %.0f° (得分 %.0f)', ...
                rec.ROM, rec.TargetROM, rec.ROMScore), 'FontName', fnt, 'FontWeight', 'bold');
            uilabel(infoLeft, 'Text', sprintf('峰值力量: %.1f / %.0f N (得分 %.0f)', ...
                rec.PeakForce, rec.TargetForce, rec.ForceScore), 'FontName', fnt, 'FontWeight', 'bold');
            uilabel(infoLeft, 'Text', sprintf('稳定性: %.0f (%s)  |  完成度: %.0f%%', ...
                rec.StabilityScore, rec.StabilityGrade, rec.CompletionScore), 'FontName', fnt);

            uilabel(infoLeft, 'Text', '', 'FontSize', 1);
            uilabel(infoLeft, 'Text', sprintf('★ 综合评分: %.0f/100 [%s]', ...
                rec.OverallScore, rec.RehabGrade), 'FontName', fnt, ...
                'FontWeight', 'bold', 'FontSize', AppConstants.FONT_SIZE_HEADING, ...
                'FontColor', AppConstants.COLOR_PRIMARY);

            infoRight = uigridlayout(infoGrid, [1, 1], 'Padding', [0,0,0,0]);
            recAx = uitextarea(infoRight, 'Editable', 'off', 'FontName', fnt, ...
                'Value', sprintf('康复建议:\n%s', rec.Rec));

            % 曲线
            curveGrid = uigridlayout(dg, [1, 2], ...
                'ColumnWidth', {'1x', '1x'}, 'Padding', [0,0,0,0], 'ColumnSpacing', 10);

            axAngle = uiaxes(curveGrid);
            if ~isempty(rec.PredAngle) && ~isempty(rec.TimeVector)
                plot(axAngle, rec.TimeVector, rec.PredAngle, 'b-', 'LineWidth', 1.2);
            end
            xlabel(axAngle, '时间 (s)'); ylabel(axAngle, '角度 (°)');
            title(axAngle, '预测角度曲线'); grid(axAngle, 'on');

            axForce = uiaxes(curveGrid);
            if ~isempty(rec.PredForce) && ~isempty(rec.TimeVector)
                plot(axForce, rec.TimeVector, rec.PredForce, 'r-', 'LineWidth', 1.2);
            end
            xlabel(axForce, '时间 (s)'); ylabel(axForce, '力 (N)');
            title(axForce, '预测力量曲线'); grid(axForce, 'on');
        end

        % ==================== 趋势分析区 ====================
        function buildTrendPanel(obj, parent)
            import config.AppConstants

            tg = uigridlayout(parent, [3, 1], ...
                'Padding', [5, 5, 5, 5], 'RowSpacing', 4);

            obj.TrendAxesROM = uiaxes(tg);
            title(obj.TrendAxesROM, 'ROM 恢复趋势', 'FontName', AppConstants.FONT_NAME);
            xlabel(obj.TrendAxesROM, '评估日期', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.TrendAxesROM, 'ROM (°)', 'FontName', AppConstants.FONT_NAME);
            grid(obj.TrendAxesROM, 'on');

            obj.TrendAxesForce = uiaxes(tg);
            title(obj.TrendAxesForce, '力量恢复趋势', 'FontName', AppConstants.FONT_NAME);
            xlabel(obj.TrendAxesForce, '评估日期', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.TrendAxesForce, '峰值力 (N)', 'FontName', AppConstants.FONT_NAME);
            grid(obj.TrendAxesForce, 'on');

            obj.TrendAxesScore = uiaxes(tg);
            title(obj.TrendAxesScore, '综合评分趋势', 'FontName', AppConstants.FONT_NAME);
            xlabel(obj.TrendAxesScore, '评估日期', 'FontName', AppConstants.FONT_NAME);
            ylabel(obj.TrendAxesScore, '评分', 'FontName', AppConstants.FONT_NAME);
            ylim(obj.TrendAxesScore, [0, 100]);
            grid(obj.TrendAxesScore, 'on');
        end

        % ==================== 导入导出区 ====================
        function buildIOPanel(obj, parent)
            import config.AppConstants

            ioGrid = uigridlayout(parent, [2, 3], ...
                'Padding', [10, 10, 10, 10], ...
                'RowSpacing', 8, 'ColumnSpacing', 8);

            % 统一使用蓝色背景、白色字体
            btnStyle = {'BackgroundColor', AppConstants.COLOR_PRIMARY, 'FontColor', [1 1 1]};

            uibutton(ioGrid, 'Text', '导入 MAT', btnStyle{:}, ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.importMAT());

            uibutton(ioGrid, 'Text', '导入 CSV', btnStyle{:}, ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.importCSV());

            uibutton(ioGrid, 'Text', '导出 MAT', btnStyle{:}, ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.exportMAT());

            uibutton(ioGrid, 'Text', '导出 CSV', btnStyle{:}, ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.exportCSV());

            uibutton(ioGrid, 'Text', '批量导出', btnStyle{:}, ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.batchExport());

            uibutton(ioGrid, 'Text', '导出PDF报告', btnStyle{:}, ...
                'FontName', AppConstants.FONT_NAME, ...
                'ButtonPushedFcn', @(~,~) obj.exportPDF());
        end

        % ==================== 数据统计区 ====================
        function buildStatPanel(obj, parent)
            import config.AppConstants

            statGrid = uigridlayout(parent, [4, 4], ...
                'Padding', [10, 10, 10, 10], ...
                'RowSpacing', 5, 'ColumnSpacing', 5);

            pairs = {
                '总患者数', '0'; '总评估次数', '0'; '总训练时长', '0 s'; ...
                '平均ROM', '--°'; '平均峰值力', '-- N'; '平均综合评分', '--'; ...
                '最佳综合评分', '--'; '最近评估', '--'
                };

            statLabels = cell(8, 1);
            for i = 1:8
                uilabel(statGrid, 'Text', pairs{i, 1}, ...
                    'FontName', AppConstants.FONT_NAME, ...
                    'FontColor', AppConstants.COLOR_TEXT_LIGHT, ...
                    'FontSize', AppConstants.FONT_SIZE_SMALL);
                statLabels{i} = uilabel(statGrid, 'Text', pairs{i, 2}, ...
                    'FontName', AppConstants.FONT_NAME, ...
                    'FontWeight', 'bold', ...
                    'FontSize', AppConstants.FONT_SIZE_NORMAL);
            end
            obj.StatTotalPatients = statLabels{1};
            obj.StatTotalAssess = statLabels{2};
            obj.StatTotalDuration = statLabels{3};
            obj.StatAvgROM = statLabels{4};
            obj.StatAvgForce = statLabels{5};
            obj.StatAvgScore = statLabels{6};
            obj.StatBestScore = statLabels{7};
            obj.StatLastDate = statLabels{8};
        end

        % ==================== 演示数据生成 ====================
        function generateDemoData(obj)
            patients = { ...
                struct('id', 'P001', 'name', '张三', 'side', '右侧'), ...
                struct('id', 'P002', 'name', '李四', 'side', '左侧'), ...
                struct('id', 'P003', 'name', '王五', 'side', '右侧') ...
                };
            actions = {'屈伸动作', '旋转动作'};
            baseDates = datetime(2026, 5, 1):7:datetime(2026, 6, 8);

            for p = 1:3
                baseROM = 60 + rand * 40;      % 起始ROM 60-100
                baseForce = 15 + rand * 20;     % 起始力量 15-35N
                baseScore = 55 + rand * 25;     % 起始评分 55-80

                for s = 1:5
                    progress = (s - 1) / 4;     % 0 → 1 进展

                    rec.PatientName = patients{p}.name;
                    rec.PatientID = patients{p}.id;
                    rec.AffectedSide = patients{p}.side;
                    rec.Date = datestr(baseDates(s), 'yyyy-mm-dd');
                    rec.DateNum = datenum(baseDates(s));
                    rec.ActionType = actions{mod(s, 2) + 1};
                    rec.DurationSec = 15 + s * 5;

                    rec.ROM = baseROM + progress * (30 + rand * 20);
                    rec.TargetROM = 120;
                    rec.MaxFlexion = rec.ROM * 0.6 + rand * 5;
                    rec.MaxExtension = -(rec.ROM - rec.MaxFlexion);
                    rec.ROMScore = min(100, rec.ROM / rec.TargetROM * 100);

                    rec.PeakForce = baseForce + progress * (20 + rand * 15);
                    rec.MeanForce = rec.PeakForce * (0.5 + rand * 0.3);
                    rec.TargetForce = 50;
                    rec.ForceScore = min(100, rec.PeakForce / rec.TargetForce * 100);
                    rec.ForceFluctuation = 0.05 + rand * 0.15;

                    rec.StabilityScore = baseScore + progress * (15 + rand * 10) - 55 + progress * 20;
                    rec.StabilityScore = max(40, min(98, rec.StabilityScore));
                    rec.StabilityGrade = utils.RehabMetrics.determineGrade(rec.StabilityScore);
                    rec.FluctuationCoeff = 0.05 + (1 - progress) * 0.15;
                    rec.SmoothnessIdx = 0.7 + progress * 0.25;
                    rec.TremorIndex = 0.01 + (1 - progress) * 0.04;

                    rec.CompletionScore = 65 + progress * 30 + rand * 5;
                    rec.OverallScore = 0.30 * rec.ROMScore + 0.25 * rec.ForceScore + ...
                        0.25 * rec.StabilityScore + 0.20 * rec.CompletionScore;
                    rec.OverallScore = max(0, min(100, rec.OverallScore));
                    rec.RehabGrade = utils.RehabMetrics.determineGrade(rec.OverallScore);
                    rec.Rec = utils.RehabMetrics.generateRecommendation(...
                        rec.ROMScore, rec.ForceScore, rec.StabilityScore, rec.CompletionScore);

                    nPts = 80 + s * 20;
                    t = (0:nPts-1)' / 10;
                    ampAngle = rec.ROM / 2;
                    rec.PredAngle = ampAngle * sin(2 * pi * t / (5 + s * 1.5)) + randn(nPts, 1) * 1.5;
                    rec.PredForce = rec.PeakForce * (0.5 + 0.5 * sin(2 * pi * t / (5 + s * 1.5))) + randn(nPts, 1) * 2;
                    rec.TimeVector = t;

                    fname = sprintf('%s_%s_s%d.mat', rec.PatientID, rec.Date, s);
                    save(fullfile(obj.RecordsPath, fname), 'rec');
                end
            end
            obj.MainApp.log('演示数据已生成: 3位患者 × 5次评估 = 15条记录');
            obj.scanRecords();
        end

        % ==================== 记录扫描与加载 ====================
        function scanRecords(obj)
            obj.Records = {};
            if ~exist(obj.RecordsPath, 'dir'), return; end
            files = dir(fullfile(obj.RecordsPath, '*.mat'));
            for i = 1:length(files)
                try
                    loaded = load(fullfile(obj.RecordsPath, files(i).name));
                    if isfield(loaded, 'rec')
                        obj.Records{end + 1} = loaded.rec;
                    elseif isfield(loaded, 'result')
                        obj.Records{end + 1} = obj.convertResult(loaded.result);
                    end
                catch
                    continue;
                end
            end
            % 按日期降序
            if ~isempty(obj.Records)
                dates = cellfun(@(r) r.DateNum, obj.Records);
                [~, idx] = sort(dates, 'descend');
                obj.Records = obj.Records(idx);
            end
            obj.refreshTable();
            obj.updateTrends();
            obj.updateStats();
            % 更新患者下拉
            patientIDs = unique(cellfun(@(r) r.PatientID, obj.Records, 'UniformOutput', false));
            obj.UIFilterPatient.Items = ['全部', patientIDs];
        end

        function refreshTable(obj)
            tableData = {};
            for i = 1:length(obj.Records)
                r = obj.Records{i};
                if ~obj.passFilter(r), continue; end

                % 所有列均转为字符串，空值显示为占位符
                dateStr = obj.toChar(r.Date, '');
                patientID = obj.toChar(r.PatientID, '未知');
                patientName = obj.toChar(r.PatientName, '未知');
                affectedSide = obj.toChar(r.AffectedSide, '未知');
                actionType = obj.toChar(r.ActionType, '未知');
                rehabGrade = obj.toChar(r.RehabGrade, '未评级');

                durationSec = obj.toScalar(r.DurationSec, 0);
                rom = obj.toScalar(r.ROM, 0);
                peakForce = obj.toScalar(r.PeakForce, 0);
                stabilityScore = obj.toScalar(r.StabilityScore, 0);
                overallScore = obj.toScalar(r.OverallScore, 0);

                tableData{end+1, 1} = dateStr;
                tableData{end, 2} = patientID;
                tableData{end, 3} = patientName;
                tableData{end, 4} = affectedSide;
                tableData{end, 5} = actionType;
                tableData{end, 6} = sprintf('%.0f', durationSec);   % 转为字符串
                tableData{end, 7} = sprintf('%.0f', rom);
                tableData{end, 8} = sprintf('%.1f', peakForce);
                tableData{end, 9} = sprintf('%.0f', stabilityScore);
                tableData{end, 10} = sprintf('%.0f', overallScore);
                tableData{end, 11} = rehabGrade;
            end
            obj.UITable.Data = tableData;
        end

        % 辅助函数：将输入转换为标量字符数组（若为空或非标量则返回默认值）
        function str = toChar(obj, input, defaultStr)
            if isempty(input)
                str = defaultStr;
            elseif isstring(input) && input == ""
                str = defaultStr;
            elseif ischar(input) || isstring(input)
                str = char(input);
            else
                str = defaultStr;
            end
        end

        % 辅助函数：将输入转换为标量数值（若为空或非标量则返回默认值）
        function val = toScalar(~, input, defaultVal)
            if isempty(input) || ~isscalar(input)
                val = defaultVal;
            elseif isnumeric(input)
                val = double(input);
            else
                val = defaultVal;
            end
        end

        function ok = passFilter(obj, r)
            ok = true;
            if obj.UIFilterPatient.Value ~= "全部" && ...
                    ~strcmp(r.PatientID, obj.UIFilterPatient.Value)
                ok = false;
            end
            if obj.UIFilterAction.Value ~= "全部" && ...
                    ~strcmp(r.ActionType, obj.UIFilterAction.Value)
                ok = false;
            end
            if obj.UIFilterGrade.Value ~= "全部" && ...
                    ~strcmp(r.RehabGrade, obj.UIFilterGrade.Value)
                ok = false;
            end
        end

        function rec = convertResult(obj, result)
            rec.PatientName = '';
            rec.PatientID = result.PatientID;
            rec.AffectedSide = '';
            rec.Date = datestr(result.Date, 'yyyy-mm-dd');
            rec.DateNum = datenum(result.Date);
            rec.ActionType = '';
            rec.DurationSec = 0;
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
            rec.PredAngle = result.PredictedAngle;
            rec.PredForce = result.PredictedForce;
            rec.TimeVector = result.TimeVector;
        end

        % ==================== 趋势图更新 ====================
        function updateTrends(obj)
            if isempty(obj.Records), return; end
            dates = cellfun(@(r) r.DateNum, obj.Records);
            roms = cellfun(@(r) r.ROM, obj.Records);
            forces = cellfun(@(r) r.PeakForce, obj.Records);
            scores = cellfun(@(r) r.OverallScore, obj.Records);

            [datesSorted, idx] = sort(dates, 'ascend');
            d = datetime(datesSorted, 'ConvertFrom', 'datenum');

            cla(obj.TrendAxesROM);
            plot(obj.TrendAxesROM, d, roms(idx), 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4);
            ylabel(obj.TrendAxesROM, 'ROM (°)'); grid(obj.TrendAxesROM, 'on');

            cla(obj.TrendAxesForce);
            plot(obj.TrendAxesForce, d, forces(idx), 'r-o', 'LineWidth', 1.5, 'MarkerSize', 4);
            ylabel(obj.TrendAxesForce, '峰值力 (N)'); grid(obj.TrendAxesForce, 'on');

            cla(obj.TrendAxesScore);
            plot(obj.TrendAxesScore, d, scores(idx), 'g-o', 'LineWidth', 1.5, 'MarkerSize', 4);
            ylabel(obj.TrendAxesScore, '评分'); ylim(obj.TrendAxesScore, [0, 100]);
            grid(obj.TrendAxesScore, 'on');
        end

        function updateStats(obj)
            n = length(obj.Records);
            obj.StatTotalAssess.Text = num2str(n);
            if n == 0
                obj.StatTotalPatients.Text = '0';
                obj.StatTotalDuration.Text = '0 s';
                obj.StatAvgROM.Text = '--°';
                obj.StatAvgForce.Text = '-- N';
                obj.StatAvgScore.Text = '--';
                obj.StatBestScore.Text = '--';
                obj.StatLastDate.Text = '--';
                return;
            end
            ids = unique(cellfun(@(r) r.PatientID, obj.Records, 'UniformOutput', false));
            obj.StatTotalPatients.Text = num2str(length(ids));

            totalDur = sum(cellfun(@(r) r.DurationSec, obj.Records));
            obj.StatTotalDuration.Text = sprintf('%.0f s', totalDur);

            avgROM = mean(cellfun(@(r) r.ROM, obj.Records));
            obj.StatAvgROM.Text = sprintf('%.0f°', avgROM);

            avgForce = mean(cellfun(@(r) r.PeakForce, obj.Records));
            obj.StatAvgForce.Text = sprintf('%.1f N', avgForce);

            avgScore = mean(cellfun(@(r) r.OverallScore, obj.Records));
            obj.StatAvgScore.Text = sprintf('%.0f', avgScore);

            bestScore = max(cellfun(@(r) r.OverallScore, obj.Records));
            obj.StatBestScore.Text = sprintf('%.0f', bestScore);

            lastDate = max(cellfun(@(r) r.DateNum, obj.Records));
            obj.StatLastDate.Text = datestr(lastDate, 'yyyy-mm-dd');
        end

        % ==================== 删除记录 ====================
        function deleteSelected(obj)
            if isempty(obj.UITable.Data), return; end
            row = obj.UITable.DisplayData.row;
            % 获取当前选中的行（需要从过滤后的表格映射回Records）
            % 简化：弹窗确认删除最新一条
            choice = uiconfirm(obj.Parent, '确认删除选中的记录?', '删除确认', ...
                'Options', {'确认删除', '取消'}, 'DefaultOption', 2);
            if ~strcmp(choice, '确认删除'), return; end

            % 简单实现：从表格中找匹配记录并删除文件
            tableData = obj.UITable.Data;
            % (实际开发中通过索引映射删除对应 .mat 文件)
            uialert(obj.Parent, '请在 records 目录下手动删除对应文件', '提示', 'Icon', 'info');
        end

        % ==================== 导入导出 ====================
        function importMAT(obj)
            [file, path] = uigetfile('*.mat', '导入评估记录');
            if isequal(file, 0), return; end
            src = fullfile(path, file);
            dst = fullfile(obj.RecordsPath, file);
            copyfile(src, dst);
            obj.scanRecords();
            obj.MainApp.log(sprintf('记录已导入: %s', file));
        end

        function importCSV(obj)
            [file, path] = uigetfile('*.csv', '导入CSV数据');
            if isequal(file, 0), return; end
            try
                T = readtable(fullfile(path, file));
                disp(T);
                obj.MainApp.log(sprintf('CSV已加载: %s', file));
                uialert(obj.Parent, 'CSV数据加载成功!', '导入成功', 'Icon', 'success');
            catch e
                uialert(obj.Parent, e.message, '导入失败', 'Icon', 'error');
            end
        end

        function exportMAT(obj)
            [file, path] = uiputfile('*.mat', '导出MAT');
            if isequal(file, 0), return; end
            records = obj.Records; %#ok<NASGU>
            save(fullfile(path, file), 'records', '-v7.3');
            obj.MainApp.log('记录已导出为MAT');
        end

        function exportCSV(obj)
    [file, path] = uiputfile('*.csv', '导出CSV');
    if isequal(file, 0), return; end
    fullPath = fullfile(path, file);
    try
        % 准备表头和数据
        headers = {'日期','患者ID','姓名','患侧','动作','时长(s)', ...
                   'ROM(°)','峰值力(N)','稳定性','综合分','等级'};
        data = obj.UITable.Data;
        % 打开文件，写入 UTF-8 BOM
        fid = fopen(fullPath, 'w', 'n', 'UTF-8');
        if fid == -1, error('无法创建文件'); end
        % 写入 BOM (EF BB BF)
        fwrite(fid, [239 187 191], 'uint8');
        % 写入表头
        fprintf(fid, '%s', headers{1});
        for i = 2:length(headers)
            fprintf(fid, ',%s', headers{i});
        end
        fprintf(fid, '\n');
        % 写入数据行
        for r = 1:size(data,1)
            row = data(r,:);
            for c = 1:length(row)
                % 将单元格内容转为字符串
                val = row{c};
                if isnumeric(val)
                    valStr = num2str(val);
                elseif ischar(val) || isstring(val)
                    valStr = char(val);
                else
                    valStr = '';
                end
                % 如果包含逗号或换行符，加双引号包裹
                if contains(valStr, ',') || contains(valStr, '"') || contains(valStr, newline)
                    valStr = strrep(valStr, '"', '""');
                    valStr = ['"' valStr '"'];
                end
                fprintf(fid, '%s', valStr);
                if c < length(row), fprintf(fid, ','); end
            end
            fprintf(fid, '\n');
        end
        fclose(fid);
        obj.MainApp.log('记录已导出为CSV (UTF-8 with BOM)');
        uialert(obj.MainApp.getFigure(), 'CSV导出成功!', '成功', 'Icon', 'success');
    catch e
        uialert(obj.MainApp.getFigure(), sprintf('导出失败: %s', e.message), '错误', 'Icon', 'error');
    end
end

        function batchExport(obj)
            if isempty(obj.Records)
                uialert(obj.MainApp.getFigure(), '无记录可导出', '提示', 'Icon', 'info');
                return;
            end
            dirPath = uigetdir(pwd, '选择导出目录');
            if dirPath == 0, return; end
            for i = 1:length(obj.Records)
                rec = obj.Records{i}; %#ok<NASGU>
                fname = sprintf('%s_%s.mat', obj.Records{i}.PatientID, obj.Records{i}.Date);
                save(fullfile(dirPath, fname), 'rec');
            end
            obj.MainApp.log(sprintf('批量导出 %d 条记录', length(obj.Records)));
            uialert(obj.MainApp.getFigure(), sprintf('已导出 %d 条记录', length(obj.Records)), '成功', 'Icon', 'success');
        end

        function exportPDF(obj)
            [file, path] = uiputfile('*.pdf', '导出PDF报告');
            if isequal(file, 0), return; end
            fullPath = fullfile(path, file);

            try
                fig = figure('Visible', 'off', 'Position', [100, 100, 600, 800], ...
                    'PaperUnits', 'points', 'PaperSize', [595, 842], ...
                    'PaperPosition', [0, 0, 595, 842]);

                summaryText = sprintf('康复档案汇总报告\n\n生成日期: %s\n总评估: %d次\n', ...
                    datestr(datetime('now'), 'yyyy-mm-dd'), length(obj.Records));

                uicontrol('Style', 'text', 'String', summaryText, ...
                    'FontSize', 14, 'Position', [50, 720, 500, 100], ...
                    'HorizontalAlignment', 'left');

                if ~isempty(obj.Records)
                    dates = cellfun(@(r) r.DateNum, obj.Records);
                    scores = cellfun(@(r) r.OverallScore, obj.Records);
                    [dS, idx] = sort(dates, 'ascend');
                    d = datetime(dS, 'ConvertFrom', 'datenum');
                    ax = axes('Units', 'points', 'Position', [50, 300, 500, 380]);
                    plot(ax, d, scores(idx), 'b-o', 'LineWidth', 1.5);
                    ylabel(ax, '综合评分'); title(ax, '康复趋势');
                    ylim(ax, [0, 100]); grid(ax, 'on');
                end

                exportgraphics(fig, fullPath, 'ContentType', 'vector');
                close(fig);
                obj.MainApp.log(sprintf('PDF已导出: %s', fullPath));
                uialert(obj.MainApp.getFigure(), 'PDF导出成功!', '成功', 'Icon', 'success');
            catch e
                if exist('fig', 'var') && isvalid(fig), close(fig); end
                uialert(obj.MainApp.getFigure(), e.message, '错误', 'Icon', 'error');
            end
        end
    end
end
