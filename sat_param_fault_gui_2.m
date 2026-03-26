function sat_param_fault_gui_2()
%SAT_PARAM_FAULT_GUI 参数与故障注入配置界面
% 功能：
% 1) 编辑初始化参数，并一键加载到 base workspace（替代 init_params.m 的手工执行）
% 2) 编辑故障参数，并自动构建/加载 params_in 与 fault_cfg（替代手工构建）
    busPath = fullfile(pwd, 'bus.m');
    if ~isfile(busPath)
        error('当前目录未找到 bus.m：%s', pwd);
    end
    run(busPath);
    app = struct();
    app.selectedInitRow = [];
    app.selectedFaultRow = [];
    app.initRawMap = struct();

    app.fig = uifigure('Name', '卫星参数与故障配置界面', ...
        'Position', [100 80 1300 760]);

    root = uigridlayout(app.fig, [3, 1]);
    root.RowHeight = {42, '1x', 48};
    root.ColumnWidth = {'1x'};
    root.Padding = [8 8 8 8];
    root.RowSpacing = 8;

    % 顶部工具条
    top = uigridlayout(root, [1, 8]);
    top.ColumnWidth = {160, 160, 160, 160, 160, 160, '1x', 200};
    top.RowHeight = {36};

    uibutton(top, 'Text', '从 init_params.m 加载默认值', ...
        'ButtonPushedFcn', @onLoadDefaults);
    uibutton(top, 'Text', '新增初始化行', ...
        'ButtonPushedFcn', @onAddInitRow);
    uibutton(top, 'Text', '删除初始化行', ...
        'ButtonPushedFcn', @onDeleteInitRow);

    uibutton(top, 'Text', '新增故障行', ...
        'ButtonPushedFcn', @onAddFaultRow);
    uibutton(top, 'Text', '删除故障行', ...
        'ButtonPushedFcn', @onDeleteFaultRow);

    uibutton(top, 'Text', '加载配置 MAT', ...
        'ButtonPushedFcn', @onLoadConfigMat);
    uibutton(top, 'Text', '保存配置 MAT', ...
        'ButtonPushedFcn', @onSaveConfigMat);

    app.statusLabel = uilabel(top, 'Text', '就绪');
    app.statusLabel.HorizontalAlignment = 'right';

    % 中间区域：左侧说明 + 右侧参数标签页
    mid = uigridlayout(root, [1, 2]);
    mid.ColumnWidth = {430, '1x'};
    mid.RowHeight = {'1x'};
    mid.ColumnSpacing = 8;
    mid.Padding = [0 0 0 0];

    % 左侧说明标签页
    introTabs = uitabgroup(mid);
    tabIntro = uitab(introTabs, 'Title', '导航说明');
    introGrid = uigridlayout(tabIntro, [2, 1]);
    introGrid.RowHeight = {28, '1x'};
    introGrid.Padding = [8 8 8 8];

    uilabel(introGrid, ...
        'Text', '右侧标签页使用指南', ...
        'FontWeight', 'bold', ...
        'FontSize', 13);

    introText = [ ...
        "1) 初始化参数（右侧）", ...
        "   - 配置初始化参数（参数名/表达式）。", ...
        "   - 点击底部“应用到工作区”后会写入 base workspace。", ...
        "", ...
        "2) 故障配置（右侧）", ...
        "   - 配置故障注入项（目标参数、故障类型、时间等）。", ...
        "   - 点击应用后会自动构建 fault_cfg。", ...
        "", ...
        "故障配置列说明：", ...
        "- 启用：true/false，是否生效。", ...
        "- 编号：故障唯一ID（如 F_ADCS_01）。", ...
        "- 目标参数：被注入参数名（支持点路径，如 eps.p_drop）。", ...
        "- 故障类型：degradation/saturation/bias/drift/dropout/outage/delay。", ...
        "- 故障程度：severity，建议 0~1。", ...
        "- 注入时刻_s：故障开始时间（秒）。", ...
        "- 恢复时刻_s：故障结束时间（秒），不恢复可填 inf。", ...
        "- 注入模式：step/ramp/intermittent/random。", ...
        "- 优先级：多故障排序，数值越大越后执行。", ...
        "- 输入基准：nominal(标称) 或 current(当前叠加值)。", ...
        "- 冲突处理方式：replace/max/min/mean。", ...
        "- 融合权重：仅 mean 模式使用，范围 0~1。", ...
        "- 目标索引：仅对向量/矩阵部分元素注入（如 [1 3]）。", ...
        "- 注入后值：直接指定 value_after，留空则按类型+程度计算。", ...
        "- 最小值/最大值：对结果限幅。", ...
        "", ...
        "3) 推荐流程", ...
        "   - 先配置初始化参数，再配置故障参数。", ...
        "   - 最后点击底部“应用到工作区”。", ...
        "", ...
        "4) 仿真调用", ...
        "   - [params_out, ids] = fault_inject(t, params_in, fault_cfg);" ...
    ];

    uitextarea(introGrid, ...
        'Value', introText, ...
        'Editable', 'off', ...
        'FontSize', 11);

    % 右侧原有参数标签页
    tabs = uitabgroup(mid);

    tabInit = uitab(tabs, 'Title', '初始化参数');
    tabFault = uitab(tabs, 'Title', '故障配置');

    % 初始化参数的子标签页（按子系统分类）
    % 先创建容器网格布局，确保子标签页占满整个标签页空间
    initContainer = uigridlayout(tabInit, [1, 1]);
    initContainer.Padding = [0 0 0 0];
    initSubTabs = uitabgroup(initContainer);
    
    % 轨道动力学选项卡
    tabOrbit = uitab(initSubTabs, 'Title', '轨道动力学');
    orbitGrid = uigridlayout(tabOrbit, [1, 1]);
    app.initTable_orbit = uitable(orbitGrid);
    app.initTable_orbit.ColumnName = {'参数名', '参数表达式', '类型', '尺寸', '参数解释'};
    app.initTable_orbit.ColumnEditable = [false, true, false, false, true];
    app.initTable_orbit.ColumnWidth = {220, '1x', 120, 100, 280};
    app.initTable_orbit.CellSelectionCallback = @onInitCellSelected;
    
    % 电源系统选项卡
    tabEPS = uitab(initSubTabs, 'Title', '电源系统');
    epsGrid = uigridlayout(tabEPS, [1, 1]);
    app.initTable_eps = uitable(epsGrid);
    app.initTable_eps.ColumnName = {'参数名', '参数表达式', '类型', '尺寸', '参数解释'};
    app.initTable_eps.ColumnEditable = [false, true, false, false, true];
    app.initTable_eps.ColumnWidth = {220, '1x', 120, 100, 280};
    app.initTable_eps.CellSelectionCallback = @onInitCellSelected;
    
    % 姿态控制选项卡
    tabADCS = uitab(initSubTabs, 'Title', '姿态控制');
    adcsGrid = uigridlayout(tabADCS, [1, 1]);
    app.initTable_adcs = uitable(adcsGrid);
    app.initTable_adcs.ColumnName = {'参数名', '参数表达式', '类型', '尺寸', '参数解释'};
    app.initTable_adcs.ColumnEditable = [false, true, false, false, true];
    app.initTable_adcs.ColumnWidth = {220, '1x', 120, 100, 280};
    app.initTable_adcs.CellSelectionCallback = @onInitCellSelected;
    
    % 传感器选项卡
    tabSensor = uitab(initSubTabs, 'Title', '传感器');
    sensorGrid = uigridlayout(tabSensor, [1, 1]);
    app.initTable_sensor = uitable(sensorGrid);
    app.initTable_sensor.ColumnName = {'参数名', '参数表达式', '类型', '尺寸', '参数解释'};
    app.initTable_sensor.ColumnEditable = [false, true, false, false, true];
    app.initTable_sensor.ColumnWidth = {220, '1x', 120, 100, 280};
    app.initTable_sensor.CellSelectionCallback = @onInitCellSelected;
    
    % 陀螺仪选项卡
    tabGyro = uitab(initSubTabs, 'Title', '陀螺仪');
    gyroGrid = uigridlayout(tabGyro, [1, 1]);
    app.initTable_gyro = uitable(gyroGrid);
    app.initTable_gyro.ColumnName = {'参数名', '参数表达式', '类型', '尺寸', '参数解释'};
    app.initTable_gyro.ColumnEditable = [false, true, false, false, true];
    app.initTable_gyro.ColumnWidth = {220, '1x', 120, 100, 280};
    app.initTable_gyro.CellSelectionCallback = @onInitCellSelected;
    
    % 推进系统选项卡
    tabProp = uitab(initSubTabs, 'Title', '推进系统');
    propGrid = uigridlayout(tabProp, [1, 1]);
    app.initTable_prop = uitable(propGrid);
    app.initTable_prop.ColumnName = {'参数名', '参数表达式', '类型', '尺寸', '参数解释'};
    app.initTable_prop.ColumnEditable = [false, true, false, false, true];
    app.initTable_prop.ColumnWidth = {220, '1x', 120, 100, 280};
    app.initTable_prop.CellSelectionCallback = @onInitCellSelected;
    
    % 通信系统选项卡
    tabComm = uitab(initSubTabs, 'Title', '通信系统');
    commGrid = uigridlayout(tabComm, [1, 1]);
    app.initTable_comm = uitable(commGrid);
    app.initTable_comm.ColumnName = {'参数名', '参数表达式', '类型', '尺寸', '参数解释'};
    app.initTable_comm.ColumnEditable = [false, true, false, false, true];
    app.initTable_comm.ColumnWidth = {220, '1x', 120, 100, 280};
    app.initTable_comm.CellSelectionCallback = @onInitCellSelected;
    
    % 其他选项卡
    tabOther = uitab(initSubTabs, 'Title', '其他');
    otherGrid = uigridlayout(tabOther, [1, 1]);
    app.initTable_other = uitable(otherGrid);
    app.initTable_other.ColumnName = {'参数名', '参数表达式', '类型', '尺寸', '参数解释'};
    app.initTable_other.ColumnEditable = [false, true, false, false, true];
    app.initTable_other.ColumnWidth = {220, '1x', 120, 100, 280};
    app.initTable_other.CellSelectionCallback = @onInitCellSelected;

    % 故障参数表
    faultGrid = uigridlayout(tabFault, [1, 1]);
    app.faultTable = uitable(faultGrid);
    app.faultTable.ColumnName = { ...
        '启用','编号','目标参数','故障类型','故障程度', ...
        '注入时刻_s','恢复时刻_s','注入模式','优先级','输入基准', ...
        '冲突处理方式','融合权重','目标索引','注入后值', ...
        '最小值','最大值'};
    app.faultTable.ColumnEditable = true(1, 16);
    app.faultTable.ColumnFormat = { ...
        'logical','char','char', ...
        {'degradation','saturation','bias','drift','dropout','outage','delay'}, ...
        'numeric','numeric','numeric', ...
        {'step','ramp','intermittent','random'}, ...
        'numeric', {'nominal','current'}, {'replace','max','min','mean'}, ...
        'numeric','char','char','char','char'};
    app.faultTable.ColumnWidth = {70, 140, 180, 120, 90, 90, 90, 100, 80, 90, 90, 90, 120, 120, 90, 90};
    app.faultTable.CellSelectionCallback = @onFaultCellSelected;

    % 底部动作条
    bottom = uigridlayout(root, [1, 5]);
    bottom.ColumnWidth = {200, 220, 220, '1x', 180};

    uibutton(bottom, 'Text', '应用到工作区', ...
        'FontWeight', 'bold', ...
        'ButtonPushedFcn', @onApplyWorkspace);

    uibutton(bottom, 'Text', '仅构建 params_in/fault_cfg', ...
        'ButtonPushedFcn', @onBuildOnly);

    uibutton(bottom, 'Text', '显示使用帮助', ...
        'ButtonPushedFcn', @onShowHelp);

    spacer = uilabel(bottom, 'Text', ''); %#ok<NASGU>

    uibutton(bottom, 'Text', '关闭', ...
        'ButtonPushedFcn', @(~,~) delete(app.fig));

    % 初始数据
    app.initRawMap = local_default_init_struct();
    
    % 将初始数据按子系统分类到各标签页
    [rows_orbit, rows_eps, rows_adcs, rows_sensor, rows_gyro, rows_prop, rows_comm, rows_other] ...
        = local_classify_init_rows(local_struct_to_init_rows(app.initRawMap));
    
    app.initTable_orbit.Data = rows_orbit;
    app.initTable_eps.Data = rows_eps;
    app.initTable_adcs.Data = rows_adcs;
    app.initTable_sensor.Data = rows_sensor;
    app.initTable_gyro.Data = rows_gyro;
    app.initTable_prop.Data = rows_prop;
    app.initTable_comm.Data = rows_comm;
    app.initTable_other.Data = rows_other;
    
    app.faultTable.Data = local_default_fault_rows();

    guidata(app.fig, app);

    % ------------------ 回调函数 ------------------
    function onLoadDefaults(~, ~)
        app = guidata(app.fig);
        setStatus('正在从 init_params.m 加载默认值...');

        try
            defaults = local_try_load_init_params();
            app.initRawMap = defaults;
            allRows = local_struct_to_init_rows(defaults);
            [rows_orbit, rows_eps, rows_adcs, rows_sensor, rows_gyro, rows_prop, rows_comm, rows_other] ...
                = local_classify_init_rows(allRows);
            
            app.initTable_orbit.Data = rows_orbit;
            app.initTable_eps.Data = rows_eps;
            app.initTable_adcs.Data = rows_adcs;
            app.initTable_sensor.Data = rows_sensor;
            app.initTable_gyro.Data = rows_gyro;
            app.initTable_prop.Data = rows_prop;
            app.initTable_comm.Data = rows_comm;
            app.initTable_other.Data = rows_other;
            
            totalRows = size(allRows, 1);
            setStatus(sprintf('已从 init_params.m 加载 %d 个初始化参数', totalRows));
        catch ME
            uialert(app.fig, sprintf('加载失败：%s\n已改用回退模板。', ME.message), '加载警告');
            app.initRawMap = local_default_init_struct();
            allRows = local_struct_to_init_rows(app.initRawMap);
            [rows_orbit, rows_eps, rows_adcs, rows_sensor, rows_gyro, rows_prop, rows_comm, rows_other] ...
                = local_classify_init_rows(allRows);
            
            app.initTable_orbit.Data = rows_orbit;
            app.initTable_eps.Data = rows_eps;
            app.initTable_adcs.Data = rows_adcs;
            app.initTable_sensor.Data = rows_sensor;
            app.initTable_gyro.Data = rows_gyro;
            app.initTable_prop.Data = rows_prop;
            app.initTable_comm.Data = rows_comm;
            app.initTable_other.Data = rows_other;
            setStatus('已加载回退模板。');
        end

        guidata(app.fig, app);
    end

    function onAddInitRow(~, ~)
        app = guidata(app.fig);
        % 在所有初始化参数表中找到有数据或有焦点的表
        tables = {app.initTable_orbit, app.initTable_eps, app.initTable_adcs, ...
                 app.initTable_sensor, app.initTable_gyro, app.initTable_prop, ...
                 app.initTable_comm, app.initTable_other};
        targetTable = [];
        for t = tables
            if ~isempty(t{1}.Data)
                targetTable = t{1};
                break;
            end
        end
        if isempty(targetTable)
            targetTable = app.initTable_other;  % 默认添加到"其他"表
        end
        
        row = {'new_param', '0', 'double', '1x1', '自定义参数说明'};
        if isempty(targetTable.Data)
            targetTable.Data = row;
        else
            targetTable.Data(end+1, :) = row;
        end
        setStatus('已新增初始化行。');
    end

    function onDeleteInitRow(~, ~)
        app = guidata(app.fig);
        if isempty(app.selectedInitRow)
            return;
        end
        % 在所有表中找到选中的行所在的表
        tables = {app.initTable_orbit, app.initTable_eps, app.initTable_adcs, ...
                 app.initTable_sensor, app.initTable_gyro, app.initTable_prop, ...
                 app.initTable_comm, app.initTable_other};
        for t = tables
            table_obj = t{1};
            if ~isempty(table_obj.Data) && size(table_obj.Data, 1) >= max(app.selectedInitRow)
                idx = app.selectedInitRow;
                idx(idx < 1 | idx > size(table_obj.Data,1)) = [];
                if ~isempty(idx)
                    table_obj.Data(idx, :) = [];
                    app.selectedInitRow = [];
                    guidata(app.fig, app);
                    setStatus('已删除初始化行。');
                    return;
                end
            end
        end
    end

    function onInitCellSelected(src, evt)
        app = guidata(app.fig);
        if ~isempty(evt.Indices)
            app.selectedInitRow = unique(evt.Indices(:,1));
            app.selectedInitTable = src;  % 记录当前操作的表
            guidata(app.fig, app);
        end
    end

    function onAddFaultRow(~, ~)
        app = guidata(app.fig);
        row = {true, 'F_NEW_01', 'p_drop', 'dropout', 0.3, 100, inf, 'step', 0, 'nominal', 'replace', 0.5, '', '', '', ''};
        if isempty(app.faultTable.Data)
            app.faultTable.Data = row;
        else
            app.faultTable.Data(end+1, :) = row;
        end
        setStatus('已新增故障行。');
    end

    function onDeleteFaultRow(~, ~)
        app = guidata(app.fig);
        if isempty(app.selectedFaultRow) || isempty(app.faultTable.Data)
            return;
        end
        idx = app.selectedFaultRow;
        idx(idx < 1 | idx > size(app.faultTable.Data,1)) = [];
        app.faultTable.Data(idx, :) = [];
        app.selectedFaultRow = [];
        guidata(app.fig, app);
        setStatus('已删除故障行。');
    end

    function onFaultCellSelected(~, evt)
        app = guidata(app.fig);
        if ~isempty(evt.Indices)
            app.selectedFaultRow = unique(evt.Indices(:,1));
            guidata(app.fig, app);
        end
    end

    function onSaveConfigMat(~, ~)
        app = guidata(app.fig);
        [f, p] = uiputfile('*.mat', '保存界面配置');
        if isequal(f, 0)
            return;
        end

        % 从所有初始化表中收集数据
        initRows_orbit = app.initTable_orbit.Data; %#ok<NASGU>
        initRows_eps = app.initTable_eps.Data; %#ok<NASGU>
        initRows_adcs = app.initTable_adcs.Data; %#ok<NASGU>
        initRows_sensor = app.initTable_sensor.Data; %#ok<NASGU>
        initRows_gyro = app.initTable_gyro.Data; %#ok<NASGU>
        initRows_prop = app.initTable_prop.Data; %#ok<NASGU>
        initRows_comm = app.initTable_comm.Data; %#ok<NASGU>
        initRows_other = app.initTable_other.Data; %#ok<NASGU>
        faultRows = app.faultTable.Data; %#ok<NASGU>
        
        save(fullfile(p, f), 'initRows_orbit', 'initRows_eps', 'initRows_adcs', ...
             'initRows_sensor', 'initRows_gyro', 'initRows_prop', 'initRows_comm', ...
             'initRows_other', 'faultRows');
        setStatus('界面配置已保存。');
    end

    function onLoadConfigMat(~, ~)
        app = guidata(app.fig);
        [f, p] = uigetfile('*.mat', '加载界面配置');
        if isequal(f, 0)
            return;
        end

        S = load(fullfile(p, f));
        if isfield(S, 'initRows_orbit')
            app.initTable_orbit.Data = local_normalize_init_rows(S.initRows_orbit);
        end
        if isfield(S, 'initRows_eps')
            app.initTable_eps.Data = local_normalize_init_rows(S.initRows_eps);
        end
        if isfield(S, 'initRows_adcs')
            app.initTable_adcs.Data = local_normalize_init_rows(S.initRows_adcs);
        end
        if isfield(S, 'initRows_sensor')
            app.initTable_sensor.Data = local_normalize_init_rows(S.initRows_sensor);
        end
        if isfield(S, 'initRows_gyro')
            app.initTable_gyro.Data = local_normalize_init_rows(S.initRows_gyro);
        end
        if isfield(S, 'initRows_prop')
            app.initTable_prop.Data = local_normalize_init_rows(S.initRows_prop);
        end
        if isfield(S, 'initRows_comm')
            app.initTable_comm.Data = local_normalize_init_rows(S.initRows_comm);
        end
        if isfield(S, 'initRows_other')
            app.initTable_other.Data = local_normalize_init_rows(S.initRows_other);
        end
        if isfield(S, 'faultRows')
            app.faultTable.Data = S.faultRows;
        end
        app.initRawMap = struct();
        guidata(app.fig, app);
        setStatus('界面配置已加载。');
    end

    function onApplyWorkspace(~, ~)
        app = guidata(app.fig);
        try
            % 若 initRawMap 为空但表中有空表达式，自动兜底加载一次
            workingRawMap = app.initRawMap;
            if isempty(fieldnames(workingRawMap))
                % 检测所有初始化表中是否有空表达式
                hasEmptyExpr = false;
                tables = {app.initTable_orbit, app.initTable_eps, app.initTable_adcs, ...
                         app.initTable_sensor, app.initTable_gyro, app.initTable_prop, ...
                         app.initTable_comm, app.initTable_other};
                for t = tables
                    if ~isempty(t{1}.Data)
                        for j = 1:size(t{1}.Data, 1)
                            if isempty(strtrim(local_to_char(t{1}.Data{j,2})))
                                hasEmptyExpr = true;
                                break;
                            end
                        end
                    end
                    if hasEmptyExpr, break; end
                end
                % 若有空表达式，尝试一次加载
                if hasEmptyExpr
                    try
                        workingRawMap = local_try_load_init_params();
                    catch
                        % 加载失败就继续，空表达式变成 []
                    end
                end
            end

            % 从所有初始化表中聚合数据
            allInitRows = [
                app.initTable_orbit.Data; 
                app.initTable_eps.Data;
                app.initTable_adcs.Data;
                app.initTable_sensor.Data;
                app.initTable_gyro.Data;
                app.initTable_prop.Data;
                app.initTable_comm.Data;
                app.initTable_other.Data
            ];
            
            [paramsIn, initMap] = local_build_params_in_from_table(allInitRows, workingRawMap);
            faultCfg = local_build_fault_cfg_from_table(app.faultTable.Data);

            % 1) 将初始化参数逐项写入 base workspace（替代 init_params.m 效果）
            names = fieldnames(initMap);
            for i = 1:numel(names)
                assignin('base', names{i}, initMap.(names{i}));
            end

            % 2) 构建并写入 params_in / fault_cfg（替代手工构建）
            assignin('base', 'params_in', paramsIn);
            assignin('base', 'fault_cfg', faultCfg);

            % 可选：同时写入一份当前故障注入后的参数快照（t=0）
            try
                [params_out_0, active_fault_ids_0] = fault_inject(0, paramsIn, faultCfg); %#ok<NASGU>
                assignin('base', 'params_out_0', params_out_0);
                assignin('base', 'active_fault_ids_0', active_fault_ids_0);
            catch
                % 若 fault_inject 不在路径或暂时不可用，不中断主流程。
            end

            setStatus(sprintf('已应用到工作区：%d 个初始化参数，%d 个故障项。', numel(names), numel(faultCfg.items)));
        catch ME
            uialert(app.fig, sprintf('应用失败：\n%s', ME.message), '应用错误');
            setStatus('应用失败。');
        end
    end

    function onBuildOnly(~, ~)
        app = guidata(app.fig);
        try
            % 同样的兜底加载逻辑
            workingRawMap = app.initRawMap;
            if isempty(fieldnames(workingRawMap))
                hasEmptyExpr = false;
                tables = {app.initTable_orbit, app.initTable_eps, app.initTable_adcs, ...
                         app.initTable_sensor, app.initTable_gyro, app.initTable_prop, ...
                         app.initTable_comm, app.initTable_other};
                for t = tables
                    if ~isempty(t{1}.Data)
                        for j = 1:size(t{1}.Data, 1)
                            if isempty(strtrim(local_to_char(t{1}.Data{j,2})))
                                hasEmptyExpr = true;
                                break;
                            end
                        end
                    end
                    if hasEmptyExpr, break; end
                end
                if hasEmptyExpr
                    try
                        workingRawMap = local_try_load_init_params();
                    catch
                    end
                end
            end

            % 从所有初始化表中聚合数据
            allInitRows = [
                app.initTable_orbit.Data; 
                app.initTable_eps.Data;
                app.initTable_adcs.Data;
                app.initTable_sensor.Data;
                app.initTable_gyro.Data;
                app.initTable_prop.Data;
                app.initTable_comm.Data;
                app.initTable_other.Data
            ];
            
            [paramsIn, ~] = local_build_params_in_from_table(allInitRows, workingRawMap);
            faultCfg = local_build_fault_cfg_from_table(app.faultTable.Data);
            assignin('base', 'params_in', paramsIn);
            assignin('base', 'fault_cfg', faultCfg);
            setStatus(sprintf('仅构建完成：params_in + fault_cfg（%d 个故障项）。', numel(faultCfg.items)));
        catch ME
            uialert(app.fig, sprintf('构建失败：\n%s', ME.message), '构建错误');
            setStatus('构建失败。');
        end
    end

    function onShowHelp(~, ~)
        msg = [ ...
            "使用方法：", ...
            "1) 在“初始化参数”页签编辑参数。", ...
            "2) 在“故障配置”页签编辑故障项。", ...
            "3) 点击“应用到工作区”。", ...
            "4) 在仿真循环中调用：[params_out, ids] = fault_inject(t, params_in, fault_cfg);", ...
            "", ...
            "参数表达式示例：", ...
            "- 标量：0.2", ...
            "- 向量：[1;2;3] 或 [1,2,3]", ...
            "- 矩阵：[1 2; 3 4]", ...
            "- 字符串：'abc'", ...
            "- 可直接使用 inf / pi。" ...
        ];
        uialert(app.fig, strjoin(cellstr(msg), newline), '帮助');
    end

    function setStatus(txt)
        app = guidata(app.fig);
        app.statusLabel.Text = txt;
        drawnow limitrate;
    end
