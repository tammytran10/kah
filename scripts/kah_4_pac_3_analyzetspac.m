clear

info = kah_info;

%%
clearvars('-except', 'info')

experiment = 'FR1';
timewin = [0, 1600];
nsurrogate = 200;

directions = {'AB', 'BA'};

tspac = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])
    
    load([info.path.processed.hd subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacbetween', 'chanpairs', 'trialinfo', 'chans', 'temporal', 'frontal')

    tspac{isubj} = struct;
    
    for idirection = 1:length(directions)
        rawtspac = squeeze(pacbetween(:, :, idirection, end));
        tspac{isubj}.(directions{idirection}).raw = rawtspac;

        surrtspac = squeeze(pacbetween(:, :, idirection, 1:nsurrogate));
        
        tspac{isubj}.(directions{idirection}).norm = (rawtspac - mean(surrtspac, 3)) ./ std(surrtspac, [], 3);

        tspac{isubj}.(directions{idirection}).pvaltrial = ((sum(rawtspac < surrtspac, 3) + 1) ./ (nsurrogate + 1));

        tspac{isubj}.(directions{idirection}).pvalpair = sum(median(rawtspac, 2) < squeeze(median(surrtspac, 2)), 2) ./ (nsurrogate + 1);    
    end
end

save([info.path.processed.hd 'FR1_tspac_between_0_1600.mat'], 'tspac')

%%
clearvars('-except', 'info')

experiment = 'FR1';
timewin = [0, 1600];
nsurrogate = 200;

tspac = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])
    
    load([info.path.processed.hd subject '_' experiment '_pac_within_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacwithin', 'trialinfo', 'chans')

    tspac{isubj} = struct;
    
    rawtspac = squeeze(pacwithin(:, :, end));
    tspac{isubj}.raw = rawtspac;

    surrtspac = squeeze(pacwithin(:, :, 1:nsurrogate));

    tspac{isubj}.norm = (rawtspac - mean(surrtspac, 3)) ./ std(surrtspac, [], 3);

    tspac{isubj}.pvaltrial = ((sum(rawtspac < surrtspac, 3) + 1) ./ (nsurrogate + 1));

    tspac{isubj}.pvalpair = sum(median(rawtspac, 2) < squeeze(median(surrtspac, 2)), 2) ./ (nsurrogate + 1);    
end

save([info.path.processed.hd 'FR1_tspac_within_0_1600.mat'], 'tspac')

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


