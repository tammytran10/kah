clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

rng('default')

% if isempty(gcp), parpool('local', 2); end % open up second pool

% Set experiment.
experiment = 'FR1';

% Set number of resampling runs.
load([info.path.processed.hd experiment '_trialshifts_default_pac_within_ts.mat'], 'shifttrials')
nsurrogate = size(shifttrials{1}, 3);

for isubj = 1:length(info.subj)    
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    % Choose time window.
    timewin = [0, 1600]; % ms
    
    % Skip subject if all permutations have already been run.
%     if exist([info.path.processed.hd subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp_' num2str(nsurrogate) '.mat'], 'file')
    if exist([info.path.processed.hd subject '_' experiment '_pac_within_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'file')        
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
%     shifts = nan(nchan, ntrial, nsurrogate);
    for ichan = 1:nchan
        for itrial = 1:ntrial
            phasecurr = squeeze(thetaphase(ichan, :, itrial));
            ampcurr = squeeze(hfaamp(ichan, :, itrial));
%             [pacwithin(ichan, itrial, end), pacwithin(ichan, itrial, 1:nsurrogate), shifts(ichan, itrial, :)] = calculatepac(phasecurr, ampcurr, 'ozkurt', nsurrogate);
            [pacwithin(ichan, itrial, end), pacwithin(ichan, itrial, 1:nsurrogate)] = calculatepac(phasecurr, ampcurr, 'ozkurt', shifttrials{isubj}(ichan, itrial, :));
        end
    end
    save([info.path.processed.hd subject '_' experiment '_pac_within_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacwithin', 'trialinfo', 'chans')
    clear pacwithin shifts
    
    continue
    
    % Get all unique pairs of channels.
    chanpairs = nchoosek(1:nchan, 2);
    nchanpair = size(chanpairs, 1);
    
    % Calculate between-channel PAC in both directions for all channel pairs and trials, + shifted surrogates.    
    pacbetween = nan(nchanpair, ntrial, 2, nsurrogate + 1);
    shifts = nan(nchanpair, ntrial, 2, nsurrogate);
    
    for idirection = 1:2
        % Switch phase and amp data based on direction.
        if idirection == 1
            phasechan = 1; ampchan = 2;
        else
            phasechan = 2; ampchan = 1;
        end
        
        for ipair = 1:nchanpair
            disp([num2str(isubj) ' ' subject ' ' num2str(ipair) '/' num2str(nchanpair) ' ' num2str(idirection)])
            for itrial = 1:ntrial
                phasecurr = squeeze(thetaphase(chanpairs(ipair, phasechan), :, itrial));
                ampcurr = squeeze(hfaamp(chanpairs(ipair, phasechan), :, itrial));
                [pacbetween(ipair, itrial, idirection, end), pacbetween(ipair, itrial, idirection, 1:nsurrogate), shifts(ipair, itrial, idirection, :)] = calculatepac(phasecurr, ampcurr, 'ozkurt', nsurrogate);
            end
        end
    end
    
    % Save.
    save([info.path.processed.hd subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacbetween', 'chanpairs', 'shifts', 'trialinfo', 'chans')
end

disp('Done.')
