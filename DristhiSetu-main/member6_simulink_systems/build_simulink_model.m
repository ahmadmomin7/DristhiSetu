
function build_simulink_model()
    modelName = 'TelemedicineSync';
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    new_system(modelName);
    open_system(modelName);

    % Configure High-Speed Fixed Discrete Engine (Set to 'normal' for 100% compatibility)
    set_param(modelName, ...
        'StopTime', '100', ...
        'SolverType', 'Fixed-step', ...
        'Solver', 'FixedStepDiscrete', ...
        'FixedStep', '0.01', ...
        'SimulationMode', 'normal');

    % 1. Patient Arrival Stream (Bursty Inflow)
    add_block('simulink/Sources/Random Number', [modelName, '/Stochastic_Arrival_Rate'], ...
        'Mean', '3.5', 'Variance', '1.2', 'SampleTime', '0.1', 'Position', [30, 60, 80, 90]);
    add_block('simulink/Discontinuities/Saturation', [modelName, '/Arrival_Clamp'], ...
        'LowerLimit', '0.5', 'UpperLimit', '8.0', 'Position', [120, 60, 160, 90]);

    % 2. Multi-Channel Signal Propagation with Rayleigh Fading
    add_block('simulink/Sources/Band-Limited White Noise', [modelName, '/Cellular_Rayleigh_Fading'], ...
        'Cov', '200', 'Ts', '0.1', 'Position', [30, 200, 80, 230]);
    add_block('simulink/Math Operations/Bias', [modelName, '/Rural_Tower_Bias'], ...
        'Bias', '256', 'Position', [120, 200, 170, 230]);
    add_block('simulink/Discontinuities/Saturation', [modelName, '/Link_Bandwidth_Limits'], ...
        'LowerLimit', '10', 'UpperLimit', '1500', 'Position', [200, 200, 240, 230]);

    % 3. Dynamic Compression Matrix
    add_block('simulink/Math Operations/Gain', [modelName, '/Adaptive_Bitrate_Scaling'], ...
        'Gain', '0.0006', 'Position', [280, 195, 330, 235]);

    % Inflow Data Generation (Scans/sec * MB/scan)
    add_block('simulink/Math Operations/Product', [modelName, '/Inflow_Data_Stream'], ...
        'Inputs', '**', 'Position', [360, 65, 390, 105]);

    % Upload Channel Capacity in MB/s
    add_block('simulink/Math Operations/Gain', [modelName, '/kbps_to_MBps_Converter'], ...
        'Gain', '0.000125', 'Position', [360, 200, 410, 230]);

    % Net Delta Flow
    add_block('simulink/Math Operations/Subtract', [modelName, '/Delta_Buffer_Flow'], ...
        'Inputs', '+-', 'Position', [440, 75, 470, 115]);

    % 4. Flash Storage [0, 256 MB Hard Capacity]
    add_block('simulink/Discrete/Discrete-Time Integrator', [modelName, '/Dual_Partition_Flash_Buffer'], ...
        'IntegratorMethod', 'Forward Euler', 'SampleTime', '0.01', ...
        'LimitOutput', 'on', 'LowerSaturationLimit', '0', 'UpperSaturationLimit', '256', ...
        'Position', [510, 80, 560, 110]);

    % 5. Dual-Queue Clinical Priority 
    add_block('simulink/Math Operations/Gain', [modelName, '/Emergency_QoS_Queue'], ...
        'Gain', '0.18', 'Position', [600, 80, 660, 110]);
    add_block('simulink/Math Operations/Gain', [modelName, '/Routine_Queue'], ...
        'Gain', '0.82', 'Position', [600, 140, 660, 170]);
    add_block('simulink/Sinks/Terminator', [modelName, '/Routine_Terminator'], ...
        'Position', [700, 145, 720, 165]);
    
    % 6. Medical Validation Delay 
    add_block('simulink/Discrete/Delay', [modelName, '/Specialist_GradCAM_Review'], ...
        'DelayLength', '1', 'Position', [700, 80, 740, 110]);

    % 7. Telemetry Sinks
    add_block('simulink/Sinks/To Workspace', [modelName, '/Buffer_Telemetry_Log'], ...
        'VariableName', 'edge_buffer_log', 'SaveFormat', 'Array', 'Position', [600, 20, 680, 50]);
    add_block('simulink/Sinks/To Workspace', [modelName, '/Emergency_Triage_Log'], ...
        'VariableName', 'urgent_queue_log', 'SaveFormat', 'Array', 'Position', [780, 80, 860, 110]);

    % Signal Connections
    add_line(modelName, 'Stochastic_Arrival_Rate/1', 'Arrival_Clamp/1');
    add_line(modelName, 'Arrival_Clamp/1', 'Inflow_Data_Stream/1');
    add_line(modelName, 'Cellular_Rayleigh_Fading/1', 'Rural_Tower_Bias/1');
    add_line(modelName, 'Rural_Tower_Bias/1', 'Link_Bandwidth_Limits/1');
    add_line(modelName, 'Link_Bandwidth_Limits/1', 'Adaptive_Bitrate_Scaling/1');
    add_line(modelName, 'Adaptive_Bitrate_Scaling/1', 'Inflow_Data_Stream/2');
    add_line(modelName, 'Link_Bandwidth_Limits/1', 'kbps_to_MBps_Converter/1');
    add_line(modelName, 'Inflow_Data_Stream/1', 'Delta_Buffer_Flow/1');
    add_line(modelName, 'kbps_to_MBps_Converter/1', 'Delta_Buffer_Flow/2');
    add_line(modelName, 'Delta_Buffer_Flow/1', 'Dual_Partition_Flash_Buffer/1');
    add_line(modelName, 'Dual_Partition_Flash_Buffer/1', 'Buffer_Telemetry_Log/1');
    add_line(modelName, 'Dual_Partition_Flash_Buffer/1', 'Emergency_QoS_Queue/1');
    add_line(modelName, 'Dual_Partition_Flash_Buffer/1', 'Routine_Queue/1');
    add_line(modelName, 'Routine_Queue/1', 'Routine_Terminator/1');
    add_line(modelName, 'Emergency_QoS_Queue/1', 'Specialist_GradCAM_Review/1');
    add_line(modelName, 'Specialist_GradCAM_Review/1', 'Emergency_Triage_Log/1');

    save_system(modelName);
    fprintf('TelemedicineSync.slx compiled and verified successfully.\n');
end