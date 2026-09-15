%% =========================================================
% MODEL 1 - STAGE 1
% RESNET-18 FAST CPU TRAINING ON EYEPACS (2-3 HOUR TARGET)
%
% MATLAB R2026a
%
% Purpose:
%   Train a 5-class diabetic retinopathy severity classifier
%   optimized for balanced multi-threaded CPU execution.
%
% Classes:
%   0 = No DR
%   1 = Mild NPDR
%   2 = Moderate NPDR
%   3 = Severe NPDR
%   4 = Proliferative DR
% =========================================================
clear;
clc;
close all;
rng(42);

fprintf('\n');
fprintf('====================================================\n');
fprintf('   MODEL 1 - STAGE 1 : EYEPACS RESNET-18 (FAST CPU)\n');
fprintf('====================================================\n');

%% =========================================================
% 1. PROJECT PATHS
% =========================================================
PROJECT_ROOT = 'D:\DR_Project';
MANIFEST_ROOT = fullfile(PROJECT_ROOT, 'manifests', 'Model1');
MODEL_DIR = fullfile(PROJECT_ROOT, 'models', 'Model1_ResNet18');
RESULT_DIR = fullfile(PROJECT_ROOT, 'results', 'Model1', 'training');

if ~isfolder(MODEL_DIR), mkdir(MODEL_DIR); end
if ~isfolder(RESULT_DIR), mkdir(RESULT_DIR); end

%% =========================================================
% 2. CPU BALANCED OPTIMIZATION SETTINGS
% =========================================================
IMAGE_SIZE = [224 224];
NUM_CLASSES = 5;
BATCH_SIZE = 16;               % Optimal CPU cache locality
EPOCHS = 6;                    % Sufficient for pre-trained weights to settle
LEARNING_RATE = 2e-4;          % Slightly higher LR for faster Adam convergence
MAX_IMAGES_PER_CLASS = 700;    % 3,500 total images (fits in 2-3 hour window)
MAX_VAL_IMAGES = 400;          % Subsamples val set to avoid 30 min val stalls
RANDOM_SEED = 42;
CLASS_NAMES = [
    "Grade_0"
    "Grade_1"
    "Grade_2"
    "Grade_3"
    "Grade_4"
];

%% =========================================================
% 3. DISPLAY SETTINGS
% =========================================================
fprintf('\n---------------- TRAINING SETTINGS ----------------\n');
fprintf('Target Execution    : Multi-threaded CPU\n');
fprintf('Model Architecture  : ResNet-18 (Lightweight & Fast)\n');
fprintf('Image size          : %d x %d\n', IMAGE_SIZE(1), IMAGE_SIZE(2));
fprintf('Number of classes   : %d\n', NUM_CLASSES);
fprintf('Batch size          : %d\n', BATCH_SIZE);
fprintf('Epochs              : %d\n', EPOCHS);
fprintf('Learning rate       : %.6f\n', LEARNING_RATE);
fprintf('Max/class (Train)   : %d (Total: %d)\n', MAX_IMAGES_PER_CLASS, MAX_IMAGES_PER_CLASS * NUM_CLASSES);
fprintf('Validation size     : %d images\n', MAX_VAL_IMAGES);
fprintf('----------------------------------------------------\n');

%% =========================================================
% 4. MANIFEST FILES
% =========================================================
trainCSV = fullfile(MANIFEST_ROOT, 'EyePACS_train.csv');
valCSV = fullfile(MANIFEST_ROOT, 'EyePACS_validation.csv');

if ~isfile(trainCSV), error('Training manifest not found: %s', trainCSV); end
if ~isfile(valCSV), error('Validation manifest not found: %s', valCSV); end