end

% ------------------ 本地工具函数 ------------------

function S = local_default_init_struct()
% 回退模板：当无法从 init_params.m 自动加载时使用。
% 包含卫星所有子系统的完整参数
S = struct();

%% 中心天体参数
S.mu = 3.986004418e14;   % 地球标准万有引力常数，m^3/s^2
S.Re = 6378137;          % 地球半径，m
S.Re2 = 4.0589641e13;    % 地球半径平方，m^2
S.J2 = 1.08262668e-3;    % 地球J2摄动系数
S.omegaE = 7.2921159e-5; % 地球自转角速度，rad/s
S.h_ref = 400e3;         % 参考高度，m
S.rho_ref = 3e-12;       % 参考密度，kg/m^3
S.H = 50e3;              % 大气标度高度，m
S.earth_theta0 = 0;      % 地球初始旋转角，rad
S.utc0 = posixtime(datetime(2026,1,1,8,0,0)); % UTC时间戳
S.year = 2026;           % 年，用于时间计算
S.month = 1;             % 月，用于时间计算
S.day = 1;               % 日，用于时间计算
S.hh = 8;                % 时，用于时间计算
S.mm = 0;                % 分，用于时间计算
S.ss = 0;                % 秒，用于时间计算
S.utc0_jd = 2460310.833; % 儒略日期

