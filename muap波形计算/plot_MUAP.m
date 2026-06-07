function plot_MUAP(MU_num, MUAP)
    % 绘制指定MU编号的64通道MUAP图像
    figure(MU_num);
    
    % 找到所有子图中纵坐标的最大值和最小值
    max_amplitude = max(MUAP(:)); % 获取整个 MUAP 矩阵的最大正值
    min_amplitude = min(MUAP(:)); % 获取整个 MUAP 矩阵的最大负值（最小值）
    
    % 设定64个子图（行向量排列），每个通道对应一个子图
    for ch = 1:64
        subplot(8, 8, ch);  % 将64个通道分布在8x8的网格上
        plot(MUAP(ch, :));   % 绘制每个通道的MUAP波形
        title(['Channel ', num2str(ch)]); % 每个子图加上通道标题
        xlabel('Time (ms)');
        ylabel('Amplitude (uV)');
        
        % 固定纵坐标范围
        ylim([min_amplitude, max_amplitude]); % 设置纵坐标范围为 [min_amplitude, max_amplitude]
    end
    
    % 为整张图设置标题
    sgtitle(['MU ', num2str(MU_num), ' MUAP for 64 Channels']);
end