clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

% Load canonical or individualized theta data.
thetalabel = 'cf';

% Set experiment.
experiment = 'FR1';

for isubj = 1:length(info.subj)    
    % Get current subject identifier.
    subject = info.subj{isubj};
   
    disp([num2str(isubj) ' ' subject])
    
    % Load subject theta phase, reformat, and save.
    [data, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, ['thetaphase_' thetalabel], [-800, 1600], 1);
    disp('Saving theta')
    save(['/Volumes/voyteklab/tamtra/data/KAH/thetaphase/' subject '_FR1_thetaphase_' thetalabel '_-800_1600.mat'], 'data', 'trialinfo', 'chans', 'times')
        
    % Load subject HFA, reformat, and save.
    [data, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'hfa', [-800, 1600], 1);
    disp('Saving HFA')
    save(['/Volumes/voyteklab/tamtra/data/KAH/hfa/' subject '_FR1_hfa_-800_1600.mat'], 'data', 'trialinfo', 'chans', 'times')
    
    % Copy trialshifts.
    copyfile([info.path.processed.hd subject '/pac/ts/' subject '_' experiment '_pac_between_ts_trialshifts_default_-800_0.mat'], ...
        '/Volumes/voyteklab/tamtra/data/KAH/shifttrials/')
    copyfile([info.path.processed.hd subject '/pac/ts/' subject '_' experiment '_pac_between_ts_trialshifts_default_0_800.mat'], ...
        '/Volumes/voyteklab/tamtra/data/KAH/shifttrials/')
    copyfile([info.path.processed.hd subject '/pac/ts/' subject '_' experiment '_pac_between_ts_trialshifts_default_800_1600.mat'], ...
        '/Volumes/voyteklab/tamtra/data/KAH/shifttrials/')
end
disp('Done.')
