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
        UIDeleteBtn                 % 删除按钮（切换模式用）
        IsDeleteMode  logical = false
        DeleteChecks  logical = []   % 复选框勾选（长度=Records）
        FilteredIndices  double = [] % 当前显示行→Records索引映射

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

        % 趋势筛选
        UITrendFilterPatient
        UITrendFilterAction

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
            filterGrid = uigridlayout(rg, [1, 9], ...
                'ColumnWidth', {'fit', '1x', 'fit', '1x', 'fit', '1x', 'fit', 'fit', 'fit'}, ...
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
            obj.UIDeleteBtn = uibutton(filterGrid, 'Text', '删除', 'FontName', fnt, ...
                'BackgroundColor', AppConstants.COLOR_DANGER, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) obj.deleteSelected());
            % 记录表格
            colNames = {'日期', '患者ID', '姓名', '患侧', '动作', '时长(s)', ...
                'ROM(°)', '峰值力(N)', '稳定性', '综合分', '等级'};
            obj.UITable = uitable(rg, ...
                'ColumnName', colNames, ...
                'ColumnWidth', {120, 75, 65, 50, 70, 60, 60, 75, 55, 60, 60}, ...
                'RowName', {}, ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_SMALL, ...
                'CellSelectionCallback', @(~, evt) obj.onRecordSelected(evt), ...
                'CellEditCallback', @(~, evt) obj.onCheckboxChanged(evt));
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

            tg = uigridlayout(parent, [4, 1], ...
                'RowHeight', {'fit', '1x', '1x', '1x'}, ...
                'Padding', [5, 5, 5, 5], 'RowSpacing', 4);

            % 趋势筛选栏
            trendFilter = uigridlayout(tg, [1, 4], ...
                'ColumnWidth', {'fit', '1x', 'fit', '1x'}, ...
                'Padding', [0, 0, 0, 0], 'ColumnSpacing', 4);
            fnt = AppConstants.FONT_NAME;
            fsz = AppConstants.FONT_SIZE_SMALL;

            uilabel(trendFilter, 'Text', '患者:', 'FontName', fnt, 'FontSize', fsz);
            obj.UITrendFilterPatient = uidropdown(trendFilter, ...
                'Items', {'全部'}, 'Value', '全部', ...
                'FontName', fnt, 'FontSize', fsz, ...
                'ValueChangedFcn', @(~,~) obj.updateTrends());

            uilabel(trendFilter, 'Text', '动作:', 'FontName', fnt, 'FontSize', fsz);
            obj.UITrendFilterAction = uidropdown(trendFilter, ...
                'Items', {'全部', '屈伸动作', '旋转动作'}, 'Value', '全部', ...
                'FontName', fnt, 'FontSize', fsz, ...
                'ValueChangedFcn', @(~,~) obj.updateTrends());

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


        % ==================== 记录扫描与加载 ====================
        function scanRecords(obj)
            obj.Records = {};
            if ~exist(obj.RecordsPath, 'dir'), return; end
            files = dir(fullfile(obj.RecordsPath, '*.mat'));
            for i = 1:length(files)
                try
                    loaded = load(fullfile(obj.RecordsPath, files(i).name));
                    if isfield(loaded, 'rec')
                        loaded.rec.SourceFile = files(i).name;
                        obj.Records{end + 1} = loaded.rec;
                    elseif isfield(loaded, 'result')
                        rec = obj.convertResult(loaded.result);
                        rec.SourceFile = files(i).name;
                        obj.Records{end + 1} = rec;
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
            % 同步更新趋势筛选下拉
            if ~isempty(obj.UITrendFilterPatient) && isvalid(obj.UITrendFilterPatient)
                prevVal = obj.UITrendFilterPatient.Value;
                obj.UITrendFilterPatient.Items = ['全部', patientIDs];
                if any(strcmp(prevVal, obj.UITrendFilterPatient.Items))
                    obj.UITrendFilterPatient.Value = prevVal;
                else
                    obj.UITrendFilterPatient.Value = '全部';
                end
            end
        end

        function refreshTable(obj)
            import config.AppConstants

            % 确保 DeleteChecks 长度与 Records 一致
            nRecords = length(obj.Records);
            if length(obj.DeleteChecks) ~= nRecords
                obj.DeleteChecks = false(1, nRecords);
            end

            % 确定显示模式和列配置
            if obj.IsDeleteMode
                colNames = {'', '日期', '患者ID', '姓名', '患侧', '动作', '时长(s)', ...
                    'ROM(°)', '峰值力(N)', '稳定性', '综合分', '等级'};
                colWidth = {30, 120, 75, 65, 50, 70, 60, 60, 75, 55, 60, 60};
                colFormat = {'logical', [], [], [], [], [], [], [], [], [], [], []};
                colEditable = [true, false(1, 11)];
            else
                colNames = {'日期', '患者ID', '姓名', '患侧', '动作', '时长(s)', ...
                    'ROM(°)', '峰值力(N)', '稳定性', '综合分', '等级'};
                colWidth = {120, 75, 65, 50, 70, 60, 60, 75, 55, 60, 60};
                colFormat = {};
                colEditable = [];
            end
            obj.UITable.ColumnName = colNames;
            obj.UITable.ColumnWidth = colWidth;
            obj.UITable.ColumnFormat = colFormat;
            obj.UITable.ColumnEditable = colEditable;

            % 构建表格数据
            tableData = {};
            obj.FilteredIndices = [];
            for i = 1:nRecords
                r = obj.Records{i};
                if ~obj.passFilter(r), continue; end
                obj.FilteredIndices(end+1) = i;

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

                rowData = {
                    dateStr, patientID, patientName, affectedSide, actionType, ...
                    sprintf('%.0f', durationSec), sprintf('%.0f', rom), ...
                    sprintf('%.1f', peakForce), sprintf('%.0f', stabilityScore), ...
                    sprintf('%.0f', overallScore), rehabGrade
                    };

                if obj.IsDeleteMode
                    tableData(end+1, :) = [obj.DeleteChecks(i), rowData];
                else
                    tableData(end+1, :) = rowData;
                end
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
            rec.Date = datestr(result.Date, 'yyyy-mm-dd HH:MM');
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

            % 筛选患者
            selPatient = obj.UITrendFilterPatient.Value;
            if strcmp(selPatient, '全部')
                patientFiltered = obj.Records;
            else
                patientFiltered = {};
                for i = 1:length(obj.Records)
                    if strcmp(obj.Records{i}.PatientID, selPatient)
                        patientFiltered{end+1} = obj.Records{i};
                    end
                end
            end

            % 筛选动作
            selAction = obj.UITrendFilterAction.Value;
            if strcmp(selAction, '全部')
                filtered = patientFiltered;
            else
                filtered = {};
                for i = 1:length(patientFiltered)
                    if strcmp(patientFiltered{i}.ActionType, selAction)
                        filtered{end+1} = patientFiltered{i};
                    end
                end
            end

            if isempty(filtered)
                cla(obj.TrendAxesROM); title(obj.TrendAxesROM, 'ROM 恢复趋势 (无数据)');
                cla(obj.TrendAxesForce); title(obj.TrendAxesForce, '力量恢复趋势 (无数据)');
                cla(obj.TrendAxesScore); title(obj.TrendAxesScore, '综合评分趋势 (无数据)');
                return;
            end

            dates = cellfun(@(r) r.DateNum, filtered);
            roms = cellfun(@(r) r.ROM, filtered);
            forces = cellfun(@(r) r.PeakForce, filtered);
            scores = cellfun(@(r) r.OverallScore, filtered);

            [datesSorted, idx] = sort(dates, 'ascend');
            d = datetime(datesSorted, 'ConvertFrom', 'datenum');

            cla(obj.TrendAxesROM);
            plot(obj.TrendAxesROM, d, roms(idx), 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4);
            title(obj.TrendAxesROM, 'ROM 恢复趋势', 'FontName', config.AppConstants.FONT_NAME);
            ylabel(obj.TrendAxesROM, 'ROM (°)'); grid(obj.TrendAxesROM, 'on');

            cla(obj.TrendAxesForce);
            plot(obj.TrendAxesForce, d, forces(idx), 'r-o', 'LineWidth', 1.5, 'MarkerSize', 4);
            title(obj.TrendAxesForce, '力量恢复趋势', 'FontName', config.AppConstants.FONT_NAME);
            ylabel(obj.TrendAxesForce, '峰值力 (N)'); grid(obj.TrendAxesForce, 'on');

            cla(obj.TrendAxesScore);
            plot(obj.TrendAxesScore, d, scores(idx), 'g-o', 'LineWidth', 1.5, 'MarkerSize', 4);
            title(obj.TrendAxesScore, '综合评分趋势', 'FontName', config.AppConstants.FONT_NAME);
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
            import config.AppConstants
            f = obj.MainApp.getFigure();

            if ~obj.IsDeleteMode
                % 进入删除模式
                if isempty(obj.Records)
                    uialert(f, '无记录可删除', '提示', 'Icon', 'info');
                    return;
                end
                obj.IsDeleteMode = true;
                obj.DeleteChecks = false(1, length(obj.Records));
                obj.UIDeleteBtn.Text = '确认删除';
                obj.UIDeleteBtn.BackgroundColor = [0.7 0.1 0.1];
                obj.refreshTable();
                return;
            end

            % 确认删除模式
            checkedIndices = find(obj.DeleteChecks);
            if isempty(checkedIndices)
                % 未勾选任何记录 → 退出删除模式
                obj.exitDeleteMode();
                return;
            end

            nChecked = length(checkedIndices);
            choice = uiconfirm(f, ...
                sprintf('确认删除 %d 条选中的记录？\n此操作不可恢复。', nChecked), ...
                '删除确认', ...
                'Options', {'确认删除', '取消'}, 'DefaultOption', 2);
            if ~strcmp(choice, '确认删除')
                return;
            end

            % 执行删除（从后往前删，避免索引错乱）
            deletedCount = 0;
            failedCount = 0;
            for i = sort(checkedIndices, 'descend')
                rec = obj.Records{i};
                % 优先使用存储的源文件名精确删除
                if isfield(rec, 'SourceFile') && ~isempty(rec.SourceFile)
                    filePath = fullfile(obj.RecordsPath, rec.SourceFile);
                    if exist(filePath, 'file')
                        delete(filePath);
                    end
                else
                    % 回退：按命名模式匹配删除（兼容无SourceFile的旧记录）
                    try
                        datePart = regexp(rec.Date, '^\d{4}-\d{2}-\d{2}', 'match', 'once');
                        if isempty(datePart), datePart = rec.Date; end
                        patterns = {
                            sprintf('%s_%s.mat', rec.PatientID, datePart), ...
                            sprintf('%s_%s_*.mat', rec.PatientID, datePart) ...
                            };
                        for pi = 1:length(patterns)
                            candidates = dir(fullfile(obj.RecordsPath, patterns{pi}));
                            for fi = 1:length(candidates)
                                delete(fullfile(obj.RecordsPath, candidates(fi).name));
                            end
                        end
                    catch e
                        failedCount = failedCount + 1;
                    end
                end
                obj.Records(i) = [];
                deletedCount = deletedCount + 1;
            end

            if failedCount > 0
                obj.MainApp.log(sprintf('已删除 %d 条记录，%d 条文件删除失败', deletedCount, failedCount));
            else
                obj.MainApp.log(sprintf('已删除 %d 条记录', deletedCount));
            end
            obj.exitDeleteMode();
        end

        function exitDeleteMode(obj)
            obj.IsDeleteMode = false;
            obj.DeleteChecks = [];
            obj.UIDeleteBtn.Text = '删除';
            obj.UIDeleteBtn.BackgroundColor = config.AppConstants.COLOR_DANGER;
            obj.scanRecords();
        end

        function onCheckboxChanged(obj, evt)
            if ~obj.IsDeleteMode, return; end
            if isempty(evt.Indices), return; end
            row = evt.Indices(1);
            col = evt.Indices(2);
            if col ~= 1, return; end
            if row > length(obj.FilteredIndices), return; end
            recIdx = obj.FilteredIndices(row);
            val = evt.NewData;
            if iscell(val), val = val{1}; end
            obj.DeleteChecks(recIdx) = logical(val);
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
                fig = figure('Visible', 'off', ...
                    'Units', 'points', ...
                    'Position', [100, 100, 600, 900], ...
                    'PaperUnits', 'points', ...
                    'PaperSize', [595, 842], ...
                    'PaperPosition', [0, 0, 595, 842]);

                % 统计数据计算
                n = length(obj.Records);
                if n > 0
                    ids = unique(cellfun(@(r) r.PatientID, obj.Records, 'UniformOutput', false));
                    totalDur = sum(cellfun(@(r) r.DurationSec, obj.Records));
                    avgROM = mean(cellfun(@(r) r.ROM, obj.Records));
                    avgForce = mean(cellfun(@(r) r.PeakForce, obj.Records));
                    avgScore = mean(cellfun(@(r) r.OverallScore, obj.Records));
                    bestScore = max(cellfun(@(r) r.OverallScore, obj.Records));
                    lastDate = max(cellfun(@(r) r.DateNum, obj.Records));
                    lastDateStr = datestr(lastDate, 'yyyy-mm-dd');
                else
                    ids = {}; totalDur = 0; avgROM = 0; avgForce = 0; avgScore = 0; bestScore = 0; lastDateStr = '--';
                end

                % ---- 标题区域 (annotation textbox 兼容性更好) ----
                annotation(fig, 'textbox', [0.08, 0.91, 0.84, 0.06], ...
                    'String', '肌电慧控 - 康复档案汇总报告', ...
                    'FontName', 'Microsoft YaHei', 'FontSize', 18, 'FontWeight', 'bold', ...
                    'Color', [0.15 0.29 0.46], 'EdgeColor', 'none', ...
                    'HorizontalAlignment', 'center');

                subInfo = sprintf('生成日期: %s    |    总评估次数: %d    |    总患者数: %d', ...
                    datestr(datetime('now'), 'yyyy-mm-dd'), n, length(ids));
                annotation(fig, 'textbox', [0.08, 0.865, 0.84, 0.04], ...
                    'String', subInfo, ...
                    'FontName', 'Microsoft YaHei', 'FontSize', 10, ...
                    'EdgeColor', 'none', 'HorizontalAlignment', 'center');

                % 统计数据表
                statStr = sprintf([ ...
                    '      总患者数:      %d              总评估次数:    %d              总训练时长:    %.0f s\n\n' ...
                    '      平均ROM:       %.0f°             平均峰值力量:  %.1f N         平均综合评分:  %.0f\n\n' ...
                    '      最佳综合评分:  %.0f               最近评估日期:  %s' ...
                    ], length(ids), n, totalDur, avgROM, avgForce, avgScore, bestScore, lastDateStr);
                annotation(fig, 'textbox', [0.08, 0.74, 0.84, 0.12], ...
                    'String', statStr, ...
                    'FontName', 'Microsoft YaHei', 'FontSize', 10, ...
                    'EdgeColor', [0.15 0.29 0.46], 'LineWidth', 1, ...
                    'BackgroundColor', [0.95 0.96 0.98]);

                % ---- 三趋势图 ----
                if ~isempty(obj.Records)
                    dates = cellfun(@(r) r.DateNum, obj.Records);
                    roms = cellfun(@(r) r.ROM, obj.Records);
                    forces = cellfun(@(r) r.PeakForce, obj.Records);
                    scores = cellfun(@(r) r.OverallScore, obj.Records);
                    [dS, idx] = sort(dates, 'ascend');
                    d = datetime(dS, 'ConvertFrom', 'datenum');

                    axROM = axes('Position', [0.10, 0.55, 0.84, 0.17]);
                    plot(axROM, d, roms(idx), 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'b');
                    ylabel(axROM, 'ROM (°)'); title(axROM, 'ROM 恢复趋势');
                    grid(axROM, 'on');

                    axForce = axes('Position', [0.10, 0.33, 0.84, 0.17]);
                    plot(axForce, d, forces(idx), 'r-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'r');
                    ylabel(axForce, '峰值力 (N)'); title(axForce, '力量恢复趋势');
                    grid(axForce, 'on');

                    axScore = axes('Position', [0.10, 0.11, 0.84, 0.17]);
                    plot(axScore, d, scores(idx), 'g-o', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'g');
                    ylabel(axScore, '评分'); xlabel(axScore, '评估日期');
                    title(axScore, '综合评分趋势');
                    ylim(axScore, [0, 100]); grid(axScore, 'on');
                end

                print(fig, fullPath, '-dpdf', '-bestfit');
                close(fig);
                obj.MainApp.log(sprintf('PDF报告已导出: %s', fullPath));
                uialert(obj.MainApp.getFigure(), 'PDF报告导出成功!', '成功', 'Icon', 'success');
            catch e
                if exist('fig', 'var') && isvalid(fig), close(fig); end
                uialert(obj.MainApp.getFigure(), e.message, '错误', 'Icon', 'error');
            end
        end
    end
end