%% 轨道动力学参数
S.Cd = 2.2;              % 阻力系数（无量纲）
S.area_d = 4;            % 大气阻力面积，m^2
S.m = 500;               % 卫星总质量，kg
S.x0 = 7e6;              % 初始位置X，m
S.y0 = 0;                % 初始位置Y，m
S.z0 = 0;                % 初始位置Z，m
S.vx0 = 0;               % 初始速度X，m/s
S.vy0 = 7546;            % 初始速度Y，m/s
S.vz0 = 0;               % 初始速度Z，m/s
S.P0 = 4.56e-6;          % 太阳光压，N/m^2
S.Cr = 1.2;              % 光压反射系数（1~1.8）
S.area_s = 2;            % 光压受照面积，m^2
S.hat_s = [1; 0; 0];     % 太阳方向单位向量（惯性系）

%% 电源子系统参数
% 外部环境
S.sunlit = 1;            % 日照标志，0/1
S.P_panel = 1000;        % 太阳板发电功率，W
% 地面站可见性
S.sta_lat = 0;           % 地面站纬度，rad
S.sta_lon = 0;           % 地面站经度，rad
S.sta_h = 0;             % 地面站高度，m
S.sta_vec = (S.Re+S.sta_h) * [
    cos(S.sta_lat)*cos(S.sta_lon);
    cos(S.sta_lat)*sin(S.sta_lon);
    sin(S.sta_lat)
];
S.gamma_max = 60*pi/180; % 最大可见角，rad
S.cos_g_max = cos(60*pi/180); % 最大可见角余弦值
% 母线与太阳板参数
S.V_bus0 = 28;           % 参考母线电压，V
S.C_bus = 1;             % 母线等效电容，F
S.V_uvlo_off = 24;       % 欠压关闭阈值，V
S.V_uvlo_on = 26;        % 欠压开启阈值，V
S.n_solar = [0; 0; -1];  % 太阳板法向单位向量
S.I_sc = 3.8;            % 太阳板短路电流，A
S.G0 = 1366.1;           % 太阳光照常数，W/m^2
S.area_pannel = 1;       % 太阳板面积，m^2
S.I_f = 3.15e-7;         % 反向饱和电流，A
S.R_s = 0.0042;          % 串联电阻，ohm
S.R_p = 10.1;            % 并联电阻，ohm
S.V_t = 0.025;           % 热电压，V
S.n_diode = 1.4;         % 二极管理想因子
S.Vmp = 7/15;            % 工作电压，V
S.num_s = 126;           % 串联电池单元个数
S.num_p = 2;             % 并联电池单元个数
S.V_oc = 882;            % 开路电压，V
S.eta_mppt = 0.95;       % MPPT效率
S.eta_buck = 0.9;        % Buck变换器效率
S.D_0 = 0.7;             % 初始占空比
S.Delta_D = 0.001;       % 占空比步长
S.D_min = 0.03;          % 占空比最小值
S.D_max = 1;             % 占空比最大值
S.dP_th = 0.05;          % 功率变化阈值
% 负载功耗
S.P_base = 20;           % 基础功耗，W
S.P_adcs = 20;           % 姿态控制功耗，W
S.P_prop = 5;            % 推进系统功耗，W
S.P_comm = 30;           % 通信功耗，W
% 电池参数
S.E_max = 7.2e5;         % 电池最大能量，J（~200Wh）
S.E0 = 4.32e5;           % 初始电能，J
S.SOC0 = 0.6;            % 初始电池荷电状态（0~1）
S.SOC_low_comm = 0.2;    % 低荷电关闭通信阈值
S.SOC_low_prop = 0.2;    % 低荷电关闭推进阈值
S.SOC_low_adcs = 0.1;    % 低荷电关闭姿态控制阈值
S.beta = 0.3;            % 负载电阻性占比
S.R_load = 1.4e3;        % 等效负载电阻，ohm
% 充放电参数
S.P_trickle = 0.5;       % 涓流充电电流，A
S.P_cc = 7.86;           % 恒流充电电流，A
S.SOC1 = 0.2;            % 涓流与恒流分界线
S.SOC2 = 0.8;            % 恒流与恒压分界线
S.P_dis_lim = -200;      % 放电功率限流，W
S.I_chg_max = 8;         % 充电电流限幅，A
S.I_dis_max = 10;        % 放电电流限幅，A
S.eta_chg = 0.95;        % 充电效率
S.eta_dis = 0.95;        % 放电效率
S.Q = 20;                % 电池最大电量，Ah
S.V_max = 33;            % 电池最大电压，V
S.V_min = 24;            % 电池最小电压，V
S.Rb = 0.2;              % 电池内阻，ohm

