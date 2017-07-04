%% Read in data
clear

% set the path to the data, and to the header/data/event files of a single subject
info = kah_info;
subject    = info.subj{15}; % change this to read in different datasets;  which subjects have which sessions/experiments are described in .../protocols/r1.json
experiment = 'FR1';    % change this to read in different datasets;  only FR1/2 can be segmented by rmr_upennram_trialfun
sessnum    = 2;      % change this to read in different datasets;  session numbers are zero-indexed

infocurr = info.(subject).(experiment).session(sessnum);

% read in data without segmenting it, by not using a trl matrix. I.e., read all the possible data in at once.
cfg = []; % start with an empty cfg
cfg.datafile     = infocurr.datadir;
cfg.dataformat   = 'read_upennram_data';
cfg.headerfile   = infocurr.headerfile;
cfg.headerformat = 'read_upennram_header';
cfg.demean = 'yes';
data = ft_preprocessing(cfg); % obtain data

depthchan = nan(numel(data.label), 1);
for ichan = 1:numel(data.label)
    depthchan(ichan) = strcmpi(data.hdr.orig2.contacts.(data.label{ichan}).type, 'd');
end

chancolors = repmat([0,0,1], numel(data.label), 1);
for ichan = 1:numel(data.label)
    if depthchan(ichan)
        chancolors(ichan,:) = [0,1,1];
    end
end

%% Look for broken channels.
% viewing the non-segmented, i.e. continuous, data in ft_databrowser
cfg = []; % start with an empty cfg
cfg.viewmode  = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
cfg.ylim      = [-40 40];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
cfg.blocksize = 4;          % set the segment size to view at once to 4s
% cfg.channelcolormap = chancolors;
% cfg.colorgroups     = 1:numel(data.label);
ft_databrowser(cfg, data);   % opens a GUI for browsing through the data

%% Add broken channels to kah_info.m and reload info
info = kah_info;
infocurr = info.(subject).(experiment).session(sessnum);

%% Remove broken channels from data
cfg = [];
cfg.channel = setdiff(data.label, ft_channelselection(infocurr.badchan.broken, data.label));
% cfg.channel = [ft_channelselection('RTS*', data.label); ft_channelselection('RTS*', data.label);

% % cfg.channel = ft_channelselection({'all', '-RFG*', '-RIHG*', '-RFPS*'}, data.label);
% cfg.channel = ft_channelselection({'RPT*'}, data.label);

% datachannel = ft_preprocessing(cfg, data);

data = ft_preprocessing(cfg, data);

depthchan = nan(numel(data.label), 1);
for ichan = 1:numel(data.label)
    depthchan(ichan) = strcmpi(data.hdr.orig2.contacts.(data.label{ichan}).type, 'd');
end

chancolors = repmat([0,0,1], numel(data.label), 1);
for ichan = 1:numel(data.label)
    if depthchan(ichan)
        chancolors(ichan,:) = [0,1,1];
    end
end

%% Visualize data
cfg = []; % start with an empty cfg
cfg.viewmode  = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
cfg.ylim      = [-40 40];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
cfg.blocksize = 4;          % set the segment size to view at once to 4s
% cfg.channelcolormap = chancolors;
% cfg.colorgroups     = 1:numel(data.label);
ft_databrowser(cfg, data);   % opens a GUI for browsing through the data

%% Detect line spectra
params = struct;
params.zthresh = 5; % default 2
% linespectra = rmr_findlinespectra(data.trial{1}, data.fsample, [50, data.fsample/2], params);
linespectra = rmr_findlinespectra(data.trial{1}, data.fsample, [50, data.fsample/2 - 10], params);

%% Add detected line spectra to kah_info.m and reload info
info = kah_info;
infocurr = info.(subject).(experiment).session(sessnum);

%% Filter out line spectra
cfg = [];
cfg.demean      = 'yes';
cfg.bsfilter    = 'yes';
cfg.bsfreq      = [(infocurr.bsfilt.peak - infocurr.bsfilt.halfbandw).', ...
    (infocurr.bsfilt.peak + infocurr.bsfilt.halfbandw).'];
cfg.bsfilttype  = 'but';
cfg.bsfiltord   = 2;
cfg.bsfiltdir   = 'twopass';
    
data = ft_preprocessing(cfg, data);

%% Visualize data
cfg = []; % start with an empty cfg
cfg.viewmode  = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
cfg.ylim      = [-40 40];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
cfg.blocksize = 4;          % set the segment size to view at once to 4s
ft_databrowser(cfg, data);   % opens a GUI for browsing through the data

%%
[freq, medianpsd] = util_medianwelch(data.trial{1}(1,:), 2 * data.fsample, data.fsample/2, 2 * data.fsample, data.fsample, []);
figure; loglog(freq, medianpsd)

%% Detect line spectra
peak = [60, 120, 180, 240, 300, 360, 420, 480];
halfbandw = repmat(0.25, size(peak));

% filter out line spectra
cfg = [];
cfg.demean      = 'yes';
cfg.bsfilter    = 'yes';
cfg.bsfreq      = [(linespec.peak - linespec.halfbandw).', (linespec.peak + linespec.halfbandw).'];
cfg.bsfilttype  = 'but';
cfg.bsfiltord   = 2;
cfg.bsfiltdir   = 'twopass';
    
data = ft_preprocessing(cfg, data);

% viewing the non-segmented, i.e. continuous, data in ft_databrowser
cfg = []; % start with an empty cfg
cfg.viewmode  = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
cfg.ylim      = [-40 40];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
cfg.blocksize = 4;          % set the segment size to view at once to 4s
ft_databrowser(cfg, data);   % opens a GUI for browsing through the data




