[hfabaseline, hfaencoding, hfapval] = deal(cell(length(info.subj), 1));

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    timewin = [-800, 1600];

    [hfaamp, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'hfa', timewin, 1);

    baseline = dsearchn(times(:), [-0.8; 0]);
    toi = dsearchn(times(:), [0; 0.8]);

    hfabaseline{isubj} = squeeze(mean(hfaamp(:, baseline(1):baseline(2), :), 2));
    hfaencoding{isubj} = squeeze(mean(hfaamp(:, toi(1):toi(2), :), 2));
    
    hfapval{isubj} = nan(length(chans), 1);
    for ichan = 1:length(chans)
        baselinecurr = hfabaseline{isubj}(ichan, :);
        encodingcurr = hfaencoding{isubj}(ichan, :);
        hfapval{isubj}(ichan) = ranksum(encodingcurr, baselinecurr);
    end
end
save([info.path.processed.hd 'FR1_hfa.mat'], 'hfabaseline', 'hfaencoding', 'hfapval')

%%
figure; 
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    timewin = [-800, 1600];

    [hfaamp, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'hfa', timewin, 1);

    subplot(4, 5, isubj)
    plot(times, mean(hfaamp, 3))
end

%%


pvals = nan(length(chans), 1);
for ichan = 1:length(chans)
    baselinecurr = squeeze(mean(hfaamp(ichan, baseline(1):baseline(2), :), 2));
    encodingcurr = squeeze(mean(hfaamp(ichan, toi(1):toi(2), :), 2));
    pvals(ichan) = ranksum(encodingcurr, baselinecurr, 'tail', 'right');
%     pvals(ichan) = signrank(stimcurr, 0, 'tail', 'right');
end
sum(pvals < 0.05/length(chans))