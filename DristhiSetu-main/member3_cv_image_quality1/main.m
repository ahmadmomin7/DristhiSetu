clc;
clear;
close all;

% Suppress Windows UI DPI warning
warning('off', 'MATLAB:ui:figure:Scrollable');

% =========================================================================
% 1. CONFIGURATION PARAMETERS
% =========================================================================
SHARPNESS_TH  = 22.0;       % Minimum acceptable sharpness score
CONTRAST_TH   = 0.35;       % Minimum contrast range score
DL_INPUT_SIZE = [224 224];   % Deep Learning Model Input Resolution

% =========================================================================
% 2. SELECT IMAGE VIA FILE DIALOG
% =========================================================================
[filename, pathname] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.bmp', 'All Retinal Images (*.jpg, *.png, *.tif)'}, ...
    'Select Retinal Fundus Image');
if isequal(filename, 0)
    error('No image selected. Processing canceled by user.');
end
ImagePath = fullfile(pathname, filename);
fprintf('Selected Image Path: %s\n', ImagePath);

% =========================================================================
% 3. READ & RESIZE IMAGE
% =========================================================================
Test_Image = imread(ImagePath);
Resized_Image = imresize(Test_Image, [584 565]);

fprintf('\n================== QUALITY GATE CHECK ==================\n');
Ready_Image = [];
Enhanced_Result = [];
sharp_2 = 0;
cont_2 = 0;

% =========================================================================
% 4. STAGE 1: FIRST QUALITY CHECK
% =========================================================================
[pass_1, sharp_1, cont_1] = Access_Quality_Local(Resized_Image, SHARPNESS_TH, CONTRAST_TH);
fprintf('Stage 1 -> Sharpness: %.2f (Min: %.1f) | Contrast: %.2f (Min: %.2f)\n', ...
    sharp_1, SHARPNESS_TH, cont_1, CONTRAST_TH);

if pass_1
    fprintf('[GATE 1] Status: PASSED. Passing Image Directly to Model...\n');
    Ready_Image = Resized_Image;
    final_status = "PASSED_DIRECT";
else
    fprintf('[GATE 1] Status: FAILED. Initiating Morphological & Dynamic Enhancement...\n');
    
    % 5. ENHANCE IMAGE
    Enhanced_Result = Enhanced_Image(Resized_Image);
    
    % 6. STAGE 2: SECOND QUALITY CHECK POST-ENHANCEMENT
    [pass_2, sharp_2, cont_2] = Access_Quality_Local(Enhanced_Result, SHARPNESS_TH, CONTRAST_TH);
    fprintf('Stage 2 -> Sharpness: %.2f | Contrast: %.2f\n', sharp_2, cont_2);
    
    if pass_2
        fprintf('[GATE 2] Status: PASSED (Post-Enhancement). Forwarding to Model...\n');
        Ready_Image = Enhanced_Result;
        final_status = "PASSED_ENHANCED";
    else
        fprintf('[GATE 2] Status: REJECTED! Image quality remains low post-enhancement.\n');
        fprintf('ACTION: Requesting image recapture from medical operator.\n');
        final_status = "REJECTED";
    end
end

