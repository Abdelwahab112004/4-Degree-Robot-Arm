function RoboRash_Professional_Ultimate_V4()
% ========================================================================
% RoboRash Professional - Ultimate Edition V4
% Features: Speed/Smoothness Control, LSPB, IK Display, Arduino Feedback
% ========================================================================
clc; clear; close all;
if ~exist('SerialLink', 'class')
    errordlg('Peter Corke Robotics Toolbox is not installed!', 'Error');
    return;
end
[Robot, params] = createRobotModel();
launchGUI(Robot, params);
end

function [Robot, params] = createRobotModel()
deg = @(x) x*pi/180;
params.jointDir = [1, 1, -1, 1, 1]; 
params.servo.minAngle = -90;  
params.servo.maxAngle = 90;   
params.servo.minPWM = 150;    
params.servo.maxPWM = 600;
L(1) = Link('d', 158.93, 'a', 0, 'alpha', deg(-90), 'qlim', deg([-90 90]));
L(2) = Link('d', 0, 'a', 130, 'alpha', 0, 'offset', deg(-90), 'qlim', deg([-90 90]));
L(3) = Link('d', 0, 'a', 122.45, 'alpha', deg(90), 'qlim', deg([-90 90]));
L(4) = Link('d', 32.77, 'a', 0, 'alpha', deg(-90), 'qlim', deg([-90 90]));
L(5) = Link('d', 0, 'a', 127.86, 'alpha', 0, 'qlim', deg([-90 90]));
Robot = SerialLink(L, 'name', 'RoboRash');
params.qlim = Robot.qlim;
end

function launchGUI(Robot, params)
gui = struct();
gui.q = zeros(1, 5); 
gui.gripperVal = 0; 
gui.trace = zeros(0, 3);
gui.isMoving = false;
gui.connected = false;
gui.arduino = [];
gui.analysisData = struct('t',[], 'q',[], 'qd',[], 'qdd',[]);

fig = figure('Name', 'RoboRash Pro V4 - Control Center', ...
             'Color', [0.94 0.94 0.96], 'Position', [50 50 1600 900]);

leftPanel = uipanel(fig, 'Position', [0.01 0.01 0.35 0.98], 'Title', 'Control Center', 'FontWeight', 'bold');
tabGroup = uitabgroup(leftPanel);
tabs = {uitab(tabGroup, 'Title', 'Manual'), ...
        uitab(tabGroup, 'Title', 'IK Control'), ...
        uitab(tabGroup, 'Title', 'Path Plan'), ...
        uitab(tabGroup, 'Title', 'Analysis'), ...
        uitab(tabGroup, 'Title', 'Arduino')};

% --- TAB 1: Manual (Updated with Speed Control) ---
gui.sliders = gobjects(6, 1); gui.valueText = gobjects(6, 1);
for i = 1:5
    y = 0.88 - (i-1)*0.10; % Adjusted spacing
    uicontrol(tabs{1}, 'Style', 'text', 'String', ['Joint ' num2str(i)], 'Units', 'normalized', 'Position', [0.05 y+0.05 0.2 0.03], 'FontWeight', 'bold');
    gui.sliders(i) = uicontrol(tabs{1}, 'Style', 'slider', 'Min', -90, 'Max', 90, 'Value', 0, 'Units', 'normalized', 'Position', [0.05 y 0.6 0.05], 'Callback', @(~,~)manualMove(i));
    gui.valueText(i) = uicontrol(tabs{1}, 'Style', 'text', 'String', '0.0°', 'Units', 'normalized', 'Position', [0.67 y+0.01 0.2 0.04], 'BackgroundColor', 'w');
end

% Gripper
y_grip = 0.35;
uicontrol(tabs{1}, 'Style', 'text', 'String', 'GRIPPER', 'Units', 'normalized', 'Position', [0.05 y_grip+0.05 0.2 0.03], 'FontWeight', 'bold', 'ForegroundColor', 'b');
gui.sliders(6) = uicontrol(tabs{1}, 'Style', 'slider', 'Min', 0, 'Max', 90, 'Value', 0, 'Units', 'normalized', 'Position', [0.05 y_grip 0.6 0.05], 'Callback', @(~,~)gripperMove());
gui.valueText(6) = uicontrol(tabs{1}, 'Style', 'text', 'String', '0.0°', 'Units', 'normalized', 'Position', [0.67 y_grip+0.01 0.2 0.04], 'BackgroundColor', 'w', 'ForegroundColor', 'b');

