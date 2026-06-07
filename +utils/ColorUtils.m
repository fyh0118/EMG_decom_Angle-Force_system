classdef ColorUtils
    % ColorUtils - 颜色生成工具

    methods (Static)
        function cmap = generateMUColormap(nColors)
            % 为MU生成区分度高的颜色映射
            if nColors <= 7
                cmap = lines(nColors);
            elseif nColors <= 20
                cmap = lines(nColors);
            else
                cmap = hsv(nColors);
            end
        end

        function color = darken(color, factor)
            % 调暗颜色
            color = color * (1 - factor);
        end

        function color = lighten(color, factor)
            % 调亮颜色
            color = color + (1 - color) * factor;
        end

        function color = interpolateColor(c1, c2, t)
            % 在两颜色之间插值
            color = c1 + t * (c2 - c1);
        end

        function colors = generateHeatmapColors(nSteps)
            % 生成热力图色阶 (蓝-绿-黄-红)
            x = linspace(0, 1, nSteps)';
            r = min(1, max(0, 3*x - 1.5));
            g = min(1, max(0, 1.5 - abs(3*x - 1.5)));
            b = min(1, max(0, 1.5 - 3*x));
            colors = [r, g, b];
        end
    end
end
