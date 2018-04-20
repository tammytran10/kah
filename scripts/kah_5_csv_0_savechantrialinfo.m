clear

info = kah_info;

%%
clearvars('-except', 'info')

experiment = 'FR1';
timewin = [0, 1600];

[chans, pairs, chanlobes, pairlobes, chanregions, pairregions, encoding] = deal(cell(length(info.subj), 1));

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])
    
    input = load([info.path.processed.hd subject '/pac/ts/cf/' subject '_' experiment '_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'chanpairs', 'trialinfo', 'chans');
    
    chans{isubj} = input.chans;
    pairs{isubj} = input.chanpairs;
    
    subjlobes = info.(subject).allchan.lobe;
    subjregions = info.(subject).allchan.sublobe;
    
    [chanlobes{isubj}, chanregions{isubj}] = deal(cell(length(chans{isubj}), 1));
    for ichan = 1:length(chans{isubj})
        chancurr = ismember(info.(subject).allchan.label, chans{isubj}{ichan});
        
        chanlobes{isubj}{ichan} = subjlobes{chancurr};
        chanregions{isubj}{ichan} = subjregions{chancurr};
    end
    
    pairlobes{isubj} = chanlobes{isubj}(pairs{isubj});
    pairregions{isubj} = chanregions{isubj}(pairs{isubj});
    pairs{isubj} = input.chans(input.chanpairs);
    encoding{isubj} = input.trialinfo(:, 3);
end

save([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'chans', 'pairs', 'chanlobes', 'pairlobes', 'chanregions', 'pairregions', 'encoding')