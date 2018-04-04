clear

% Set subjects.
info = struct;
info.subj = {'R1020J' 'R1032D' 'R1033D' 'R1034D' 'R1045E' 'R1059J' 'R1075J' 'R1080E' 'R1120E' 'R1135E' ...
    'R1142N' 'R1147P' 'R1149N' 'R1151E' 'R1154D' 'R1162N' 'R1166D' 'R1167M' 'R1175N'};

% Set path to cluster depending on whether the script is run on TSCC or local.
clusterpath = '/projects/ps-voyteklab/tamtra/data/KAH/'; % TSCC
local = 0;
if ~exist(clusterpath, 'dir')
    clusterpath = '/Volumes/voyteklab/tamtra/data/KAH/'; % local
    local = 1;
end

% Get individual or canonical theta phase data.
thetalabel = 'cf';

% Set experiment.
experiment = 'FR1';

% Set true if just testing one run
testrun = 1;

% Change these params for non test runs.
stack = 40; timreq = 300; memreq = 0.3 * 1024^3;

% Pre-allocate input to qsubcellfun. Each cell element is one of the inputs for one job.
% Each job is one channel pair.
% qsubcellfun will parallelize across all channel pairs regardless of subject.
[subjects, chanA, chanB, pairnums, paths, thetalabels] = deal({});

totalpair = 0;

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    disp([num2str(isubj) ' ' subject])
    
    % Get number of channels.
    subjdata = matfile([clusterpath 'thetaphase/' subject '_FR1_thetaphase_' thetalabel '.mat']);
    nchan = length(subjdata.chans);
    
    % Get all unique pairs of channels.
    chanpairs = nchoosek(1:nchan, 2);
    nchanpair = size(chanpairs, 1);
    if testrun
        nchanpair = 1; % do just one pair to test.
    end
    totalpair = totalpair + nchanpair;

    % Specify inputs to kah_calculatepac per channel pair.
    for ipair = 1:nchanpair
        % Skip job if this channel pair has already been run.
        newfile = [clusterpath 'tspac/' thetalabel '/' subject '_FR1_pac_between_ts_0_1600_pair_' num2str(pairnum) '_resamp.mat'];
        if exist(newfile, 'file')
            continue
        end
        
        % Set inputs for kah_calculatepac.m
        channums = chanpairs(ipair, :);
        
        subjects = [subjects; subject];
        chanA = [chanA; channums(1)];
        chanB = [chanB; channums(2)];
        pairnums = [pairnums; ipair];
        paths = [paths; clusterpath];
        thetalabels = [thetalabels; thetalabel];
    end
    disp([num2str(sum(cellfun(@(x) ~isempty(x), strfind(subjects, subject)))) '/' num2str(nchanpair)])
end
disp([num2str(length(subjects)) '/' num2str(totalpair)])

% Max out time and mem requests for test run.
if testrun
    timreq = 28800; stack = 1; memreq = 4 * 1024^3;
end

if local
    % Run a few to check what's going on.
    for irun = 1:length(subjects)
        tic
        memtic
        kah_calculatepac(subjects{irun}, chanA{irun}, chanB{irun}, pairnums{irun}, paths{irun}, thetalabels{irun});
        memtoc
        toc
    end
else
    % Run me!
    qsubcellfun('kah_calculatepac', subjects, chanA, chanB, pairnums, paths, thetalabels, ...
        'backend', 'torque', 'queue', 'hotel', 'timreq', timreq, 'stack', stack, 'matlabcmd', '/opt/matlab/2015a/bin/matlab', 'options', '-V -k oe ', 'sleep', 30, 'memreq', memreq)
end
disp('Done.')