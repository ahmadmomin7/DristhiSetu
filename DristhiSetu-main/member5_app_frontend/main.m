%% =========================================================
% DRISTHISETU - TEST BENCH INFERENCE (FAULT-TOLERANT)
% Run directory : member5_app_frontend
% Model path    : D:\EyeTriage_Prototype (1)\EyeTriage_Prototype\DR_Project\models\Model1_ResNet18\ResNet18_EyePACS.mat
% Test folder   : member3_cv_image_quality1/b. Testing Set
% =========================================================
clear;
clc;
close all;

%% 1. EXACT CONFIGURATION PATHS
MODEL_PATH = 'D:\EyeTriage_Prototype (1)\EyeTriage_Prototype\DR_Project\models\Model1_ResNet18\ResNet18_EyePACS.mat';

CURRENT_DIR = pwd;
BASE_DIR    = fileparts(CURRENT_DIR); 

TEST_DIR = fullfile(BASE_DIR, 'member3_cv_image_quality1', 'b. Testing Set');
if ~isfolder(TEST_DIR)
    TEST_DIR = 'D:\EyeTriage_Prototype (1)\EyeTriage_Prototype\member3_cv_image_quality1\b. Testing Set';
end

if ~isfile(MODEL_PATH)
    error('Model file not found at: %s', MODEL_PATH);
end

if ~isfolder(TEST_DIR)
    error('Testing folder not found at: %s', TEST_DIR);
end

%% 2. LOAD NETWORK AND METADATA
fprintf('Loading model: %s\n', MODEL_PATH);
loadedData = load(MODEL_PATH);

if isfield(loadedData, 'netEyePACS')
    net = loadedData.netEyePACS;
elseif isfield(loadedData, 'net')
    net = loadedData.net;
else
    error('Neither "netEyePACS" nor "net" variable found in the .mat file.');
end

if isfield(loadedData, 'CLASS_NAMES')
    CLASS_NAMES = loadedData.CLASS_NAMES;
else
    CLASS_NAMES = ["Grade_0"; "Grade_1"; "Grade_2"; "Grade_3"; "Grade_4"];
end

if isfield(loadedData, 'IMAGE_SIZE')
    IMAGE_SIZE = loadedData.IMAGE_SIZE;
else
    IMAGE_SIZE = [224 224];
end

fprintf('Model successfully loaded.\n');
fprintf('Input size  : %d x %d x 3\n', IMAGE_SIZE(1), IMAGE_SIZE(2));
fprintf('Class list  : %s\n\n', strjoin(CLASS_NAMES, ', '));

%% 3. COLLECT TEST IMAGES
extList = {'*.jpg', '*.jpeg', '*.png', '*.tif', '*.tiff'};
imgList = [];
for e = extList
    imgList = [imgList; dir(fullfile(TEST_DIR, '**', e{1}))]; %#ok<AGROW>
end

% Filter out hidden or 0-byte ghost files
validIdx = false(numel(imgList), 1);
for i = 1:numel(imgList)
    if ~startsWith(imgList(i).name, '.') && imgList(i).bytes > 1024
        validIdx(i) = true;
    end
end
imgList = imgList(validIdx);

numTests = numel(imgList);
if numTests == 0
    error('No valid image files detected in: %s', TEST_DIR);
end

fprintf('Dataset target  : %s\n', TEST_DIR);
fprintf('Valid images    : %d\n\n', numTests);

%% 4. EXECUTE BATCH PREDICTIONS
results = struct('FileName', {}, 'PredictedGrade', {}, 'Confidence', {}, 'ReferralRisk', {});

fprintf('%-32s | %-12s | %-12s | %-18s\n', 'File Name', 'Predicted', 'Confidence', 'Triage Status');
fprintf('%s\n', repmat('-', 1, 80));

for idx = 1:numTests
    imgPath = fullfile(imgList(idx).folder, imgList(idx).name);
    
    try
        img = imread(imgPath);
        
        % Normalize channels
        if ndims(img) == 2
            img = repmat(img, 1, 1, 3);
        elseif size(img, 3) > 3
            img = img(:, :, 1:3);
        end
        
        inputTensor = single(imresize(img, IMAGE_SIZE));
        scores = predict(net, inputTensor);
        
        [confidenceVal, predIdx] = max(scores);
        predClass = CLASS_NAMES(predIdx);
        confidencePct = confidenceVal * 100;
        
        if ismember(predClass, ["Grade_0", "Grade_1"])
            triageAction = "Non-Referable";
        else
            triageAction = "REFERRAL REQUIRED";
        end
        
        results(idx).FileName = imgList(idx).name;
        results(idx).PredictedGrade = char(predClass);
        results(idx).Confidence = confidencePct;
        results(idx).ReferralRisk = char(triageAction);
        
        fprintf('%-32s | %-12s | %9.2f %%  | %-18s\n', ...
            imgList(idx).name, ...
            predClass, ...
            confidencePct, ...
            triageAction);
            
    catch ME
        % Handle corrupted or unsupported files cleanly
        results(idx).FileName = imgList(idx).name;
        results(idx).PredictedGrade = "CORRUPT_FILE";
        results(idx).Confidence = 0.0;
        results(idx).ReferralRisk = "MANUAL_REVIEW";
        
        fprintf('%-32s | %-12s | %9.2f %%  | %-18s\n', ...
            imgList(idx).name, ...
            "CORRUPT", ...
            0.0, ...
            "SKIPPED (ERROR)");
    end
end

fprintf('%s\n', repmat('-', 1, 80));

%% 5. SAVE CSV LOG
resultsTable = struct2table(results);
outputPath = fullfile(CURRENT_DIR, 'Batch_Test_Inference_Results.csv');
writetable(resultsTable, outputPath);

fprintf('\nInference finished.\nResults exported to: %s\n', outputPath);