classdef RehabMetrics
    % RehabMetrics - 康复评估指标计算工具
    %   ROM、力量、稳定性、完成度、综合评分

    methods (Static)
        function result = computeROM(predictedAngle)
            result.MaxFlexion = max(predictedAngle);
            result.MaxExtension = min(predictedAngle);
            result.ROM = result.MaxFlexion - result.MaxExtension;
        end

        function result = computeForceMetrics(predictedForce)
            result.MeanForce = mean(predictedForce, 'omitnan');
            result.PeakForce = max(predictedForce);
            result.FluctuationRate = std(predictedForce, 'omitnan') / max(result.MeanForce, 0.01);
        end

        function result = computeStability(predictedAngle, fs)
            if nargin < 2 || isempty(fs) || fs <= 0
                fs = 10;
            end
            angle = predictedAngle(:);
            n = length(angle);
            if n < 3
                result.Smoothness = 50;
                result.FluctuationCoeff = 0;
                result.TremorIndex = 0;
                result.Score = 50;
                result.Grade = '合格';
                return;
            end
            % 平滑度: 基于归一化 Jerk (越低越平滑)
            jerk = diff(angle, 3);
            result.Smoothness = max(0, 1 - min(1, std(jerk) / max(std(angle), 0.01) / 100));
            % 波动系数
            env = movmax(angle, max(3, round(n/20))) - movmin(angle, max(3, round(n/20)));
            result.FluctuationCoeff = std(env) / max(mean(env), 0.01);
            % Tremor 指数 (高频能量占比)
            nfft = 2^nextpow2(n);
            Y = fft(angle - mean(angle), nfft);
            P = abs(Y).^2 / nfft;
            freqAxis = (0:nfft-1)' * fs / nfft;
            highBand = freqAxis >= 3 & freqAxis <= 12;
            tremorEnergy = sum(P(highBand));
            totalEnergy = sum(P);
            if totalEnergy > 0
                result.TremorIndex = tremorEnergy / totalEnergy;
            else
                result.TremorIndex = 0;
            end
            % 稳定性综合评分
            smoothScore = result.Smoothness * 100;
            fluctScore = max(0, 100 - result.FluctuationCoeff * 50);
            tremorScore = max(0, 100 - result.TremorIndex * 200);
            result.Score = 0.4 * smoothScore + 0.3 * fluctScore + 0.3 * tremorScore;
            result.Score = max(0, min(100, result.Score));
            result.Grade = utils.RehabMetrics.determineGrade(result.Score);
        end

        function score = computeROMScore(rom, targetROM)
            if targetROM <= 0
                score = 50;
            else
                score = min(100, rom / targetROM * 100);
            end
        end

        function score = computeForceScore(peakForce, targetForce)
            if targetForce <= 0
                score = 50;
            else
                score = min(100, peakForce / targetForce * 100);
            end
        end

        function score = computeCompletionScore(predictedAngle, targetROM, predictedForce, targetForce)
            angle = predictedAngle(:);
            force = predictedForce(:);
            rom = max(angle) - min(angle);
            peakF = max(force);
            romRatio = min(1, rom / max(targetROM, 0.01));
            forceRatio = min(1, peakF / max(targetForce, 0.01));
            score = (romRatio * 0.6 + forceRatio * 0.4) * 100;
            score = max(0, min(100, score));
        end

        function [totalScore, grade] = computeCompositeScore(romScore, forceScore, stabilityScore, completionScore)
            totalScore = 0.30 * romScore + 0.25 * forceScore + 0.25 * stabilityScore + 0.20 * completionScore;
            totalScore = max(0, min(100, totalScore));
            grade = utils.RehabMetrics.determineGrade(totalScore);
        end

        function grade = determineGrade(score)
            if score >= 90
                grade = '优秀';
            elseif score >= 80
                grade = '良好';
            elseif score >= 70
                grade = '合格';
            elseif score >= 60
                grade = '待提高';
            else
                grade = '较差';
            end
        end

        function rec = generateRecommendation(romScore, forceScore, stabilityScore, completionScore)
            recs = {};
            if romScore < 60
                recs{end + 1} = '关节活动度不足，建议从较小ROM开始训练';
            elseif romScore < 85
                recs{end + 1} = '关节活动度良好，可逐步增加目标ROM';
            else
                recs{end + 1} = '关节活动度优秀，可维持当前训练方案';
            end
            if forceScore < 60
                recs{end + 1} = '力量输出不足，建议进行分阶段力量训练';
            elseif forceScore < 85
                recs{end + 1} = '力量控制能力良好，可适当提高目标力量';
            else
                recs{end + 1} = '力量输出优秀，继续保持';
            end
            if stabilityScore < 60
                recs{end + 1} = '运动稳定性偏低，建议降低运动速度进行练习';
            elseif stabilityScore < 85
                recs{end + 1} = '运动稳定性良好，可逐步增加训练复杂度';
            else
                recs{end + 1} = '运动稳定性优秀';
            end
            if completionScore < 60
                recs{end + 1} = '动作完成度不足，建议调整目标值或增加辅助';
            end
            rec = strjoin(recs, '；');
        end
    end
end
