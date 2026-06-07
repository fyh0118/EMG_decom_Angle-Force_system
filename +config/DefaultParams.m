classdef DefaultParams
    % DefaultParams - 系统各模块的默认参数

    properties (Constant)
        % ---- 数据采集默认参数 ----
        FS_DEFAULT            = 2000       % 采样率 (Hz)
        N_CHANNELS            = 128        % 总通道数
        N_FLEXOR_CH           = 64         % 屈肌通道数
        N_EXTENSOR_CH         = 64         % 伸肌通道数
        DISPLAY_WINDOW_SEC    = 5          % 波形显示窗口 (秒)
        RECORDING_DURATION_SEC = 20        % 默认录制时长 (秒)

        % ---- 信号处理默认参数 ----
        BANDPASS_LOW          = 20         % 带通滤波低频 (Hz)
        BANDPASS_HIGH         = 500        % 带通滤波高频 (Hz)
        NOTCH_FREQ            = 50         % 陷波频率 (Hz)

        % ---- 肌电分解默认参数 ----
        DECOMP_EXTENSION_FACTOR = 0.5
        DECOMP_MIN_FR         = 5          % 最小放电率 (Hz)
        DECOMP_MAX_FR         = 35         % 最大放电率 (Hz)
        DECOMP_SIL_THRESHOLD  = 0.90       % SIL阈值
        DECOMP_MAX_ITER       = 100        % 最大迭代次数
        DECOMP_AUTO_DETECT    = true

        % ---- 特征提取默认参数 (与用户现有配置一致) ----
        FEATURE_WINDOW_MS     = 200        % 滑动窗长度 (ms)
        FEATURE_STEP_MS       = 100        % 滑动窗步长 (ms)
        FEATURE_TYPE          = 'CumulativeSpikeCount'  % 特征类型

        % ---- 角度预测默认参数 ----
        ANGLE_RANGE           = [-90 90]   % 腕关节角度范围 (°)
        FORCE_RANGE           = [0 100]    % 力范围 (%MVC)
        PRED_UPDATE_INTERVAL_MS = 100      % 在线预测更新间隔 (ms)

        % ---- 康复评估默认参数 ----
        ASSESS_MOVEMENT_TYPE  = '屈腕'     % 默认动作类型
        ASSESS_TARGET_FORCE   = 20         % 默认目标力 (%MVC)
        ASSESS_REPETITIONS    = 5          % 默认重复次数
        ASSESS_TARGET_ROM     = 60         % 默认ROM目标 (°)
        ASSESS_TOLERANCE_DEG  = 5          % 角度容差 (°)
        ASSESS_TOLERANCE_FORCE = 5         % 力容差 (%MVC)
        ASSESS_TRAJECTORY     = '正弦'     % 默认目标轨迹
        ASSESS_CYCLE_SEC      = 5          % 默认周期 (秒)

        % ---- 模型相关 ----
        MODEL_FILENAME        = 'net.mat'  % 默认模型文件名
        MODEL_TYPE            = 'CNN-biLSTM'
        MODEL_INPUT_SIZE      = 100        % 输入特征维度 (MU数量)
        MODEL_OUTPUT_SIZE     = 2          % 双输出: 角度 + 力
    end
end
