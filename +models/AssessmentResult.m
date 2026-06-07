classdef AssessmentResult
    % AssessmentResult - 康复评估结果数据类

    properties
        SessionID       string = ""
        PatientID       string = ""
        Date            datetime

        % ROM
        ROM             double = NaN    % 实际ROM (°)
        ROMTarget       double = NaN    % 目标ROM (°)
        ROMPercent      double = NaN    % 达成百分比

        % 平滑度
        NormalizedJerk  double = NaN
        SmoothnessScore double = NaN    % 0-100

        % 角度跟踪
        AngleTrackingAccuracy double = NaN  % 0-100
        AngleRMSE       double = NaN

        % 力跟踪
        ForceTrackingAccuracy double = NaN  % 0-100
        ForceRMSE       double = NaN

        % 预测精度
        PredAngleRMSE   double = NaN
        PredAngleR2     double = NaN
        PredForceRMSE   double = NaN
        PredForceR2     double = NaN

        % 综合评分 (0-100)
        OverallScore    double = NaN

        % 五维评分
        DimensionScores struct

        % 时间序列数据（用于报告绘图）
        TimeVector      double = []
        TargetAngle     double = []
        ActualAngle     double = []
        PredictedAngle  double = []
        TargetForce     double = []
        ActualForce     double = []
        PredictedForce  double = []
    end

    methods
        function obj = AssessmentResult()
            obj.Date = datetime('now');
            obj.DimensionScores = struct(...
                'ROM', NaN, ...
                'Smoothness', NaN, ...
                'AngleTracking', NaN, ...
                'ForceTracking', NaN, ...
                'Consistency', NaN);
        end
    end
end
