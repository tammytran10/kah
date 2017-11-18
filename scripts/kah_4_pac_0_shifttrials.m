clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

rng('default')

% Set experiment.
experiment = 'FR1';

% Set number of resampling runs.
nperm = 200;

% For number of sample to shift one time series by.
shifttrials = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    disp([num2str(isubj) ' ' subject])
    
    % Load subject HFA data.
    [~, trialinfo, chans, times] = kah_loadftdata(info, subject, 'hfa', [0, 1600], 0);
    ntrial = size(trialinfo, 1);
    nchan = length(chans);
    nsamp = length(times);
    
    % Generate random sample shifts.
    shifts = nan(nchan, ntrial, nperm);
    for ichan = 1:nchan
        for itrial = 1:ntrial
            shifts(ichan, itrial, :) = randperm(nsamp - 1, nperm) + 1;
        end
    end
    shifttrials{isubj} = shifts;
end

save([info.path.processed.hd experiment '_trialshifts_default_pac_within_ts.mat'], 'shifttrials')
disp('Done.')