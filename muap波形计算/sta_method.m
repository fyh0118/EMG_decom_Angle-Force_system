%% 改通道位置
EMG_Real = zeros(size(EMG));

EMG_Real(1, :) = EMG(34, :);
EMG_Real(2, :) = EMG(31, :);
EMG_Real(3, :) = EMG(32, :);
EMG_Real(4, :) = EMG(29, :);
EMG_Real(5, :) = EMG(30, :);
EMG_Real(6, :) = EMG(27, :);
EMG_Real(7, :) = EMG(28, :);
EMG_Real(8, :) = EMG(25, :);

EMG_Real(9, :) = EMG(17, :);
EMG_Real(10, :) = EMG(18, :);
EMG_Real(11, :) = EMG(21, :);
EMG_Real(12, :) = EMG(22, :);
EMG_Real(13, :) = EMG(19, :);
EMG_Real(14, :) = EMG(24, :);
EMG_Real(15, :) = EMG(23, :);
EMG_Real(16, :) = EMG(26, :);

EMG_Real(17, :) = EMG(20, :);
EMG_Real(18, :) = EMG(15, :);
EMG_Real(19, :) = EMG(16, :);
EMG_Real(20, :) = EMG(13, :);
EMG_Real(21, :) = EMG(14, :);
EMG_Real(22, :) = EMG(11, :);
EMG_Real(23, :) = EMG(12, :);
EMG_Real(24, :) = EMG(9, :);

EMG_Real(25, :) = EMG(1, :);
EMG_Real(26, :) = EMG(4, :);
EMG_Real(27, :) = EMG(3, :);
EMG_Real(28, :) = EMG(6, :);
EMG_Real(29, :) = EMG(5, :);
EMG_Real(30, :) = EMG(8, :);
EMG_Real(31, :) = EMG(7, :);
EMG_Real(32, :) = EMG(10, :);

EMG_Real(33, :) = EMG(2, :);
EMG_Real(34, :) = EMG(63, :);
EMG_Real(35, :) = EMG(64, :);
EMG_Real(36, :) = EMG(61, :);
EMG_Real(37, :) = EMG(62, :);
EMG_Real(38, :) = EMG(59, :);
EMG_Real(39, :) = EMG(60, :);
EMG_Real(40, :) = EMG(57, :);

EMG_Real(41, :) = EMG(50, :);
EMG_Real(42, :) = EMG(51, :);
EMG_Real(43, :) = EMG(52, :);
EMG_Real(44, :) = EMG(54, :);
EMG_Real(45, :) = EMG(53, :);
EMG_Real(46, :) = EMG(56, :);
EMG_Real(47, :) = EMG(55, :);
EMG_Real(48, :) = EMG(58, :);

EMG_Real(49, :) = EMG(49, :);
EMG_Real(50, :) = EMG(45, :);
EMG_Real(51, :) = EMG(48, :);
EMG_Real(52, :) = EMG(47, :);
EMG_Real(53, :) = EMG(46, :);
EMG_Real(54, :) = EMG(43, :);
EMG_Real(55, :) = EMG(44, :);
EMG_Real(56, :) = EMG(41, :);

EMG_Real(57, :) = EMG(33, :);
EMG_Real(58, :) = EMG(36, :);
EMG_Real(59, :) = EMG(35, :);
EMG_Real(60, :) = EMG(38, :);
EMG_Real(61, :) = EMG(37, :);
EMG_Real(62, :) = EMG(40, :);
EMG_Real(63, :) = EMG(39, :);
EMG_Real(64, :) = EMG(42, :);
emg_data=EMG_Real;
%% 算MUAP
% 算出的结果是各MU在各通道muap波形
% emg_data=EMG;
MUAP_results = MUAP_IQR(emg_data(1:64,:), Spike_train(:,:), 60);   % emg信号，spike train，平均窗大小

disp('算完muap')


%% 画图

% 指定你想查看的MU编号

MU_to_plot =1; 

% 从MUAP_results中取出对应的MUAP数据
MUAP_to_plot = MUAP_results{MU_to_plot}.MUAP; % 这里的MUAP是64通道的信号

% 调用绘图函数绘制该MUAP
plot_MUAP(MU_to_plot, MUAP_to_plot);

% savefig(sprintf("CKC_10db_MU%d.fig",MU_to_plot));
