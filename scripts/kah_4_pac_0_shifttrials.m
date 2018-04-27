%% FOR WITHIN-CHANNEL TSPAC
clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

rng('default')

% Set experiment.
experiment = 'FR1';

% Set time window.
timewin = [0, 800];

% Set number of resampling runs.
nperm = 200;

% For number of sample to shift one time series by.
shifttrials = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    disp([num2str(isubj) ' ' subject])
    
    % Load subject HFA data.
    [~, trialinfo, chans, times] = kah_loadftdata(info, subject, 'hfa', timewin, 0);
    ntrial = size(trialinfo, 1);
    nchan = length(chans);
    nsamp = length(times);
    
    % Generate random sample shifts.
    shifts = nan(nchan, ntrial, nperm);
    for ipair = 1:nchan
        for itrial = 1:ntrial
            shifts(ipair, itrial, :) = randperm(nsamp - 1, nperm) + 1;
        end
    end
    shifttrials{isubj} = shifts;
end

save([info.path.processed.hd experiment '_pac_within_ts_trialshifts_default_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'shifttrials')
disp('Done.')

%% FOR BETWEEN-CHANNEL TSPAC
clear

% Load Kahana info.
info = kah_info;

clearvars('-except', 'info')

rng('default')

% Set experiment.
experiment = 'FR1';

% Set time window.
timewin = [0, 800];

% Set number of resampling runs.
nperm = 200;

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    disp([num2str(isubj) ' ' subject])
    
    % Load subject HFA data.
    [~, trialinfo, chans, times] = kah_loadftdata(info, subject, 'hfa', timewin, 0);
    ntrial = size(trialinfo, 1);
    nchan = length(chans);
    nsamp = length(times);
    
    chanpairs = nchoosek(1:nchan, 2);
    nchanpair = size(chanpairs, 1);
    
    % Generate random sample shifts.
    shifttrials = nan(nchanpair, ntrial, 2, nperm);
    for ipair = 1:nchanpair
        for itrial = 1:ntrial
            for idirection = 1:2
                shifttrials(ipair, itrial, idirection, :) = randperm(nsamp - 1, nperm) + 1;
            end
        end
    end
    save([info.path.processed.hd subject '/pac/ts/' subject '_' experiment '_pac_between_ts_trialshifts_default_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'shifttrials')
    save([info.path.processed.hd subject '/pac/ts/' subject '_' experiment '_pac_between_ts_trialshifts_default_-800_0.mat'], 'shifttrials')
    save([info.path.processed.hd subject '/pac/ts/' subject '_' experiment '_pac_between_ts_trialshifts_default_800_1600.mat'], 'shifttrials')
end
disp('Done.')