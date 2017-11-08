clear; clc

% Load Kahana info.
info = kah_info;

% Set experiment.
experiment = 'FR1';

% Set whether to permute trials or not.
dopermute = 0;

% Set number of resampling runs.
if dopermute
    load([info.path.processed experiment '_trialperms_default_phaseencode.mat'], 'permtrials')
    nperm = size(permtrials, 2);
else
    nperm = 1;
end

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};

    disp([num2str(isubj) ' ' subject])

    % Get number of channels.
    subjfiles = extractfield(dir([info.path.processed.cluster 'thetaphase/']), 'name');
    subjfiles = subjfiles(contains(subjfiles, subject));
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
            datA{ipair} = [info.path.processed.cluster 'thetaphase/' subject '_' experiment '_thetaphase_' num2str(channums(1))];
            datB{ipair} = [info.path.processed.cluster 'thetaphase/' subject '_' experiment '_thetaphase_' num2str(channums(2))];
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