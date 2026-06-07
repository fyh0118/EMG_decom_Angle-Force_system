clc;
clear;
close all;
% ST和RMS通用的，只需改路径即可
%% =========================
% 路径
%% =========================

force_folder = ...
'G:\matlab_projects\CKC_achieve\data\EMG_FYH\EMG_FYH20260414\Force_EMG_Paired_ForPrediction\noSmooth';

st_folder = ...
'G:\matlab_projects\CKC_achieve\data\EMG_FYH\EMG_FYH20260414\mix_TwoOut\st_label';

save_folder = ...
'G:\matlab_projects\CKC_achieve\data\EMG_FYH\EMG_FYH20260414\mix_TwoOut\st_label_cutqianhou';

if ~exist(save_folder, 'dir')
    mkdir(save_folder);
end

%% =========================
% 获取所有 ST csv
%% =========================

csv_files = dir(fullfile(st_folder, '*.csv'));

%% =========================
% 开始处理
%% =========================

for i = 1:length(csv_files)

    %% csv文件
    csv_name = csv_files(i).name;
    csv_path = fullfile(st_folder, csv_name);

    fprintf('处理: %s\n', csv_name);

    %% =========================
    % 提取匹配名
    % S02_G01_F10_T02
    %% =========================

    tokens = regexp(csv_name, ...
        '(S\d+_G\d+_F\d+_T\d+)', ...
        'match');

    if isempty(tokens)
        warning('文件名无法匹配: %s', csv_name);
        continue;
    end

    base_name = tokens{1};

    %% =========================
    % 对应 force 文件
    %% =========================

    force_name = [base_name '_forceEMG.mat'];
    force_path = fullfile(force_folder, force_name);

    if ~exist(force_path, 'file')
        warning('未找到 force 文件: %s', force_name);
        continue;
    end

    %% =========================
    % 读取 ST 特征
    %% =========================

    st_data = readmatrix(csv_path);

    target_len = size(st_data, 1);

    %% =========================
    % 读取 force_clean
    %% =========================

    force_data = load(force_path);

    if ~isfield(force_data, 'force_clean')
        warning('force_clean 不存在: %s', force_name);
        continue;
    end

    force_clean = force_data.force_clean(:);

    %% =========================
    % 插值重采样到 ST 长度
    %% =========================

    % old_len = length(force_clean);
    % 
    % x_old = linspace(0, 1, old_len);
    % x_new = linspace(0, 1, target_len);
    % 
    % force_resampled = interp1( ...
    %     x_old, ...
    %     force_clean, ...
    %     x_new, ...
    %     'linear' ...
    % );
    % 
    % force_resampled = force_resampled(:);

    % 前后截取
    old_len = length(force_clean);
    if old_len >= target_len
        % 力数据够长：对称截取中间target_len个点
        extra = old_len - target_len;
        cut_front = floor(extra / 2);    % 前面去掉的点数
        cut_back  = extra - cut_front;   % 后面去掉的点数（extra为奇数时后面多去1个）
        force_resampled = force_clean(cut_front+1 : end-cut_back);

        % 验证长度正确
        assert(length(force_resampled) == target_len, ...
            '截取长度不对: %d vs %d', length(force_resampled), target_len);
    end
    force_resampled = force_resampled(:);

    %% =========================
    % 拼接最后一列
    %% =========================
    % final_data = [st_data, force_resampled];% 拼接力标签
    % 替换力标签
    final_data = st_data;
    final_data(:, end) = force_resampled;

    %% =========================
    % 保存
    %% =========================

    save_path = fullfile(save_folder, csv_name);

    writematrix(final_data, save_path);

end

fprintf('\n全部完成！\n');