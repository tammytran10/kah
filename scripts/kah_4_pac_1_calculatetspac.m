clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

% if isempty(gcp), parpool('local', 2); end % open up second pool

% Set experiment.
experiment = 'FR1';

% Set number of resampling runs.
nsurrogate = 100;

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    % Choose time window.
    timewin = [0, 1600]; % ms
    
    % Skip subject if all permutations have already been run.
    if exist([info.path.processed.hd subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp_' num2str(nsurrogate) '.mat'], 'file')
        disp(['Skipping ' subject])
        continue
    end
    
    disp([num2str(isubj) ' ' subject])
    
    % Load subject theta phase and HFA data.
    [thetaphase, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'thetaphase', timewin, 1);
    hfaamp = kah_loadftdata(info, subject, 'hfa', timewin, 1);
    
    ntrial = size(trialinfo, 1);
    encoding = trialinfo(:, 3);
    nchan = length(chans);
    nsamp = length(times);
    
    % Calculate within-channel PAC per channel and trial, + surrogate shifts.
    pacwithin = nan(nchan, ntrial, nsurrogate + 1);
    shifts = nan(nchan, ntrial, nsurrogate);
    for ichan = 1:nchan
        for itrial = 1:ntrial
            phasecurr = squeeze(thetaphase(ichan, :, itrial));
            ampcurr = squeeze(hfaamp(ichan, :, itrial));
            [pacwithin(ichan, itrial, end), pacwithin(ichan, itrial, 1:nsurrogate), shifts(ichan, itrial, :)] = calculatepac(phasecurr, ampcurr, 'ozkurt');
        end
    end
    save([info.path.processed.hd subject '_' experiment '_pac_within_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacwithin', 'trialinfo', 'chans', 'shifts')
    clear pacwithin shifts
    
    % Get all unique pairs of channels.
    chanpairs = nchoosek(1:nchan, 2);
    nchanpair = size(chanpairs, 1);
    
    % Calculate between-channel PAC in both directions for all channel pairs and trials, + shifted surrogates.    
    pacbetween = nan(nchanpair, ntrial, 2, nperm + 1);
    shifts = nan(nchanpair, ntrial, 2, nperm);
    
    for idirection = 1:2
        % Switch phase and amp data based on direction.
        if idirection == 1
            phasechan = 1; ampchan = 2;
        else
            phasechan = 2; ampchan = 1;
        end
        
        for ipair = 1:nchanpair
            for itrial = 1:ntrial
                phasecurr = squeeze(thetaphase(chanpairs(ipair, phasechan), :, itrial));
                ampcurr = squeeze(hfaamp(chanpairs(ipair, phasechan), :, itrial));
                [pacbetween(ipair, itrial, end), pacbetween(ipair, itrial, 1:nperm), shifts(ipair, itrial, :)] = calculatepac(phasecurr, ampcurr, 'ozkurt');
            end
        end
    end
    
    % Save.
    save([info.path.processed.hd subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacbetween', 'chanpairs', 'shifts', 'trialinfo', 'chans')
end

disp('Done.')
