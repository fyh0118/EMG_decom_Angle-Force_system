classdef SessionBrowser
    % SessionBrowser - 会话浏览组件

    properties (Access = private)
        Parent
        MainApp
        UITable
        UIFilterPatient
        UIFilterProtocol
        UIDateFrom
        UIDateTo
        UIRefreshBtn
        UILoadBtn
        UIDeleteBtn
        UIRecordCount
    end

    properties (Access = public)
        SessionList   models.SessionData
        FilteredList  models.SessionData
        OnSessionSelected  function_handle  % 回调: (sessionData)
    end

    methods
        function obj = SessionBrowser(parent, mainApp)
            obj.Parent = parent;
            obj.MainApp = mainApp;
            obj.SessionList = models.SessionData.empty();
            obj.FilteredList = models.SessionData.empty();
            obj.buildUI();
        end

        function buildUI(obj)
            import config.AppConstants

            mainGrid = uigridlayout(obj.Parent, [3, 1], ...
                'RowHeight', {'fit', '1x', 'fit'}, ...
                'Padding', [0, 0, 0, 0], ...
                'RowSpacing', 5);

            % ---- 筛选栏 ----
            filterGrid = uigridlayout(mainGrid, [1, 6], ...
                'ColumnWidth', {'fit', 'fit', 'fit', 'fit', '1x', 'fit'}, ...
                'Padding', [0, 0, 0, 0]);

            uilabel(filterGrid, 'Text', '患者:', 'FontName', AppConstants.FONT_NAME);
            obj.UIFilterPatient = uidropdown(filterGrid, ...
                'Items', {'全部'}, 'Value', '全部', ...
                'FontName', AppConstants.FONT_NAME);

            uilabel(filterGrid, 'Text', '方案:', 'FontName', AppConstants.FONT_NAME);
            obj.UIFilterProtocol = uidropdown(filterGrid, ...
                'Items', {'全部', '屈腕', '伸腕', '对捏', '侧捏'}, ...
                'Value', '全部', ...
                'ValueChangedFcn', @(~,~) obj.applyFilter(), ...
                'FontName', AppConstants.FONT_NAME);

            obj.UIRefreshBtn = uibutton(filterGrid, ...
                'Text', '刷新', ...
                'ButtonPushedFcn', @(~,~) obj.refresh(), ...
                'FontName', AppConstants.FONT_NAME);

            % ---- 会话列表表格 ----
            obj.UITable = uitable(mainGrid, ...
                'ColumnName', {'日期', '患者', '方案', '时长(s)', 'MU数', '角度RMSE', '力RMSE', '得分'}, ...
                'ColumnWidth', {140, 80, 60, 60, 50, 80, 80, 50}, ...
                'ColumnSortable', [true, true, true, true, true, true, true, true], ...
                'CellSelectionCallback', @(src, evt) obj.onRowSelected(evt), ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontSize', AppConstants.FONT_SIZE_SMALL);

            % ---- 操作栏 ----
            actionGrid = uigridlayout(mainGrid, [1, 5], ...
                'ColumnWidth', {'fit', 'fit', 'fit', '1x', 'fit'}, ...
                'Padding', [0, 0, 0, 0]);

            obj.UILoadBtn = uibutton(actionGrid, 'Text', '加载选中', ...
                'ButtonPushedFcn', @(~,~) obj.loadSelected(), ...
                'FontName', AppConstants.FONT_NAME);
            obj.UIDeleteBtn = uibutton(actionGrid, 'Text', '删除选中', ...
                'ButtonPushedFcn', @(~,~) obj.deleteSelected(), ...
                'FontName', AppConstants.FONT_NAME);

            obj.UIRecordCount = uilabel(actionGrid, ...
                'Text', '共 0 条记录', ...
                'HorizontalAlignment', 'right', ...
                'FontName', AppConstants.FONT_NAME, ...
                'FontColor', AppConstants.COLOR_TEXT_LIGHT);
        end

        function refresh(obj)
            obj.applyFilter();
        end

        function applyFilter(obj)
            patientFilter = obj.UIFilterPatient.Value;
            protocolFilter = obj.UIFilterProtocol.Value;

            allSessions = obj.SessionList;
            if isempty(allSessions)
                obj.FilteredList = allSessions;
            else
                keep = true(length(allSessions), 1);
                if ~strcmp(patientFilter, '全部')
                    keep = keep & strcmp({allSessions.PatientID}, patientFilter);
                end
                if ~strcmp(protocolFilter, '全部')
                    keep = keep & strcmp({allSessions.Protocol}, protocolFilter);
                end
                obj.FilteredList = allSessions(keep);
            end
            obj.updateTable();
        end

        function updateTable(obj)
            n = length(obj.FilteredList);
            if n == 0
                obj.UITable.Data = cell(0, 8);
            else
                tableData = cell(n, 8);
                for i = 1:n
                    s = obj.FilteredList(i);
                    tableData{i, 1} = datestr(s.Date, 'yyyy-mm-dd HH:MM');
                    tableData{i, 2} = s.PatientID;
                    tableData{i, 3} = s.Protocol;
                    tableData{i, 4} = sprintf('%.0f', s.DurationSec);
                    tableData{i, 5} = sprintf('%d', s.NMUs);
                    tableData{i, 6} = sprintf('%.2f', s.AngleRMSE);
                    tableData{i, 7} = sprintf('%.2f', s.ForceRMSE);
                    tableData{i, 8} = sprintf('%.0f', s.OverallScore);
                end
                obj.UITable.Data = tableData;
            end
            obj.UIRecordCount.Text = sprintf('共 %d 条记录', n);
        end

        function addSession(obj, session)
            obj.SessionList(end + 1) = session;
            obj.applyFilter();
        end

        function onRowSelected(obj, evt)
            if ~isempty(evt.Indices)
                idx = evt.Indices(1);
                selectedSession = obj.FilteredList(idx);
                if ~isempty(obj.OnSessionSelected)
                    obj.OnSessionSelected(selectedSession);
                end
            end
        end

        function loadSelected(obj)
            if ~isempty(obj.UITable.Data)
                % 由外部通过回调处理
                sel = obj.UITable.DisplayData(obj.UITable.DisplayDataRow, :);
                if ~isempty(sel) && ~isempty(obj.OnSessionSelected)
                    % 找到选中的会话
                    for i = 1:length(obj.FilteredList)
                        if strcmp(datestr(obj.FilteredList(i).Date, 'yyyy-mm-dd HH:MM'), sel{1})
                            obj.OnSessionSelected(obj.FilteredList(i));
                            break;
                        end
                    end
                end
            end
        end

        function deleteSelected(obj)
            sel = obj.UITable.DisplayData(obj.UITable.DisplayDataRow, :);
            if isempty(sel), return; end
            answer = uiconfirm(obj.Parent, ...
                sprintf('确定要删除选中的会话记录吗？'), '确认删除', ...
                'Options', {'确定', '取消'}, 'DefaultOption', 2);
            if strcmp(answer, '确定')
                for i = length(obj.SessionList):-1:1
                    if strcmp(datestr(obj.SessionList(i).Date, 'yyyy-mm-dd HH:MM'), sel{1})
                        obj.SessionList(i) = [];
                        break;
                    end
                end
                obj.applyFilter();
            end
        end
    end
end
