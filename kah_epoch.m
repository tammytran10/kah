tic
clear

% set the path to the data, and to the header/data/event files of a single subject
info = kah_info;
subject    = 'R1045E'; % change this to read in different datasets;  which subjects have which sessions/experiments are described in .../protocols/r1.json
experiment = 'FR1';    % change this to read in different datasets;  only FR1/2 can be segmented by rmr_upennram_trialfun
sessnum    = 1;        % change this to read in different datasets

% Specify trial windows.
cfg = [];
cfg.header      = read_upennram_header(info.(subject).(experiment).session(sessnum).headerfile);
cfg.event       = read_upennram_event(info.(subject).(experiment).session(sessnum).eventfile);
cfg.encduration = 2; % during encoding, the period, in seconds, after/before pre/poststim periods 
cfg.recduration = 0; % during   recall, the period, in seconds, after/before pre/poststim periods 
cfg.encprestim  = 1;   % during encoding, the period, in seconds, before word onset that is additionally cut out (t=0 will remain word onset)
cfg.encpoststim = 0;   % during encoding, the period, in seconds, after cfg.encduration, that is additionally cut out 
cfg.recprestim  = 0;   % during   recall, the period, in seconds, before word onset that is additionally cut out (t=0 will remain word onset)
cfg.recpoststim = 0;   % during   recall, the period, in seconds, after cfg.recduration, that is additionally cut out 
trl = rmr_upennram_trialfun(cfg); % obtain the trl matrix, which contains the segmentation details (Note, this function can also be called from with ft_definetrial)

wintime = cfg.encduration + cfg.encprestim;

% Keep encoding trials only.
trl = trl(trl(:,4) == 1, :); 
    
% Remove trials with artifacts.
cfg             = []; 
cfg.trl         = trl; % trial info about usable trials
cfg.dataformat   = 'read_upennram_data';
cfg.headerformat = 'read_upennram_header';
cfg.headerfile  = info.(subject).(experiment).session(sessnum).headerfile;
cfg.datafile    = info.(subject).(experiment).session(sessnum).datadir; 
cfg.artfctdef.xxx.artifact = info.(subject).(experiment).session(sessnum).badsegment; % set beginning and end samples for artifacts
cfg = ft_rejectartifact(cfg); % keep only clean trials

trl = cfg.trl;

% Load data and filter for theta phase.
cfg = []; 
cfg.datafile     = info.(subject).(experiment).session(sessnum).datadir; 
cfg.dataformat   = 'read_upennram_data';
cfg.headerfile   = info.(subject).(experiment).session(sessnum).headerfile;
cfg.headerformat = 'read_upennram_header';

cfg.channel = setdiff(info.(subject).allchan, ft_channelselection(info.(subject).badchan.broken, info.(subject).allchan));
cfg.channel = setdiff(cfg.channel, ft_channelselection(info.(subject).badchan.epileptic, info.(subject).allchan));

cfg.demean = 'yes';

cfg.reref = 'yes';
cfg.refchannel = 'all';

cfg.padding = wintime + info.(subject).FR1.bsfilt.edge;

cfg.bsfilter    = 'yes';
cfg.bsfreq      = [(info.(subject).FR1.bsfilt.peak - info.(subject).FR1.bsfilt.halfbandw).', ...
    (info.(subject).FR1.bsfilt.peak + info.(subject).FR1.bsfilt.halfbandw).'];
cfg.bsfilttype  = 'but';
cfg.bsfiltord   = 2;
cfg.bsfiltdir   = 'twopass';

% cfg.lpfilter    = 'yes';
% cfg.lpfreq      = 240;
% cfg.lpfilttype  = 'firws';

cfg.bpfilter      = 'yes';
cfg.bpfreq        = [4, 8];
cfg.bpfilttype    = 'firws';
cfg.bpfiltwintype = 'hamming';
cfg.hilbert = 'angle';

cfg.trl = trl;

thetaphase = ft_preprocessing(cfg);
toc   
%%
gammabands = [80, 100; 100, 120; 120, 140; 140, 160];

gammaamp = cell(size(gammabands, 1), 1);
for iband = 1:size(gammabands, 1)
    cfg.bpfilter      = 'yes';
    cfg.bpfreq        = gammabands(iband,:);
    cfg.bpfilttype    = 'firws';
    cfg.bpfiltwintype = 'hamming';
    cfg.hilbert = 'abs';
    gammaamp{iband} = ft_preprocessing(cfg);
end









cfg = []; % start with an empty cfg
cfg.channel = setdiff(data.label, ft_channelselection(infocurr.badchan.broken, data.label));
cfg.channel = setdiff(cfg.channel, ft_channelselection(infocurr.badchan.epileptic, data.label));

cfg.reref = 'yes';
cfg.refchannel = 'all';

data = ft_preprocessing(cfg, data); % obtain data

%%
cfg = [];
cfg.bpfilter      = 'yes';
cfg.bpfreq        = [4, 8];
cfg.bpfilttype    = 'firws';
cfg.bpfiltwintype = 'hamming';
cfg.hilbert = 'angle';

data = ft_preprocessing(cfg, data); % obtain data

%%
cfg = []; % start with an empty cfg
cfg.header      = read_upennram_header(infocurr.headerfile);
cfg.event       = read_upennram_event(infocurr.eventfile);
cfg.encduration = 1.6; % during encoding, the period, in seconds, after/before pre/poststim periods 
cfg.recduration = 0.5; % during   recall, the period, in seconds, after/before pre/poststim periods 
cfg.encprestim  = 0;   % during encoding, the period, in seconds, before word onset that is additionally cut out (t=0 will remain word onset)
cfg.encpoststim = 0;   % during encoding, the period, in seconds, after cfg.encduration, that is additionally cut out 
cfg.recprestim  = 0;   % during   recall, the period, in seconds, before word onset that is additionally cut out (t=0 will remain word onset)
cfg.recpoststim = 0;   % during   recall, the period, in seconds, after cfg.recduration, that is additionally cut out 
trl = rmr_upennram_trialfun(cfg); % obtain the trl matrix, which contains the segmentation details (Note, this function can also be called from with ft_definetrial)

% read in data and segment it (this is the stage where filtering the data is usually done, as it allows for data padding in a convenient way)
cfg = []; % start with an empty cfg
% cfg.datafile     = infocurr.datadir;
% cfg.dataformat   = 'read_upennram_data';
% cfg.headerfile   = infocurr.headerfile;
% cfg.headerformat = 'read_upennram_header';
cfg.trl          = trl;

data = ft_preprocessing(cfg, data); % obtain segmented data

%%
% cfg = []; % start with an empty cfg
cfg.viewmode  = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
% cfg.ylim      = [-5 5];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
% cfg.blocksize = 4;          % set the segment size to view at once to 4s
ft_databrowser(cfg, gammaamp{1});   % opens a GUI for browsing through the data
