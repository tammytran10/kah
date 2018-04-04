clear; clc

info = kah_info;

%%
clearvars('-except', 'info')

timewin = [0, 1600];
thetalabel = 'cf';

experiment = 'FR1';

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    
    disp([num2str(isubj) ' ' subject])
    
    % Load info about channels and time.
    [~, trialinfo, chans] = kah_loadftdata(info, subject, ['thetaphase_' thetalabel], timewin, 0);    
    nchan = length(chans);
    ntrial = size(trialinfo, 1);
    
    % Get all unique pairs of channels. 
    chanpairs = nchoosek(1:nchan, 2);    
    nchanpair = size(chanpairs, 1);
    
    % Initialize to store all channel pairs.
    pacbetween = nan(nchanpair, ntrial, 2, 201);

    for ipair = 1:nchanpair
        if mod(ipair, 50) == 0, disp([num2str(ipair) '/' num2str(nchanpair)]), end
        % Load individual channel pair.
        input = load([info.path.processed.cluster 'tspac/' thetalabel '/' subject '_FR1_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_pair_' num2str(ipair) '_resamp.mat']);
        
        % Save individual channel pairs.
        pacbetween(ipair, :, :, :) = input.pacbetween;
    end
    
    % Save.
    save([info.path.processed.hd subject '/pac/ts/' thetalabel '/' subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacbetween', 'chanpairs', 'trialinfo', 'chans')
end