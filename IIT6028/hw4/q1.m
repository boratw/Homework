% %Load image as reduced size for reduce memory usage.
% image_jpg = {};
% for i = 1:16
%     image_jpg{end+1} = imread(strcat('exposure_stack\\exposure',int2str(i),'.jpg'));
%     image_jpg{end} = im2uint8(imresize(image_jpg{end}, 0.125));
% end
% 
% image_res = zeros(500, 750, 3);
% 
% image_tiff = {};
% for i = 1:16
%     image_tiff{end+1} = imread(strcat('res_stack\\exposure',int2str(i),'.tiff'));
%     image_tiff{end} = im2uint8(imresize(image_tiff{end}, 0.125));
% end

%g = zeros(3, 256);
for chan = 1:3
    % sample 2000 pointes
    samples = zeros(32000, 1, 'uint8');
    for i = 0:1999
        x = randi(750);
        y = randi(500);
        for f = 1:16
            samples(i * 16 + f) = image_jpg{f}(y, x, chan);
        end
    end
    lambda = 1.0;
    % construct G matrix and the differance value b
    getg = zeros(32256, 256);
    b = zeros(30255, 1);
    for i = 0:1999
        for j = 1:15
            getg((i * 16 + j), samples((i * 16 + j)) + 1) = 1;
            b(i * 15 + j) = 0.69314718055994530941723212145818 * getw(samples(i * 16 + j + 1));
        end
        getg((i * 16 + 16), samples((i * 16 + 16)) + 1) = 1;
    end

    % append original g for create laplacian
    for i = 1:256
        getg(32000 + i, i) = 1;
    end

    % set constant (for preserve 255)
    b(30255) = log(255);


    % set first derivative matrix 
    diff = zeros(30255, 32256);
    for i = 0:1999
        for j = 1:15
            diff(i * 15 + j, i * 16 + j) = -b(i * 15 + j);
            diff(i * 15 + j, i * 16 + j + 1) = b(i * 15 + j);
        end
    end
    % set second derivative (laplacian) matrix 
    for i = 1:254
        diff(30000 + i, 32000 + i) =  1 * lambda;
        diff(30000 + i, 32000 + i + 1) = -2 * 1 * lambda;
        diff(30000 + i, 32000 + i + 2) = 1 * lambda;
    end
    % set constant (for preserve 255)
    diff(30255, 32256) = 1;


    A = diff * getg;
    g(chan, :) = A \ b;

    m = 0;
    for i = 1:500
        for j = 1:750
            wsum = 0;
            v = 0;
            for f = 1:16
%                  v = v + getw(image_tiff{f}(i, j, chan)) * ...
%                     double(image_tiff{f}(i, j, chan)) * 2 ^ (-f);
%                 if(image_tiff{f}(i, j, chan) > 0)
%                     v = v + getw(image_tiff{f}(i, j, chan)) * ...
%                         (log(double(image_tiff{f}(i, j, chan)))  - 0.69314718 * f);
%                     wsum = wsum + getw(image_tiff{f}(i, j, chan));
%                 end
                
%                 % Descripted below
%                 % /--
                v = v + getw(image_jpg{f}(i, j, chan)) * ...
                    exp(g(1, image_jpg{f}(i, j, chan) + 1)) * 2 ^ (-f);
%                 % --/
                % For Logarithm merging
                % /--
%                 v = v + getw(image_jpg{f}(i, j, chan)) * ...
%                     (g(1, image_jpg{f}(i, j, chan) + 1) - 0.69314718 * f);
                % --/
                wsum = wsum + getw(image_jpg{f}(i, j, chan));
            end
            if wsum ~= 0
                v = v / wsum;
            end
            % For Logarithm merging
            % /--
            %v = exp(v);
            % --/
            image_res(i, j, chan) = v;
            if (m < v)
                m = v;
            end
        end
    end
    image_res(:, :, chan) = image_res(:, :, chan) ./ m;
end

% Image Evaluation
image_xyz = rgb2xyz(image_res, 'ColorSpace', 'srgb');
lum = zeros(6, 1);
for f = 1:6
    for i = fp(f, 1) - 3 : fp(f, 1) + 3
        for j = fp(f, 2) - 3 : fp(f, 2) + 3
            lum(f) = lum(f) + image_xyz(j, i, 2);
        end
    end
    lum(f) = log(lum(f) / 49);
end
lumerr = 0;
for f = 2:5
    lumerr = lumerr + ((lum(1) + (lum(6) - lum(1)) * (f-1) / 5) - lum(f)) ^ 2;
end

    
hdrwrite(image_res, 'rendered_gaussian_linear.hdr');
imwrite(image_res * 5, 'rendered_gaussian_linear_x5.png')
imwrite(image_res * 25, 'rendered_gaussian_linear_x25.png')
imwrite(image_res * 125, 'rendered_gaussian_linear_x125.png')
imwrite(image_res * 625, 'rendered_gaussian_linear_x625.png')
imwrite(image_res * 2500, 'rendered_gaussian_linear_x2500.png')
imwrite(image_res * 12500, 'rendered_gaussian_linear_x12500.png')
