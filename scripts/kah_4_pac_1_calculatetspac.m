clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

% if isempty(gcp), parpool('local', 2); end % open up second pool

% Set experiment.
experiment = 'FR1';

% Set number of resampling runs.
load([info.path.processed.hd experiment '_trialshifts_default_pac.mat'], 'shifttrials')
nperm = size(subtrials, 3);

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    % Choose time window.
    timewin = [0, 1600]; % ms
    
    % Skip subject if all permutations have already been run.
    if exist([info.path.processed.hd subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp_' num2str(nperm) '.mat'], 'file')
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
    
    % Calculate within-channel PAC.
    pacwithin = nan(nchan, ntrial, nperm);
    for ichan = 1:nchan
        for itrial = 1:ntrial
            for iperm = 1:nperm + 1
                if iperm > nperm
                    shift = 1:nsamp;
                else
                    shift = shifttrials{isubj}(ichan, itrial, iperm);
                    shift = [shift:nsamp, 1:shift - 1];
                end
                phasecurr = squeeze(thetaphase(ichan, :, itrial));
                ampcurr = squeeze(hfaamp(ichan, shift, itrial));
                pacwithin(ichan, itrial, iperm) = pac_calculateozkurt(phasecurr, ampcurr);
            end
        end
    end
    
    save([info.path.processed.hd subject '_' experiment '_pac_within_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacwithin', 'times', 'trialinfo', 'chans')
    clear pacwithin
    
    % Get all unique pairs of channels.
    chanpairs = nchoosek(1:nchan, 2);
    nchanpair = size(chanpairs, 1);
    
    % Calculate between-channel PAC in both directions for all channel pairs and trial subsets.
    for iperm = 1:nperm
        % Skip permutation if already run.
        filecurr = [info.path.processed.hd subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp_' num2str(iperm) '.mat'];
        if exist(filecurr, 'file')
            disp(['Skipping ' subject ' ' num2str(iperm) '/' num2str(nperm)])
            continue
        end
        
        % Calculate separately for correct and incorrect trials.
        pacbetween = nan(nchanpair, ntrial, 2, nperm);
        
        % Switch phase and amp data based on direction.
        for idirection = 1:2
            if idirection == 1
                phasechan = 1; ampchan = 2;
            else
                phasechan = 2; ampchan = 1;
            end
            
            for ipair = 1:nchanpair
                if iperm > nperm
                    shift = 1:nsamp;
                else
                    shift = shifttrials{isubj}(ichan, itrial, iperm);
                    shift = [shift:nsamp, 1:shift - 1];
                end
                phasecurr = squeeze(thetaphase(chanpairs(ipair, phasechan), :, itrial));
                ampcurr = squeeze(hfaamp(chanpairs(ipair, ampchan), shift, itrial));
                pacbetween(ipair, itrial, idirection, iperm) = pac_calculateozkurt(phasecurr, ampcurr);
            end
        end
    
        % Save.
        save(filecurr, 'pacbetween', 'chanpairs', 'times', 'trialinfo', 'chans')
    end
end
disp('Done.')