% --- NEW: Speed/Smoothness Slider ---
uicontrol(tabs{1}, 'Style', 'text', 'String', '⚡ MOTION SMOOTHNESS / SPEED', 'Units', 'normalized', 'Position', [0.05 0.25 0.9 0.03], 'FontWeight', 'bold', 'ForegroundColor', [0.8 0.4 0]);
uicontrol(tabs{1}, 'Style', 'text', 'String', '(Low = Fast/Rough | High = Slow/Smooth)', 'Units', 'normalized', 'Position', [0.05 0.22 0.9 0.02], 'FontSize', 8);
% Range: 20 steps (Fast) to 200 steps (Very Smooth)
gui.speedSlider = uicontrol(tabs{1}, 'Style', 'slider', 'Min', 20, 'Max', 200, 'Value', 50, 'Units', 'normalized', 'Position', [0.05 0.18 0.9 0.04]);

uicontrol(tabs{1}, 'Style', 'pushbutton', 'String', '🏠 HOME', 'Units', 'normalized', 'Position', [0.1 0.05 0.8 0.06], 'Callback', @(~,~)resetHome());

% --- TAB 2: IK Control ---
labels = {'X:', 'Y:', 'Z:'}; defaults = [250, 0, 300]; gui.ikEdit = gobjects(3, 1);
for i = 1:3
    uicontrol(tabs{2}, 'Style', 'text', 'String', labels{i}, 'Units', 'normalized', 'Position', [0.1 0.85-i*0.08 0.2 0.05], 'FontSize', 10);
    gui.ikEdit(i) = uicontrol(tabs{2}, 'Style', 'edit', 'String', num2str(defaults(i)), 'Units', 'normalized', 'Position', [0.35 0.85-i*0.08 0.4 0.06]);
end
uicontrol(tabs{2}, 'Style', 'pushbutton', 'String', 'MOVE TO TARGET', 'Units', 'normalized', 'Position', [0.1 0.55 0.8 0.08], 'Callback', @execIK, 'FontWeight', 'bold');

uicontrol(tabs{2}, 'Style', 'text', 'String', 'Inverse Kinematics Solution (Degrees):', 'Units', 'normalized', 'Position', [0.05 0.45 0.9 0.05], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
gui.ikResultText = uicontrol(tabs{2}, 'Style', 'listbox', 'String', {'Waiting for command...'}, 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.35], 'FontSize', 10, 'BackgroundColor', [0.9 1 0.9]);

% --- TAB 3: Path Plan ---
uicontrol(tabs{3}, 'Style', 'text', 'String', 'Shape:', 'Units', 'normalized', 'Position', [0.05 0.92 0.2 0.03]);
gui.motionPop = uicontrol(tabs{3}, 'Style', 'popupmenu', 'String', {'Line (LSPB)', 'Circle (LSPB)', 'Square (LSPB)', 'Helix (LSPB)'}, 'Units', 'normalized', 'Position', [0.3 0.92 0.6 0.04]);

lbls = {'Center X', 'Center Y', 'Center Z', 'Size/Rad', 'Height (Helix)', 'Time (s)', 'Points'};
defs = {'90', '0', '300', '50', '50', '5', '50'};
gui.pathParams = gobjects(7,1);
for k=1:7
    y_pos = 0.85 - (k-1)*0.09;
    uicontrol(tabs{3}, 'Style', 'text', 'String', lbls{k}, 'Units', 'normalized', 'Position', [0.05 y_pos 0.35 0.04], 'HorizontalAlignment','left');
    gui.pathParams(k) = uicontrol(tabs{3}, 'Style', 'edit', 'String', defs{k}, 'Units', 'normalized', 'Position', [0.45 y_pos 0.45 0.05]);
end

uicontrol(tabs{3}, 'Style', 'pushbutton', 'String', '▶ EXECUTE PATH', 'Units', 'normalized', 'Position', [0.1 0.15 0.8 0.08], 'BackgroundColor', [0.1 0.5 0.2], 'ForegroundColor', 'w', 'Callback', @runPrecisionMotion);
uicontrol(tabs{3}, 'Style', 'pushbutton', 'String', 'Clear Trace', 'Units', 'normalized', 'Position', [0.1 0.05 0.8 0.06], 'Callback', @clearTrace);