% =========================================================================
% 7. DEEP LEARNING MODEL DISPATCH & FEATURE SEGMENTATION
% =========================================================================
if strcmp(final_status, "PASSED_DIRECT") || strcmp(final_status, "PASSED_ENHANCED")
    
    % --- MODULE A: PREPARE DEEP LEARNING INPUT TENSORS ---
    DL_Input_Image = imresize(Ready_Image, DL_INPUT_SIZE);
    DL_Tensor = single(DL_Input_Image) / 255.0;
    DL_Tensor = reshape(DL_Tensor, [DL_INPUT_SIZE(1), DL_INPUT_SIZE(2), 3, 1]);
    
    fprintf('\n---------------------------------------------------------\n');
    fprintf('DL Tensor Built Successfully | Shape: [%d x %d x %d x %d]\n', size(DL_Tensor));
    fprintf('---------------------------------------------------------\n');
    
    % --- MODULE B: FIELD OF VIEW & PREPROCESSING ---
    Converted_Image = im2double(Ready_Image);
    [H, W, ~] = size(Converted_Image);
    
    FOV_Mask = (Converted_Image(:,:,1) + Converted_Image(:,:,2)) > 0.05;
    FOV_Mask = imerode(FOV_Mask, strel('disk', 8));
    
    Green_Channel = Converted_Image(:,:,2);
    Red_Channel   = Converted_Image(:,:,1);
    
    % Edge-preserving bilateral filter flattens JPEG grain while keeping vessels sharp
    Green_Clean   = imbilatfilt(Green_Channel, 0.015, 2.0);
    Green_Norm    = adapthisteq(Green_Clean, 'NumTiles', [8 8], 'ClipLimit', 0.010);
    Green_Norm(~FOV_Mask) = 0;
    
    % --- MODULE C: OPTIC DISC (OD) LOCALIZATION WITH FALLBACK ---
    [centers, radii] = imfindcircles(im2uint8(Green_Norm), [25 75], 'ObjectPolarity', 'bright', 'Sensitivity', 0.94);
    OD_Mask = false(H, W);
    
    if ~isempty(centers)
        od_c = round(centers(1,:));
        od_r = radii(1);
    else
        Smooth_Bright = imfilter(Red_Channel + Green_Channel, fspecial('gaussian', [35 35], 10));
        Smooth_Bright(~FOV_Mask) = 0;
        [~, max_idx] = max(Smooth_Bright(:));
        [my, mx] = ind2sub([H, W], max_idx);
        od_c = [mx, my];
        od_r = 45;
    end
    [X, Y] = meshgrid(1:W, 1:H);
    OD_Mask = (X - od_c(1)).^2 + (Y - od_c(2)).^2 <= (od_r + 22).^2;
    
    % --- MODULE D: FOVEA / MACULA LOCALIZATION ---
    Fovea_Mask = false(H, W);
    if od_c(1) < W/2
        fovea_x = min(W - 25, round(od_c(1) + 2.5 * od_r * 2));
    else
        fovea_x = max(25, round(od_c(1) - 2.5 * od_r * 2));
    end
    fovea_y = round(od_c(2));
    [X, Y] = meshgrid(1:W, 1:H);
    Fovea_Mask = (X - fovea_x).^2 + (Y - fovea_y).^2 <= (od_r * 0.85).^2;
    
    % --- MODULE E: BLOOD VESSEL EXTRACTION ---
    Avg_Filter = fspecial('average', [11 11]);
    Subtracted_Vessels = imsubtract(imfilter(Green_Norm, Avg_Filter), Green_Norm);
    Subtracted_Vessels(~FOV_Mask) = 0;
    
    level = threshold_Level(Subtracted_Vessels);
    thr_v = max(0.012, level * 0.98);
    Binary_Vessels = imbinarize(Subtracted_Vessels, thr_v) & FOV_Mask;
    Clean_Vessels_No_OD = bwareaopen(Binary_Vessels, 35) & (~OD_Mask);
    
    % --- MODULE F: STRICT MULTI-SPECTRAL HARD EXUDATES DETECTION ---
    % 1. Exudates are distinct, saturated YELLOW (High Green & High Red, Low Blue)
    Blue_Channel = Converted_Image(:,:,3);
    Yellow_Index = (Green_Channel .* Red_Channel) ./ (Blue_Channel + 0.15);
    
    % 2. Morphological Top-Hat on the Yellow Index map
    TopHat_Yellow = imtophat(Yellow_Index, strel('disk', 8));
    
    % 3. Relative threshold against background luminance
    p85_green = prctile(Green_Channel(FOV_Mask), 85);
    Exudates_Raw = (TopHat_Yellow > 0.25) & ...                 % Prominent yellow peak
                   (Green_Channel > p85_green) & ...            % Must be in top 15% brightest retinal structures
                   (Red_Channel > 0.70) & ...
                   FOV_Mask & (~OD_Mask) & (~Clean_Vessels_No_OD);
               
    Exudates_Mask = bwareaopen(Exudates_Raw, 15);               % Eliminate isolated single-pixel compression grain
    
    % --- MODULE G: MICROANEURYSMS & HEMORRHAGES SEPARATION ---
    BottomHat_Dark = imbothat(Green_Norm, strel('disk', 4));
    Local_Mean = imfilter(Green_Norm, fspecial('average', [25 25]));
    
    % Dark lesion candidates must be noticeably darker than their immediate local surroundings
    Dark_Candidates = (BottomHat_Dark > 0.11) & ...
                      ((Local_Mean - Green_Norm) > 0.07) & ...
                      FOV_Mask & (~Clean_Vessels_No_OD) & (~OD_Mask);
    
    % 1. Microaneurysms: Tiny, isolated round dots (4 to 30 px, high circularity)
    MA_Raw = bwareaopen(Dark_Candidates, 4) & ~bwareaopen(Dark_Candidates, 30);
    ma_props = regionprops(MA_Raw, 'Eccentricity', 'PixelIdxList');
    Microaneurysms_Mask = false(H, W);
    for k = 1:length(ma_props)
        if ma_props(k).Eccentricity < 0.82
            Microaneurysms_Mask(ma_props(k).PixelIdxList) = true;
        end
    end
    
    % 2. Hemorrhages: Medium to large blood pooling (31 to 500 px, solid blob)
    Hem_Raw = bwareaopen(Dark_Candidates, 31) & ~bwareaopen(Dark_Candidates, 500);
    hem_props = regionprops(Hem_Raw, 'Solidity', 'Area', 'PixelIdxList');
    Hemorrhages_Mask = false(H, W);
    for k = 1:length(hem_props)
        if hem_props(k).Solidity > 0.55 && hem_props(k).Area >= 31
            Hemorrhages_Mask(hem_props(k).PixelIdxList) = true;
        end
    end
    
    % --- MODULE H: NEOVASCULARIZATION DETECTION (NVD) ---
    OD_Margin = imdilate(OD_Mask, strel('disk', 18)) & (~OD_Mask);
    NVD_Pixels = sum(Clean_Vessels_No_OD(OD_Margin));
    is_neovascular = NVD_Pixels > 130;
    
    % --- MODULE I: QUANTITATIVE CLINICAL METRICS ---
    num_exudates = bwconncomp(Exudates_Mask).NumObjects;
    num_ma       = bwconncomp(Microaneurysms_Mask).NumObjects;
    num_hem      = bwconncomp(Hemorrhages_Mask).NumObjects;
    fovea_threat = any(Exudates_Mask(Fovea_Mask));
    
    fprintf('\n================ BIOMARKER DETECTION SUMMARY ================\n');
    fprintf('• Hard Exudates Count       : %d\n', num_exudates);
    fprintf('• Microaneurysms Count      : %d\n', num_ma);
    fprintf('• Hemorrhages Count         : %d\n', num_hem);
    fprintf('• Macular/Foveal Involvement: %s\n', string(fovea_threat));
    fprintf('• Neovascular Risk (PDR)    : %s\n', string(is_neovascular));
    fprintf('============================================================\n');
    
    % --- MODULE J: MULTI-BIOMARKER COLOR OVERLAY ---
    Final_Result = Colorize_Image(Ready_Image, Clean_Vessels_No_OD, [0 220 255]);  % Cyan: Vessels
    Final_Result = Colorize_Image(Final_Result, Exudates_Mask, [255 230 0]);         % Yellow: Exudates
    Final_Result = Colorize_Image(Final_Result, Microaneurysms_Mask, [255 40 40]);   % Red: Microaneurysms
    Final_Result = Colorize_Image(Final_Result, Hemorrhages_Mask, [230 0 120]);      % Magenta: Hemorrhages
    Final_Result = Colorize_Image(Final_Result, bwperim(Fovea_Mask), [60 120 255]); % Blue Ring: Fovea
    
    % --- MODULE K: EXPORT DATA PAYLOAD FOR TEAMMATE'S MODEL ---
    CV_Biomarkers = struct();
    CV_Biomarkers.exudates_count = num_exudates;
    CV_Biomarkers.microaneurysms_count = num_ma;
    CV_Biomarkers.hemorrhages_count = num_hem;
    CV_Biomarkers.foveal_threat = fovea_threat;
    CV_Biomarkers.neovascular_risk = is_neovascular;
    
    save('cv_model_handoff.mat', 'DL_Tensor', 'CV_Biomarkers', 'Clean_Vessels_No_OD', ...
         'Exudates_Mask', 'Microaneurysms_Mask', 'Hemorrhages_Mask');
    fprintf('>> Data payload saved to "cv_model_handoff.mat" for classification & Grad-CAM pipeline.\n');
    
    % --- DISPLAY FEATURE EXTRACTION OUTPUTS ---
    figure('Name', 'Retinal Feature Extraction Outputs', 'Position', [50 50 1100 700]);
    subplot(2, 3, 1); imshow(Clean_Vessels_No_OD); title('1. Blood Vessels (OD Removed)');
    subplot(2, 3, 2); imshow(Exudates_Mask); title(sprintf('2. Hard Exudates (n=%d)', num_exudates));
    subplot(2, 3, 3); imshow(Microaneurysms_Mask); title(sprintf('3. Microaneurysms (n=%d)', num_ma));
    subplot(2, 3, 4); imshow(Hemorrhages_Mask); title(sprintf('4. Hemorrhages (n=%d)', num_hem));
    subplot(2, 3, 5); imshow(Fovea_Mask); title('5. Localized Fovea/Macula');
    subplot(2, 3, 6); imshow(Final_Result); title('6. Multi-Biomarker Clinical Overlay');
    
else
    fprintf('\n---------------------------------------------------------\n');
    fprintf('STATUS: PROCESSING TERMINATED (Image Sent Back for Recapture)\n');
    fprintf('---------------------------------------------------------\n');
end

% =========================================================================
% 8. DISPLAY QUALITY STAGE COMPARISON WINDOW
% =========================================================================
figure('Name', 'Quality Gate Stage Verification', 'Position', [150 150 900 400]);
subplot(1, 2, 1); imshow(Resized_Image);
title(sprintf('Input Image\nSharpness: %.2f | Contrast: %.2f', sharp_1, cont_1));
subplot(1, 2, 2);
if strcmp(final_status, "PASSED_ENHANCED") || strcmp(final_status, "REJECTED")
    imshow(Enhanced_Result);
    title(sprintf('Enhanced Image (Stage 2)\nSharpness: %.2f | Contrast: %.2f', sharp_2, cont_2));
else
    imshow(Resized_Image);
    title('Passed Direct (No Enhancement Required)');
end