%% 姿态确定与控制子系统
% 航天器物理属性
S.Jx = 10;               % X轴转动惯量，kg*m^2
S.Jy = 12;               % Y轴转动惯量，kg*m^2
S.Jz = 8;                % Z轴转动惯量，kg*m^2
% 航天器初始状态
S.w0_x = 0;              % 初始角速度X分量，rad/s
S.w0_y = 0;              % 初始角速度Y分量，rad/s
S.w0_z = 0;              % 初始角速度Z分量，rad/s
S.Q0 = [0.6;0.8;0;0];  % 初始四元数标量分量

S.angle0 = [0;0;0];      % 初始欧拉角，rad
S.angleE = [0,0,0];      % 目标欧拉角，rad

S.QE = eul2quat(S.angleE, 'ZYX');              % 目标四元数分量

% 姿态控制器参数
S.Kp = [0.05;0.06;0.4];% 竖滚、俯仰、偏航轴比例系数

S.Kd = [1.10;1.32;0.88];% 竖滚、俯仰、偏航轴微分系数
S.Torque_limit = 0.2;    % 控制力矩限幅，N*m
% 反作用轮参数
S.tau = 0.05;            % 反作用轮伺服时间常数，s
S.kp_w = 100;            % 力矩电机控制器比例系数
S.ki_w = 0;              % 力矩电机控制器积分系数
S.i_w_min = -2;          % 反作用轮指令电流下限，A
S.i_w_max = 2;           % 反作用轮指令电流上限，A
S.Cm = 0.01;             % 电磁转矩系数
S.d_f = 2e-5;            % 粘性摩擦力矩系数
S.d_c = 2e-5;            % 库仑摩擦力矩
S.T_max = 0.05;          % 反作用轮最大输出力矩，N*m
S.Iw = 0.02;             % 反作用轮转动惯量，kg*m^2
S.A_w = [
  1, -1, -1, 1;
  1, 1, -1, -1;
  2, 2, 2, 2;
]*sqrt(1/6); 
S.K_w = S.A_w' / (S.A_w * S.A_w');
S.eta = 0.7;             % 反作用轮机电效率
S.rpm_max = 6000;        % 反作用轮最大转速，rpm
S.h_max = 0.12;          % 单轴角动量上限，N*m*s
S.sf_factor = 0.85;      % 反作用轮安全系数
S.k_h = 0.05;            % 角动量卸载比例系数，1/s
% 激光陀螺参数
S.perimeter_m = 0.4;     % 谐振腔周长，m
S.area_m2 = 0.0127;      % 谐振腔面积，m^2
S.wavelength_m = 632.8e-9; % 激光波长，m
S.V_pzt_min = 0;         % PZT最小工作电压，V
S.V_pzt_max = 100;       % PZT最大工作电压，V
S.sweep_frequency = 50;  % 扫模频率，Hz
S.tau_th_s = 200;        % 热时常，s
S.k_sf1_ppm = 1.0;       % 比例因子一阶项，ppm
S.k_sf2_ppm = 0.0;       % 比例因子二阶项，ppm
S.bias0_deg_h = 0.01;    % 初始零偏，deg/h
S.k_bias1_deg_h_per_C = 1.0;   % 零偏温度系数一阶
S.k_bias2_deg_h_per_C = 0.0;   % 零偏温度系数二阶
S.f_n_hz = 400;          % 抖动自然频率，Hz
S.zeta = 0.01;           % 抖动阻尼比
S.v_peak_deg_s = 1.0;    % 抖动峰值，deg/s
S.initial_phase = 0;     % 抖动初始相位，rad
S.I_triggle = 8;         % 光强控制阈值
S.I_gate = 0.5;          % 光强门槛
S.I_e = 11;              % 期望光强
S.kP = 10;               % 比例增益
S.kI = 0.01;             % 积分增益
S.V_center = 50;         % 中心电压，V
S.k_a = 4e-4;            % Lamb增益灵敏度
S.alpha1 = 0.1;          % 增益系数1
S.alpha2 = 0.1;          % 增益系数2
S.beta1 = 0.01;      % 自饱和系数1
S.beta2 = 0.01;      % 自饱和系数2
S.theta12 = 0.005;       % 交叉饱和系数12
S.theta21 = 0.005;       % 交叉饱和系数21
S.sigma1 = 0;            % 频率基准1
S.sigma2 = 0;            % 频率基准2
S.tau12 = 0.001;     % 互聚焦系数12，s
S.tau21 = 0.001;     % 互聚焦系数21，s
S.r1 = 1e-4;             % 反向散射系数1
S.r2 = 1e-4;             % 反向散射系数2
S.epsilon = 0.01;        % 反向散射固有相移
S.ARW_deg_per_sqrt_h = 0.01;  % 陀螺角随机游走，deg/sqrt(h)
S.white_rate_std_deg_s = 0;   % 陀螺白噪声标准差，deg/s

