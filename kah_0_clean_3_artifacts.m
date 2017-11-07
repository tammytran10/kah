% Script for manual cleaning of Kahana data.
% Filters out line spectra, average re-references using clean surface channels, then plots data for marking.

clear; clc

% Load info for Kahana project.
info = kah_info;

%%
clearvars('-except', 'info')

% Set subject and session number to clean.
subject    = 'R1033D'; 
sessnum    = 1;        

% Set experiment to clean.
experiment = 'FR1';    

% Read in continuous data.
cfg = []; 
cfg.datafile     = info.(subject).(experiment).session(sessnum).datadir;
cfg.dataformat   = 'read_upennram_data';
cfg.headerfile   = info.(subject).(experiment).session(sessnum).headerfile;
cfg.headerformat = 'read_upennram_header';
data = ft_preprocessing(cfg); 

% Filter out line spectra.
cfg = [];
cfg.demean      = 'yes';
cfg.bsfilter    = 'yes';
cfg.bsfreq      = [(info.(subject).(experiment).bsfilt.peak - info.(subject).(experiment).bsfilt.halfbandw).', ...
    (info.(subject).(experiment).bsfilt.peak + info.(subject).(experiment).bsfilt.halfbandw).'];
cfg.bsfilttype  = 'but';
cfg.bsfiltord   = 2;
cfg.bsfiltdir   = 'twopass';

data = ft_preprocessing(cfg, data); 

% Average re-reference using clean surface channels.
surface = ~strcmpi('d', info.(subject).allchan.type);
clean = ~ismember(info.(subject).allchan.label, info.(subject).badchan.all);
cleansurface = surface & clean;

cfg = [];
cfg.reref = 'yes';
cfg.refchannel = data.label(cleansurface);
data = ft_preprocessing(cfg, data);

% Move clean surface channels to the top of the matrix for easier viewing.
chanreorder = [find(cleansurface); find(~cleansurface)];
data.label = data.label(chanreorder);
data.trial{1} = data.trial{1}(chanreorder,:);
cleansurface = cleansurface(chanreorder);

% Get times of when trials start and stop in the recording.
cfg = []; 
cfg.encprestim  = 1;    
cfg.encduration = 2.75; 
cfg.encpoststim = 0;    
cfg.recprestim  = 1;    
cfg.recduration = 0;    
cfg.recpoststim = 0;    
cfg.header = read_upennram_header(info.(subject).(experiment).session(sessnum).headerfile);
cfg.event  = read_upennram_event(info.(subject).(experiment).session(sessnum).eventfile);

% Obtain the trl matrix. The first two columns are sample starts and stops of the trials
trl = rmr_upennram_trialfun(cfg); 

% Display segments when trials in session actually begin and end.
disp(trl([1, size(trl, 1)], 1:2)./data.fsample / 4)

%% Calculate the second gradient to detect slight buzz or jumps in the data.
datdiff    = gradient(gradient(data.trial{1}(cleansurface, :)));
datdiff    = max(abs(zscore(datdiff, [], 2)));

%% Set second gradient threshold to mark artifacts.
threshold  = 10; % in zvalue
artpadding = 0.1; % in seconds
artifact = find(datdiff > threshold); 
artifact = artifact(:); 
artifact = cat(2, artifact - round(artpadding * data.fsample), artifact + round(artpadding * data.fsample)); % overlap is removed after going through ft_databrowser
artifact(artifact < 1) = 1;
artifact(artifact > length(data.time{1})) = length(data.time{1});

%% Plot data, graying out non channels of interest and with detected buzz/jumps on top.
chancolors = get(groot, 'DefaultAxesColorOrder');
chancolors = repmat(chancolors, ceil(length(data.label)/size(chancolors, 1)), 1);
chancolors = chancolors(1:length(data.label), :);
chancolors(~cleansurface, :) = repmat([0.7, 0.7, 0.7], sum(~cleansurface), 1);

cfg = []; 
cfg.viewmode  = 'vertical'; 
cfg.ylim      = [-40 40];   
cfg.blocksize = 4;          
cfg.channelcolormap = chancolors;
cfg.colorgroups     = 1:numel(data.label);
cfg.artfctdef.badseg.artifact = info.(subject).(experiment).session(sessnum).badsegment; 
cfg.artfctdef.jumps.artifact = artifact;
dataart = ft_databrowser(cfg, data);   
