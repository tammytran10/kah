clear; close all

info = kah_info;

%%
clearvars('-except', 'info')

% Set windows for a pre-trial baseline period and an post-stimulus encoding period.
baseline_time = [-800, 0];
encoding_time = [0, 800];

[hfabaseline, hfaencoding, hfapval] = deal(cell(length(info.subj), 1));

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp(subject)

    % Load data.
    [hfaamp, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'hfa', [-800, 1600], 1);

    % Get indicies of time windows.
    baseline_ind = dsearchn(times(:), baseline_time(:)./1000);
    encoding_ind = dsearchn(times(:), encoding_time(:)./1000);

    % Get average HFA across time windows.
    hfabaseline{isubj} = squeeze(mean(hfaamp(:, baseline_ind(1):baseline_ind(2), :), 2));
    hfaencoding{isubj} = squeeze(mean(hfaamp(:, encoding_ind(1):encoding_ind(2), :), 2));
    
    % For each channel, determine if HFA during encoding is significantly higher than during baseline.
    hfapval{isubj} = nan(length(chans), 1);
    for ichan = 1:length(chans)
        baseline_chancurr = hfabaseline{isubj}(ichan, :);
        encoding_chancurr = hfaencoding{isubj}(ichan, :);
        hfapval{isubj}(ichan) = ranksum(encoding_chancurr, baseline_chancurr);
    end
end

% Save baseline activity.
hfa = hfabaseline;
save([info.path.processed.hd 'FR1_hfa_' num2str(baseline_time(1)) '_' num2str(baseline_time(2)) '.mat'], 'hfa', 'hfapval')

% Save encoding activity.
hfa = hfaencoding;
save([info.path.processed.hd 'FR1_hfa_' num2str(encoding_time(1)) '_' num2str(encoding_time(2)) '.mat'], 'hfa', 'hfapval')
disp('Done.')