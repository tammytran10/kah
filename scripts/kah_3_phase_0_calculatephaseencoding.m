clear

% Load Kahana info.
info = kah_info;

%
clearvars('-except', 'info')

testtype = 'corrcl'; % options corrcl, wwtest, and cmtest
thetalabel = 'cf';

% Set experiment.
experiment = 'FR1';

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    disp([num2str(isubj) ' ' subject])

    % Load subject theta phase data.
    [dat, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, ['thetaphase_' thetalabel], [-800, 1600], 1);
    
    encoding = logical(trialinfo(:, 3));
    nchan = length(chans);
    nsamp = length(times);

    % Get all unique pairs of channels. 
    chanpairs = nchoosek(1:nchan, 2);    
    nchanpair = size(chanpairs, 1);

    % Initialize.
    [statA, statB, statbetween, pvalA, pvalB, pvalbetween] = deal(nan(nchanpair, nsamp));

    % For each channel pair, determine the extent to which the phase of either
    % channel (or the phase difference between channels) predicts
    % remembered/forgotten.
    for ipair = 1:nchanpair
        disp([num2str(isubj) ' ' subject ' ' num2str(ipair) '/' num2str(nchanpair)])
        
        datA = squeeze(dat(chanpairs(ipair, 1),:,:));
        datB = squeeze(dat(chanpairs(ipair, 2),:,:));
        
        [statA(ipair, :, :), statB(ipair, :, :), statbetween(ipair, :, :),...
            pvalA(ipair, :, :), pvalB(ipair, :, :), pvalbetween(ipair, :, :)] ...
            = kah_calculatephaseencode(datA, datB, encoding, testtype, []);
    end

    % Save.
    save([info.path.processed.hd subject '/phase/' thetalabel '/' subject '_' experiment '_phaseencode_' testtype '_-800_1600_nosamp.mat'], 'statA', 'statB', 'statbetween', 'pvalA', 'pvalB', 'pvalbetween', 'chanpairs', 'times', 'trialinfo', 'chans')
end
disp('Done.')
