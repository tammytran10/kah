
%%
dir1 = squeeze(median(pacbetween(:, :, 1, :), 2));
dir2 = squeeze(median(pacbetween(:, :, 2, :), 2));

pval1 = (sum(dir1(:, end) < dir1(:, 1:nsurrogate), 2) + 1) ./ (nsurrogate + 1);
pval2 = (sum(dir2(:, end) < dir2(:, 1:nsurrogate), 2) + 1) ./ (nsurrogate + 1);

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

%%
pairnum = 1;
trialnum = 1; 
direction = 1;

(sum(pacbetween(pairnum, trialnum, direction, end) < pacbetween(pairnum, trialnum, direction, 1:nsurrogate)) + 1) ./ (nsurrogate + 1)

%%
pairnum = 9;
pac = (sum(pacbetween(pairnum, :, direction, end) < pacbetween(pairnum, :, direction, 1:nsurrogate), 4) + 1) ./ (nsurrogate + 1) < 0.05;
mean(pac)
sum(trialinfo(pac, 3)) ./ sum(pac)


