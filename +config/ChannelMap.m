classdef ChannelMap
    % ChannelMap - 128通道HD-sEMG的通道标签和映射

    properties (Constant)
        N_FLEXOR_CH   = 64
        N_EXTENSOR_CH = 64
        N_TOTAL_CH    = 128

        % 数据矩阵中的通道索引
        FLEXOR_START   = 1
        FLEXOR_END     = 64
        EXTENSOR_START = 65
        EXTENSOR_END   = 128
    end

    methods (Static)
        function labels = getChannelLabels()
            labels = cell(AppConstants.N_TOTAL_CH, 1);
            for i = 1:ChannelMap.N_FLEXOR_CH
                labels{i} = sprintf('屈肌 CH%02d', i);
            end
            for i = 1:ChannelMap.N_EXTENSOR_CH
                labels{ChannelMap.EXTENSOR_START + i - 1} = sprintf('伸肌 CH%02d', i);
            end
        end

        function [flexorIdx, extensorIdx] = getChannelIndices()
            flexorIdx = ChannelMap.FLEXOR_START:ChannelMap.FLEXOR_END;
            extensorIdx = ChannelMap.EXTENSOR_START:ChannelMap.EXTENSOR_END;
        end

        function isFlexor = isFlexorChannel(chIdx)
            isFlexor = (chIdx >= ChannelMap.FLEXOR_START && chIdx <= ChannelMap.FLEXOR_END);
        end

        function sideLabel = getSideLabel(chIdx)
            if chIdx >= ChannelMap.FLEXOR_START && chIdx <= ChannelMap.FLEXOR_END
                sideLabel = '屈肌';
            else
                sideLabel = '伸肌';
            end
        end

        function color = getChannelColor(chIdx)
            if chIdx >= ChannelMap.FLEXOR_START && chIdx <= ChannelMap.FLEXOR_END
                color = AppConstants.COLOR_FLEXOR;
            else
                color = AppConstants.COLOR_EXTENSOR;
            end
        end
    end
end
