% member3_cv_image_quality1/extract_biomarkers.m
function [masks, overlayResult, metrics] = extract_biomarkers(Ready_Image)
    Converted_Image = im2double(Ready_Image);
    [H, W, ~] = size(Converted_Image);
    
    % Field of View
    FOV_Mask = (Converted_Image(:,:,1) + Converted_Image(:,:,2)) > 0.05;
    FOV_Mask = imerode(FOV_Mask, strel('disk', 8));
    
    Green_Channel = Converted_Image(:,:,2);
    Red_Channel   = Converted_Image(:,:,1);
    Blue_Channel  = Converted_Image(:,:,3);
    
    Green_Clean   = imbilatfilt(Green_Channel, 0.015, 2.0);
    Green_Norm    = adapthisteq(Green_Clean, 'NumTiles', [8 8], 'ClipLimit', 0.010);
    Green_Norm(~FOV_Mask) = 0;
    
    % 1. Optic Disc Localization
    [centers, radii] = imfindcircles(im2uint8(Green_Norm), [25 75], 'ObjectPolarity', 'bright', 'Sensitivity', 0.94);
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
    
    % 2. Fovea Localization
    if od_c(1) < W/2
        fovea_x = min(W - 25, round(od_c(1) + 2.5 * od_r * 2));
    else
        fovea_x = max(25, round(od_c(1) - 2.5 * od_r * 2));
    end
    fovea_y = round(od_c(2));
    Fovea_Mask = (X - fovea_x).^2 + (Y - fovea_y).^2 <= (od_r * 0.85).^2;
    
    % 3. Vessel Segmentation (Calls threshold_Level.m)
    Avg_Filter = fspecial('average', [11 11]);
    Subtracted_Vessels = imsubtract(imfilter(Green_Norm, Avg_Filter), Green_Norm);
    Subtracted_Vessels(~FOV_Mask) = 0;
    
    level = threshold_Level(Subtracted_Vessels); % Direct call to member3 file
    thr_v = max(0.012, level * 0.98);
    Binary_Vessels = imbinarize(Subtracted_Vessels, thr_v) & FOV_Mask;
    Clean_Vessels_No_OD = bwareaopen(Binary_Vessels, 35) & (~OD_Mask);
    
    % 4. Hard Exudates Detection
    Yellow_Index = (Green_Channel .* Red_Channel) ./ (Blue_Channel + 0.15);
    TopHat_Yellow = imtophat(Yellow_Index, strel('disk', 8));
    p85_green = prctile(Green_Channel(FOV_Mask), 85);
    Exudates_Raw = (TopHat_Yellow > 0.25) & ...
                   (Green_Channel > p85_green) & ...
                   (Red_Channel > 0.70) & ...
                   FOV_Mask & (~OD_Mask) & (~Clean_Vessels_No_OD);
    Exudates_Mask = bwareaopen(Exudates_Raw, 15);
    
    % 5. Microaneurysms & Hemorrhages
    BottomHat_Dark = imbothat(Green_Norm, strel('disk', 4));
    Local_Mean = imfilter(Green_Norm, fspecial('average', [25 25]));
    Dark_Candidates = (BottomHat_Dark > 0.11) & ...
                      ((Local_Mean - Green_Norm) > 0.07) & ...
                      FOV_Mask & (~Clean_Vessels_No_OD) & (~OD_Mask);
                  
    MA_Raw = bwareaopen(Dark_Candidates, 4) & ~bwareaopen(Dark_Candidates, 30);
    ma_props = regionprops(MA_Raw, 'Eccentricity', 'PixelIdxList');
    Microaneurysms_Mask = false(H, W);
    for k = 1:length(ma_props)
        if ma_props(k).Eccentricity < 0.82
            Microaneurysms_Mask(ma_props(k).PixelIdxList) = true;
        end
    end
    
    Hem_Raw = bwareaopen(Dark_Candidates, 31) & ~bwareaopen(Dark_Candidates, 500);
    hem_props = regionprops(Hem_Raw, 'Solidity', 'Area', 'PixelIdxList');
    Hemorrhages_Mask = false(H, W);
    for k = 1:length(hem_props)
        if hem_props(k).Solidity > 0.55 && hem_props(k).Area >= 31
            Hemorrhages_Mask(hem_props(k).PixelIdxList) = true;
        end
    end
    
    % 6. Neovascularization Check
    OD_Margin = imdilate(OD_Mask, strel('disk', 18)) & (~OD_Mask);
    is_neovascular = sum(Clean_Vessels_No_OD(OD_Margin)) > 130;
    
    % Metrics Payload
    metrics = struct();
    metrics.exudates_count       = bwconncomp(Exudates_Mask).NumObjects;
    metrics.microaneurysms_count = bwconncomp(Microaneurysms_Mask).NumObjects;
    metrics.hemorrhages_count    = bwconncomp(Hemorrhages_Mask).NumObjects;
    metrics.foveal_threat        = any(Exudates_Mask(Fovea_Mask));
    metrics.neovascular_risk     = is_neovascular;
    
    masks = struct();
    masks.exudates = Exudates_Mask;
    masks.ma       = Microaneurysms_Mask;
    masks.hem      = Hemorrhages_Mask;
    masks.fovea    = Fovea_Mask;
    masks.vessels  = Clean_Vessels_No_OD;
    
    % 7. Overlay Composite (Calls Colorize_Image.m directly)
    overlayResult = Colorize_Image(Ready_Image, Clean_Vessels_No_OD, [0 220 255]);
    overlayResult = Colorize_Image(overlayResult, Exudates_Mask, [255 230 0]);
    overlayResult = Colorize_Image(overlayResult, Microaneurysms_Mask, [255 40 40]);
    overlayResult = Colorize_Image(overlayResult, Hemorrhages_Mask, [230 0 120]);
    overlayResult = Colorize_Image(overlayResult, bwperim(Fovea_Mask), [60 120 255]);
    
    DL_Tensor = single(imresize(Ready_Image, [224 224])) / 255.0;
    DL_Tensor = reshape(DL_Tensor, [224, 224, 3, 1]);
    CV_Biomarkers = metrics;
    save('cv_model_handoff.mat', 'DL_Tensor', 'CV_Biomarkers', 'Clean_Vessels_No_OD', ...
         'Exudates_Mask', 'Microaneurysms_Mask', 'Hemorrhages_Mask');
end