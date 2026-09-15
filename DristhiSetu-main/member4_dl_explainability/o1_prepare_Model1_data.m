%% =========================================================
% MODEL 1 - DATA PREPARATION
% EyePACS + DDR + IDRiD + Messidor-2
% =========================================================

clear;
clc;
close all;

rng(42);

%% ---------------------------------------------------------
% PROJECT PATHS
% ----------------------------------------------------------

PROJECT_ROOT = ...
    'D:\DR_Project';

DATASET_ROOT = fullfile(PROJECT_ROOT,'datasets');

EYE_ROOT = fullfile( ...
    DATASET_ROOT,'Diabetic Retinopathy');

DDR_ROOT = fullfile( ...
    DATASET_ROOT,'DDR-dataset','DR_grading');

IDRID_ROOT = fullfile( ...
    DATASET_ROOT,'IDRID','B. Disease Grading');

MESSIDOR_ROOT = fullfile( ...
    DATASET_ROOT,'Messidor-2');

MANIFEST_ROOT = fullfile( ...
    PROJECT_ROOT,'manifests','Model1');

if ~exist(MANIFEST_ROOT,'dir')
    mkdir(MANIFEST_ROOT);
end

fprintf('\n============================================\n');
fprintf(' MODEL 1 DATA PREPARATION\n');
fprintf('============================================\n');

%% =========================================================
% 1. EYEPACS
% ==========================================================

fprintf('\n--------------------------------------------\n');
fprintf('Preparing EyePACS...\n');
fprintf('--------------------------------------------\n');

eyeCSV = fullfile(EYE_ROOT,'trainLabels.csv');

% Prefer cropped images
eyeImageFolder = fullfile( ...
    EYE_ROOT,'resized_train_cropped');

if ~exist(eyeImageFolder,'dir')
    eyeImageFolder = fullfile( ...
        EYE_ROOT,'resized_train');
end

T = readtable(eyeCSV);

fprintf('CSV rows: %d\n',height(T));

%% Build image lookup

imgFiles = [
    dir(fullfile(eyeImageFolder,'*.jpeg'));
    dir(fullfile(eyeImageFolder,'*.jpg'));
    dir(fullfile(eyeImageFolder,'*.png'))
];

fprintf('Images found: %d\n',numel(imgFiles));

nameMap = containers.Map( ...
    'KeyType','char', ...
    'ValueType','char');

for i = 1:numel(imgFiles)

    [~,base,~] = fileparts(imgFiles(i).name);

    nameMap(base) = fullfile( ...
        imgFiles(i).folder, ...
        imgFiles(i).name);

end

files = strings(height(T),1);
valid = false(height(T),1);

for i = 1:height(T)

    key = char(string(T.image{i}));

    if isKey(nameMap,key)

        files(i) = string(nameMap(key));
        valid(i) = true;

    end

end

eyeTable = table( ...
    files(valid), ...
    double(T.level(valid)), ...
    'VariableNames',{'File','Label'});

fprintf('Matched images: %d\n',height(eyeTable));

%% Patient ID extraction
% Keeps left/right eye of same patient in same split

patientID = strings(height(eyeTable),1);

for i = 1:height(eyeTable)

    [~,name,~] = fileparts(eyeTable.File(i));

    parts = split(name,'_');

    patientID(i) = parts(1);

end

eyeTable.Patient = patientID;

uniquePatients = unique(patientID);

rng(42);

shuffleIdx = randperm(numel(uniquePatients));

uniquePatients = uniquePatients(shuffleIdx);

numValidation = round( ...
    0.15 * numel(uniquePatients));

validationPatients = ...
    uniquePatients(1:numValidation);

isValidation = ...
    ismember(patientID,validationPatients);

EyeTrain = eyeTable(~isValidation,:);
EyeValidation = eyeTable(isValidation,:);

EyeTrain.Patient = [];
EyeValidation.Patient = [];

fprintf('\nEyePACS Training:   %d\n',height(EyeTrain));
fprintf('EyePACS Validation: %d\n',height(EyeValidation));

fprintf('\nEyePACS class distribution:\n');

disp(groupcounts(EyeTrain,'Label'));

writetable( ...
    EyeTrain, ...
    fullfile(MANIFEST_ROOT,'EyePACS_train.csv'));

writetable( ...
    EyeValidation, ...
    fullfile(MANIFEST_ROOT,'EyePACS_validation.csv'));

%% =========================================================
% 2. DDR
% ==========================================================

fprintf('\n--------------------------------------------\n');
fprintf('Preparing DDR...\n');
fprintf('--------------------------------------------\n');

