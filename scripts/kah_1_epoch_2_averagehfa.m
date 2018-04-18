clear; close all

info = kah_info;

%%
clearvars('-except', 'info')

% Set windows for a pre-trial baseline period and an post-stimulus encoding period.
baseline_time = [-800, 0];
early_encoding_time = [0, 800];
late_encoding_time = [800, 1600];

[hfa_baseline, hfa_early_encoding, hfa_late_encoding, hfa_pval] = deal(cell(length(info.subj), 1));

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp(subject)

    % Load data.
    [hfaamp, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'hfa', [-800, 1600], 1);

    % Get indicies of time windows.
    baseline_ind = dsearchn(times(:), baseline_time(:)./1000);
    early_encoding_ind = dsearchn(times(:), early_encoding_time(:)./1000);
    late_encoding_ind = dsearchn(times(:), late_encoding_time(:)./1000);

    % Get average HFA across time windows.
    hfa_baseline{isubj} = squeeze(mean(hfaamp(:, baseline_ind(1):baseline_ind(2), :), 2));
    hfa_early_encoding{isubj} = squeeze(mean(hfaamp(:, early_encoding_ind(1):early_encoding_ind(2), :), 2));
    hfa_late_encoding{isubj} = squeeze(mean(hfaamp(:, late_encoding_ind(1):late_encoding_ind(2), :), 2));
    
    % For each channel, determine if HFA during encoding is significantly higher than during baseline.
    hfa_pval{isubj} = nan(length(chans), 1);
    for ichan = 1:length(chans)
        baseline_chancurr = hfa_baseline{isubj}(ichan, :);
        encoding_chancurr = hfa_early_encoding{isubj}(ichan, :);
        hfa_pval{isubj}(ichan) = ranksum(encoding_chancurr, baseline_chancurr);
    end
end

% % Save baseline activity.
% hfa = hfa_baseline;
% save([info.path.processed.hd 'FR1_hfa_' num2str(baseline_time(1)) '_' num2str(baseline_time(2)) '.mat'], 'hfa', 'hfapval')
% 
% % Save encoding activity.
% hfa = hfa_early_encoding;
% save([info.path.processed.hd 'FR1_hfa_' num2str(early_encoding_time(1)) '_' num2str(early_encoding_time(2)) '.mat'], 'hfa', 'hfapval')

% Save encoding activity.
hfa = hfa_late_encoding;
save([info.path.processed.hd 'FR1_hfa_' num2str(late_encoding_time(1)) '_' num2str(late_encoding_time(2)) '.mat'], 'hfa', 'hfa_pval')
disp('Done.')