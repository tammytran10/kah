% Script that detects line spectra on re-referenced data from clean surface channels only. 
% Non-re-referenced data could also be used.

clear

% Load info for Project Kahana.
info = kah_info;

%%
clearvars('-except', 'info')

% Set subject and experiment.
subject    = 'R1059J';
experiment = 'FR1';
    
% Get the number of sessions.
nsess = length(info.(subject).(experiment).session);

% Storing individual session data. 
datref = cell(1, nsess);

% Load each session so that lines are detected across sessions.
for isess = 1:nsess
    cfg = []; 
    cfg.datafile     = info.(subject).(experiment).session(isess).datadir;
    cfg.dataformat   = 'read_upennram_data';
    cfg.headerfile   = info.(subject).(experiment).session(isess).headerfile;
    cfg.headerformat = 'read_upennram_header';
    cfg.demean       = 'yes';
    
    data = ft_preprocessing(cfg);

    % Keep only clean surface channels.
    surface = ~strcmpi('d', info.(subject).allchan.type);
    clean = ~ismember(info.(subject).allchan.label, info.(subject).badchan.all);

    cfg = [];
    cfg.channel = data.label(surface & clean);
    data = ft_preprocessing(cfg, data);

    % Store data.
    datref{isess} = data.trial{1} - repmat(mean(data.trial{1}, 1), size(data.trial{1}, 1), 1); 
    clear data
end

%% Detect line spectra and add detected line spectra to kah_info.m
params = struct;
params.zthresh = inf;

linespectra = rmr_findlinespectra(datref{1}, info.(subject).fs, [50, 310], params); % single session
linespectra = rmr_findlinespectra(cell2mat(datref), info.(subject).fs, [50, 310], params); % concatenated sessions
