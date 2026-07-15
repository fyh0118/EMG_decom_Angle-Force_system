function main()
    % main - 肌电慧控系统入口
    % 基于高密度肌电分解的腕关节运动解码与康复评估系统

    % 检查MATLAB版本兼容性 (需要R2018a或更高版本支持uifigure)
    if ~isdeployed && verLessThan('matlab', '9.4')
        errordlg('本系统需要MATLAB R2018a或更高版本', '版本不兼容');
        return;
    end

    % 添加所有子目录到路径（仅开发模式，编译后由Runtime自动管理）
    if ~isdeployed
        rootPath = fileparts(mfilename('fullpath'));
        addpath(genpath(rootPath));
    end

    % 登录→系统→返回登录 循环
    while true
        loginScreen = LoginScreen();
        mode = loginScreen.show();

        if mode == ""
            break;
        end

        app = MainApp(mode);
        app.launch();
        waitfor(app.getFigure());

        if ~app.ReturnToLogin
            break;
        end
    end
end
