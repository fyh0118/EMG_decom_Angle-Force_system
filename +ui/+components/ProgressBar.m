classdef ProgressBar
    % ProgressBar - 进度条组件 (用于分解进度显示)

    properties (Access = private)
        Dlg
        Bar
        Label
    end

    methods
        function obj = ProgressBar(title, message)
            obj.Dlg = uiprogressdlg(...
                'Title', title, ...
                'Message', message, ...
                'Indeterminate', 'off', ...
                'Cancelable', 'on');
        end

        function update(obj, percent, message)
            if isvalid(obj.Dlg)
                obj.Dlg.Value = percent;
                obj.Dlg.Message = message;
            end
        end

        function [isCancelled] = isCancelled(obj)
            isCancelled = false;
            if isvalid(obj.Dlg)
                isCancelled = obj.Dlg.CancelRequested;
            end
        end

        function close(obj)
            if isvalid(obj.Dlg)
                close(obj.Dlg);
            end
        end
    end
end