%% 姿态传感器参数
S.f_st = 5;              % 星敏更新率，Hz
S.Ts_st = 0.2;           % 星敏更新周期，s
S.T_delay_st = 0.2;      % 星敏延迟，s
S.sigma_arcsec = 30;     % 星敏姿态噪声，arcsec
S.sigma_rad = 30/3600*pi/180;  % 星敏姿态噪声，rad
S.p_drop = 0.02;         % 星敏掉帧概率（0~1）
S.sigma_sun = 0.5*pi/180;% 太阳敏感器噪声，rad
S.fov = 60*pi/180;       % 太阳敏感器视场角，rad
S.n_sun = [0; 0; 1];     % 太阳敏感器安装朝向轴
S.sigma_earth = 0.2*pi/180;  % 地心敏感器噪声，rad
S.t_a = 1;               % 姿态解算周期，s
S.kp_f = 1;              % 姿态纠正强度，rad/s per rad
S.ki_f = 0.01;           % 偏执估计速率，rad/s^2 per rad
S.Tcorr_limit = 0.05;    % 纠正力矩限幅

%% 通信子系统参数
S.f = 2.2e9;             % 载波频率，Hz
S.c = 299792458;         % 光速，m/s
S.Pt_dBW = 10;           % 发射功率，dBW
S.Gt_dB = 3;             % 星上天线增益，dB
S.Gr_dB = 20;            % 地面站天线增益，dB
S.Noise_dBW = -170;      % 噪声功率，dBW
% 固态功放参数
S.P_in_driver_dBW = -6;  % 前级驱动功率，dBW
S.G_sspa_dB = 20;        % SSPA小信号增益，dB
S.P_sspa_dBW = 15;       % SSPA最大输出功率，dBW
S.eta_sspa = 0.35;       % SSPA效率
% 行波管放大器参数
S.G_twta_dB = 20;        % TWTA小信号增益，dB
S.P_twta_dBW = 15;       % TWTA最大输出功率，dBW
S.eta_twta = 0.35;       % TWTA效率

%% 推进子系统参数
% 化学推进
S.T_nominal = 20;        % 化学推进标称推力，N
S.Isp = 220;             % 化学推进比冲，s
S.g0 = 9.80665;          % 标准重力加速度，m/s^2
S.m0 = 20;               % 化推初始工质质量，kg
S.tau_thr = 0.2;         % 推力时间常数，s
S.r_ref = 7.026e6;       % 轨道半径维持目标，m
S.D_thr = 0.4;           % 推力输出占空比
S.T_thr = 1;             % 推力输出周期
% 电推进
S.eta_et = 0.9;          % 电推进效率（0~1）
S.P_et_max = 10;         % 电推功耗，W
S.m0_et = 5;             % 电推初始工质质量，kg
S.tau_et = 0.5;          % 电推时间常数，s
S.Isp_et = 1500;         % 电推比冲，s
S.L = 0.5;               % 推力作用点偏心距，m
S.P_overhead = 1;        % 电推固定开销，W

%% 测控子系统参数
S.comm_allow = 1;        % 通信允许标志（0/1）
S.cmd_on_step = 500;     % 发射机开机时刻，s
S.cmd_off_step = 2000;   % 发射机关机时刻，s
S.R_data = 1e6;          % 数据生成速率，bps
S.cmd_comm = 1;          % 通信允许
%% 仿真参数
S.dt = 0.01;             % 仿真步长，s
end

function S = local_try_load_init_params()
% 尝试在独立函数工作区运行 init_params.m，并抓取变量。
% 注：init_params.m 若包含 clear/clc，不影响 base workspace。

scriptPath = fullfile(pwd, 'init_params.m');
if ~isfile(scriptPath)
    error('当前目录未找到 init_params.m：%s', pwd);
end

% 在本函数工作区执行脚本。
run(scriptPath);

vars = whos;
S = struct();
skip = {'ans'};
for i = 1:numel(vars)
    varName = vars(i).name;
    if any(strcmp(varName, skip))
        continue;
    end
    try
        S.(varName) = eval(varName);
    catch
        % 跳过无法读取的变量
    end
end

if isempty(fieldnames(S))
    error('未从 init_params.m 捕获到任何变量');
end
end

function rows = local_struct_to_init_rows(S)
names = fieldnames(S);
rows = cell(numel(names), 5);
for i = 1:numel(names)
    n = names{i};
    v = S.(n);
    rows{i,1} = n;
    rows{i,2} = local_value_to_expr(v);
    rows{i,3} = class(v);
    rows{i,4} = local_size_to_str(size(v));
    rows{i,5} = local_param_comment(n);
end
end

function rows = local_normalize_init_rows(rowsIn)
% 兼容旧版 MAT 配置：若只有 4 列，自动补一列注释。
if isempty(rowsIn)
    rows = cell(0, 5);
    return;
end

if size(rowsIn, 2) >= 5
    rows = rowsIn(:, 1:5);
    return;
end

rows = cell(size(rowsIn, 1), 5);
rows(:, 1:size(rowsIn, 2)) = rowsIn;
for i = 1:size(rows, 1)
    name = strtrim(local_to_char(rows{i,1}));
    rows{i,5} = local_param_comment(name);
end
end

function [rows_orbit, rows_eps, rows_adcs, rows_sensor, rows_gyro, rows_prop, rows_comm, rows_other] = local_classify_init_rows(allRows)
% 将初始化参数按子系统分类
% 返回按子系统分类的参数行
rows_orbit = {};
rows_eps = {};
rows_adcs = {};
rows_sensor = {};
rows_gyro = {};
rows_prop = {};
rows_comm = {};
rows_other = {};

