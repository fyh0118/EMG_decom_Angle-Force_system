classdef SignalQualityIndicators
    % SignalQualityIndicators - 128通道信号质量LED指示灯阵列

    properties (Access = private)
        Parent
        LEDGrid         matlab.ui.control.UILamp
        SNRValues       double
    end

    methods
        function obj = SignalQualityIndicators(parent)
            obj.Parent = parent;
            obj.SNRValues = zeros(128, 1);
            obj.buildUI();
        end
    end

    methods (Access = private)
        function buildUI(obj)
            import config.AppConstants

            % 8行 x 16列 LED阵列
            ledGrid = uigridlayout(obj.Parent, [8, 16], ...
                'Padding', [2, 2, 2, 2], ...
                'RowSpacing', 1, 'ColumnSpacing', 1);

            obj.LEDGrid = gobjects(128, 1);
            for row = 1:8
                for col = 1:16
                    ch = (row - 1) * 16 + col;
                    if ch <= 128
                        obj.LEDGrid(ch) = uilamp(ledGrid, ...
                            'Color', [0.5 0.5 0.5]);
                    end
                end
            end
        end
    end

    methods (Access = public)
        function updateFromData(obj, data, fs)
            % 从数据计算SNR并更新指示灯
            if nargin < 2 || isempty(data)
                return;
            end
            if nargin < 3
                fs = 2000;
            end
            obj.SNRValues = services.SignalQualityService.computeChannelSNR(data, fs);
            obj.refreshLEDs();
        end

        function updateFromSNR(obj, snrValues)
            obj.SNRValues = snrValues;
            obj.refreshLEDs();
        end

        function refreshLEDs(obj)
            import config.AppConstants
            for ch = 1:min(length(obj.SNRValues), 128)
                if isvalid(obj.LEDGrid(ch))
                    obj.LEDGrid(ch).Color = services.SignalQualityService.getQualityColor(obj.SNRValues(ch));
                end
            end
        end

        function [goodCount, marginalCount, poorCount] = getStatistics(obj)
            poorCount = sum(obj.SNRValues < AppConstants.SNR_MARGINAL_THRESHOLD);
            marginalCount = sum(obj.SNRValues >= AppConstants.SNR_MARGINAL_THRESHOLD & ...
                              obj.SNRValues < AppConstants.SNR_GOOD_THRESHOLD);
            goodCount = sum(obj.SNRValues >= AppConstants.SNR_GOOD_THRESHOLD);
        end
    end
end
