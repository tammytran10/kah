%% Read in data
clear

% set the path to the data, and to the header/data/event files of a single subject
info = kah_info;
subject    = 'R1059J'; % change this to read in different datasets;  which subjects have which sessions/experiments are described in .../protocols/r1.json
experiment = 'FR1';    % change this to read in different datasets;  only FR1/2 can be segmented by rmr_upennram_trialfun
sessnum    = 1;      % change this to read in different datasets

infocurr = info.(subject).(experiment).session(sessnum);

% read in data without segmenting it, by not using a trl matrix. I.e., read all the possible data in at once.
cfg = []; % start with an empty cfg
cfg.datafile     = infocurr.datadir;
cfg.dataformat   = 'read_upennram_data';
cfg.headerfile   = infocurr.headerfile;
cfg.headerformat = 'read_upennram_header';
cfg.demean = 'yes';
data = ft_preprocessing(cfg); % obtain data

% find grid/strip electrode labels
surface = zeros(numel(data.label), 1);
for ichan = 1:numel(data.label)
    if ~strcmpi(data.hdr.orig2.contacts.(data.label{ichan}).type, 'd')
        surface(ichan) = 1;
    end
end

% move grid electrodes to the top of the matrix
nonsurface = ~surface;
chanreorder = [find(surface); find(nonsurface)];
data.label = data.label(chanreorder);
data.trial{1} = data.trial{1}(chanreorder,:);
surface = surface(chanreorder);

%% Look for broken channels.
% viewing the non-segmented, i.e. continuous, data in ft_databrowser
cfg = []; % start with an empty cfg
cfg.viewmode  = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
cfg.ylim      = [-40 40];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
cfg.blocksize = 4;          % set the segment size to view at once to 4s
ft_databrowser(cfg, data);   % opens a GUI for browsing through the data

%% Remove broken channels from data
info = kah_info;
infocurr = info.(subject).(experiment).session(sessnum);

broken = ismember(data.label, ft_channelselection(infocurr.badchan.broken, data.label));
surface = surface(~broken);

cfg = [];
cfg.channel = data.label(~broken);
data = ft_preprocessing(cfg, data);

cfg = []; % start with an empty cfg
cfg.viewmode  = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
cfg.ylim      = [-40 40];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
cfg.blocksize = 4;          % set the segment size to view at once to 4s
ft_databrowser(cfg, data);   % opens a GUI for browsing through the data

%% Detect line spectra and add detected line spectra to kah_info.m 
params = struct;
params.zthresh = 1;
linespectra = rmr_findlinespectra(data.trial{1}, data.fsample, [50, 250], params);

%% Filter out line spectra
info = kah_info;
infocurr = info.(subject).(experiment).session(sessnum);

