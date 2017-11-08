% Script for combining the multiple gamma bands from kah_1_epoch_0_epochtrials.m into one HFA signal.
% Individual bands are z-scored, then averaged together.

clear; clc

info = kah_info;

experiment = 'FR1';

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])

    [gammaamp, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'gammaamp', [-800, 1600], 1);

    % Pre-allocate data running sum, format (channel x time x trial).
    hfa = zeros(length(chans), length(times), size(trialinfo, 1));

    for iband = 1:length(gammaamp)
        % Z-score individually per channel and across all trials.
        bandcurr = zscore(reshape(gammaamp{iband}, length(chans), []), [], 2);
        bandcurr = reshape(bandcurr, length(chans), length(times), []);

        % Add z-scores to running sum.
        hfa = hfa + bandcurr;
    end
    % Average together z-scores from different bands.
    hfa = hfa ./ length(gammaamp);

    % Save HFA amplitude.
    save([info.path.processed.hd subject '_' experiment '_hfa_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'hfa', 'timewin', 'trialinfo', 'times', 'chans', 'temporal', 'frontal', '-v7.3')
end
disp('Done.')