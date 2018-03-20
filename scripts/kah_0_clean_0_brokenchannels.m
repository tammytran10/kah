% Script that loads raw, unsegmented Kahana data for visualization and detection of broken channels.
clear

% Load info for Project Kahana.
info = kah_info;

%%
clearvars('-except', 'info')

% Set subject, experiment, and session number.
subject    = 'R1059J'; 
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

% Visualize data.
cfg = []; 
cfg.viewmode  = 'vertical';
cfg.ylim      = [-40 40];  
cfg.blocksize = 4;         
ft_databrowser(cfg, data);

%%% ADD BROKEN CHANNELS TO KAH_INFO.M