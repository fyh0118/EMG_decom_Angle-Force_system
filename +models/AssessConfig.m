classdef AssessConfig
    % AssessConfig - 康复评估方案配置

    properties
        MovementType    string = '屈腕'   % 屈腕 | 伸腕
        TargetForce     double = 20       % 目标力 (%MVC)
        Repetitions     double = 5        % 重复次数
        TargetROM       double = 60       % 目标ROM (°)
        ToleranceDeg    double = 5        % 角度容差 (°)
        ToleranceForce  double = 5        % 力容差 (%MVC)
        TargetTrajectory string = '正弦'  % 正弦 | 斜坡 | 自由
        CycleSec        double = 5        % 周期 (秒)
        EnableBiofeedback logical = true
        RecordSession   logical = true
    end

    methods
        function obj = AssessConfig()
        end
    end
end
