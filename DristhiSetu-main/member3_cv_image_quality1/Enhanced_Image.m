function Enhanced_RGB = Enhanced_Image(Img_RGB)

Img_double = im2double(Img_RGB);


% 1. Robust Field of View (FOV) Mask

FOV_Mask = (Img_double(:,:,1) + Img_double(:,:,2)) > 0.06;

FOV_Mask = imerode(FOV_Mask, strel('disk', 8));


% 2. Convert to Lab Color Space to separate intensity from color

Lab_Img = rgb2lab(Img_double);

L_chan = Lab_Img(:,:,1) / 100; % Normalized Luminance [0, 1]


% 3. Illumination Background Leveling on Luminance ONLY

se_bg = strel('disk', 40);

bg = imclose(imopen(L_chan, se_bg), se_bg);

mean_val = mean(L_chan(FOV_Mask));

L_corrected = (L_chan ./ (bg + 0.12)) * mean_val;

L_corrected(~FOV_Mask) = 0;


% 4. Gentle Adaptive Histogram Equalization on Luminance ONLY

L_enhanced = adapthisteq(L_corrected, 'NumTiles', [8 8], 'ClipLimit', 0.012, 'Distribution', 'uniform');


% Reconstruct Lab image (a* and b* retain natural retinal orange/red tones)

Lab_Img(:,:,1) = L_enhanced * 100;

Enhanced_RGB = lab2rgb(Lab_Img);


% 5. Gentle Edge-Preserving Denoise

Enhanced_RGB = imbilatfilt(Enhanced_RGB, 0.012, 1.5);


% Zero out outer borders

for c = 1:3

ch = Enhanced_RGB(:,:,c);

ch(~FOV_Mask) = 0;

Enhanced_RGB(:,:,c) = ch;

end


Enhanced_RGB = im2uint8(max(0, min(1, Enhanced_RGB)));

end 

