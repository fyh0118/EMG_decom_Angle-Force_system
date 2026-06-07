classdef AcquisitionConfig
    % AcquisitionConfig - 数据采集配置参数

    properties
        DeviceType      string = 'HD-sEMG'
        Fs              double = 2000
        FlexorEnabled   logical = true
        ExtensorEnabled logical = true
        DisplayWindowSec double = 5
        RecordingDurationSec double = 20
        SavePath        string = ''
        SubjectID       string = ''
        Protocol        string = '屈腕'
        Notes           string = ''
        CameraEnabled   logical = false
        RecordAngle     logical = false
    end

    methods
        function obj = AcquisitionConfig()
        end

        function nCh = getActiveChannels(obj)
            nCh = 0;
            if obj.FlexorEnabled, nCh = nCh + 64; end
            if obj.ExtensorEnabled, nCh = nCh + 64; end
        end
    end
end
