clear; clc

% Set subject, path, and experiment info.
subjects = {'R1020J' 'R1032D' 'R1033D' 'R1034D' 'R1045E' 'R1059J' 'R1075J' 'R1080E' 'R1120E' 'R1135E' ...
    'R1142N' 'R1147P' 'R1149N' 'R1151E' 'R1154D' 'R1162N' 'R1166D' 'R1167M' 'R1175N'};
clusterpath = '/projects/ps-voyteklab/tamtra/data/KAH/';
experiment = 'FR1';

% Set whether to permute trials or not.
dopermute = 0;

% Set number of resampling runs.
if dopermute
    load([clusterpath experiment '_trialperms_default_phaseencode.mat'], 'permtrials')
    nperm = size(permtrials, 2);
else
    nperm = 1;
end

timewin = [-800, 1600];

for isubj = 1
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
    nchanpair = 1;
    
    for iperm = 1
        % Pre-allocate input to qsubcellfun.
        [datA, datB, encoding, type, outputfile] = deal(cell(nchanpair, 1));

        % Specify inputs to kah_subfunc_phaseencode per channel pair. 
        for ipair = 1
            channums = chanpairs(ipair, :);
            datA{ipair} = [clusterpath 'thetaphase/' subject '_' experiment '_thetaphase_' num2str(channums(1)) '.mat'];
            datB{ipair} = [clusterpath 'thetaphase/' subject '_' experiment '_thetaphase_' num2str(channums(2)) '.mat'];
            type{ipair} = 'cmtest'; % change for different test types.

            if dopermute
                encoding{ipair} = permtrials{isubj, iperm};
                outputfile{ipair} = [clusterpath subject '_FR1_phaseencode_' type{ipair} '_' num2str(timewin(1)) '_' num2str(timewin(2)) '_pair_' num2str(ipair) '_resamp_' num2str(iperm) '.mat'];
            else
                encoding{ipair} = [];
                outputfile{ipair} = [clusterpath subject '_FR1_phaseencode_' type{ipair} '_' num2str(timewin(1)) '_' num2str(timewin(2)) '_pair_' num2str(ipair) '_nosamp.mat'];
            end
        end

        qsubcellfun('kah_calculatephaseencode', datA, datB, encoding, type, outputfile, ...
            'backend', 'torque', 'queue', 'hotel', 'timreq', 200, 'stack', 1, 'matlabcmd', '/opt/matlab/2015a/bin/matlab', 'options', '-V -k oe ', 'sleep', 30, 'memreq', 0.05*1024^3)
    end
end
disp('Done.')