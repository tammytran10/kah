clear; clc

info = kah_info;

%%
clearvars('-except', 'info')

type = 'cmtest';
timewin = [-800, 1600];

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    
    disp([num2str(isubj) ' ' subject])
    
    % Load info about channels and time.
    [~, trialinfo, chans, times] = kah_loadftdata(info, subject, 'thetaphase', timewin, 0);    
    nchan = length(chans);
    nsamp = length(times);
    
    % Get all unique pairs of channels. 
    chanpairs = nchoosek(1:nchan, 2);    
    nchanpair = size(chanpairs, 1);
    
    % Initialize to store all channel pairs.
    [statA, statB, statbetween, pvalA, pvalB, pvalbetween] = deal(nan(nchanpair, nsamp));

    for ipair = 1:nchanpair
        % Load individual channel pair.
        input = load([info.path.processed.cluster subject '_FR1_phaseencode_' type '_' num2str(timewin(1)) '_' num2str(timewin(2)) '_pair_' num2str(ipair) '_nosamp.mat']);
        
        % Save individual channel pairs.
        varnames = fieldnames(input);       
        for ivar = 1:length(varnames)
            varcurr = varnames{ivar};
            eval([varcurr '(ipair, :) = input.' varcurr ';'])
        end
    end
    
    % Save.
    save([info.path.processed.hd subject '_' experiment '_phaseencode_' type '_' num2str(timewin(1)) '_' num2str(timewin(2)) '_nosamp.mat'], 'statA', 'statB', 'statbetween', 'pvalA', 'pvalB', 'pvalbetween', 'chanpairs', 'times', 'trialinfo', 'chans')
end