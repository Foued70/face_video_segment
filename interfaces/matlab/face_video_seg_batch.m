function face_video_seg_batch(varargin)
%FACE_VIDEO_SEG_BATCH Summary of this function goes here
%   Detailed explanation goes here

%% Parse input arguments
p = inputParser;
addRequired(p, 'inDir', @ischar);
addRequired(p, 'outDir', @ischar);
addRequired(p, 'landmarks', @ischar);
addParameter(p, 'indices', [], @isvector);
addParameter(p, 'minWidth', 0, @isscalar);
addParameter(p, 'minHeight', 0, @isscalar);
addParameter(p, 'maxScaleWidth', 0, @isscalar);
addParameter(p, 'maxScaleHeight', 0, @isscalar);
addParameter(p, 'track', 2, @isscalar);
addParameter(p, 'verbose', 0, @isscalar);
parse(p,varargin{:});
indices = p.Results.indices;

%% Create output directory structure
outputPath = fullfile(p.Results.outDir, 'output');
segmentationsPath = fullfile(p.Results.outDir, 'face_segmentations');
segTreesPath = fullfile(p.Results.outDir, 'seg_trees');
landmarksPath = fullfile(p.Results.outDir, 'landmarks');
fvsPath = fullfile(p.Results.outDir, 'fvs_files');
if(~exist(outputPath, 'dir'))
    mkdir(outputPath);
    mkdir(segmentationsPath);
    mkdir(segTreesPath);
    mkdir(landmarksPath);
    mkdir(fvsPath);
end

%% Parse input directory
filt = '.*(avi|mp4|mkv)';
fileDescs = dir(p.Results.inDir);
%fileNames = {fileDescs.name};
%fileNames = {fileDescs(~cellfun(@isempty,regexpi({fileDescs.name},filt))).name};
fileNames = {fileDescs(~cellfun(@is_video,{fileDescs.name})).name};
if(isempty(indices))
    indices = 1:length(fileNames);
elseif(max(indices) > length(fileNames) || min(indices) < 1)
    error(['indices must be from 1 to ' num2str(length(fileNames))]);
end

%% For each video file
for i = indices   
    vidFile = fullfile(p.Results.inDir, fileNames{i});
    [vidPath,vidName, vidExt] = fileparts(vidFile);    
    disp(['Processing "', [vidName vidExt], '"']);
    
    %% Check resolution
    vid = VideoReader(vidFile);
    if(p.Results.minWidth > 0 && p.Results.minHeight > 0)
        %vid = VideoReader(vidFile);
        if(vid.Width < p.Results.minWidth || vid.Height < p.Results.minHeight)
            disp(['Skipping "', [vidName vidExt], '" because of low resolution']);
            continue;
        end
    end
    
    %% Segmentation tree
    dstSegTreeFile = [vidName vidExt '.pb'];
    dstSegTreePath = fullfile(segTreesPath, dstSegTreeFile);
    dstSegTreePath2 = fullfile(vidPath, dstSegTreeFile);
    if(exist(dstSegTreePath, 'file') == 2)
        disp(['"' dstSegTreeFile '" already exists. Skipping segmentation tree creation.']);
    elseif(exist(dstSegTreePath2, 'file') == 2)
        disp(['"' dstSegTreeFile '" already exists. Skipping segmentation tree creation.']);
        copyfile(dstSegTreePath2, segTreesPath);
    else
        disp(['Creating segmentation tree "' dstSegTreeFile '".']);
        %seg_tree(vidFile, segTreesPath, 'verbose', 0);
        fvs_segment(vidFile, 'outFile', dstSegTreePath);
    end
    
    %% Landmarks cache
    dstLandmarksFile = [vidName '.lms'];
    dstLandmarksPath = fullfile(landmarksPath, dstLandmarksFile);
    dstLandmarksPath2 = fullfile(vidPath, dstLandmarksFile);
    if(exist(dstLandmarksPath, 'file') == 2)
        disp(['"' dstLandmarksFile '" already exists. Skipping caching landmarks.']);
    elseif(exist(dstLandmarksPath2, 'file') == 2)
        disp(['"' dstLandmarksFile '" already exists. Skipping caching landmarks.']);
        copyfile(dstLandmarksPath2, dstLandmarksPath);
    else
        disp(['Creating landmarks cache "' dstLandmarksFile '".']);
        if((p.Results.maxScaleWidth > 0 && (vid.Width*2) > p.Results.maxScaleWidth) ||...
            (p.Results.maxScaleHeight > 0 && (vid.Height*2) > p.Results.maxScaleHeight))
            scales = 1;
        else
            scales = 1:2;
        end
        sfl_cache(vidFile, p.Results.landmarks, 'output', dstLandmarksPath, 'scales', scales, 'track', p.Results.track);
    end
    
    %% Find regions
    dstFvsFile = [vidName '.fvs'];
    dstFvsPath = fullfile(fvsPath, dstFvsFile);
    if(exist(dstFvsPath, 'file') == 2)
        disp(['"' dstFvsFile '" already exists. Skipping finding regions.']);
    else
        disp(['Creating face video segmentation file "' dstFvsFile '".']);
        fvs_find_regions(vidFile, fvsPath, dstLandmarksPath, dstSegTreePath, 'verbose', p.Results.verbose);
    end
    
    %% Write keyframes
    vidOutDir = fullfile(outputPath, vidName);
    if(exist(vidOutDir, 'dir') == 7)
        disp(['"' vidName '" directory already exists. Skipping writing keyframes.']);
    else
        disp(['Writing keyframes to the directory "' vidName '".']);
        mkdir(vidOutDir);
        fvs_write_keyframes(dstFvsPath, vidOutDir, vidFile, dstSegTreePath, dstLandmarksPath, 'debug', p.Results.verbose);
    end      
end

function b = is_video(file)
    [filePath, fileName, fileExt] = fileparts(file);
    b = isempty(regexpi(fileExt, filt));
end
end