allDDRImages = [
    dir(fullfile(DDR_ROOT,'**','*.jpg'));
    dir(fullfile(DDR_ROOT,'**','*.jpeg'));
    dir(fullfile(DDR_ROOT,'**','*.png'))
];

fprintf('DDR images found: %d\n',numel(allDDRImages));

%% Build filename map

DDRMap = containers.Map( ...
    'KeyType','char', ...
    'ValueType','char');

for i = 1:numel(allDDRImages)

    DDRMap(allDDRImages(i).name) = ...
        fullfile( ...
        allDDRImages(i).folder, ...
        allDDRImages(i).name);

end

txtFiles = dir(fullfile(DDR_ROOT,'*.txt'));

fprintf('DDR text label files found: %d\n', ...
    numel(txtFiles));

DDRTrain = table;
DDRValidation = table;
DDRTest = table;

for f = 1:numel(txtFiles)

    filenameLower = lower(txtFiles(f).name);

    fullTxt = fullfile( ...
        txtFiles(f).folder, ...
        txtFiles(f).name);

    fprintf('Reading %s\n',txtFiles(f).name);

    D = readDDRLabelFile(fullTxt,DDRMap);

    if contains(filenameLower,'train')

        DDRTrain = [DDRTrain; D];

    elseif contains(filenameLower,'valid') || ...
           contains(filenameLower,'val')

        DDRValidation = [DDRValidation; D];

    elseif contains(filenameLower,'test')

        DDRTest = [DDRTest; D];

    end

end

fprintf('\nDDR Train:      %d\n',height(DDRTrain));
fprintf('DDR Validation: %d\n',height(DDRValidation));
fprintf('DDR Test:       %d\n',height(DDRTest));

if ~isempty(DDRTrain)
    writetable( ...
        DDRTrain, ...
        fullfile(MANIFEST_ROOT,'DDR_train.csv'));
end

if ~isempty(DDRValidation)
    writetable( ...
        DDRValidation, ...
        fullfile(MANIFEST_ROOT,'DDR_validation.csv'));
end

if ~isempty(DDRTest)
    writetable( ...
        DDRTest, ...
        fullfile(MANIFEST_ROOT,'DDR_test.csv'));
end

%% =========================================================
% 3. IDRID
% ==========================================================

fprintf('\n--------------------------------------------\n');
fprintf('Preparing IDRiD...\n');
fprintf('--------------------------------------------\n');

labelFiles = [
    dir(fullfile(IDRID_ROOT,'**','*.csv'));
    dir(fullfile(IDRID_ROOT,'**','*.xlsx'))
];

fprintf('Possible IDRiD label files: %d\n', ...
    numel(labelFiles));

IDRIDTrain = table;
IDRIDTest = table;

for f = 1:numel(labelFiles)

    path = fullfile( ...
        labelFiles(f).folder, ...
        labelFiles(f).name);

    fprintf('\nChecking:\n%s\n',path);

    try

        IT = readtable( ...
            path, ...
            'VariableNamingRule','preserve');

    catch
        continue;
    end

    vars = lower(string(IT.Properties.VariableNames));

    imageCol = find(contains(vars,'image'),1);

    gradeCol = find( ...
        contains(vars,'retinopathy') | ...
        contains(vars,'grade'),1);

    if isempty(imageCol) || isempty(gradeCol)
        continue;
    end

    fprintf('Disease grading file detected.\n');

    imageNames = string(IT{:,imageCol});
    grades = double(IT{:,gradeCol});

    datasetTable = createIDRiDManifest( ...
        imageNames,grades,IDRID_ROOT);

    fileLower = lower(labelFiles(f).name);

    folderLower = lower(labelFiles(f).folder);

    if contains(fileLower,'train') || ...
       contains(folderLower,'train')

        IDRIDTrain = [IDRIDTrain; datasetTable];

    elseif contains(fileLower,'test') || ...
           contains(folderLower,'test')

        IDRIDTest = [IDRIDTest; datasetTable];

    end

end

% Remove duplicate rows
if ~isempty(IDRIDTrain)
    IDRIDTrain = unique(IDRIDTrain,'rows');
end

if ~isempty(IDRIDTest)
    IDRIDTest = unique(IDRIDTest,'rows');
end

fprintf('\nIDRiD Official Train: %d\n', ...
    height(IDRIDTrain));

fprintf('IDRiD Official Test:  %d\n', ...
    height(IDRIDTest));

%% Create internal validation from official training

