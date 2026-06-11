classdef AssessmentService < handle
    % AssessmentService - 康复评估服务

    methods (Static)
        function result = runFullAssessment(predictedAngle, predictedForce, ...
                trueAngle, trueForce, timeVector, config, patientInfo)
            % 运行完整评估
            %
            % INPUT:
            %   predictedAngle/Force - 模型预测输出
            %   trueAngle/Force      - 真实标签 (或实测值)
            %   timeVector           - 时间向量
            %   config               - AssessConfig 评估方案配置
            %   patientInfo          - PatientInfo 患者信息
            %
            % OUTPUT:
            %   result - AssessmentResult 对象

            import models.AssessmentResult
            import utils.AngleMetrics
            import utils.MovementAnalysis

            result = AssessmentResult();
            result.PatientID = patientInfo.PatientID;
            result.Date = datetime('now');

            % 1. ROM评估
            [result.ROM, result.ROMPercent] = MovementAnalysis.computeROM(...
                predictedAngle, config.TargetROM);
            result.ROMTarget = config.TargetROM;

            % 2. 平滑度评估
            fs = 2000 / (length(predictedAngle) / timeVector(end));
            fs = max(fs, 1);
            [result.NormalizedJerk, result.SmoothnessScore] = ...
                MovementAnalysis.computeSmoothness(predictedAngle, fs);

            % 3. 角度跟踪精度 (如果有目标轨迹)
            if ~isempty(trueAngle)
                result.AngleTrackingAccuracy = MovementAnalysis.computeTrackingAccuracy(...
                    predictedAngle, trueAngle, config.ToleranceDeg);
                angleMetrics = AngleMetrics.computeAll(trueAngle, predictedAngle);
                result.AngleRMSE = angleMetrics.RMSE;
            else
                result.AngleTrackingAccuracy = NaN;
                result.AngleRMSE = NaN;
            end

            % 4. 力跟踪精度
            if ~isempty(trueForce)
                result.ForceTrackingAccuracy = MovementAnalysis.computeTrackingAccuracy(...
                    predictedForce, trueForce, config.ToleranceForce);
                forceMetrics = AngleMetrics.computeAll(trueForce, predictedForce);
                result.ForceRMSE = forceMetrics.RMSE;
            else
                result.ForceTrackingAccuracy = NaN;
                result.ForceRMSE = NaN;
            end

            % 5. 预测精度
            if ~isempty(trueAngle)
                angleMet = AngleMetrics.computeAll(trueAngle, predictedAngle);
                result.PredAngleRMSE = angleMet.RMSE;
                result.PredAngleR2 = angleMet.R2;
            end
            if ~isempty(trueForce)
                forceMet = AngleMetrics.computeAll(trueForce, predictedForce);
                result.PredForceRMSE = forceMet.RMSE;
                result.PredForceR2 = forceMet.R2;
            end

            % 6. 维度评分
            result.DimensionScores.ROM = min(100, result.ROMPercent);
            result.DimensionScores.Smoothness = result.SmoothnessScore;
            result.DimensionScores.AngleTracking = result.AngleTrackingAccuracy;
            result.DimensionScores.ForceTracking = result.ForceTrackingAccuracy;

            % 一致性评分 (基于角度预测R²)
            if ~isnan(result.PredAngleR2)
                result.DimensionScores.Consistency = result.PredAngleR2 * 100;
            else
                result.DimensionScores.Consistency = NaN;
            end

            % 7. 综合评分 (加权)
            weights = struct('ROM', 0.20, 'Smoothness', 0.15, ...
                'AngleTracking', 0.25, 'ForceTracking', 0.25, 'Consistency', 0.15);
            result.OverallScore = services.AssessmentService.computeOverallScore(...
                result.DimensionScores, weights);

            % 8. 保存时间序列数据
            result.TimeVector = timeVector;
            result.PredictedAngle = predictedAngle;
            result.PredictedForce = predictedForce;
            if ~isempty(trueAngle), result.ActualAngle = trueAngle; end
            if ~isempty(trueForce), result.ActualForce = trueForce; end
        end

        function [score] = computeOverallScore(dimScores, weights)
            % 计算加权综合评分 (0-100)
            score = 0;
            totalWeight = 0;
            fn = fieldnames(dimScores);
            for i = 1:length(fn)
                val = dimScores.(fn{i});
                if ~isnan(val) && isfield(weights, fn{i})
                    score = score + val * weights.(fn{i});
                    totalWeight = totalWeight + weights.(fn{i});
                end
            end
            if totalWeight > 0
                score = score / totalWeight;
            else
                score = 50;
            end
            score = max(0, min(100, score));
        end

        function result = runRehabAssessment(predictedAngle, predictedForce, ...
                timeVector, targetROM, targetForce, patientInfo)
            % 康复模式评估（无真实标签）
            import models.AssessmentResult
            import utils.RehabMetrics

            result = AssessmentResult();
            if nargin >= 6 && ~isempty(patientInfo)
                result.PatientID = patientInfo.PatientID;
            end
            result.Date = datetime('now');
            result.TargetROM = targetROM;
            result.TargetForce = targetForce;

            % 1. ROM评估
            romResult = RehabMetrics.computeROM(predictedAngle);
            result.MaxFlexion = romResult.MaxFlexion;
            result.MaxExtension = romResult.MaxExtension;
            result.ROM = romResult.ROM;
            result.ROMScore = RehabMetrics.computeROMScore(romResult.ROM, targetROM);
            result.ROMPercent = result.ROMScore;

            % 2. 力量评估
            forceResult = RehabMetrics.computeForceMetrics(predictedForce);
            result.PeakForce = forceResult.PeakForce;
            result.MeanForce = forceResult.MeanForce;
            result.ForceFluctuation = forceResult.FluctuationRate;
            result.ForceScore = RehabMetrics.computeForceScore(forceResult.PeakForce, targetForce);

            % 3. 稳定性评估
            fs = 2000 / max(1, (length(predictedAngle) / max(timeVector(end), 0.01)));
            stabResult = RehabMetrics.computeStability(predictedAngle, fs);
            result.SmoothnessIdx = stabResult.Smoothness;
            result.FluctuationCoeff = stabResult.FluctuationCoeff;
            result.TremorIndex = stabResult.TremorIndex;
            result.StabilityScore = stabResult.Score;
            result.StabilityGrade = stabResult.Grade;

            % 4. 动作完成度
            result.CompletionScore = RehabMetrics.computeCompletionScore(...
                predictedAngle, targetROM, predictedForce, targetForce);

            % 5. 综合评分
            [result.OverallScore, result.RehabGrade] = RehabMetrics.computeCompositeScore(...
                result.ROMScore, result.ForceScore, result.StabilityScore, result.CompletionScore);

            % 6. 康复建议
            result.RehabRecommendation = RehabMetrics.generateRecommendation(...
                result.ROMScore, result.ForceScore, result.StabilityScore, result.CompletionScore);

            % 7. 保存时间序列
            result.TimeVector = timeVector;
            result.PredictedAngle = predictedAngle;
            result.PredictedForce = predictedForce;
        end

        function [recommendation] = generateRecommendation(result)
            % 生成康复建议
            recommendations = {};

            if ~isnan(result.ROM)
                if result.ROMPercent < 60
                    recommendations{end + 1} = '关节活动度不足，建议从较小ROM开始训练';
                elseif result.ROMPercent < 85
                    recommendations{end + 1} = '关节活动度良好，可逐步增加目标ROM';
                else
                    recommendations{end + 1} = '关节活动度优秀，可维持当前训练方案';
                end
            end

            if ~isnan(result.SmoothnessScore)
                if result.SmoothnessScore < 50
                    recommendations{end + 1} = '运动平滑度偏低，建议降低运动速度进行练习';
                end
            end

            if ~isnan(result.ForceTrackingAccuracy)
                if result.ForceTrackingAccuracy < 70
                    recommendations{end + 1} = '力控制能力需改善，建议进行分阶段力训练';
                end
            end

            if isempty(recommendations)
                recommendation = '各项指标良好，继续保持当前康复方案';
            else
                recommendation = strjoin(recommendations, '；');
            end
        end
    end
end
