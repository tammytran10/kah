clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

% Load canonical or individualized theta data.
thetalabel = 'cf';

% Set experiment.
experiment = 'FR1';

% Choose time window.
timewin = [0, 800]; % ms
   
% Set number of resampling runs.
load([info.path.processed.hd experiment '_pac_within_ts_trialshifts_default_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'shifttrials')
nsurrogate = size(shifttrials{1}, 3);

for isubj = 1:length(info.subj)    
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    
    % Skip subject if all permutations have already been run.
    filecurr = [info.path.processed.hd subject '/pac/ts/' thetalabel '/' subject '_' experiment '_pac_within_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'];
    if exist(filecurr, 'file')        
        disp(['Skipping ' subject])
        continue
    end
    
    disp([num2str(isubj) ' ' subject])
    
    % Load subject theta phase and HFA data.
    [thetaphase, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, ['thetaphase_' thetalabel], timewin, 1);
    hfaamp = kah_loadftdata(info, subject, 'hfa', timewin, 1);
    
    ntrial = size(trialinfo, 1);
    encoding = trialinfo(:, 3);
    nchan = length(chans);
    nsamp = length(times);
    
    % Calculate within-channel PAC per channel and trial, + surrogate shifts.
    pacwithin = nan(nchan, ntrial, nsurrogate + 1);
    for ichan = 1:nchan
        disp([num2str(isubj) ' ' num2str(ichan) '/' num2str(nchan)])
        for itrial = 1:ntrial
            phasecurr = squeeze(thetaphase(ichan, :, itrial));
            ampcurr = squeeze(hfaamp(ichan, :, itrial));
            [pacwithin(ichan, itrial, end), pacwithin(ichan, itrial, 1:nsurrogate)] = calculatepac(phasecurr, ampcurr, 'ozkurt', shifttrials{isubj}(ichan, itrial, :));
        end
    end
    save(filecurr, 'pacwithin', 'trialinfo', 'chans')
end
disp('Done.')