if ~isempty(IDRIDTrain)

    rng(42);

    N = height(IDRIDTrain);

    idx = randperm(N);

    numVal = round(0.15*N);

    valIdx = idx(1:numVal);
    trainIdx = idx(numVal+1:end);

    IDRIDValidation = IDRIDTrain(valIdx,:);

    IDRIDTrainFinal = IDRIDTrain(trainIdx,:);

    fprintf('\nIDRiD Fine-tune Train: %d\n', ...
        height(IDRIDTrainFinal));

    fprintf('IDRiD Validation:      %d\n', ...
        height(IDRIDValidation));

    writetable( ...
        IDRIDTrainFinal, ...
        fullfile(MANIFEST_ROOT,'IDRID_train.csv'));

    writetable( ...
        IDRIDValidation, ...
        fullfile(MANIFEST_ROOT,'IDRID_validation.csv'));

end

if ~isempty(IDRIDTest)

    writetable( ...
        IDRIDTest, ...
        fullfile(MANIFEST_ROOT,'IDRID_test.csv'));

end

%% =========================================================
% 4. MESSIDOR-2
% ==========================================================

fprintf('\n--------------------------------------------\n');
fprintf('Preparing Messidor-2...\n');
fprintf('--------------------------------------------\n');

messCSV = fullfile( ...
    MESSIDOR_ROOT,'messidor_data.csv');

MT = readtable( ...
    messCSV, ...
    'VariableNamingRule','preserve');

messImageRoot = fullfile( ...
    MESSIDOR_ROOT,'messidor-2');

messImages = [
    dir(fullfile(messImageRoot,'**','*.png'));
    dir(fullfile(messImageRoot,'**','*.jpg'));
    dir(fullfile(messImageRoot,'**','*.jpeg'))
];

MessMap = containers.Map( ...
    'KeyType','char', ...
    'ValueType','char');

for i = 1:numel(messImages)

    MessMap(messImages(i).name) = ...
        fullfile( ...
        messImages(i).folder, ...
        messImages(i).name);

end

messFiles = strings(height(MT),1);
messValid = false(height(MT),1);

for i = 1:height(MT)

    name = char(string(MT.id_code{i}));

    if isKey(MessMap,name)

        messFiles(i) = string(MessMap(name));
        messValid(i) = true;

    end

end

Messidor = table( ...
    messFiles(messValid), ...
    double(MT.diagnosis(messValid)), ...
    'VariableNames',{'File','Label'});

fprintf('Messidor matched images: %d\n', ...
    height(Messidor));

writetable( ...
    Messidor, ...
    fullfile(MANIFEST_ROOT,'Messidor_test.csv'));

%% =========================================================
% SUMMARY
% ==========================================================

fprintf('\n============================================\n');
fprintf(' MODEL 1 DATA PREPARATION COMPLETE\n');
fprintf('============================================\n');

fprintf('\nManifest directory:\n%s\n', ...
    MANIFEST_ROOT);

fprintf('\nNext script:\n');
fprintf('02_train_EyePACS.m\n');


%% =========================================================
% LOCAL FUNCTION: DDR LABEL READER
% ==========================================================

function T = readDDRLabelFile(txtPath,imageMap)

lines = readlines(txtPath);

files = strings(0,1);
labels = zeros(0,1);

for i = 1:numel(lines)

    line = strtrim(lines(i));

    if strlength(line)==0
        continue;
    end

    tokens = split(line);

    tokens(tokens=="") = [];

    if numel(tokens)<2
        continue;
    end

    imageToken = char(tokens(1));

    labelValue = str2double(tokens(end));

    if isnan(labelValue)
        continue;
    end

    [~,name,ext] = fileparts(imageToken);

    filename = [name ext];

    if isKey(imageMap,filename)

        files(end+1,1) = ...
            string(imageMap(filename));

        labels(end+1,1) = ...
            labelValue;

    end

end

T = table( ...
    files, ...
    labels, ...
    'VariableNames',{'File','Label'});

end


%% =========================================================
% LOCAL FUNCTION: IDRID MANIFEST
% ==========================================================

function T = createIDRiDManifest( ...
    imageNames,grades,rootDir)

allImages = [
    dir(fullfile(rootDir,'**','*.jpg'));
    dir(fullfile(rootDir,'**','*.jpeg'));
    dir(fullfile(rootDir,'**','*.png'))
];

imgMap = containers.Map( ...
    'KeyType','char', ...
    'ValueType','char');

for i = 1:numel(allImages)

    [~,base,~] = fileparts(allImages(i).name);

    imgMap(base) = fullfile( ...
        allImages(i).folder, ...
        allImages(i).name);

end

files = strings(0,1);
labels = zeros(0,1);

for i = 1:numel(imageNames)

    [~,base,~] = fileparts(imageNames(i));

    key = char(base);

    if isKey(imgMap,key)

        files(end+1,1) = ...
            string(imgMap(key));

        labels(end+1,1) = ...
            grades(i);

    end

end

T = table( ...
    files, ...
    labels, ...
    'VariableNames',{'File','Label'});

end