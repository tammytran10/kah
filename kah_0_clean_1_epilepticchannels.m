% Script that loads raw, unsegmented Kahana data, removes bad channels, and moves surface channels to the top.
% Used for visualization and detection of epileptic channels.
clear

% Load info for Project Kahana.
info = kah_info;

%%
clearvars('-except', 'info')

% Set subject, experiment, and session number.
subject    = 'R1033D'; 
experiment = 'FR1';    
sessnum    = 1;      

% Load data.
cfg = []; 
cfg.datafile     = info.(subject).(experiment).session(sessnum).datadir;
cfg.dataformat   = 'read_upennram_data';
cfg.headerfile   = info.(subject).(experiment).session(sessnum).headerfile;
cfg.headerformat = 'read_upennram_header';
cfg.demean = 'yes';
data = ft_preprocessing(cfg); 

% Move surface electrodes to the top of the matrix.
surface = ~strcmpi('d', info.(subject).allchan.type);
chanreorder = [find(surface); find(~surface)];
data.label = data.label(chanreorder);
data.trial{1} = data.trial{1}(chanreorder,:);
surface = surface(chanreorder);

% Remove broken channels.
broken = ismember(data.label, info.(subject).badchan.broken);
surface = surface(~broken);
cfg = [];
cfg.channel = data.label(~broken);
data = ft_preprocessing(cfg, data);

% Visualize the data, graying out epileptic channels.
chancolors = get(groot, 'DefaultAxesColorOrder');
chancolors = repmat(chancolors, ceil(length(data.label)/size(chancolors, 1)), 1);
chancolors = chancolors(1:length(data.label), :);
grayout = ismember(data.label, info.(subject).badchan.epileptic);
grayout = grayout | ~surface;
chancolors(grayout,:) = repmat([0.7, 0.7, 0.7], sum(grayout), 1);

cfg = []; 
cfg.viewmode  = 'vertical'; 
cfg.ylim      = [-40 40];   
cfg.blocksize = 4;          
cfg.channelcolormap = chancolors;
cfg.colorgroups     = 1:numel(data.label);
ft_databrowser(cfg, data);   

% Check if enough channels remain.
kah_channum(info, subject)