if isempty(allRows)
    rows_orbit = cell(0, 5);
    rows_eps = cell(0, 5);
    rows_adcs = cell(0, 5);
    rows_sensor = cell(0, 5);
    rows_gyro = cell(0, 5);
    rows_prop = cell(0, 5);
    rows_comm = cell(0, 5);
    rows_other = cell(0, 5);
    return;
end

% 定义参数分类映射（完整覆盖init_params.m的所有参数）
orbit_params = {'cd', 'area_d', 'm', 'x0', 'y0', 'z0', 'vx0', 'vy0', 'vz0', 'p0', 'cr', 'area_s', 'hat_s'};
eps_params = {'sunlit', 'p_panel', 'v_bus0', 'c_bus', 'v_uvlo_off', 'v_uvlo_on', 'eta_mppt', 'eta_buck', ...
              'i_sc', 'area_pannel', 'd_0', 'delta_d', 'e_max', 'e0', 'soc0', ...
              'soc_low_comm', 'soc_low_prop', 'soc_low_adcs', 'i_chg_max', 'i_dis_max', ...
              'eta_chg', 'eta_dis', 'q', 'v_max', 'v_min', 'rb', 'p_base', 'p_adcs', 'p_prop', 'p_comm', ...
              'sta_lat', 'sta_lon', 'sta_h', 'sta_vec','gamma_max', 'cos_g_max', 'n_solar', 'i_f', 'r_s', 'r_p', 'v_t', ...
              'n_diode', 'vmp', 'num_s', 'num_p', 'v_oc', 'd_min', 'd_max', 'dp_th', 'beta', 'r_load', ...
              'p_trickle', 'p_cc', 'soc1', 'soc2', 'p_dis_lim', 'g0'};
adcs_params = {'jx', 'jy', 'jz', 'torque_limit', 't_max', 'tau', 'iw', 'eta', 'rpm_max', 'k_h', ...
              'w0', 'q0','qe', ...
              'angle0', 'anglee', ...
              'kp', 'kd',...
              'kp_w', 'ki_w', 'i_w_min', 'i_w_max', 'cm', 'd_f', 'd_c', 'h_max', 'sf_factor'};
gyro_params = {'k_sf1_ppm', 'bias0_deg_h', 'arw_deg_per_sqrt_h', 'white_rate_std_deg_s', ...
              'perimeter_m', 'area_m2', 'wavelength_m', 'v_pzt_min', 'v_pzt_max', 'sweep_frequency', ...
              'tau_th_s', 'k_sf2_ppm', 'k_bias1_deg_h_per_c', 'k_bias2_deg_h_per_c', ...
              'f_n_hz', 'zeta', 'v_peak_deg_s', 'initial_phase', 'i_triggle', 'i_gate', 'i_e', ...
              'kp', 'ki', 'v_center', 'k_a', 'alpha1', 'alpha2', 'beta1', 'beta2', ...
              'theta12', 'theta21', 'sigma1', 'sigma2', 'tau12', 'tau21', 'r1', 'r2', 'epsilon'};
sensor_params = {'p_drop', 'f_st', 'ts_st', 'sigma_arcsec', 't_delay_st', 'sigma_sun', 'fov', 'sigma_earth', ...
                'sigma_rad', 'n_sun', 't_a', 'kp_f', 'ki_f', 'tcorr_limit'};
prop_params = {'t_nominal', 'isp', 'm0', 'tau_thr', 'isp_et', 'tau_et', 'eta_et', 'p_et_max', 'm0_et', 'g0', 'r_ref', 'l', 'p_overhead'};
comm_params = {'p_sspa_dbw', 'eta_sspa', 'pt_dbw', 'f', 'c', 'gt_db', 'gr_db', 'noise_dbw', ...
              'p_in_driver_dbw', 'g_sspa_db', 'g_twta_db', 'p_twta_dbw', 'eta_twta'};
other_params = {'mu', 're', 're2', 'j2', 'omegae', 'h_ref', 'rho_ref', 'h', 'earth_theta0', ...
               'utc0', 'year', 'month', 'day', 'hh', 'mm', 'ss', 'utc0_jd', ...
               'comm_allow', 'cmd_on_step', 'cmd_off_step', 'r_data', 'dt'};

% 分类参数行
for i = 1:size(allRows, 1)
    paramName = lower(strtrim(local_to_char(allRows{i,1})));
    row = allRows(i, :);
    
    if ismember(paramName, orbit_params)
        rows_orbit = [rows_orbit; row];
    elseif ismember(paramName, eps_params)
        rows_eps = [rows_eps; row];
    elseif ismember(paramName, adcs_params)
        rows_adcs = [rows_adcs; row];
    elseif ismember(paramName, sensor_params)
        rows_sensor = [rows_sensor; row];
    elseif ismember(paramName, gyro_params)
        rows_gyro = [rows_gyro; row];
    elseif ismember(paramName, prop_params)
        rows_prop = [rows_prop; row];
    elseif ismember(paramName, comm_params)
        rows_comm = [rows_comm; row];
    else
        rows_other = [rows_other; row];
    end
end

% 确保所有输出都是 cell 数组，即使为空
if isempty(rows_orbit), rows_orbit = cell(0, size(allRows, 2)); end
if isempty(rows_eps), rows_eps = cell(0, size(allRows, 2)); end
if isempty(rows_adcs), rows_adcs = cell(0, size(allRows, 2)); end
if isempty(rows_sensor), rows_sensor = cell(0, size(allRows, 2)); end
if isempty(rows_gyro), rows_gyro = cell(0, size(allRows, 2)); end
if isempty(rows_prop), rows_prop = cell(0, size(allRows, 2)); end
if isempty(rows_comm), rows_comm = cell(0, size(allRows, 2)); end
if isempty(rows_other), rows_other = cell(0, size(allRows, 2)); end
end