trainTable = readtable(trainCSV, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');
valTable = readtable(valCSV, 'Delimiter', ',', 'TextType', 'string', 'VariableNamingRule', 'preserve');

trainTable = trainTable(:, {'File', 'Label'});
valTable = valTable(:, {'File', 'Label'});

trainTable.File = string(trainTable.File);
valTable.File = string(valTable.File);
trainTable.Label = double(trainTable.Label);
valTable.Label = double(valTable.Label);

% Clean rows
validTrain = ~ismissing(trainTable.File) & strlength(strtrim(trainTable.File)) > 0 & ~isnan(trainTable.Label);
validVal = ~ismissing(valTable.File) & strlength(strtrim(valTable.File)) > 0 & ~isnan(valTable.Label);
trainTable = trainTable(validTrain, :);
valTable = valTable(validVal, :);

% Check file existence
trainTable = trainTable(isfile(trainTable.File), :);
valTable = valTable(isfile(valTable.File), :);

%% =========================================================
% 5. BALANCE TRAINING & SUB-SAMPLE VALIDATION DATA
% =========================================================
fprintf('\nBalancing training distribution...\n');
trainTable = balanceDataset(trainTable, MAX_IMAGES_PER_CLASS, RANDOM_SEED);

% Subsample validation set proportionally so validation does not stall CPU
if height(valTable) > MAX_VAL_IMAGES
    valParts = cell(5,1);
    valPerClass = floor(MAX_VAL_IMAGES / NUM_CLASSES);
    for c = 0:4
        sub = valTable(valTable.Label == c, :);
        pick = min(height(sub), valPerClass);
        valParts{c+1} = sub(randperm(height(sub), pick), :);
    end
    valTable = vertcat(valParts{:});
    valTable = valTable(randperm(height(valTable)), :);
end

fprintf('\nBalanced Training Size   : %d\n', height(trainTable));
disp(groupcounts(trainTable, 'Label'));

fprintf('Fast Validation Size     : %d\n', height(valTable));
disp(groupcounts(valTable, 'Label'));

%% =========================================================
% 6. PREPARE IMAGE DATASTORES & PIPELINE
% =========================================================
imdsTrain = imageDatastore(trainTable.File);
imdsTrain.Labels = categorical(trainTable.Label, 0:4, CLASS_NAMES);
imdsTrain.ReadFcn = @(filename) readAndAugmentImage(filename, IMAGE_SIZE);

imdsValidation = imageDatastore(valTable.File);
imdsValidation.Labels = categorical(valTable.Label, 0:4, CLASS_NAMES);
imdsValidation.ReadFcn = @(filename) readAndPrepareImage(filename, IMAGE_SIZE);

%% =========================================================
% 7. LOAD PRETRAINED RESNET-18
% =========================================================
fprintf('\nLoading Pretrained ResNet-18...\n');
try
    net = imagePretrainedNetwork("resnet18", NumClasses=NUM_CLASSES);
    fprintf('ResNet-18 loaded successfully.\n');
catch ME
    fprintf('Error loading ResNet-18: %s\n', ME.message);
    rethrow(ME);
end

%% =========================================================
% 8. CPU TRAINING OPTIONS & VALIDATION FREQUENCY
% =========================================================
iterationsPerEpoch = ceil(height(trainTable) / BATCH_SIZE);
validationFrequency = iterationsPerEpoch;  % Validate once per epoch

fprintf('Iterations per epoch : %d\n', iterationsPerEpoch);
fprintf('Validation frequency : %d\n', validationFrequency);

options = trainingOptions( ...
    "adam", ...
    InitialLearnRate=LEARNING_RATE, ...
    MaxEpochs=EPOCHS, ...
    MiniBatchSize=BATCH_SIZE, ...
    Shuffle="every-epoch", ...
    ValidationData=imdsValidation, ...
    ValidationFrequency=validationFrequency, ...
    Metrics="accuracy", ...
    L2Regularization=1e-4, ...
    ExecutionEnvironment="cpu", ...
    Plots="training-progress", ...
    Verbose=true);

%% =========================================================
% 9. START TRAINING
% =========================================================
fprintf('\n====================================================\n');
fprintf('             STARTING FAST CPU TRAINING\n');
fprintf('====================================================\n');
trainingStartTime = datetime('now');
fprintf('Training started at: %s\n', char(trainingStartTime));

[netEyePACS, trainingInfo] = trainnet( ...
    imdsTrain, ...
    net, ...
    "crossentropy", ...
    options);

trainingEndTime = datetime('now');
trainingDuration = trainingEndTime - trainingStartTime;

fprintf('\nTraining completed in: %s\n', char(trainingDuration));

%% =========================================================
% 10. SAVE MODEL & RESULTS
% =========================================================
modelPath = fullfile(MODEL_DIR, 'ResNet18_EyePACS.mat');
save(modelPath, ...
    'netEyePACS', ...
    'CLASS_NAMES', ...
    'IMAGE_SIZE', ...
    'NUM_CLASSES', ...
    'trainingInfo', ...
    'trainingStartTime', ...
    'trainingEndTime', ...
    '-v7.3');

summaryPath = fullfile(RESULT_DIR, 'EyePACS_ResNet18_Summary.mat');
save(summaryPath, 'trainTable', 'valTable', 'trainingInfo');

fprintf('\nTrained model saved: %s\n', modelPath);
fprintf('Summary saved: %s\n', summaryPath);

%% =========================================================
% HELPER FUNCTIONS
% =========================================================
function balanced = balanceDataset(T, maxPerClass, randomSeed)
rng(randomSeed);
balancedParts = cell(5,1);
for classValue = 0:4
    subset = T(T.Label == classValue, :);
    n = height(subset);
    if n == 0, error('Grade %d has 0 images.', classValue); end
    if n > maxPerClass
        indices = randperm(n, maxPerClass);
        selected = subset(indices, :);
    elseif n < maxPerClass
        indices = randi(n, maxPerClass, 1);
        selected = subset(indices, :);
    else
        selected = subset;
    end
    balancedParts{classValue + 1} = selected;
end
balanced = vertcat(balancedParts{:});
balanced = balanced(randperm(height(balanced)), :);
end

function I = readAndPrepareImage(filename, imageSize)
I = imread(filename);
if ndims(I) == 2, I = repmat(I, 1, 1, 3); end
if size(I, 3) > 3, I = I(:,:,1:3); end
I = imresize(I, imageSize);
if ~isa(I, 'uint8'), I = im2uint8(I); end
end

function I = readAndAugmentImage(filename, imageSize)
I = imread(filename);
if ndims(I) == 2, I = repmat(I, 1, 1, 3); end
if size(I, 3) > 3, I = I(:,:,1:3); end
I = imresize(I, imageSize);

% Rapid online augmentation
if rand() > 0.5, I = fliplr(I); end
if rand() > 0.5, I = flipud(I); end
k = randi([0, 3]);
if k > 0, I = rot90(I, k); end

if ~isa(I, 'uint8'), I = im2uint8(I); end
end