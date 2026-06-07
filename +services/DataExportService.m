classdef DataExportService < handle
    % DataExportService - 数据导入导出服务

    methods (Static)
        % ---- MAT文件操作 ----
        function saveSession(sessionData, filePath)
            % 保存会话数据到MAT文件
            s = sessionData.toStruct();
            save(filePath, '-struct', 's', '-v7.3');
        end

        function sessionData = loadSession(filePath)
            % 从MAT文件加载会话数据
            s = load(filePath);
            sessionData = models.SessionData();
            sessionData = sessionData.fromStruct(s);
        end

        function saveFullData(filePath, rawData, fs, spikeTrain, ...
                featureMatrix, timeVector, predictedAngle, predictedForce, ...
                trueAngle, trueForce, sessionInfo)
            % 保存完整实验数据
            save(filePath, ...
                'rawData', 'fs', 'spikeTrain', ...
                'featureMatrix', 'timeVector', ...
                'predictedAngle', 'predictedForce', ...
                'trueAngle', 'trueForce', 'sessionInfo', ...
                '-v7.3');
        end

        function [data, fs, spikeTrain, featureMatrix, timeVector, ...
                predictedAngle, predictedForce, trueAngle, trueForce, sessionInfo] = ...
                loadFullData(filePath)
            % 加载完整实验数据
            loaded = load(filePath);
            data = loaded.rawData;
            fs = loaded.fs;
            spikeTrain = loaded.spikeTrain;
            featureMatrix = loaded.featureMatrix;
            timeVector = loaded.timeVector;
            predictedAngle = loaded.predictedAngle;
            predictedForce = loaded.predictedForce;
            trueAngle = loaded.trueAngle;
            trueForce = loaded.trueForce;
            sessionInfo = loaded.sessionInfo;
        end

        % ---- CSV导出 ----
        function exportSpikeTrainsCSV(spikeTrainMatrix, fs, timeVector, filePath)
            % 导出运动单位发放序列到CSV
            [nMU, nSamples] = size(spikeTrainMatrix);
            t = (0:nSamples-1) / fs;

            T = array2table(spikeTrainMatrix', ...
                'VariableNames', arrayfun(@(i) sprintf('MU_%03d', i), 1:nMU, 'UniformOutput', false));
            T.Time = t(:);
            T = movevars(T, 'Time', 'Before', 1);
            writetable(T, filePath);
        end

        function exportPredictionCSV(timeVector, predictedAngle, trueAngle, ...
                predictedForce, trueForce, filePath)
            % 导出角度+力预测结果到CSV
            T = table(timeVector(:), trueAngle(:), predictedAngle(:), ...
                trueForce(:), predictedForce(:), ...
                'VariableNames', {'Time_s', 'TrueAngle_deg', 'PredictedAngle_deg', ...
                'TrueForce_pctMVC', 'PredictedForce_pctMVC'});
            writetable(T, filePath);
        end

        function exportAssessmentCSV(assessmentResult, filePath)
            % 导出评估结果到CSV
            summary = table(...
                assessmentResult.Date, ...
                assessmentResult.ROM, ...
                assessmentResult.NormalizedJerk, ...
                assessmentResult.AngleTrackingAccuracy, ...
                assessmentResult.ForceTrackingAccuracy, ...
                assessmentResult.PredAngleRMSE, ...
                assessmentResult.PredForceRMSE, ...
                assessmentResult.OverallScore, ...
                'VariableNames', {'Date', 'ROM_deg', 'NormJerk', ...
                'AngleTracking_pct', 'ForceTracking_pct', ...
                'AngleRMSE_deg', 'ForceRMSE_pctMVC', 'OverallScore'});
            writetable(summary, filePath);
        end

        % ---- 报告导出 ----
        function exportFigure(figOrAx, filePath, format)
            % 导出图表为图片
            if nargin < 3, format = 'png'; end
            if isa(figOrAx, 'matlab.ui.Figure')
                exportgraphics(figOrAx, filePath, 'Resolution', 150);
            else
                exportgraphics(figOrAx, filePath, 'Resolution', 150);
            end
        end

        function exportReportHTML(assessmentResult, patientInfo, filePath)
            % 导出评估报告为HTML
            fid = fopen(filePath, 'w', 'native', 'UTF-8');
            fprintf(fid, '<!DOCTYPE html><html><head><meta charset="UTF-8">');
            fprintf(fid, '<title>康复评估报告 - %s</title>', patientInfo.Name);
            fprintf(fid, '<style>body{font-family:"Microsoft YaHei",sans-serif;max-width:800px;margin:0 auto;padding:20px;}');
            fprintf(fid, 'h1{color:#264a9e;border-bottom:2px solid #264a9e;}');
            fprintf(fid, 'h2{color:#339966;}');
            fprintf(fid, 'table{border-collapse:collapse;width:100%%;margin:10px 0;}');
            fprintf(fid, 'td,th{border:1px solid #ddd;padding:8px;text-align:left;}');
            fprintf(fid, 'th{background-color:#264a9e;color:white;}');
            fprintf(fid, '.score{font-size:48px;text-align:center;color:#264a9e;font-weight:bold;}');
            fprintf(fid, '</style></head><body>');

            fprintf(fid, '<h1>肌电慧控 - 康复评估报告</h1>');
            fprintf(fid, '<p><strong>患者:</strong> %s | <strong>ID:</strong> %s | <strong>日期:</strong> %s</p>', ...
                patientInfo.Name, patientInfo.PatientID, datestr(assessmentResult.Date));

            fprintf(fid, '<h2>综合评分</h2>');
            fprintf(fid, '<div class="score">%d / 100</div>', round(assessmentResult.OverallScore));

            fprintf(fid, '<h2>评估指标</h2><table>');
            fprintf(fid, '<tr><th>指标</th><th>结果</th><th>参考范围</th></tr>');
            fprintf(fid, '<tr><td>关节活动度 (ROM)</td><td>%.1f° / %.0f°</td><td>目标ROM</td></tr>', ...
                assessmentResult.ROM, assessmentResult.ROMTarget);
            fprintf(fid, '<tr><td>运动平滑度</td><td>%.2f</td><td>越小越平滑</td></tr>', ...
                assessmentResult.NormalizedJerk);
            fprintf(fid, '<tr><td>角度跟踪精度</td><td>%.1f%%</td><td>> 80%%</td></tr>', ...
                assessmentResult.AngleTrackingAccuracy);
            fprintf(fid, '<tr><td>力跟踪精度</td><td>%.1f%%</td><td>> 80%%</td></tr>', ...
                assessmentResult.ForceTrackingAccuracy);
            fprintf(fid, '<tr><td>角度预测 RMSE</td><td>%.2f°</td><td>< 5°</td></tr>', ...
                assessmentResult.PredAngleRMSE);
            fprintf(fid, '<tr><td>力预测 RMSE</td><td>%.2f%% MVC</td><td>< 5%%</td></tr>', ...
                assessmentResult.PredForceRMSE);
            fprintf(fid, '</table>');

            fprintf(fid, '<p><em>报告由肌电慧控系统自动生成</em></p>');
            fprintf(fid, '</body></html>');
            fclose(fid);
        end
    end
end
