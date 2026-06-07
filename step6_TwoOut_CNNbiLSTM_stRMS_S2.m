%% S02 CNNbiLSTM
clc;
clear;
close all;
%%% 把这个代码改成了通用版本，只需要改变RMS特征形式，统一为CSV格式，修改read_file_path路径和feature_type就行
%%% 该代码是S02混合力角度预测
%% 1. 路径与参数
subject_id = 'S02';
gesture_id = 'G01';
trailnum=20;
seq_len = 25;
r2_all = zeros(2, 2);   % 2行(st/rms) × 2列(angle/force)
for p=1:2

    %% 循环的
    % readfile={'G:\matlab_projects\CKC_achieve\data\EMG_FYH\EMG_FYH20260414\mix_TwoOut\st_label',...
    %     'G:\matlab_projects\CKC_achieve\data\EMG_FYH\EMG_FYH20260414\mix_TwoOut\RMS_CSV'};%% Smooth
    readfile={'G:\matlab_projects\CKC_achieve\data\EMG_FYH\EMG_FYH20260414\mix_TwoOut\st_label_noSmooth',...
        'G:\matlab_projects\CKC_achieve\data\EMG_FYH\EMG_FYH20260414\mix_TwoOut\RMS_label_noSmooth'};


    features={'st','rms'};
    read_file_path=readfile{p};
    feature_type=features{p};


    random=2021;
    rng(random);
    result_txt = fullfile(read_file_path, ...
        sprintf('result_seq%d_rng%d_%s.txt', seq_len,random, datestr(now, 'yyyymmdd_HHMMSS')));

    fid = fopen(result_txt, 'w');   % 'w'表示覆盖写
    %% =========================
    % 2. 构建所有样本索引（F30 + F50）
    %% =========================

    forces =  {'F10','F20','F30','F40','F50'};
    trials = 1:trailnum;

    all_samples = {};

    for f = 1:length(forces)
        for t = trials
            sample.force = forces{f};
            sample.trial = t;
            all_samples{end+1} = sample;
        end
    end

    %% =========================
    % 3. 强制 进训练集
    %% =========================

    train_samples = {};
    remain_samples = {};

    for i = 1:length(all_samples)
        if all_samples{i}.trial == 18
            train_samples{end+1} = all_samples{i};
        else
            remain_samples{end+1} = all_samples{i};
        end
    end

    %% =========================
    % 4. 按  分开划分（推荐）
    %% =========================

    forces =  {'F10','F20','F30','F40','F50'};

    train_samples = {};
    val_samples = {};
    test_samples = {};

    for f = 1:length(forces)

        force_name = forces{f};

        % 当前力的所有样本
        force_samples = {};

        for i = 1:length(all_samples)
            if strcmp(all_samples{i}.force, force_name)
                force_samples{end+1} = all_samples{i};
            end
        end

        % --- 强制 T04进训练集 ---
        train_force = {};
        remain_force = {};

        for i = 1:length(force_samples)
            if force_samples{i}.trial == 18
                train_force{end+1} = force_samples{i};
            else
                remain_force{end+1} = force_samples{i};
            end
        end

        % 数量
        Nf = length(force_samples); % 10

        n_train = round(0.7 * Nf); % 7
        n_val   = round(0.1 * Nf); % 1
        n_test  = Nf - n_train - n_val; % 2

        % 已经有 T04
        n_train_remain = n_train - length(train_force);

        idx = randperm(length(remain_force));

        train_idx = idx(1:n_train_remain);
        val_idx   = idx(n_train_remain+1 : n_train_remain+n_val);
        test_idx  = idx(n_train_remain+n_val+1 : end);

        % 加入
        for i = train_idx
            train_force{end+1} = remain_force{i};
        end

        val_force  = remain_force(val_idx);
        test_force = remain_force(test_idx);

        % 合并到总集合
        train_samples = [train_samples, train_force];
        val_samples   = [val_samples, val_force];
        test_samples  = [test_samples, test_force];

    end

    fprintf('训练集数量: %d\n', length(train_samples));
    fprintf('验证集数量: %d\n', length(val_samples));
    fprintf('测试集数量: %d\n', length(test_samples));
    %% =========================
    % 5. 读取数据函数（统一处理）
    %% =========================

    train_trial_data = read_samples(train_samples, read_file_path, subject_id, gesture_id, feature_type);
    val_trial_data   = read_samples(val_samples,   read_file_path, subject_id, gesture_id, feature_type);
    test_trial_data  = read_samples(test_samples,  read_file_path, subject_id, gesture_id, feature_type);
    %% 3. 去除 NaN（按 trial 分别处理）
    train_trial_data = remove_nan_trials(train_trial_data);
    val_trial_data   = remove_nan_trials(val_trial_data);
    test_trial_data  = remove_nan_trials(test_trial_data);
    %% 在读取数据之后、归一化之前，对ST特征加sqrt变换
    if strcmp(feature_type, 'st')
        for i = 1:length(train_trial_data)
            train_trial_data{i}.X = sqrt(train_trial_data{i}.X);
        end
        for i = 1:length(val_trial_data)
            val_trial_data{i}.X = sqrt(val_trial_data{i}.X);
        end
        for i = 1:length(test_trial_data)
            test_trial_data{i}.X = sqrt(test_trial_data{i}.X);
        end
    end
    %% 替换第4步，改为按通道归一化（推荐）

    % 计算每个MU通道在训练集上的min/max
    P_train_all = [];
    for i = 1:length(train_trial_data)
        P_train_all = [P_train_all; train_trial_data{i}.X];
    end

    % mapminmax默认是按行处理，转置后每列是一个通道
    % 这里我们明确按通道（列）做归一化
    ch_min = min(P_train_all, [], 1);   % 1×c，每个通道的最小值
    ch_max = max(P_train_all, [], 1);   % 1×c，每个通道的最大值
    ch_range = ch_max - ch_min;
    ch_range(ch_range == 0) = 1;        % 防止除零（某通道全为0）

    % 定义归一化函数
    norm_fn = @(X) (X - ch_min) ./ ch_range;

    % 应用到各集合
    for i = 1:length(train_trial_data)
        train_trial_data{i}.X_norm = norm_fn(train_trial_data{i}.X);
    end
    for i = 1:length(val_trial_data)
        val_trial_data{i}.X_norm = norm_fn(val_trial_data{i}.X);
    end
    for i = 1:length(test_trial_data)
        test_trial_data{i}.X_norm = norm_fn(test_trial_data{i}.X);
    end
    %% 4. 用训练集拟合归一化参数
    % P_train_all = [];
    % for i = 1:length(train_trial_data)
    %     P_train_all = [P_train_all; train_trial_data{i}.X];
    % end
    %
    % [P_train_all_norm, ps_input] = mapminmax(P_train_all', 0, 1); %#ok<ASGLU>
    %
    % % 将归一化参数应用到每个 trial
    % for i = 1:length(train_trial_data)
    %     X = train_trial_data{i}.X;
    %     X_norm = mapminmax('apply', X', ps_input)';
    %     train_trial_data{i}.X_norm = X_norm;
    % end
    %
    % for i = 1:length(val_trial_data)
    %     X = val_trial_data{i}.X;
    %     X_norm = mapminmax('apply', X', ps_input)';
    %     val_trial_data{i}.X_norm = X_norm;
    % end
    %
    % for i = 1:length(test_trial_data)
    %     X = test_trial_data{i}.X;
    %     X_norm = mapminmax('apply', X', ps_input)';
    %     test_trial_data{i}.X_norm = X_norm;
    % end
    %% 在build_sequence_dataset之前，对Y也归一化
    % 用训练集的角度和力分别归一化
    %% 对双输出标签归一化（用训练集fit，val/test用同一参数）
    all_angle = []; all_force = [];
    for i = 1:length(train_trial_data)
        all_angle = [all_angle; train_trial_data{i}.Y_angle];
        all_force = [all_force; train_trial_data{i}.Y_force];
    end

    angle_min = min(all_angle); angle_max = max(all_angle);
    force_min = min(all_force); force_max = max(all_force);
    angle_range = angle_max - angle_min;
    force_range = force_max - force_min;

    % 归一化函数
    norm_angle = @(y) (y - angle_min) / angle_range;
    norm_force = @(y) (y - force_min) / force_range;

    % 应用到三个集合
    all_sets = {train_trial_data, val_trial_data, test_trial_data};
    for s = 1:3
        for i = 1:length(all_sets{s})
            all_sets{s}{i}.Y_angle = norm_angle(all_sets{s}{i}.Y_angle);
            all_sets{s}{i}.Y_force = norm_force(all_sets{s}{i}.Y_force);
        end
    end
    train_trial_data = all_sets{1};
    val_trial_data   = all_sets{2};
    test_trial_data  = all_sets{3};
    %% 5. 构造序列数据（每个 trial 单独滑窗，避免跨 trial 拼接）
    [train_data, T_train] = build_sequence_dataset(train_trial_data, seq_len);
    [val_data,   T_val]   = build_sequence_dataset(val_trial_data, seq_len);
    [test_data,  T_test]  = build_sequence_dataset(test_trial_data, seq_len);

    fprintf('\n===== 序列样本统计 =====\n');
    fprintf('训练集序列数: %d\n', numel(train_data));
    fprintf('验证集序列数: %d\n', numel(val_data));
    fprintf('测试集序列数: %d\n', numel(test_data));

    c = size(train_trial_data{1}.X, 2);
    fprintf('特征维度 c = %d\n', c);
    %% 6. 记录测试集每个 trial 对应的序列长度（用于分 trial 评估）
    test_trial_seq_lengths = zeros(length(test_trial_data), 1);
    test_trial_names = cell(length(test_trial_data), 1);

    for i = 1:length(test_trial_data)
        n = size(test_trial_data{i}.X_norm, 1);
        test_trial_seq_lengths(i) = n - seq_len + 1;
        test_trial_names{i} = test_trial_data{i}.name;
    end

    %% 7. 定义 CNN-biLSTM 回归网络
    layers = [
        sequenceInputLayer(c, "Name", "input")

        convolution1dLayer(3, 64, "Padding", "same", "Name", "conv1")
        batchNormalizationLayer("Name", "bn1")
        reluLayer("Name", "relu1")
        dropoutLayer(0.3, "Name", "drop1")

        bilstmLayer(128, "OutputMode", "last", "Name", "bilstm")

        fullyConnectedLayer(64, "Name", "fc1")
        reluLayer("Name", "relu2")
        dropoutLayer(0.2, "Name", "drop2")

        fullyConnectedLayer(32, "Name", "fc2")
        reluLayer("Name", "relu3")

        fullyConnectedLayer(2, "Name", "fc_out")
        regressionLayer("Name", "output")
        ];
    %% 8. 训练参数
    miniBatchSize = 64;  % 原来是64

    options = trainingOptions("adam", ...
        "MiniBatchSize", miniBatchSize, ...
        "MaxEpochs", 100, ...
        "InitialLearnRate", 1e-4, ...
        "L2Regularization", 1e-4, ...
        "Shuffle", "every-epoch", ...
        "ValidationData", {val_data, T_val}, ...
        "ValidationFrequency", max(1, floor(numel(train_data) / miniBatchSize)), ...
        "Verbose", true, ...
        "ExecutionEnvironment", "gpu");
    % 带早停的版本
    % options = trainingOptions("adam", ...
    %     "MiniBatchSize", miniBatchSize, ...
    %     "MaxEpochs", 200, ...
    %     "InitialLearnRate", 1.0e-04, ...
    %     "L2Regularization", 1e-4, ...
    %     "Shuffle", "every-epoch", ...
    %     "ValidationData", {val_data, T_val}, ...
    %     "ValidationFrequency", max(1, floor(numel(train_data) / miniBatchSize)), ...
    %     "Verbose", true, ...%"Plots", "training-progress", ...
    %     "ExecutionEnvironment", "gpu",...
    %     "ValidationPatience", 10, ...          % 连续 5 次验证无改善则停止
    %     "OutputNetwork", "best-validation-loss");

    %% 9. 训练网络
    net = trainNetwork(train_data, T_train, layers, options);
    % load G:\matlab_projects\CKC_achieve\data\EMG_FYH\G01\G01_mixForce\python分解三拼\SIL0.85\st_label\S02_G01mix_CNN_biLSTM_regression_rng2021_len25_R20.8164.mat
    %% 10. 预测
    YPred_train = predict(net, train_data, 'MiniBatchSize', miniBatchSize);
    YPred_val   = predict(net, val_data,   'MiniBatchSize', miniBatchSize);
    YPred_test  = predict(net, test_data,  'MiniBatchSize', miniBatchSize);

    % 拆分角度和力
    YPred_train_angle = YPred_train(:,1);  YPred_train_force = YPred_train(:,2);
    YPred_val_angle   = YPred_val(:,1);    YPred_val_force   = YPred_val(:,2);
    YPred_test_angle  = YPred_test(:,1);   YPred_test_force  = YPred_test(:,2);

    T_train_angle = T_train(:,1);  T_train_force = T_train(:,2);
    T_val_angle   = T_val(:,1);    T_val_force   = T_val(:,2);
    T_test_angle  = T_test(:,1);   T_test_force  = T_test(:,2);

    %% 11. 评价指标
    calc_rmse = @(y,yp) sqrt(mean((y-yp).^2));
    calc_mae  = @(y,yp) mean(abs(y-yp));
    calc_r2   = @(y,yp) 1 - sum((y-yp).^2) / sum((y-mean(y)).^2);

    % 角度指标
    rmse_test_angle = calc_rmse(T_test_angle, YPred_test_angle);
    mae_test_angle  = calc_mae(T_test_angle,  YPred_test_angle);
    r2_test_angle   = calc_r2(T_test_angle,   YPred_test_angle);

    % 力指标
    rmse_test_force = calc_rmse(T_test_force, YPred_test_force);
    mae_test_force  = calc_mae(T_test_force,  YPred_test_force);
    r2_test_force   = calc_r2(T_test_force,   YPred_test_force);

    % 反归一化后的RMSE（有物理意义）
    rmse_angle_deg = rmse_test_angle * angle_range;   % 单位：度
    rmse_force_N   = rmse_test_force * force_range;   % 单位：N
    mae_angle_deg  = mae_test_angle  * angle_range;
    mae_force_N    = mae_test_force  * force_range;

    fprintf('角度: RMSE=%.2f°, MAE=%.2f°, R²=%.4f\n', rmse_angle_deg, mae_angle_deg, r2_test_angle);
    fprintf('力:   RMSE=%.2fN, MAE=%.2fN, R²=%.4f\n', rmse_force_N,   mae_force_N,   r2_test_force);

    fprintf(fid, '\n=== 时间: %s ===\n', datestr(now));
    fprintf(fid, '\n===== 双输出回归结果 =====\n');
    fprintf(fid, '角度 - RMSE=%.4f, MAE=%.4f, R^2=%.4f\n', rmse_test_angle, mae_test_angle, r2_test_angle);
    fprintf(fid, '力   - RMSE=%.4f, MAE=%.4f, R^2=%.4f\n', rmse_test_force, mae_test_force, r2_test_force);

    r2_all(p,1) = r2_test_angle;   % 主要记录角度R²
    r2_all(p,2) = r2_test_force;   % 同时记录力R²
    %% 12. 测试集整体曲线——角度
    % fig1 = figure;
    % plot(T_test_angle, 'b-', 'LineWidth', 1.2); hold on;
    % plot(YPred_test_angle, 'r-', 'LineWidth', 1.2);
    % legend('True Angle', 'Predicted Angle');
    % xlabel('Window Index');
    % ylabel('Angle (deg)');
    % title(sprintf('Test Set Angle: RMSE=%.4f°, R^2=%.4f', rmse_angle_deg, r2_test_angle));
    % grid on;
    % savefig(fig1, fullfile(read_file_path, sprintf('test_angle_curve_rng%d_len%d_R2%.4f.fig', random, seq_len, r2_test_angle)));
    % 
    % %% 测试集整体曲线——力
    % fig2 = figure;
    % plot(T_test_force, 'b-', 'LineWidth', 1.2); hold on;
    % plot(YPred_test_force, 'r-', 'LineWidth', 1.2);
    % legend('True Force', 'Predicted Force');
    % xlabel('Window Index');
    % ylabel('Force (N)');
    % title(sprintf('Test Set Force: RMSE=%.4fN, R^2=%.4f', rmse_force_N, r2_test_force));
    % grid on;
    % savefig(fig2, fullfile(read_file_path, sprintf('test_force_curve_rng%d_len%d_R2%.4f.fig', random, seq_len, r2_test_force)));
    % 
    % %% 13. 散点图——角度
    % fig3 = figure;
    % scatter(T_test_angle, YPred_test_angle, 30, 'filled');
    % xlabel('True Angle (deg)'); ylabel('Predicted Angle (deg)');
    % title(sprintf('Angle Scatter: R^2=%.4f', r2_test_angle));
    % grid on; lsline;
    % savefig(fig3, fullfile(read_file_path, sprintf('test_angle_scatter_rng%d_len%d_R2%.4f.fig', random, seq_len, r2_test_angle)));
    % 
    % %% 散点图——力
    % fig4 = figure;
    % scatter(T_test_force, YPred_test_force, 30, 'filled');
    % xlabel('True Force (N)'); ylabel('Predicted Force (N)');
    % title(sprintf('Force Scatter: R^2=%.4f', r2_test_force));
    % grid on; lsline;
    % savefig(fig4, fullfile(read_file_path, sprintf('test_force_scatter_rng%d_len%d_R2%.4f.fig', random, seq_len, r2_test_force)));
    % 
    % %% 14. 分trial测试结果——角度和力分开报告
    % fprintf('\n===== 分 trial 测试结果 =====\n');
    % fprintf(fid, '\n===== 分 trial 测试结果 =====\n');
    % start_idx = 1;
    % for k = 1:length(test_trial_seq_lengths)
    %     n = test_trial_seq_lengths(k);
    %     end_idx = start_idx + n - 1;
    % 
    %     y_true_angle = T_test_angle(start_idx:end_idx);
    %     y_pred_angle = YPred_test_angle(start_idx:end_idx);
    %     y_true_force = T_test_force(start_idx:end_idx);
    %     y_pred_force = YPred_test_force(start_idx:end_idx);
    % 
    %     % 反归一化后计算RMSE/MAE（R²不受影响）
    %     rmse_a = calc_rmse(y_true_angle, y_pred_angle) * angle_range;
    %     mae_a  = calc_mae(y_true_angle,  y_pred_angle) * angle_range;
    %     r2_a   = calc_r2(y_true_angle,   y_pred_angle);
    % 
    %     rmse_f = calc_rmse(y_true_force, y_pred_force) * force_range;
    %     mae_f  = calc_mae(y_true_force,  y_pred_force) * force_range;
    %     r2_f   = calc_r2(y_true_force,   y_pred_force);
    % 
    %     fprintf('%s | 角度: RMSE=%.2f°, MAE=%.2f°, R²=%.4f | 力: RMSE=%.2fN, MAE=%.2fN, R²=%.4f\n', ...
    %         test_trial_names{k}, rmse_a, mae_a, r2_a, rmse_f, mae_f, r2_f);
    %     fprintf(fid, '%s | 角度: RMSE=%.2f°, MAE=%.2f°, R²=%.4f | 力: RMSE=%.2fN, MAE=%.2fN, R²=%.4f\n', ...
    %         test_trial_names{k}, rmse_a, mae_a, r2_a, rmse_f, mae_f, r2_f);
    % 
    %     start_idx = end_idx + 1;
    % end
    % 
    % %% 运动段指标——角度和力分开
    % fprintf('\n===== 测试集（仅运动段） =====\n');
    % fprintf(fid, '\n===== 测试集（仅运动段） =====\n');
    % 
    % y_true_move_angle = []; y_pred_move_angle = [];
    % y_true_move_force = []; y_pred_move_force = [];
    % 
    % start_idx = 1;
    % for k = 1:length(test_trial_seq_lengths)
    %     n = test_trial_seq_lengths(k);
    %     end_idx = start_idx + n - 1;
    % 
    %     start_move = start_idx + 50;
    %     end_move   = end_idx   - 50;
    % 
    %     if end_move <= start_move
    %         fprintf('⚠️ %s 长度不足，跳过\n', test_trial_names{k});
    %         start_idx = end_idx + 1;
    %         continue;
    %     end
    % 
    %     ya_true = T_test_angle(start_move:end_move);
    %     ya_pred = YPred_test_angle(start_move:end_move);
    %     yf_true = T_test_force(start_move:end_move);
    %     yf_pred = YPred_test_force(start_move:end_move);
    % 
    %     y_true_move_angle = [y_true_move_angle; ya_true];
    %     y_pred_move_angle = [y_pred_move_angle; ya_pred];
    %     y_true_move_force = [y_true_move_force; yf_true];
    %     y_pred_move_force = [y_pred_move_force; yf_pred];
    % 
    %     rmse_a = calc_rmse(ya_true, ya_pred) * angle_range;
    %     r2_a   = calc_r2(ya_true,  ya_pred);
    %     rmse_f = calc_rmse(yf_true, yf_pred) * force_range;
    %     r2_f   = calc_r2(yf_true,  yf_pred);
    % 
    %     fprintf('%s (move) | 角度R²=%.4f, RMSE=%.2f° | 力R²=%.4f, RMSE=%.2fN\n', ...
    %         test_trial_names{k}, r2_a, rmse_a, r2_f, rmse_f);
    %     fprintf(fid, '%s (move) | 角度R²=%.4f, RMSE=%.2f° | 力R²=%.4f, RMSE=%.2fN\n', ...
    %         test_trial_names{k}, r2_a, rmse_a, r2_f, rmse_f);
    % 
    %     start_idx = end_idx + 1;
    % end
    % 
    % %% 运动段整体指标
    % r2_move_angle   = calc_r2(y_true_move_angle, y_pred_move_angle);
    % rmse_move_angle = calc_rmse(y_true_move_angle, y_pred_move_angle) * angle_range;
    % r2_move_force   = calc_r2(y_true_move_force, y_pred_move_force);
    % rmse_move_force = calc_rmse(y_true_move_force, y_pred_move_force) * force_range;
    % 
    % fprintf('\n运动段整体 | 角度: RMSE=%.2f°, R²=%.4f | 力: RMSE=%.2fN, R²=%.4f\n', ...
    %     rmse_move_angle, r2_move_angle, rmse_move_force, r2_move_force);
    % fprintf(fid, '\n运动段整体 | 角度: RMSE=%.2f°, R²=%.4f | 力: RMSE=%.2fN, R²=%.4f\n', ...
    %     rmse_move_angle, r2_move_angle, rmse_move_force, r2_move_force);
    % 
    % %% 运动段曲线——角度
    % fig5 = figure;
    % plot(y_true_move_angle * angle_range + angle_min, 'b-', 'LineWidth', 1.2); hold on;
    % plot(y_pred_move_angle * angle_range + angle_min, 'r-', 'LineWidth', 1.2);
    % legend('True Angle', 'Predicted Angle');
    % xlabel('Window Index'); ylabel('Angle (deg)');
    % title(sprintf('Move Segment Angle: RMSE=%.2f°, R²=%.4f', rmse_move_angle, r2_move_angle));
    % grid on;
    % savefig(fig5, fullfile(read_file_path, sprintf('test_angle_move_rng%d_len%d_R2%.4f.fig', random, seq_len, r2_move_angle)));
    % 
    % %% 运动段曲线——力
    % fig6 = figure;
    % plot(y_true_move_force * force_range + force_min, 'b-', 'LineWidth', 1.2); hold on;
    % plot(y_pred_move_force * force_range + force_min, 'r-', 'LineWidth', 1.2);
    % legend('True Force', 'Predicted Force');
    % xlabel('Window Index'); ylabel('Force (N)');
    % title(sprintf('Move Segment Force: RMSE=%.2fN, R²=%.4f', rmse_move_force, r2_move_force));
    % grid on;
    % savefig(fig6, fullfile(read_file_path, sprintf('test_force_move_rng%d_len%d_R2%.4f.fig', random, seq_len, r2_move_force)));    
    %% 15. 保存模型
    save(fullfile(read_file_path, sprintf('S02_G01mix_CNN_biLSTM_regression_rng%d_len%d_R2_A%.4f_F%.4f.mat',random,seq_len,r2_test_angle,r2_test_force)), ...
        'net',  'seq_len',  'r2_test_angle','r2_test_force');
    fclose(fid);
end
fprintf('\nST:  角度R²=%.4f, 力R²=%.4f\n', r2_all(1,1), r2_all(1,2));
fprintf('RMS: 角度R²=%.4f, 力R²=%.4f\n', r2_all(2,1), r2_all(2,2));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 本脚本用到的局部函数
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function trial_data_out = remove_nan_trials(trial_data_in)
trial_data_out = trial_data_in;
for i = 1:length(trial_data_in)
    X = trial_data_in{i}.X;
    Y_angle = trial_data_in{i}.Y_angle;
    Y_force = trial_data_in{i}.Y_force;

    valid_idx = all(~isnan(X), 2) & ~isnan(Y_angle) & ~isnan(Y_force);

    trial_data_out{i}.X       = X(valid_idx, :);
    trial_data_out{i}.Y_angle = Y_angle(valid_idx);
    trial_data_out{i}.Y_force = Y_force(valid_idx);
end
end

function [seq_data, seq_label] = build_sequence_dataset(trial_data, seq_len)
seq_data  = {};
seq_label = [];   % N×2，第1列角度，第2列力

for i = 1:length(trial_data)
    X       = trial_data{i}.X_norm;
    Y_angle = trial_data{i}.Y_angle;
    Y_force = trial_data{i}.Y_force;
    n = size(X, 1);

    if n < seq_len
        warning('%s 样本数小于seq_len，跳过', trial_data{i}.name);
        continue;
    end

    for j = 1:(n - seq_len + 1)
        one_seq = X(j:j+seq_len-1, :)';        % c × seq_len
        one_y   = [Y_angle(j+seq_len-1), Y_force(j+seq_len-1)];  % 1×2

        seq_data{end+1, 1}  = one_seq;
        seq_label(end+1, :) = one_y;
    end
end

seq_label = double(seq_label);
end


function trial_data = read_samples(samples, folder, subject_id, gesture_id,feature_type)

trial_data = {};   % ⚠️ 不预分配，动态加入

cnt = 1;

for i = 1:length(samples)

    force_id = samples{i}.force;
    t = samples{i}.trial;

    %% ===== 根据特征类型决定文件名 =====
    switch lower(feature_type)
        case 'st'
            suffix = 'st_feature';
        case 'rms'
            suffix = 'rms_feature';
        otherwise
            error('未知特征类型: %s', feature_type);
    end
    file_name = sprintf('%s_%s_%s_T%02d_%s.csv', ...
        subject_id, gesture_id, force_id, t, suffix);

    file_path = fullfile(folder, file_name);

    %% ---------- 文件不存在：直接跳过 ----------
    if ~exist(file_path, 'file')
        fprintf('⚠️ 缺失，跳过: %s\n', file_name);
        continue;
    end

    %% ---------- 读取 ----------
    data = readmatrix(file_path);

    if isempty(data) || size(data,2) < 2
        fprintf('⚠️ 数据异常，跳过: %s\n', file_name);
        continue;
    end

    X = data(:, 1:end-2);        % 特征列（去掉最后两列）
    Y = data(:, end-1:end);      % 最后两列：[角度, 力]

    %% ---------- 再做一层保险（防NaN） ----------
    valid_idx = all(~isnan(X), 2) & ~isnan(Y(:,1)) & ~isnan(Y(:,2));
    X = X(valid_idx, :);
    Y = Y(valid_idx, :);

    if isempty(X)
        fprintf('⚠️ 全NaN，跳过: %s\n', file_name);
        continue;
    end

    %% ---------- 存 ----------
    trial_data{cnt}.X = X;
    trial_data{cnt}.Y_angle = Y(:,1);   % 倒数第二列：角度
    trial_data{cnt}.Y_force = Y(:,2);   % 最后一列：力
    trial_data{cnt}.name = sprintf('%s_T%02d', force_id, t);

    fprintf('✅ %s (%s): X=%d×%d\n', ...
        trial_data{cnt}.name,feature_type, size(X,1), size(X,2));

    cnt = cnt + 1;

end

end