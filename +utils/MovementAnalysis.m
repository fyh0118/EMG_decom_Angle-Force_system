classdef MovementAnalysis
    % MovementAnalysis - 运动分析工具（ROM、平滑度等）

    methods (Static)
        function [rom, romPercent] = computeROM(angleTrace, targetROM)
            % 计算关节活动度 ROM
            rom = max(angleTrace) - min(angleTrace);
            if nargin > 1 && targetROM > 0
                romPercent = (rom / targetROM) * 100;
            else
                romPercent = NaN;
            end
        end

        function [normJerk, smoothnessScore] = computeSmoothness(angleTrace, fs)
            % 计算归一化Jerk (运动平滑度指标)
            % 数值越小 = 运动越平滑
            jerk = diff(angleTrace, 3) * (fs^3);  % 三阶导数 (加加速度)
            jerkRMS = sqrt(mean(jerk.^2));
            rom = max(angleTrace) - min(angleTrace);
            duration = length(angleTrace) / fs;
            if rom > 0 && duration > 0
                normJerk = jerkRMS * (duration^5) / (rom^2);
            else
                normJerk = NaN;
            end
            % 转换到0-100分数 (经验阈值: normJerk < 10 = good, > 100 = poor)
            if ~isnan(normJerk)
                smoothnessScore = max(0, min(100, 100 * exp(-normJerk / 30)));
            else
                smoothnessScore = NaN;
            end
        end

        function accuracy = computeTrackingAccuracy(actualTrace, targetTrace, tolerance)
            % 计算跟踪精度: 在容差范围内的样本百分比
            if nargin < 3, tolerance = 5; end
            withinTolerance = abs(actualTrace(:) - targetTrace(:)) <= tolerance;
            accuracy = (sum(withinTolerance) / length(withinTolerance)) * 100;
        end

        function [targetAngle, targetForce] = generateTargetTrajectory(trajectoryType, ...
                durationSec, fs, targetROM, targetForceLevel, cycleSec)
            % 生成目标轨迹 (角度+力)
            nSamples = round(durationSec * fs);
            t = (0:nSamples-1)' / fs;

            switch lower(trajectoryType)
                case '正弦'
                    targetAngle = (targetROM / 2) * sin(2 * pi * t / cycleSec);
                    targetForce = targetForceLevel * (0.5 + 0.5 * sin(2 * pi * t / cycleSec));
                case '斜坡'
                    targetAngle = targetROM * (mod(t, cycleSec) / cycleSec - 0.5) * 2;
                    targetForce = targetForceLevel * mod(t, cycleSec) / cycleSec;
                case '自由'
                    targetAngle = zeros(nSamples, 1);
                    targetForce = targetForceLevel * ones(nSamples, 1);
                otherwise
                    targetAngle = zeros(nSamples, 1);
                    targetForce = zeros(nSamples, 1);
            end
        end
    end
end
