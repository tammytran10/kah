clearvars('-except', 'info')

load([info.path.processed.hd 'FR1_thetabands_0_1600_trials.mat'], 'amplitudes')

thetapvals = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    nchan = size(amplitudes{isubj}, 1);
    
    for ichan = 1:nchan
        ampcurr = amplitudes{isubj}(ichan, :);
        thetapvals{isubj}(ichan) = myBinomTest(sum(ampcurr > 0), length(ampcurr), 0.5, 'two');
    end
end

%%
save([info.path.processed.hd 'FR1_thetabands_0_1600_trials.mat'], 'amplitudes', 'thetapvals')
%%
pvals = nan(size(amplitudes{1}, 1), 1);
for ichan = 1:size(amplitudes{1}, 1)
    x = amplitudes{1}(ichan,:);
    thetabump = sum(x > 0);
    notheta = sum(x == 0);

    pvals(ichan) = myBinomTest(thetabump, length(x), 0.5, 'two');
end

sum(pvals < 0.05/length(pvals))