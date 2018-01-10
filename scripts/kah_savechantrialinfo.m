clear

info = kah_info;

%%
clearvars('-except', 'info')

experiment = 'FR1';
timewin = [0, 1600];

[chans, pairs, chanregions, pairregions, encoding] = deal(cell(length(info.subj), 1));

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])
    
    input = load([info.path.processed.hd subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'chanpairs', 'trialinfo', 'chans', 'temporal', 'frontal');
    
    chans{isubj} = input.chans;
    pairs{isubj} = input.chanpairs;
    
    chanregions{isubj} = cell(length(chans{isubj}), 1);
    for ichan = 1:length(chans{isubj})
        if input.temporal(ichan)
            chanregions{isubj}{ichan} = 'T';
        elseif input.frontal(ichan)
            chanregions{isubj}{ichan} = 'F';
        else
            chanregions{isubj}{ichan} = 'N';
        end
    end
    
    pairregions{isubj} = chanregions{isubj}(pairs{isubj});
    pairs{isubj} = input.chans(input.chanpairs);
    encoding{isubj} = input.trialinfo(:, 3);
end

save([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'chans', 'pairs', 'chanregions', 'pairregions', 'encoding')