function txt = local_param_comment(name)
% 常见参数说明映射。未命中时返回统一兜底说明，避免界面留空。
switch lower(strtrim(name))
    %% 中心天体参数
    case 'mu'
        txt = '地球标准万有引力常数，m^3/s^2';
    case 're'
        txt = '地球半径，m';
    case 're2'
        txt = '地球半径平方，m^2';
    case 'j2'
        txt = '地球J2摄动系数';
    case 'omegae'
        txt = '地球自转角速度，rad/s';
    case 'h_ref'
        txt = '参考高度，m';
    case 'rho_ref'
        txt = '参考大气密度，kg/m^3';
    case 'h'
        txt = '大气标度高度，m';
    case 'earth_theta0'
        txt = '地球初始旋转角，rad';
    case 'utc0'
        txt = 'UTC时间戳';
    case 'year'
        txt = '年份（用于时间计算）';
    case 'month'
        txt = '月份（用于时间计算）';
    case 'day'
        txt = '日期（用于时间计算）';
    case 'hh'
        txt = '小时（用于时间计算）';
    case 'mm'
        txt = '分钟（用于时间计算）';
    case 'ss'
        txt = '秒数（用于时间计算）';
    case 'utc0_jd'
        txt = '儒略日期';
    %% 轨道动力学参数
    case 'cd'
        txt = '阻力系数（无量纲）';
    case 'area_d'
        txt = '大气阻力面积（m^2）';
    case 'm'
        txt = '卫星总质量（kg）';
    case 'x0'
        txt = '初始位置X坐标（m）';
    case 'y0'
        txt = '初始位置Y坐标（m）';
    case 'z0'
        txt = '初始位置Z坐标（m）';
    case 'vx0'
        txt = '初始速度X分量（m/s）';
    case 'vy0'
        txt = '初始速度Y分量（m/s）';
    case 'vz0'
        txt = '初始速度Z分量（m/s）';
    case 'p0'
        txt = '太阳光压，N/m^2';
    case 'cr'
        txt = '太阳光压反射系数（0~1）';
    case 'area_s'
        txt = '太阳光压受面积，m^2';
    case 'hat_s'
        txt = '太阳方向单位向量（惯性系）';
    %% 电源子系统参数
    case 'sunlit'
        txt = '日照标志（0/1）';
    case 'p_panel'
        txt = '太阳板发电功率，W';
    case 'sta_lat'
        txt = '地面站纬度，rad';
    case 'sta_lon'
        txt = '地面站经度，rad';
    case 'sta_h'
        txt = '地面站高度，m';
    case 'sta_vec'
        txt = '地面站坐标';
    case 'gamma_max'
        txt = '最大可见角，rad';
    case 'cos_g_max'
        txt = '最大可见角的余弦值';
    case 'v_bus0'
        txt = '母线参考电压，V';
    case 'c_bus'
        txt = '母线等效电容，F';
    case 'v_uvlo_off'
        txt = '欠压下限，V';
    case 'v_uvlo_on'
        txt = '欠压上限，V';
    case 'n_solar'
        txt = '太阳板法向单位向量';
    case 'i_sc'
        txt = '太阳板短路电流，A';
    case 'area_pannel'
        txt = '太阳板面积，m^2';
    case 'i_f'
        txt = '反向饱和电流，A';
    case 'r_s'
        txt = '太阳板串联电阻，ohm';
    case 'r_p'
        txt = '太阳板并联电阻，ohm';
    case 'v_t'
        txt = '热电压，V';
    case 'n_diode'
        txt = '二极管理想因子';
    case 'vmp'
        txt = '太阳板工作电压，V';
    case 'num_s'
        txt = '串联电池单元个数';
    case 'num_p'
        txt = '并联电池单元个数';
    case 'v_oc'
        txt = '太阳板开路电压，V';
    case 'eta_mppt'
        txt = 'MPPT效率（0~1）';
    case 'eta_buck'
        txt = 'Buck变换器效率（0~1）';
    case 'd_0'
        txt = '初始占空比（0~1）';
    case 'delta_d'
        txt = '占空比步长（0~1）';
    case 'd_min'
        txt = '占空比最小值（0~1）';
    case 'd_max'
        txt = '占空比最大值（0~1）';
    case 'dp_th'
        txt = '功率变化阈值，W';
    case 'p_base'
        txt = '基础功耗，W';
    case 'p_adcs'
        txt = '姿态控制功耗，W';
    case 'p_prop'
        txt = '推进系统功耗，W';
    case 'p_comm'
        txt = '通信功耗，W';
    case 'e_max'
        txt = '电池最大能量，J';
    case 'e0'
        txt = '初始电能，J';
    case 'soc0'
        txt = '初始荷电状态（0~1）';
    case 'soc_low_comm'
        txt = '低荷电关通信阈值（0~1）';
    case 'soc_low_prop'
        txt = '低荷电关推进阈值（0~1）';
    case 'soc_low_adcs'
        txt = '低荷电关姿态控制阈值（0~1）';
    case 'beta'
        txt = '负载电阻性占比';
    case 'r_load'
        txt = '等效负载电阻，ohm';
    case 'p_trickle'
        txt = '涓流充电电流，A';
    case 'p_cc'
        txt = '恒流充电电流，A';
    case 'soc1'
        txt = '涓流与恒流分界线（0~1）';
    case 'soc2'
        txt = '恒流与恒压分界线（0~1）';
    case 'p_dis_lim'
        txt = '放电功率限流，W';
    case 'i_chg_max'
        txt = '充电电流限幅，A';
    case 'i_dis_max'
        txt = '放电电流限幅，A';
    case 'eta_chg'
        txt = '充电效率（0~1）';
    case 'eta_dis'
        txt = '放电效率（0~1）';
    case 'q'
        txt = '电池最大电量，Ah';
    case 'v_max'
        txt = '电池最大电压，V';
    case 'v_min'
        txt = '电池最小电压，V';
    case 'rb'
        txt = '电池内阻，ohm';
    %% 姿态确定与控制子系统参数
    case 'jx'
        txt = '转动惯量X轴，kg*m^2';
    case 'jy'
        txt = '转动惯量Y轴，kg*m^2';
    case 'jz'
        txt = '转动惯量Z轴，kg*m^2';
    case 'w0_x'
        txt = '初始角速度X分量，rad/s';
    case 'w0_y'
        txt = '初始角速度Y分量，rad/s';
    case 'w0_z'
        txt = '初始角速度Z分量，rad/s';
    case 'q0'
        txt = '初始四元数标量分量';
    case 'angle0'
        txt = '初始欧拉角，rad';
    case 'anglee'
        txt = '目标欧拉角，rad';
    case 'qe'
        txt = '目标四元数标量标量';
    case 'kp'
        txt = '姿态控制器比例系数';
    case 'kd'
        txt = '姿态控制器微分系数';
    case 'torque_limit'
        txt = '控制力矩限幅，N*m';
    case 'tau'
        txt = '反作用轮伺服时间常数，s';
    case 'kp_w'
        txt = '力矩电机控制器比例系数';
    case 'ki_w'
        txt = '力矩电机控制器积分系数';
    case 'i_w_min'
        txt = '反作用轮指令电流下限，A';
    case 'i_w_max'
        txt = '反作用轮指令电流上限，A';
    case 'cm'
        txt = '电磁转矩系数';
    case 'd_f'
        txt = '粘性摩擦力矩系数';
    case 'd_c'
        txt = '库仑摩擦力矩系数';
    case 't_max'
        txt = '反作用轮最大输出力矩，N*m';
    case 'iw'
        txt = '反作用轮转动惯量，kg*m^2';
    case 'eta'
        txt = '反作用轮机电效率（0~1）';
    case 'k_w'
        txt = '反作用轮安装阵';
    case 'a_w'
        txt = '反作用轮分配阵';
    case 'rpm_max'
        txt = '反作用轮最大转速，rpm';
    case 'h_max'
        txt = '单轴角动量上限，N*m*s';
    case 'sf_factor'
        txt = '反作用轮安全系数';
    case 'k_h'
        txt = '角动量卸载比例系数，1/s';
    case 'perimeter_m'
        txt = '激光陀螺谐振腔周长，m';
    case 'area_m2'
        txt = '激光陀螺谐振腔面积，m^2';
    case 'wavelength_m'
        txt = '激光波长，m';
    case 'v_pzt_min'
        txt = 'PZT最小工作电压，V';
    case 'v_pzt_max'
        txt = 'PZT最大工作电压，V';
    case 'sweep_frequency'
        txt = '扫模频率，Hz';
    case 'tau_th_s'
        txt = '陀螺热时常，s';
    case 'k_sf1_ppm'
        txt = '陀螺比例因子一阶项，ppm';
    case 'k_sf2_ppm'
        txt = '陀螺比例因子二阶项，ppm';
    case 'bias0_deg_h'
        txt = '陀螺初始零偏，deg/h';
    case 'k_bias1_deg_h_per_c'
        txt = '陀螺零偏温度系数一阶';
    case 'k_bias2_deg_h_per_c'
        txt = '陀螺零偏温度系数二阶';
    case 'f_n_hz'
        txt = '陀螺抖动自然频率，Hz';
    case 'zeta'
        txt = '陀螺抖动阻尼比';
    case 'v_peak_deg_s'
        txt = '陀螺抖动峰值，deg/s';
    case 'initial_phase'
        txt = '陀螺抖动初始相位，rad';
    case 'i_triggle'
        txt = '光强控制阈值';
    case 'i_gate'
        txt = '光强门槛';
    case 'i_e'
        txt = '期望光强';
    case 'kp'
        txt = '陀螺比例增益';
    case 'ki'
        txt = '陀螺积分增益';
    case 'v_center'
        txt = '陀螺中心电压，V';
    case 'k_a'
        txt = 'Lamb增益灵敏度';
    case 'alpha1'
        txt = '增益系数1';
    case 'alpha2'
        txt = '增益系数2';
    case 'beta1_lng'
        txt = '自饱和系数1';
    case 'beta2_lng'
        txt = '自饱和系数2';
    case 'theta12'
        txt = '交叉饱和系数12';
    case 'theta21'
        txt = '交叉饱和系数21';
    case 'sigma1'
        txt = '频率基准1';
    case 'sigma2'
        txt = '频率基准2';
    case 'tau12_lng'
        txt = '互聚焦系数12，s';
    case 'tau21_lng'
        txt = '互聚焦系数21，s';
    case 'r1'
        txt = '反向散射系数1';
    case 'r2'
        txt = '反向散射系数2';
    case 'epsilon'
        txt = '反向散射固有相移';
    case 'arw_deg_per_sqrt_h'
        txt = '陀螺角随机游走，deg/sqrt(h)';
    case 'white_rate_std_deg_s'
        txt = '陀螺白噪声标准差，deg/s';
    %% 姿态相关传感器参数
    case 'f_st'
        txt = '星敏更新率，Hz';
    case 'ts_st'
        txt = '星敏更新周期，s';
    case 'sigma_arcsec'
        txt = '星敏1sigma姿态噪声，角秒';
    case 't_delay_st'
        txt = '星敏数据延迟，s';
    case 'sigma_rad'
        txt = '星敏姿态噪声，rad';
    case 'p_drop'
        txt = '星敏掉帧概率（0~1）';
    case 'sigma_sun'
        txt = '太阳敏感器噪声，rad';
    case 'fov'
        txt = '太阳敏感器视场角，rad';
    case 'n_sun'
        txt = '太阳敏感器安装朝向轴';
    case 'sigma_earth'
        txt = '地心敏感器噪声，rad';
    case 't_a'
        txt = '姿态解算周期，s';
    case 'kp_f'
        txt = '姿态纠正强度，rad/s per rad';
    case 'ki_f'
        txt = '偏执估计速率，rad/s^2 per rad';
    case 'tcorr_limit'
        txt = '纠正力矩限幅，N*m';
    %% 通信子系统参数
    case 'f'
        txt = '载波频率，Hz';
    case 'c'
        txt = '光速，m/s';
    case 'pt_dbw'
        txt = '发射功率，dBW';
    case 'gt_db'
        txt = '星上天线增益，dB';
    case 'gr_db'
        txt = '地面站天线增益，dB';
    case 'noise_dbw'
        txt = '噪声功率，dBW';
    case 'p_in_driver_dbw'
        txt = '前级驱动功率，dBW';
    case 'g_sspa_db'
        txt = 'SSPA小信号增益，dB';
    case 'p_sspa_dbw'
        txt = 'SSPA最大输出功率，dBW';
    case 'eta_sspa'
        txt = 'SSPA效率（0~1）';
    case 'g_twta_db'
        txt = 'TWTA小信号增益，dB';
    case 'p_twta_dbw'
        txt = 'TWTA最大输出功率，dBW';
    case 'eta_twta'
        txt = 'TWTA效率（0~1）';
    %% 推进子系统参数
    case 't_nominal'
        txt = '化学推进标称推力，N';
    case 'isp'
        txt = '化学推进比冲，s';
    case 'g0'
        txt = '标准重力加速度，m/s^2';
    case 'm0'
        txt = '化推初始工质质量，kg';
    case 'tau_thr'
        txt = '推力响应时间常数，s';
    case 'r_ref'
        txt = '轨道半径维持目标，m';
    case 'd_thr'
        txt = '推力响应时间常数，s';
    case 't_ref'
        txt = '轨道半径维持目标，m';
    case 'eta_et'
        txt = '电推进效率（0~1）';
    case 'p_et_max'
        txt = '电推功耗，W';
    case 'm0_et'
        txt = '电推初始工质质量，kg';
    case 'tau_et'
        txt = '电推响应时间常数，s';
    case 'isp_et'
        txt = '电推进比冲，s';
    case 'l'
        txt = '推力作用点偏心距，m';
    case 'p_overhead'
        txt = '电推固定开销，W';
    %% 测控子系统参数
    case 'comm_allow'
        txt = '通信允许标志（0/1）';
    case 'cmd_on_step'
        txt = '发射机开机时刻，s';
    case 'cmd_off_step'
        txt = '发射机关机时刻，s';
    case 'r_data'
        txt = '数据生成速率，bps';
    case 'cmd_comm'
        txt = '通信允许，0/1';
    %% 仿真参数
    case 'dt'
        txt = '仿真步长，s';
    otherwise
        txt = '来自 init_params.m 的参数（请按需补充说明）';
