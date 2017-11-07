% Script for checking how many total trials there are and how many remain after cleaning.
clear; clc

% Load info for Project Kahana.
info = kah_info;

%%
% Set subject, experiment, and session number.
subject = 'R1167M';
experiment = 'FR1';
sessnum = 1;

% Load trial information.
cfg = []; 
cfg.encprestim  = 1;    
cfg.encduration = 2.75; 
cfg.encpoststim = 0;    
cfg.recprestim  = 1;    
cfg.recduration = 0;    
cfg.recpoststim = 0;    
cfg.header = read_upennram_header(info.(subject).(experiment).session(sessnum).headerfile);
cfg.event  = read_upennram_event(info.(subject).(experiment).session(sessnum).eventfile);

trl = rmr_upennram_trialfun(cfg); 

% Get number of total trials.
ncorrect = sum(trl(trl(:, 4) == 1, 6));
ntrial = length(trl(trl(:, 4) == 1, 6));     
recall = sum(trl(trl(:, 4) == 1, 6))/length(trl(trl(:, 4) == 1, 6));     
disp([num2str(ncorrect) '/' num2str(ntrial) ' - ' num2str(recall)])

% Remove trials with artifacts.
cfg             = []; 
cfg.trl         = trl; 
cfg.dataformat   = 'read_upennram_data';
cfg.headerformat = 'read_upennram_header';
cfg.headerfile = info.(subject).(experiment).session(sessnum).headerfile;
cfg.datafile    = info.(subject).(experiment).session(sessnum).datadir; 
cfg.artfctdef.xxx.artifact = info.(subject).(experiment).session(sessnum).badsegment; 
cfg = ft_rejectartifact(cfg);

% Get number of clean trials.
ncorrect = sum(cfg.trl(cfg.trl(:, 4) == 1, 6));
ntrial = length(cfg.trl(cfg.trl(:, 4) == 1, 6));     
recall = sum(cfg.trl(cfg.trl(:, 4) == 1, 6))/length(cfg.trl(cfg.trl(:, 4) == 1, 6));     
disp([num2str(ncorrect) '/' num2str(ntrial) ' - ' num2str(recall)])
