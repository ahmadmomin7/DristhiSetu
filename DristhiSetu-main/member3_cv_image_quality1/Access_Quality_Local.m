function [is_good, score_sharpness, score_contrast] = Access_Quality_Local(Img_RGB, sharp_th, contrast_th)
    try
        Img_double = im2double(Img_RGB);
        
        if size(Img_double, 3) == 1
            Green_Channel = Img_double;
        else
            Green_Channel = Img_double(:,:,2); 
        end
        
        % Robust Field-Of-View (FOV) Mask
        Sum_Image = sum(Img_double, 3);
        FOV_Mask = Sum_Image > 0.08; 
        FOV_Mask = imerode(FOV_Mask, strel('disk', 6));
        
        if sum(FOV_Mask(:)) < 200
            FOV_Mask = true(size(Green_Channel));
        end
        
        Green_u8 = im2uint8(Green_Channel);
        
        % Fast Laplacian kernel for sharpness evaluation
        LapFilter = [0 1 0; 1 -4 1; 0 1 0];
        LapImg = imfilter(Green_u8, LapFilter, 'replicate');
        
        valid_lap_pixels = double(LapImg(FOV_Mask));
        score_sharpness = var(valid_lap_pixels);
        
        % Contrast evaluation using 5th and 95th percentiles
        valid_green_pixels = double(Green_u8(FOV_Mask));
        p95 = prctile(valid_green_pixels, 95);
        p5  = prctile(valid_green_pixels, 5);
        
        score_contrast = (p95 - p5) / (p95 + p5 + eps);
        is_good = (score_sharpness >= sharp_th) && (score_contrast >= contrast_th);
        
    catch
        score_sharpness = 0;
        score_contrast = 0;
        is_good = false; 
    end
end