classdef SessionData
    % SessionData - 单次采集/实验会话的元数据

    properties
        SessionID      string = ""
        PatientID      string = ""
        Protocol       string = ""      % 实验方案: '屈腕', '伸腕', etc.
        Date           datetime
        DurationSec    double = 0       % 录制时长 (秒)
        Fs             double = 2000    % 采样率
        NChannels      double = 128    % 通道数
        RawDataPath    string = ""      % 原始数据文件路径
        Notes          string = ""

        % 分解结果摘要
        NMUs           double = 0
        NFlexorMUs     double = 0
        NExtensorMUs   double = 0
        MeanSIL        double = NaN
        MeanPNR        double = NaN
        DecompResultPath string = ""

        % 预测结果摘要
        AngleRMSE      double = NaN
        AngleMAE       double = NaN
        AngleR2        double = NaN
        ForceRMSE      double = NaN
        ForceMAE       double = NaN
        ForceR2        double = NaN

        % 评估结果摘要
        ROM            double = NaN
        Smoothness     double = NaN
        OverallScore   double = NaN
    end

    methods
        function obj = SessionData()
            obj.Date = datetime('now');
        end

        function label = getDisplayLabel(obj)
            dateStr = datestr(obj.Date, 'yyyy-mm-dd HH:MM');
            label = sprintf('[%s] %s - %s', dateStr, obj.PatientID, obj.Protocol);
        end

        function s = toStruct(obj)
            props = properties(obj);
            for i = 1:length(props)
                s.(props{i}) = obj.(props{i});
            end
        end

        function obj = fromStruct(obj, s)
            for fn = fieldnames(s)'
                if isprop(obj, fn{1})
                    obj.(fn{1}) = s.(fn{1});
                end
            end
        end
    end
end
