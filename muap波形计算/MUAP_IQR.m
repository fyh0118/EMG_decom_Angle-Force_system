% MUAP_IQR
function MUAP_results = MUAP_IQR(EMG, Spike_train, Windowsize)

% 基于STA方法计算64通道MUAP，并使用IQR阈值筛选通道（基于MUAP绝对值峰值）
% 输入： sorted_SIG，spike_trains2
% 输出： MUAP_results，包括每个MU的符合条件的通道序号（排序后的）、绝对值峰值，和64通道MUAP

%% 主流程

% 假设spike_trains2是一个矩阵，其中每一行对应一个MU
num_MUs = size(Spike_train, 1);  % 获取Spike_train的行数，即MU的数量

% 用1到num_MUs的序列表示多个MU的编号
MU_list = 1:num_MUs;  % 这将是一个包含每个MU编号的数组

% 初始化一个cell数组，保存每个MU的结果
MUAP_results = cell(num_MUs, 1);

% 遍历每个MU
for MU_to_compute = 1:num_MUs
    % 获取当前MU的spike_train_unit（假设spike_trains2为所有MU的spike序列）
    spike_train_unit = Spike_train(MU_to_compute, :);
    
    % 计算AP_final（即MUAP）
    AP_final = compute_AP_final(EMG, spike_train_unit, Windowsize); % 60为Windowsize

    % 使用动态阈值选择符合条件的通道
    selected_channels = select_channels_dynamic_threshold(AP_final);

    % 计算该MU每个通道的MUAP峰值并保存
    peak_amplitudes = max(abs(AP_final), [], 2);
    channels_data = [selected_channels, peak_amplitudes(selected_channels)]; % 创建二维矩阵
    
    % 保存当前MU的结果到MUAP_results中
    MUAP_results{MU_to_compute}.channels = channels_data;    % 存储选中的通道编号
    MUAP_results{MU_to_compute}.MUAP = AP_final;                 % 存储对应的MUAP
end


% %% 画图
% % 指定你想查看的MU编号
% MU_to_plot = 7; 
% 
% % 从MUAP_results中取出对应的MUAP数据
% MUAP_to_plot = MUAP_results{MU_to_plot}.MUAP; % 这里的MUAP是64通道的信号
% 
% % 调用绘图函数绘制该MUAP
% plot_MUAP(MU_to_plot, MUAP_to_plot);


%% 函数部分

% 各通道MUAP计算函数
function AP_final = compute_AP_final(EMG, spike_train_unit, Windowsize)
    spikes = find(spike_train_unit);  
    num_spikes = length(spikes);  

    AP_matrix = zeros(size(EMG, 1), Windowsize+1, num_spikes);
    for i = 1:num_spikes
        if spikes(i) > Windowsize/2 && spikes(i) + Windowsize/2 <= size(EMG, 2)
            AP_matrix(:, :, i) = EMG(:, (spikes(i)-Windowsize/2):(spikes(i)+Windowsize/2)); 
        end
    end
    
    AP_final = mean(AP_matrix, 3); % 在第3维平均，得到MUAP 
end

% 根据IQR筛选通道的函数
function [selected_channels, peak_amplitudes] = select_channels_dynamic_threshold(AP_final)
    % 计算每个通道的峰值MUAP幅值（即每行的最大值）
    peak_amplitudes = max(abs(AP_final), [], 2);

    % 计算四分位数和四分位距
    Q3 = prctile(peak_amplitudes, 75); % 第三四分位数（75%）
    Q1 = prctile(peak_amplitudes, 25); % 第一四分位数（25%）
    IQR = Q3 - Q1; % 四分位距

    % 动态阈值计算
    thr = Q3 + 1.5 * IQR;

    % 筛选出峰值MUAP幅值大于阈值的通道
    selected_channels = find(peak_amplitudes > thr);

end

end 