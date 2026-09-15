function Color_Image = Colorize_Image(Resized_Image, Mask, Color_RGB, alpha)
    % COLORIZE_IMAGE Overlays colored binary/logical masks onto RGB images.
    % Usage:
    %   Color_Image = Colorize_Image(Resized_Image, Mask, Color_RGB)
    %   Color_Image = Colorize_Image(Resized_Image, Mask, Color_RGB, alpha) % alpha: 0.0 to 1.0
    
    if nargin < 3 || isempty(Color_RGB)
        Color_RGB = [0 255 255]; % Default Cyan
    end
    if nargin < 4 || isempty(alpha)
        alpha = 1.0; % 1.0 = solid overlay (matches previous behavior), 0.7 = semi-transparent
    end

    % 1. Guard: Ensure Image is uint8 RGB
    if ~isa(Resized_Image, 'uint8')
        Resized_u8 = im2uint8(Resized_Image);
    else
        Resized_u8 = Resized_Image;
    end
    
    if size(Resized_u8, 3) == 1
        Resized_u8 = repmat(Resized_u8, [1 1 3]);
    end

    % 2. Guard: Handle empty or all-false masks cleanly
    if isempty(Mask) || ~any(Mask(:))
        Color_Image = Resized_u8;
        return;
    end

    % 3. Guard: Force Mask to strict logical type and check dimensions
    Mask = logical(Mask);
    if size(Mask, 1) ~= size(Resized_u8, 1) || size(Mask, 2) ~= size(Resized_u8, 2)
        Mask = imresize(Mask, [size(Resized_u8, 1), size(Resized_u8, 2)], 'nearest');
    end

    % 4. Guard: Auto-scale Color_RGB if passed as [0, 1] range
    if max(Color_RGB) <= 1.0 && any(Color_RGB > 0)
        Color_RGB = Color_RGB * 255;
    end
    Color_RGB = uint8(Color_RGB);

    % 5. Blended or Solid Coloring
    if alpha >= 1.0
        % Fast direct assignment
        Red_Channel   = Resized_u8(:,:,1);
        Green_Channel = Resized_u8(:,:,2);
        Blue_Channel  = Resized_u8(:,:,3);

        Red_Channel(Mask)   = Color_RGB(1);
        Green_Channel(Mask) = Color_RGB(2);
        Blue_Channel(Mask)  = Color_RGB(3);

        Color_Image = cat(3, Red_Channel, Green_Channel, Blue_Channel);
    else
        % Semi-transparent clinical blending: (1-a)*Img + a*Color
        Color_Image = Resized_u8;
        for c = 1:3
            ch = Color_Image(:,:,c);
            ch(Mask) = uint8((1 - alpha) * double(ch(Mask)) + alpha * double(Color_RGB(c)));
            Color_Image(:,:,c) = ch;
        end
    end
end