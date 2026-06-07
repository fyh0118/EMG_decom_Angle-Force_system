function main()
    % main - 肌电慧控系统入口
    % 基于高密度肌电分解的腕关节运动解码与康复评估系统

    % 检查MATLAB版本兼容性 (需要R2018a或更高版本支持uifigure)
    if verLessThan('matlab', '9.4')
        errordlg('本系统需要MATLAB R2018a或更高版本', '版本不兼容');
        return;
    end

    % 添加所有子目录到路径
    rootPath = fileparts(mfilename('fullpath'));
    addpath(genpath(rootPath));

    % 启动主应用
    app = MainApp();
    app.launch();
end
