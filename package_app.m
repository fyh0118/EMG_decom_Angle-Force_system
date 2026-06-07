function package_app()
    % package_app - 使用MATLAB Compiler打包为独立EXE
    % 需要: MATLAB Compiler Toolbox
    %
    % 使用方法:
    %   1. 在MATLAB中运行此脚本
    %   2. 或命令行: mcc -m main.m -a net.mat -a +config/ -a +models/ -a +services/ -a +ui/ -a +utils/

    fprintf('===== 肌电慧控 - MATLAB Compiler 打包 =====\n');

    % 检查MATLAB Compiler是否可用
    if license('test', 'MATLAB_Compiler')
        fprintf('[OK] MATLAB Compiler 许可证已就绪\n');
    else
        error('需要 MATLAB Compiler Toolbox');
    end

    rootPath = fileparts(mfilename('fullpath'));

    % 收集所有文件
    configFiles = dir(fullfile(rootPath, '+config', '*.m'));
    modelFiles = dir(fullfile(rootPath, '+models', '*.m'));
    serviceFiles = dir(fullfile(rootPath, '+services', '*.m'));
    uiCompFiles = dir(fullfile(rootPath, '+ui', 'components', '*.m'));
    uiTabFiles = dir(fullfile(rootPath, '+ui', 'tabs', '*.m'));
    uiDlgFiles = dir(fullfile(rootPath, '+ui', 'dialogs', '*.m'));
    utilFiles = dir(fullfile(rootPath, '+utils', '*.m'));

    % 构建编译命令
    addArgs = '';
    addArgs = [addArgs, ' -a +config'];
    addArgs = [addArgs, ' -a +models'];
    addArgs = [addArgs, ' -a +services'];
    addArgs = [addArgs, ' -a +ui'];
    addArgs = [addArgs, ' -a +utils'];

    % 如果有模型文件，一并打包
    modelPath = fullfile(rootPath, 'net.mat');
    if isfile(modelPath)
        addArgs = [addArgs, ' -a net.mat'];
        fprintf('[OK] 模型文件 net.mat 将被包含\n');
    else
        fprintf('[WARN] 未找到 net.mat, 模型需手动放置到exe同目录\n');
    end

    % 编译命令
    mccCmd = sprintf('mcc -m main.m -d ./deploy -o EMGControl%s', addArgs);
    fprintf('\n执行编译命令:\n  %s\n\n', mccCmd);

    % 执行编译
    try
        eval(mccCmd);
        fprintf('\n[SUCCESS] 编译完成!\n');
        fprintf('输出目录: %s\n', fullfile(rootPath, 'deploy'));
        fprintf('\n部署说明:\n');
        fprintf('  1. 将 deploy/ 文件夹复制到目标电脑\n');
        fprintf('  2. 确保目标电脑已安装 MATLAB Runtime (免费下载)\n');
        fprintf('  3. 下载地址: https://www.mathworks.com/products/compiler/mcr.html\n');
        fprintf('  4. 运行 EMGControl.exe 启动应用\n');
    catch e
        fprintf('[ERROR] 编译失败: %s\n', e.message);
        fprintf('\n请手动运行以下命令:\n');
        fprintf('  cd %s\n', rootPath);
        fprintf('  %s\n', mccCmd);
    end
end
