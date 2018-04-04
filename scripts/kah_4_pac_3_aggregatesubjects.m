clear

info = kah_info;

%%
clearvars('-except', 'info')

experiment = 'FR1';
timewin = [0, 1600];
nsurrogate = 200;
thetalabel = 'cf';

directions = {'AB', 'BA'};

tspac = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])
    
    load([info.path.processed.hd subject '/pac/ts/' thetalabel '/' subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacbetween', 'chanpairs', 'trialinfo', 'chans', 'temporal', 'frontal')

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

save([info.path.processed.hd 'FR1_pac_between_ts_0_1600_' thetalabel '.mat'], 'tspac')

%%
clearvars('-except', 'info')

experiment = 'FR1';
timewin = [0, 1600];
nsurrogate = 200;

tspac = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])
    
    load([info.path.processed.hd subject '/pac/ts/' thetalabel '/' subject '_' experiment '_pac_within_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacwithin', 'trialinfo', 'chans')

    tspac{isubj} = struct;
    
    rawtspac = squeeze(pacwithin(:, :, end));
    tspac{isubj}.raw = rawtspac;

    surrtspac = squeeze(pacwithin(:, :, 1:nsurrogate));

    tspac{isubj}.norm = (rawtspac - mean(surrtspac, 3)) ./ std(surrtspac, [], 3);

    tspac{isubj}.pvaltrial = ((sum(rawtspac < surrtspac, 3) + 1) ./ (nsurrogate + 1));

    tspac{isubj}.pvalpair = sum(median(rawtspac, 2) < squeeze(median(surrtspac, 2)), 2) ./ (nsurrogate + 1);    
end

save([info.path.processed.hd 'FR1_pac_within_ts_0_1600_' thetalabel '.mat'], 'tspac')
