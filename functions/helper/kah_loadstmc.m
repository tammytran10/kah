function pacbetween = kah_loadstmc(info, timewins)
types = {'raw', 'norm'};
directions = {'AB', 'BA'};

pacbetween = cell(length(timewins), length(types), length(directions));

for iwin = 1:length(timewins)
    timewin = timewins{iwin};
    input = load([info.path.processed.hd 'FR1_pac_between_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_cf.mat']);
    
    for itype = 1:length(types)
        for idir = 1:length(directions)
            for isubj = 1:length(info.subj)
                pacbetween{iwin, itype, idir}{isubj} = input.tspac{isubj}.(directions{idir}).(types{itype});
            end
        end
    end
end
