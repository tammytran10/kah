clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

rng('default')

% Set experiment.
experiment = 'FR1';

% Set number of resampling runs.
nperm = 100;

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
    shifttrials{isubj} = ceil(nsamp * rand([nchan, ntrial, nperm]));
end

save([info.path.processed.hd experiment '_trialshifts_default_pac.mat'], 'shifttrials')
disp('Done.')
