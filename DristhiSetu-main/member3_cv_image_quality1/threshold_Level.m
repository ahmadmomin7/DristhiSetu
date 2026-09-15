function level = threshold_Level(Image)

Image_u8 = im2uint8(Image(:));

Image_u8 = Image_u8(Image_u8 > 5); % Discard background zero values


if isempty(Image_u8)

level = 0.5;

return;

end


[histogram_Count, Bin_Number] = imhist(Image_u8);

total_pixels = sum(histogram_Count);


T = round(sum(Bin_Number .* histogram_Count) / total_pixels);

T = max(1, min(255, T));


for iter = 1:100

w0 = sum(histogram_Count(1:T));

w1 = sum(histogram_Count(T+1:end));


if w0 > 0

u0 = sum(Bin_Number(1:T) .* histogram_Count(1:T)) / w0;

else

u0 = 1;

end


if w1 > 0

u1 = sum(Bin_Number(T+1:end) .* histogram_Count(T+1:end)) / w1;

else

u1 = 255;

end


T_next = round((u0 + u1) / 2);

T_next = max(1, min(255, T_next));


if abs(T_next - T) < 1

break;

end

T = T_next;

end

level = (T - 1) / 255;