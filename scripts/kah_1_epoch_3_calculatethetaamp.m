% Script for calculating average theta amplitude over a time window.
clear; clc

info = kah_info;

%%
experiment = 'FR1';
timewin = [0, 800];
thetalabel = 'cf';

thetaamp = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])

    % Load theta amplitude and channel/trial info.
    [thetaamp{isubj}, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, ['thetaamp_' thetalabel], [-800, 1600], 1);
    
    % Z-score across baseline and encoding periods.
    thetaamp{isubj} = zscore(reshape(thetaamp{isubj}, length(chans), []), [], 2);
    thetaamp{isubj} = reshape(thetaamp{isubj}, length(chans), length(times), []);
        
    % Average theta amplitude over the first half of the encoding window.
    toi = dsearchn(times(:), timewin(:)./1000);
    thetaamp{isubj} = squeeze(mean(thetaamp{isubj}(:, toi(1):toi(2), :), 2));
end
save([info.path.processed.hd 'FR1_thetaamp_' thetalabel '_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'thetaamp')
disp('Done.')