cfg = [];
cfg.demean      = 'yes';
cfg.bsfilter    = 'yes';
cfg.bsfreq      = [(infocurr.bsfilt.peak - infocurr.bsfilt.halfbandw).', ...
    (infocurr.bsfilt.peak + infocurr.bsfilt.halfbandw).'];
cfg.bsfilttype  = 'but';
cfg.bsfiltord   = 2;
cfg.bsfiltdir   = 'twopass';
    
data = ft_preprocessing(cfg, data);

%% Look for epileptic/spiky channels
info = kah_info;
infocurr = info.(subject).(experiment).session(sessnum);

% viewing the non-segmented, i.e. continuous, data in ft_databrowser
chancolors = get(groot, 'DefaultAxesColorOrder');
chancolors = repmat(chancolors, ceil(length(data.label)/size(chancolors, 1)), 1);
chancolors = chancolors(1:length(data.label), :);
grayout = ismember(data.label, infocurr.badchan.epileptic);
chancolors(grayout,:) = repmat([0.7, 0.7, 0.7], sum(grayout), 1);

cfg = []; % start with an empty cfg
cfg.viewmode  = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
cfg.ylim      = [-40 40];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
cfg.blocksize = 4;          % set the segment size to view at once to 4s
cfg.channelcolormap = chancolors;
cfg.colorgroups     = 1:numel(data.label);
ft_databrowser(cfg, data);   % opens a GUI for browsing through the data

%% Get clean grid channels and average re-reference separately. Replace these channels in data.
cfg = [];
cfg.channel = data.label(surface & ~ismember(data.label, ft_channelselection(infocurr.badchan.epileptic, data.label)));
cfg.reref = 'yes';
cfg.refchannel = 'all';
datagrid = ft_preprocessing(cfg, data);

gridclean = surface & ~ismember(data.label, infocurr.badchan.epileptic);
data.trial{1}(gridclean,:) = datagrid.trial{1};

%% Manually mark artifacts.
% viewing the non-segmented, i.e. continuous, data in ft_databrowser
info = kah_info;
infocurr = info.(subject).(experiment).session(sessnum);

chancolors = get(groot, 'DefaultAxesColorOrder');
chancolors = repmat(chancolors, ceil(length(data.label)/size(chancolors, 1)), 1);
chancolors = chancolors(1:length(data.label), :);
grayout = ismember(data.label, infocurr.badchan.epileptic);
chancolors(grayout,:) = repmat([0.7, 0.7, 0.7], sum(grayout), 1);

cfg = []; % start with an empty cfg
cfg.viewmode  = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
cfg.ylim      = [-40 40];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
cfg.blocksize = 4;          % set the segment size to view at once to 4s
cfg.channelcolormap = chancolors;
cfg.colorgroups     = 1:numel(data.label);
cfg.artfctdef.sharp.artifact = infocurr.badsegment;
dataart = ft_databrowser(cfg, data);   % opens a GUI for browsing through the data

%% Check how many trials are rejected.
info = kah_info;
infocurr = info.(subject).(experiment).session(sessnum);

cfg = []; % start with an empty cfg
cfg.encduration = 2; % during encoding, the period, in seconds, after/before pre/poststim periods 
cfg.recduration = 0; % during   recall, the period, in seconds, after/before pre/poststim periods 
cfg.encprestim  = 2;   % during encoding, the period, in seconds, before word onset that is additionally cut out (t=0 will remain word onset)
cfg.encpoststim = 0;   % during encoding, the period, in seconds, after cfg.encduration, that is additionally cut out 
cfg.recprestim  = 0;   % during   recall, the period, in seconds, before word onset that is additionally cut out (t=0 will remain word onset)
cfg.recpoststim = 0;   % during   recall, the period, in seconds, after cfg.recduration, that is additionally cut out 

cfg.header = read_upennram_header(infocurr.headerfile);
cfg.event = read_upennram_event(infocurr.eventfile);
trl = rmr_upennram_trialfun(cfg); % obtain the trl matrix, which contains the segmentation details (Note, this function can also be called from with ft_definetrial)

% remove trials with artifacts
cfg             = []; 
cfg.trl         = trl; % trial info about usable trials
cfg.dataformat   = 'read_upennram_data';
cfg.headerformat = 'read_upennram_header';
cfg.headerfile = infocurr.headerfile;
cfg.datafile    = infocurr.datadir; 
cfg.artfctdef.xxx.artifact = infocurr.badsegment; % set beginning and end samples for artifacts
cfg = ft_rejectartifact(cfg); % keep only clean trials

%%






[freq, medianpsd] = util_medianwelch(data.trial{1}(1,:), 2 * data.fsample, data.fsample/2, 2 * data.fsample, data.fsample, []);
figure; loglog(freq, medianpsd)





% cfg.channel = [ft_channelselection('RTS*', data.label); ft_channelselection('RTS*', data.label);
% cfg.channel = ft_channelselection({'all', '-RFG*', '-RIHG*', '-RFPS*'}, data.label);
% datachannel = ft_preprocessing(cfg, data);

for ch = 1:numel(data.label)
    chan = data.label{ch};
    if contains(chan, 'x')
        chan = chan(1:end-1);
    end
    disp([chan ' ' data.hdr.orig2.contacts.(chan).atlases.avg.region])
end

%%
clc

subjs = {'R1032D', 'R1128E', 'R1034D', 'R1167M', 'R1142N', 'R1059J', 'R1020J', 'R1045E'};

for isubj = 2
    subjcurr = subjs{isubj};
    chanfile = [info.path.data subjcurr '/localizations/0/montages/0/neuroradiology/current_processed/contacts.json'];
    chanjson = loadjson(chanfile);

    chanlabel = fieldnames(chanjson.(subjcurr).contacts);
    for ichan = 1:length(chanlabel)
        chan = chanlabel{ichan};
        chantype = chanjson.(subjcurr).contacts.(chan).type; % grid (G), strip (S), depth (D)
        
        if ~strcmpi(chantype, 'D')
            chan = [chan, 'x'];
            if ~ismember(chan, info.(subjcurr).FR1.session(1).badchan.broken)
                if ~ismember(chan, info.(subjcurr).FR1.session(1).badchan.epileptic)
                    disp([chan ' ' chanjson.(subjcurr).contacts.(chanlabel{ichan}).atlases.avg.region])
                else
                    disp('Epileptic')
                end
            else
                disp('Broken')
            end
        end
    end
end