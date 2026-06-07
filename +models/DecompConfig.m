classdef DecompConfig
    % DecompConfig - 肌电分解参数配置

    properties
        ExtensionFactor  double = 0.5
        MinFiringRate    double = 5      % Hz
        MaxFiringRate    double = 35     % Hz
        SILThreshold     double = 0.90
        MaxIterations    double = 100
        AutoDetect       logical = true
        UseParallel      logical = false
        Fs               double = 2000
    end

    methods
        function obj = DecompConfig()
        end
    end
end
