clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

% Set experiment.
experiment = 'FR1';

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    filecurr = ['/Volumes/voyteklab/tamtra/data/KAH/hfaamp/' subject '_' experiment '_hfaamp.mat'];

%     if exist(filecurr, 'file')
%         continue
%     end
        
    disp([num2str(isubj) ' ' subject])

    % Load subject data.
    [data, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'hfa', [-800, 1600], 1);
    return
    save(filecurr, 'data', 'chans', 'times', 'trialinfo')
end