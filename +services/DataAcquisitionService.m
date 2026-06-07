classdef DataAcquisitionService < handle
    % DataAcquisitionService - 数据采集设备服务封装
    %   封装HD-sEMG设备的数据采集（支持在线和模拟模式）

    properties
        Config          models.AcquisitionConfig
        IsConnected     logical = false
        IsAcquiring     logical = false
        Buffer          double          % 数据缓冲区
        Timestamps      double          % 时间戳
        BufferDurationSec double = 30   % 缓冲区时长
    end

    properties (Access = private)
        Timer           timer
    end

    events
        DataAvailable       % 新数据到达事件
        DeviceDisconnected  % 设备断开事件
    end

    methods
        function obj = DataAcquisitionService(config)
            if nargin < 1
                config = models.AcquisitionConfig();
            end
            obj.Config = config;
        end

        function success = connectDevice(obj, deviceType)
            % 连接设备（实际使用时替换为DAQ驱动调用）
            obj.Config.DeviceType = deviceType;
            obj.IsConnected = true;
            success = true;
            fprintf('[DAQ] 设备已连接: %s\n', deviceType);
        end

        function disconnect(obj)
            if obj.IsAcquiring
                obj.stopAcquisition();
            end
            obj.IsConnected = false;
            notify(obj, 'DeviceDisconnected');
        end

        function startAcquisition(obj, fs, nChannels)
            % 开始数据采集
            % 在线模式：从DAQ硬件读取
            % 模拟模式：生成模拟数据用于演示
            if ~obj.IsConnected
                warning('设备未连接，使用模拟模式');
            end
            obj.Config.Fs = fs;
            obj.IsAcquiring = true;
            nBufferSamples = round(obj.BufferDurationSec * fs);
            obj.Buffer = zeros(nChannels, nBufferSamples);
            obj.Timestamps = zeros(1, nBufferSamples);

            % 使用定时器模拟数据采集 (实际使用中替换为DAQ回调)
            obj.Timer = timer('Period', 0.1, 'ExecutionMode', 'fixedRate', ...
                'TimerFcn', @(~,~) obj.acquireBlock());
            start(obj.Timer);
        end

        function stopAcquisition(obj)
            obj.IsAcquiring = false;
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
            end
        end

        function acquireBlock(obj)
            % 模拟数据采集 (每100ms产生200个样本 @2kHz)
            if ~obj.IsAcquiring, return; end
            nNewSamples = round(0.1 * obj.Config.Fs);
            % 生成模拟EMG数据 (替换为实际DAQ读取)
            newData = 0.1 * randn(obj.Config.getActiveChannels(), nNewSamples);
            notify(obj, 'DataAvailable');
        end
    end
end
