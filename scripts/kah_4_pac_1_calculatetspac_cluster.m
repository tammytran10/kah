clear; clc

% Set subjects.
subjects = {'R1020J' 'R1032D' 'R1033D' 'R1034D' 'R1045E' 'R1059J' 'R1075J' 'R1080E' 'R1120E' 'R1135E' ...
    'R1142N' 'R1147P' 'R1149N' 'R1151E' 'R1154D' 'R1162N' 'R1166D' 'R1167M' 'R1175N'};

% Set path to cluster depending on whether the script is run on TSCC or local.
clusterpath = '/projects/ps-voyteklab/tamtra/data/KAH/'; % TSCC
local = 0;
if ~exist(clusterpath, 'dir')
    clusterpath = '/Volumes/voyteklab/tamtra/data/KAH/'; % local
    local = 1;
end

% Set experiment and time window.
experiment = 'FR1';
timewin = [0, 1600];

% Set true if just testing one run
testrun = 0;

% Change these params for non test runs.
stack = 40; timreq = 300; memreq = 0.05 * 1024^3;

% Pre-allocate input to qsubcellfun. Each cell element is one of the inputs for one job.
% Each job is one channel pair.
% qsubcellfun will parallelize across all channel pairs regardless of subject.
[chanA, chanB, outputfile] = deal({});

for isubj = 1:length(subjects)
    % Get current subject identifier.
    subject = subjects{isubj};
    
    disp([num2str(isubj) ' ' subject])
    
    % Get number of channels.
    subjfiles = extractfield(dir([clusterpath 'thetaphase/']), 'name');
    subjfiles = subjfiles(cellfun(@(x) ~isempty(x), strfind(subjfiles, subject)));
    nchan = length(subjfiles);
    
    % Get all unique pairs of channels.
    chanpairs = nchoosek(1:nchan, 2);
    nchanpair = size(chanpairs, 1);
    if testrun
        nchanpair = 1; % do just one pair to test.
    end
    
    % Specify inputs to kah_calculatepac per channel pair.
    for ipair = 1:nchanpair
        % Determine name of output file.
        newfile = [clusterpath subject '_FR1_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_pair_' num2str(ipair) '.mat'];
        
        % Skip job if this channel pair has already been run.
        if exist(newfile, 'file')
            continue
        end
        
        % Set inputs for kah_calculatephaseencode.m
        channums = chanpairs(ipair, :);
        
        datA = [datA; [clusterpath subject '_' experiment '_thetaphase_' num2str(channums(1)) '.mat']];
        chanB = [chanB; [clusterpath 'thetaphase/' subject '_' experiment '_hfaamp_' num2str(channums(2)) '.mat']];
        outputfile = [outputfile; newfile];
    end
end

% Max out time and mem requests for test run.
if testrun
    timreq = 28800; stack = 1; memreq = 4 * 1024^3;
end

if local
    for isubj = 1:length(subjects)
        memtic
        kah_calculatepac(chanA{isubj}, chanB{isubj}, outputfile{isubj});
        memtoc
    end
else
    % Run me!
    qsubcellfun('kah_calculatepac', chanA, chanB, outputfile, ...
        'backend', 'torque', 'queue', 'hotel', 'timreq', timreq, 'stack', stack, 'matlabcmd', '/opt/matlab/2015a/bin/matlab', 'options', '-V -k oe ', 'sleep', 30, 'memreq', memreq)
end
disp('Done.')