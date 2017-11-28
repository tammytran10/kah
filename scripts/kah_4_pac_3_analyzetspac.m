clear

info = kah_info;

%%
clearvars('-except', 'info')

experiment = 'FR1';
timewin = [0, 1600];
nsurrogate = 200;

subject = info.subj{1};

load([info.path.processed.hd subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacbetween', 'chanpairs', 'trialinfo', 'chans', 'temporal', 'frontal')

%%
dir1 = squeeze(median(pacbetween(:, :, 1, :), 2));
dir2 = squeeze(median(pacbetween(:, :, 2, :), 2));

pval1 = (sum(dir1(:, end) > dir1(:, 1:nsurrogate), 2) + 1) ./ (nsurrogate + 1);
pval2 = (sum(dir2(:, end) > dir2(:, 1:nsurrogate), 2) + 1) ./ (nsurrogate + 1);

ttpairs = all(temporal(chanpairs), 2);
ttpac = pval1(ttpairs) < 0.05 | pval2(ttpairs) < 0.05;

ffpairs = all(frontal(chanpairs) , 2);
ffpac = pval1(ffpairs) < 0.05 | pval2(ffpairs) < 0.05;

[tfpairs, tfpac, ftpac] = deal(zeros(size(chanpairs, 1), 1));
for ipair = 1:size(chanpairs, 1)
    if temporal(chanpairs(ipair, 1)) && frontal(chanpairs(ipair, 2))
        tfpairs(ipair) = 1;
        tfpac(ipair) = pval1(ipair) < 0.05;
        ftpac(ipair) = pval2(ipair) < 0.05;
    elseif frontal(chanpairs(ipair, 1)) && temporal(chanpairs(ipair, 2))
        tfpairs(ipair) = 1;
        tfpac(ipair) = pval2(ipair) < 0.05;
        ftpac(ipair) = pval1(ipair) < 0.05;
    end
end

tspac = 