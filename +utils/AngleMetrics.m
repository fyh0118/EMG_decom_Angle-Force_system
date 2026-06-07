classdef AngleMetrics
    % AngleMetrics - 预测性能指标计算工具

    methods (Static)
        function rmse = computeRMSE(yTrue, yPred)
            % 均方根误差
            rmse = sqrt(mean((yTrue(:) - yPred(:)).^2));
        end

        function mae = computeMAE(yTrue, yPred)
            % 平均绝对误差
            mae = mean(abs(yTrue(:) - yPred(:)));
        end

        function r2 = computeR2(yTrue, yPred)
            % 决定系数 R²
            ssRes = sum((yTrue(:) - yPred(:)).^2);
            ssTot = sum((yTrue(:) - mean(yTrue(:))).^2);
            if ssTot > 0
                r2 = 1 - ssRes / ssTot;
            else
                r2 = NaN;
            end
        end

        function cc = computeCC(yTrue, yPred)
            % 皮尔逊相关系数
            r = corrcoef(yTrue(:), yPred(:));
            cc = r(1, 2);
        end

        function metrics = computeAll(yTrue, yPred, label)
            % 计算所有指标
            if nargin < 3, label = ''; end
            metrics.RMSE = utils.AngleMetrics.computeRMSE(yTrue, yPred);
            metrics.MAE  = utils.AngleMetrics.computeMAE(yTrue, yPred);
            metrics.R2   = utils.AngleMetrics.computeR2(yTrue, yPred);
            metrics.CC   = utils.AngleMetrics.computeCC(yTrue, yPred);
            metrics.Label = label;
        end

        function metrics = computeDualMetrics(trueAngle, predAngle, trueForce, predForce)
            % 同时计算角度和力的所有指标
            metrics.Angle = utils.AngleMetrics.computeAll(trueAngle, predAngle, '角度');
            metrics.Force  = utils.AngleMetrics.computeAll(trueForce, predForce, '力');
        end
    end
end
