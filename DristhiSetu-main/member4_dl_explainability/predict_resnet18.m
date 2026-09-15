% member4_dl_explainability/predict_resnet18.m
function [predClass, confPct, isOk] = predict_resnet18(net, img, classNames)
% PREDICT_RESNET18 Runs classification against trained ResNet-18 EyePACS model.
if nargin < 3 || isempty(classNames)
    classNames = ["Grade_0", "Grade_1", "Grade_2", "Grade_3", "Grade_4"];
end

predClass = "Unknown";
confPct = 0.0;
isOk = false;

if isempty(net), return; end

try
    % Standardize input dimensions
    inputTensor = imresize(img, [224 224]);
    if ndims(inputTensor) == 2
        inputTensor = repmat(inputTensor, 1, 1, 3);
    elseif size(inputTensor, 3) > 3
        inputTensor = inputTensor(:,:,1:3);
    end

    % Forward pass
    scores = predict(net, single(inputTensor));
    [maxVal, predIdx] = max(scores);

    predClass = classNames(predIdx);
    confPct = maxVal * 100.0;
    isOk = true;
catch ME
    fprintf('[predict_resnet18] Forward inference failed: %s\n', ME.message);
end
end