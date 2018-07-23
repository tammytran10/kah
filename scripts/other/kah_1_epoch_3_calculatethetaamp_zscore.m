% Script for calculating average theta amplitude over a time window.
clear; clc

info = kah_info;

%%
experiment = 'FR1';
timewins = {[-800, 0], [0, 800], [800, 1600]};
thetalabel = 'canon';

[thetaamp_all, times_all] = deal(cell(length(info.subj), 1));

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])

    % Load theta amplitude and channel/trial info.
    [thetaamp_all{isubj}, ~, chans, times] = kah_loadftdata(info, subject, ['thetaamp_' thetalabel], [-800, 1600], 1);
    
    % Z-score across baseline and encoding periods.
    thetaamp_all{isubj} = zscore(reshape(thetaamp_all{isubj}, length(chans), []), [], 2);
    thetaamp_all{isubj} = reshape(thetaamp_all{isubj}, length(chans), length(times), []);
    
    times_all{isubj} = times;
end

for iwin = 1:length(timewins)
    timewin = timewins{iwin};
    
    thetaamp = cell(length(info.subj), 1);
    
    for isubj = 1:length(info.subj)
        % Average theta amplitude over the first half of the encoding window.
        toi = dsearchn(times_all{isubj}(:), timewin(:)./1000);
        thetaamp{isubj} = squeeze(mean(thetaamp_all{isubj}(:, toi(1):toi(2), :), 2));
    end
    save([info.path.processed.hd 'FR1_thetaamp_' thetalabel '_' num2str(timewin(1)) '_' num2str(timewin(2)) '_zscore.mat'], 'thetaamp')
end
disp('Done.')