end
end

function s = local_size_to_str(sz)
if isempty(sz)
    s = '0x0';
    return;
end
s = sprintf('%dx', sz);
s = s(1:end-1);
end

function expr = local_value_to_expr(v)
if isnumeric(v) || islogical(v)
    expr = mat2str(v);
elseif ischar(v)
    expr = ['''' strrep(v, '''', '''''') ''''];
elseif isstring(v) && isscalar(v)
    c = char(v);
    expr = ['''' strrep(c, '''', '''''') ''''];
else
    % 对对象/复杂类型给空表达式，用户可手工填写。
    expr = '';
end
end

function [paramsIn, initMap] = local_build_params_in_from_table(rows, rawMap)
if isempty(rows)
    paramsIn = struct();
    initMap = struct();
    return;
end

if nargin < 2 || isempty(rawMap)
    rawMap = struct();
end

initMap = struct();
for i = 1:size(rows, 1)
    name = strtrim(local_to_char(rows{i,1}));
    expr = strtrim(local_to_char(rows{i,2}));

    if isempty(name)
        continue;
    end

    if ~isvarname(name)
        error('第 %d 行初始化参数名非法：%s', i, name);
    end

    if isempty(expr)
        % 表格表达式留空时，优先回填从 init_params.m 捕获的原始值（支持 struct/cell/object）。
        if isfield(rawMap, name)
            val = rawMap.(name);
        else
            val = [];
        end
    else
        val = local_eval_expr(expr);
    end
    initMap.(name) = val;
end

% params_in 默认使用全部初始化变量。
paramsIn = initMap;
end

function faultCfg = local_build_fault_cfg_from_table(rows)
faultCfg = struct();

if isempty(rows)
    faultCfg.items = struct([]);
    return;
end

% 预先创建符合struct数组要求的模板项（所有字段都使用cell统一包装）
template = local_create_fault_item_template();

items = repmat(template, 0, 1);
for i = 1:size(rows, 1)
    enable = logical(local_eval_if_needed(rows{i,1}));
    if ~enable
        continue;
    end

    item = template;
    item.enable = true;
    item.id = local_to_char(rows{i,2});
    item.target_param = local_to_char(rows{i,3});
    item.fault_type = local_to_char(rows{i,4});
    item.severity = double(local_eval_if_needed(rows{i,5}));
    item.t_inject_s = double(local_eval_if_needed(rows{i,6}));
    item.t_recover_s = double(local_eval_if_needed(rows{i,7}));
    item.mode = local_to_char(rows{i,8});
    item.priority = double(local_eval_if_needed(rows{i,9}));
    item.input_base = local_to_char(rows{i,10});
    item.compose = local_to_char(rows{i,11});
    item.compose_alpha = double(local_eval_if_needed(rows{i,12}));

    targetIdxRaw = strtrim(local_to_char(rows{i,13}));
    if ~isempty(targetIdxRaw)
        item.target_index = local_eval_expr(targetIdxRaw);
    end

    valueAfterRaw = strtrim(local_to_char(rows{i,14}));
    if ~isempty(valueAfterRaw)
        item.value_after = local_eval_expr(valueAfterRaw);
    end

    minRaw = strtrim(local_to_char(rows{i,15}));
    if ~isempty(minRaw)
        item.min_value = local_eval_expr(minRaw);
    end

    maxRaw = strtrim(local_to_char(rows{i,16}));
    if ~isempty(maxRaw)
        item.max_value = local_eval_expr(maxRaw);
    end

    if isempty(item.id)
        item.id = sprintf('F_AUTO_%03d', i);
    end

    if isempty(item.target_param)
        error('第 %d 行故障项 target_param 为空。', i);
    end

    items(end+1,1) = item; %#ok<AGROW>
end

faultCfg.items = items;
end

function template = local_create_fault_item_template()
% 创建一个标准的故障项模板，所有字段都预初始化，确保数组元素字段一致。
template = struct();
template.enable = true;
template.id = '';
template.target_param = '';
template.fault_type = '';
template.severity = 0.0;
template.t_inject_s = 0.0;
template.t_recover_s = inf;
template.mode = '';
template.priority = 0.0;
template.input_base = '';
template.compose = '';
template.compose_alpha = 0.5;
template.target_index = [];
template.value_after = [];
template.min_value = [];
template.max_value = [];
end

function out = local_eval_if_needed(v)
if isnumeric(v) || islogical(v)
    out = v;
    return;
end
s = strtrim(local_to_char(v));
if isempty(s)
    out = [];
    return;
end
out = local_eval_expr(s);
end

function v = local_eval_expr(expr)
if isempty(expr)
    v = [];
    return;
end

% 优先按 MATLAB 表达式求值，支持 inf/pi/向量等。
try
    v = eval(expr);
catch
    % 求值失败时退化为字符串。
    v = expr;
end
end

function c = local_to_char(v)
if ischar(v)
    c = v;
elseif isstring(v)
    if isscalar(v)
        c = char(v);
    else
        c = char(join(v, ','));
    end
elseif isnumeric(v)
    c = num2str(v);
elseif islogical(v)
    c = char(string(v));
else
    c = '';
end
end

function rows = local_default_fault_rows()
rows = {
    true,  'F_ADCS_ST_01', 'p_drop',   'dropout',     0.6, 900,  1500, 'step', 0, 'nominal', 'replace', 0.5, '', '', '0', '1';
    true,  'F_ADCS_RW_01', 'T_max',    'degradation', 0.5, 1200, inf,  'step', 1, 'nominal', 'replace', 0.5, '', '', '0', '';
    false, 'F_EPS_01',     'eta_mppt', 'degradation', 0.3, 800,  inf,  'ramp', 0, 'nominal', 'replace', 0.5, '', '', '0', '1'
};
end
