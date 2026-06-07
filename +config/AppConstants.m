classdef AppConstants
    % AppConstants - 应用全局常量（配色方案、字体、布局尺寸）

    properties (Constant)
        % ---- 窗口尺寸 ----
        WINDOW_WIDTH = 1400
        WINDOW_HEIGHT = 900
        STATUS_BAR_HEIGHT = 36
        % ---- 模板文件夹 ----
        TEMPLATE_ROOT = 'F:\EMG_decom_angle_system\模板';   % 根据您的实际路径修改
        % ---- 配色方案（医疗康复专业风格） ----
        COLOR_BG           = [0.94 0.96 0.98]   % 淡蓝灰背景
        COLOR_PANEL_BG     = [1.00 1.00 1.00]   % 白色面板
        COLOR_PRIMARY      = [0.15 0.45 0.75]   % 临床蓝
        COLOR_SECONDARY    = [0.20 0.65 0.45]   % 医疗绿
        COLOR_ACCENT       = [0.25 0.55 0.80]   % 强调蓝
        COLOR_WARNING      = [0.95 0.60 0.20]   % 琥珀色警告
        COLOR_DANGER       = [0.85 0.25 0.25]   % 红色危险
        COLOR_TEXT         = [0.15 0.15 0.15]   % 近黑文字
        COLOR_TEXT_LIGHT   = [0.50 0.50 0.50]   % 浅色文字
        COLOR_GRID         = [0.85 0.85 0.85]   % 网格线
        COLOR_TAB_BG       = [0.92 0.94 0.97]   % Tab背景

        % ---- 通道配色 ----
        COLOR_FLEXOR       = [0.20 0.45 0.70]   % 屈肌通道色
        COLOR_EXTENSOR     = [0.70 0.30 0.25]   % 伸肌通道色

        % ---- 信号质量指示灯 ----
        COLOR_SIG_GOOD     = [0.20 0.75 0.40]   % SNR > 20dB
        COLOR_SIG_MARGINAL = [0.95 0.70 0.20]   % 10-20dB
        COLOR_SIG_POOR     = [0.90 0.25 0.25]   % < 10dB

        % ---- 预测曲线配色 ----
        COLOR_TRUE_ANGLE   = [0.20 0.40 0.80]   % 真实角度曲线
        COLOR_PRED_ANGLE   = [0.80 0.25 0.25]   % 预测角度曲线
        COLOR_TRUE_FORCE   = [0.20 0.40 0.80]   % 真实力曲线
        COLOR_PRED_FORCE   = [0.80 0.25 0.25]   % 预测力曲线
        COLOR_RMS_BASELINE = [0.20 0.65 0.45]   % RMS基线方法
        COLOR_TARGET       = [0.50 0.50 0.50]   % 目标轨迹
        COLOR_ERROR_BAND   = [0.90 0.60 0.60]   % 误差带

        % ---- 字体配置 ----
        FONT_SIZE_TITLE    = 16
        FONT_SIZE_HEADING  = 13
        FONT_SIZE_NORMAL   = 11
        FONT_SIZE_SMALL    = 9
        FONT_NAME          = 'Microsoft YaHei'
        FONT_MONO          = 'Consolas'

        % ---- 间距 ----
        PADDING            = 10
        ROW_SPACING        = 6
        COL_SPACING        = 6

        % ---- 信号质量阈值 ----
        SNR_GOOD_THRESHOLD    = 20   % dB
        SNR_MARGINAL_THRESHOLD = 10  % dB
    end

    methods (Static)
        function colors = getFlexorGradient(nCh)
            baseColor = AppConstants.COLOR_FLEXOR;
            colors = AppConstants.makeGradient(baseColor, nCh);
        end

        function colors = getExtensorGradient(nCh)
            baseColor = AppConstants.COLOR_EXTENSOR;
            colors = AppConstants.makeGradient(baseColor, nCh);
        end

        function colors = makeGradient(baseColor, nSteps)
            colors = zeros(nSteps, 3);
            for i = 1:nSteps
                factor = 0.6 + 0.4 * (i - 1) / max(nSteps - 1, 1);
                colors(i, :) = baseColor * factor + [1 1 1] * (1 - factor);
            end
        end
    end
end