% --- TAB 4: Analysis ---
uicontrol(tabs{4}, 'Style', 'pushbutton', 'String', '🌐 GENERATE TRUE WORKSPACE', ...
    'Units', 'normalized', 'Position', [0.1 0.88 0.8 0.08], ...
    'BackgroundColor', [0.4 0.2 0.6], 'ForegroundColor', 'w', 'FontWeight', 'bold', ...
    'Callback', @(~,~)generateTrueWorkspace(Robot));
gui.axPos = axes(tabs{4}, 'Units', 'normalized', 'Position', [0.15 0.62 0.75 0.20]); title('Position');
gui.axVel = axes(tabs{4}, 'Units', 'normalized', 'Position', [0.15 0.34 0.75 0.20]); title('Velocity');
gui.axAcc = axes(tabs{4}, 'Units', 'normalized', 'Position', [0.15 0.06 0.75 0.20]); title('Acceleration');

% --- TAB 5: Arduino ---
gui.portEdit = uicontrol(tabs{5}, 'Style', 'edit', 'String', 'COM3', 'Units', 'normalized', 'Position', [0.35 0.8 0.3 0.05]);
gui.connBtn = uicontrol(tabs{5}, 'Style', 'pushbutton', 'String', 'CONNECT', 'Units', 'normalized', 'Position', [0.1 0.65 0.8 0.1], 'Callback', @toggleArduino);
gui.arduinoStatus = uicontrol(tabs{5}, 'Style', 'text', 'String', 'OFFLINE', 'Units', 'normalized', 'Position', [0.1 0.55 0.8 0.05], 'ForegroundColor', 'r', 'FontWeight', 'bold');

% --- Main Plot ---
gui.ax = axes(fig, 'Position', [0.4 0.35 0.55 0.6]);
Robot.plot(gui.q, 'workspace', [-500 500 -500 500 0 600], 'noarrow', 'notiles');
hold on; grid on; axis equal; view(135, 30);
gui.tracePlot = plot3(0, 0, 0, 'r', 'LineWidth', 2.5);

% --- Info Panel ---
infoPanel = uipanel(fig, 'Position', [0.4 0.01 0.55 0.3], 'Title', 'Robot Feedback');
gui.fkDisp = uicontrol(infoPanel, 'Style', 'text', 'String', 'X: 0 | Y: 0 | Z: 0', 'Units', 'normalized', 'Position', [0.05 0.6 0.9 0.3], 'FontSize', 16, 'FontWeight', 'bold');
uicontrol(infoPanel, 'Style', 'text', 'String', 'Sent to Arduino (Degrees):', 'Units', 'normalized', 'Position', [0.05 0.35 0.4 0.15], 'HorizontalAlignment', 'left', 'ForegroundColor', 'b');
gui.arduinoDisp = uicontrol(infoPanel, 'Style', 'text', 'String', '[ J1: 0 | J2: 0 | J3: 0 | J4: 0 | J5: 0 | G: 0 ]', 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.2], 'FontSize', 12, 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', 'g', 'FontWeight', 'bold');

updateAllDisplays();

