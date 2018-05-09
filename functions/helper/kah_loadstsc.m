function [thetaamp, hfa, slopes, pacwithin_raw, pacwithin_norm] = kah_loadstsc(info, timewins)

[thetaamp, hfa, slopes, pacwithin_raw, pacwithin_norm] = deal(cell(length(timewins), 1));

for iwin = 1:length(timewins)
    timewin = timewins{iwin};
    input = load([info.path.processed.hd 'FR1_thetaamp_cf_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat']);
    thetaamp{iwin} = input.thetaamp;

    input = load([info.path.processed.hd 'FR1_hfa_' num2str(timewin(1)) '_' num2str(timewin(2)) '_2_150.mat']);
    hfa{iwin} = input.hfa;
    
    input = load([info.path.processed.hd 'FR1_slopes_' num2str(timewin(1)) '_' num2str(timewin(2)) '_2_150.mat']);
    slopes{iwin} = input.slopes;
    
    [pacwithin_raw{iwin}, pacwithin_norm{iwin}] = deal(cell(length(info.subj), 1));
    input = load([info.path.processed.hd 'FR1_pac_within_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_cf.mat']);
    for isubj = 1:length(info.subj)
        pacwithin_raw{iwin}{isubj} = input.tspac{isubj}.raw;
        pacwithin_norm{iwin}{isubj} = input.tspac{isubj}.norm;
    end
end