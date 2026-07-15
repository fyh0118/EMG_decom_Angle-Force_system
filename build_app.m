function build_app()
    % build_app - 打包肌电慧控为独立可安装EXE
    % 需要: MATLAB Compiler (R2022a+), 学校账号已激活
    % 输出: build_output/EMGDecom.exe (含安装包)

    rootPath = fileparts(mfilename('fullpath'));

    fprintf('===== 肌电慧控 打包工具 =====\n');
    fprintf('项目根目录: %s\n', rootPath);

    % 检查 MATLAB Compiler 许可
    if ~license('checkout', 'Compiler')
        error('MATLAB Compiler许可检出失败，请确认学校账号已登录激活');
    end

    % 图标（需 .ico 格式，png 不支持；无 ico 则不设图标）
    iconFile = fullfile(rootPath, 'logo.png');
    % iconFile = '';
    if ~exist(iconFile, 'file')
        iconFile = '';
        fprintf('[提示] 未找到 logo.ico，EXE将使用默认图标\n');
        fprintf('       如需自定义图标，将PNG转为ICO放到项目根目录\n');
    end

    % 将桥EXE复制到项目根目录（MATLAB Compiler 保留目录结构，
    % 直接引用子目录文件会导致 ctfroot 下路径不匹配）
    bridgeExeSrc = fullfile(rootPath, 'build_pyinstaller', 'dist', 'decompose_python_bridge.exe');
    bridgeExeDst = fullfile(rootPath, 'decompose_python_bridge.exe');
    copyfile(bridgeExeSrc, bridgeExeDst);
    fprintf('[打包] 已复制桥EXE: %s -> %s\n', bridgeExeSrc, bridgeExeDst);

    % 打包选项
    args = {
        fullfile(rootPath, 'main.m'), ...
        'ExecutableName', 'EMGDecom', ...
        'ExecutableVersion', '1.0.0', ...
        'AdditionalFiles', {...
            fullfile(rootPath, '模板'), ...
            fullfile(rootPath, 'muap波形计算'), ...
            fullfile(rootPath, 'logo.png'), ...
            fullfile(rootPath, 'decompose_python_bridge.py'), ...
            bridgeExeDst ...
            }, ...
        'OutputDir', fullfile(rootPath, 'build_output'), ...
        'Verbose', true ...
        };
    if ~isempty(iconFile)
        args = [args, {'ExecutableIcon', iconFile}];
    end
    opts = compiler.build.StandaloneApplicationOptions(args{:});

    % 执行打包
    result = compiler.build.standaloneApplication(opts);

    fprintf('\n===== 打包成功 =====\n');
% fprintf('EXE位置: %s\n', fullfile(result.OutputFolder, 'EMGDecom.exe'));

    fprintf('\n安装后的目录结构:\n');
    fprintf('  安装目录/\n');
    fprintf('    ├── EMGDecom.exe\n');
    fprintf('    ├── 模板/          ← 模型和分解模板，可自行添加新被试\n');
    fprintf('    │   ├── S01/\n');
    fprintf('    │   │   ├── G01/  (net.mat + norm_params.mat + ica模型)\n');
    fprintf('    │   │   └── ...\n');
    fprintf('    │   └── S02/\n');
    fprintf('    └── muap波形计算/   ← MUAP分析工具\n');
    fprintf('\n评估记录保存位置: %%APPDATA%%\\肌电慧控\\records\\\n');
end