% --- CALLBACKS ---
    function manualMove(jn)
        gui.q(jn) = deg2rad(get(gui.sliders(jn), 'Value'));
        Robot.animate(gui.q); updateAllDisplays();
        if gui.connected, sendToArduino(gui.q); end
    end

    function gripperMove()
        gui.gripperVal = get(gui.sliders(6), 'Value');
        updateAllDisplays();
        if gui.connected, sendToArduino(gui.q); end
    end

    function resetHome()
        gui.gripperVal = 0; set(gui.sliders(6), 'Value', 0);
        moveSmooth(zeros(1,5));
    end

    function execIK(~, ~)
        tgt = [str2double(get(gui.ikEdit(1), 'String')), str2double(get(gui.ikEdit(2), 'String')), str2double(get(gui.ikEdit(3), 'String'))];
        T = transl(tgt);
        q_sol = Robot.ikine(T, 'q0', gui.q, 'mask', [1 1 1 0 0 0], 'tol', 1e-6);
        if ~isempty(q_sol)
            moveSmooth(q_sol);
            degSol = rad2deg(q_sol);
            resStr = {sprintf('Target: [%.1f, %.1f, %.1f]', tgt); '-----------------------------';
                      sprintf('J1: %.2f°', degSol(1)); sprintf('J2: %.2f°', degSol(2));
                      sprintf('J3: %.2f°', degSol(3)); sprintf('J4: %.2f°', degSol(4));
                      sprintf('J5: %.2f°', degSol(5))};
            set(gui.ikResultText, 'String', resStr);
        else
            errordlg('Target Unreachable');
        end
    end

    function runPrecisionMotion(~, ~)
        if gui.isMoving, return; end
        gui.isMoving = true;
        try
            CX = str2double(get(gui.pathParams(1), 'String'));
            CY = str2double(get(gui.pathParams(2), 'String'));
            CZ = str2double(get(gui.pathParams(3), 'String'));
            Dim = str2double(get(gui.pathParams(4), 'String'));
            H_Helix = str2double(get(gui.pathParams(5), 'String'));
            T_dur = str2double(get(gui.pathParams(6), 'String'));
            N = str2double(get(gui.pathParams(7), 'String'));

            [pts, t_vec] = generatePrecisionPath(gui.motionPop.Value, N, T_dur, [CX, CY, CZ], Dim, H_Helix);
            q_traj = zeros(N, 5); lastQ = gui.q;
            h = waitbar(0, 'Computing Path IK...');
            for i = 1:N
                T = transl(pts(i,:));
                sol = Robot.ikine(T, 'q0', lastQ, 'mask', [1 1 1 0 0 0], 'tol', 1e-7);
                if isempty(sol), close(h); error('Step %d unreachable', i); end
                q_traj(i,:) = sol; lastQ = sol; waitbar(i/N, h);
            end
            close(h);
            
            % Execute
            moveSmooth(q_traj(1,:)); pause(0.5); 
            dt = T_dur/N; 
            
            % Update Analysis
            qd_traj = gradient(q_traj', dt)'; qdd_traj = gradient(qd_traj', dt)';
            gui.analysisData.t = t_vec; gui.analysisData.q = q_traj;
            gui.analysisData.qd = qd_traj; gui.analysisData.qdd = qdd_traj;
            updateAnalysisPlots();

            gui.trace = [];
            for i = 1:N
                gui.q = q_traj(i,:); Robot.animate(gui.q);
                T_curr = Robot.fkine(gui.q); gui.trace = [gui.trace; T_curr.t'];
                set(gui.tracePlot, 'XData', gui.trace(:,1), 'YData', gui.trace(:,2), 'ZData', gui.trace(:,3));
                updateAllDisplays(); 
                if gui.connected, sendToArduino(gui.q); end
                pause(dt);
            end
        catch ME, errordlg(ME.message); end
        gui.isMoving = false;
    end

    function [pts, t] = generatePrecisionPath(type, N, T, C, D, H)
        s = lspb(0, 1, N); t = linspace(0, T, N)';
        CX = C(1); CY = C(2); CZ = C(3);
        switch type
            case 1, pts = [linspace(CX, CX+D, N)', repmat(CY, N, 1), repmat(CZ, N, 1)];
            case 2, theta = s * 2 * pi; pts = [CX + D*cos(theta), CY + D*sin(theta), repmat(CZ, N, 1)];
            case 3, side = D; half = side/2;
                corn = [CX-half, CY-half; CX+half, CY-half; CX+half, CY+half; CX-half, CY+half; CX-half, CY-half];
                pts = []; steps = floor(N/4);
                for i = 1:4, pts = [pts; [linspace(corn(i,1), corn(i+1,1), steps)', linspace(corn(i,2), corn(i+1,2), steps)', repmat(CZ, steps, 1)]]; end
                while size(pts,1) < N, pts = [pts; pts(end,:)]; end; pts = pts(1:N, :);
            case 4, theta = s * 6 * pi; pts = [CX + D*cos(theta), CY + D*sin(theta), linspace(CZ, CZ+H, N)'];
        end
    end

    function generateTrueWorkspace(RobotArm)
        numPoints = 50000; qlim = RobotArm.qlim;
        p = sobolset(5,'Skip',100); U = net(p, numPoints);
        Q = zeros(numPoints,5); for k = 1:5, Q(:,k) = qlim(k,1) + U(:,k)*(qlim(k,2)-qlim(k,1)); end
        maxReach = 572.01; minReach = 60; base_radius = 120; base_height = 85.5; tol = 0.1;
        workspace = zeros(numPoints,3); colors = zeros(numPoints,1); validCount = 0;
        hw = waitbar(0, 'Extracting true workspace...');
        for j = 1:numPoints
            T = RobotArm.fkine(Q(j,:)); pos = T.t'; dist3D = norm(pos); xyDist = norm(pos(1:2));
            if (pos(3) >= 0) && (dist3D <= maxReach) && ((pos(3) > base_height + tol) || (xyDist > base_radius + tol))
                validCount = validCount + 1; workspace(validCount,:) = pos;
                ratio = (dist3D - minReach)/(maxReach - minReach);
                if ratio < 0.33, colors(validCount) = 1; elseif ratio < 0.66, colors(validCount) = 2; else, colors(validCount) = 3; end
            end
            if mod(j,5000)==0, waitbar(j/numPoints, hw); end
        end
        close(hw);
        figure('Name', 'True Workspace Extraction', 'Color', 'w'); hold on;
        scatter3(workspace(colors==1,1), workspace(colors==1,2), workspace(colors==1,3), 8, 'g', 'filled');
        scatter3(workspace(colors==2,1), workspace(colors==2,2), workspace(colors==2,3), 8, 'b', 'filled');
        scatter3(workspace(colors==3,1), workspace(colors==3,2), workspace(colors==3,3), 8, 'r', 'filled');
        xlabel('X'); ylabel('Y'); zlabel('Z'); axis equal; grid on; view(135,35);
    end

% --- UTILS ---
    function updateAllDisplays()
        degVals = rad2deg(gui.q) .* params.jointDir;
        arduinoStr = sprintf('[ J1: %.0f | J2: %.0f | J3: %.0f | J4: %.0f | J5: %.0f | G: %.0f ]', degVals(1), degVals(2), degVals(3), degVals(4), degVals(5), gui.gripperVal);
        set(gui.arduinoDisp, 'String', arduinoStr);
        for k=1:5, set(gui.sliders(k), 'Value', rad2deg(gui.q(k))); set(gui.valueText(k), 'String', sprintf('%.1f°', rad2deg(gui.q(k)))); end
        set(gui.valueText(6), 'String', sprintf('%.1f°', gui.gripperVal));
        T = Robot.fkine(gui.q); set(gui.fkDisp, 'String', sprintf('X: %.1f | Y: %.1f | Z: %.1f', T.t(1), T.t(2), T.t(3)));
        drawnow;
    end

    function updateAnalysisPlots()
        d = gui.analysisData; colors = {'r','g','b','m','k'};
        axes(gui.axPos); cla; hold on; for i=1:5, plot(d.t, d.q(:,i), 'Color', colors{i}); end; grid on; title('Pos');
        axes(gui.axVel); cla; hold on; for i=1:5, plot(d.t, d.qd(:,i), 'Color', colors{i}); end; grid on; title('Vel');
        axes(gui.axAcc); cla; hold on; for i=1:5, plot(d.t, d.qdd(:,i), 'Color', colors{i}); end; grid on; title('Acc');
    end

    function toggleArduino(~, ~)
        try, if ~gui.connected, port = get(gui.portEdit, 'String'); gui.arduino = serial(port, 'BaudRate', 115200); fopen(gui.arduino); gui.connected = true; set(gui.connBtn, 'String', 'DISCONNECT'); set(gui.arduinoStatus, 'String', 'CONNECTED', 'ForegroundColor', [0 0.5 0]); else, fclose(gui.arduino); delete(gui.arduino); gui.connected = false; set(gui.connBtn, 'String', 'CONNECT'); set(gui.arduinoStatus, 'String', 'OFFLINE', 'ForegroundColor', 'r'); end; catch, errordlg('Connection Failed'); end
    end

    function sendToArduino(qVal)
        degVals = rad2deg(qVal) .* params.jointDir;
        cmd = sprintf('<%.2f,%.2f,%.2f,%.2f,%.2f,%.2f>\n', degVals, gui.gripperVal);
        if gui.connected, fprintf(gui.arduino, cmd); end
    end

    function moveSmooth(qt)
        % --- NEW: DYNAMIC SPEED/SMOOTHNESS CONTROL ---
        % Read the slider value for steps count
        % Higher value = More steps = Slower Speed & Smoother Motion
        steps = round(get(gui.speedSlider, 'Value')); 
        
        traj = jtraj(gui.q, qt, steps);
        for i=1:steps
            gui.q = traj(i,:); Robot.animate(gui.q); updateAllDisplays();
            if gui.connected, sendToArduino(gui.q); end; 
            pause(0.015); % Consistent timing, steps determine duration
        end
    end

    function clearTrace(~, ~), gui.trace = []; set(gui.tracePlot, 'XData', [], 'YData', [], 'ZData', []); end
    function closeGUI(~, ~), if gui.connected, fclose(gui.arduino); end; delete(fig); end
end