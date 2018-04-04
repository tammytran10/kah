
%%
% For checking the effects of the time threshold.

timethresh = 0.01:0.01:0.3; % time thresholds to try.

% Pre-allocate for saving the percent channel pairs and individual channels that show an encoding episode.
[percentpairs, percentchans] = deal(nan(length(info.subj), length(timethresh)));

for isubj = 1:length(info.subj)   
    disp(info.subj{isubj})
    for itime = 1:length(timethresh)
        encoding = kah_getphaseencoding(info, info.subj{isubj}, 'corrcl', 'time', timethresh(itime), 'pvalue', [0, 1.6], 'all');
        percentpairs(isubj, itime) = encoding.percentpair;
        percentchans(isubj, itime) = encoding.percentchan;
    end
end


%%
figure;

for itime = 1:length(timethresh)
    subplot(5, 6, itime)
    hist(percentpairs(:, itime))
    title(num2str(timethresh(itime)))
end

%%
[~, sortind] = sort(percentpairs);
recall = cellfun(@mean, encoding);

for thresh = 1:30
%     figure; scatter(percentpairs(:, thresh), recall)
[rho, pval] = corr(percentpairs(:, thresh), recall, 'type', 'Spearman')
end
%%
pairnum = 80;

figure(3); clf; hold on
plot(times, statbetween(pairnum, :))

threshep = encodingtimesubj{pairnum};
for iep = 1:size(threshep, 1)
    plot(times(threshep(iep, 1):threshep(iep, 2)), statbetween(pairnum, threshep(iep, 1):threshep(iep, 2)), 'r')
end
ylim([0, 0.3])
     
% [freq, powspec] = util_taperpsd(statbetween(pairnum, :)', info.(subject).fs, size(statbetween, 2), 'hanning');
% figure; plot(freq, powspec) 
        %%
onset = cellfun(@(x) min(min(x)), encodingtimesubj, 'UniformOutput', false);
onset(cellfun(@isempty, onset)) = {nan};
onset = cell2mat(onset);

encodingstrengthsubj = cellfun(@(x) mean(cell2mat(x)), encodingstrengthsubj);
