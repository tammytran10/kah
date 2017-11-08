clear; clc

% Load Kahana info.
info = struct;
info.subj = {'R1020J' 'R1032D' 'R1033D' 'R1034D' 'R1045E' 'R1059J' 'R1075J' 'R1080E' 'R1120E' 'R1135E' ...
    'R1142N' 'R1147P' 'R1149N' 'R1151E' 'R1154D' 'R1162N' 'R1166D' 'R1167M' 'R1175N'};
info.path.processed.cluster = '/projects/ps-voyteklab/tamtra/data/KAH/';
% info.path.processed.cluster = '/Volumes/voyteklab/tamtra/data/KAH/';

% Set experiment.
experiment = 'FR1';

% Set whether to permute trials or not.
dopermute = 0;

% Set number of resampling runs.
if dopermute
    load([info.path.processed.cluster experiment '_trialperms_default_phaseencode.mat'], 'permtrials')
    nperm = size(permtrials, 2);
else
    nperm = 1;
end

timewin = [-800, 1600];

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};

    disp([num2str(isubj) ' ' subject])

    % Get number of channels.
    subjfiles = extractfield(dir([info.path.processed.cluster 'thetaphase/']), 'name');
    subjfiles = subjfiles(cellfun(@(x) ~isempty(x), strfind(subjfiles, subject)));
    nchan = length(subjfiles);
    
    % Get all unique pairs of channels. 
    chanpairs = nchoosek(1:nchan, 2);    
    nchanpair = size(chanpairs, 1);

    for iperm = 1:nperm
        % Pre-allocate input to qsubcellfun.
        [datA, datB, encoding, type, outputfile] = deal(cell(nchanpair, 1));

        % Specify inputs to kah_subfunc_phaseencode per channel pair. 
        for ipair = 1:nchanpair
            channums = chanpairs(ipair, :);
            datA{ipair} = [info.path.processed.cluster 'thetaphase/' subject '_' experiment '_thetaphase_' num2str(channums(1)) '.mat'];
            datB{ipair} = [info.path.processed.cluster 'thetaphase/' subject '_' experiment '_thetaphase_' num2str(channums(2)) '.mat'];
            type{ipair} = 'cmtest'; % change for different test types.

            if dopermute
                encoding{ipair} = permtrials{isubj, iperm};
                outputfile{ipair} = [info.path.processed.cluster subject '_FR1_phaseencode_' type{ipair} '_' num2str(timewin(1)) '_' num2str(timewin(2)) '_pair_' num2str(ipair) '_resamp_' num2str(iperm) '.mat'];
            else
                encoding{ipair} = [];
                outputfile{ipair} = [info.path.processed.cluster subject '_FR1_phaseencode_' type{ipair} '_' num2str(timewin(1)) '_' num2str(timewin(2)) '_pair_' num2str(ipair) '_nosamp.mat'];
            end
            
        end

        qsubcellfun('kah_calculatephaseencode', datA, datB, encoding, type, outputfile, ...
            'backend', 'torque', 'queue', 'hotel', 'timreq', 60*60*100, 'matlabcmd', '/opt/matlab/2015a/bin/matlab', 'stack', 100, 'options', '-V -k oe ', 'sleep', 30)
    end
end
disp('Done.')