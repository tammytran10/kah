
% READ_UPENNRAM_EXAMPLEDATAREADING provides an example on how trial-segmented data can obtained 
% from UPenn's RAM (Restoring Active Memory) publically available datasets.
% 
% UPenn's RAM project is a DARPA funded project, headed by Daniel Rizzuto and Michael Kahana.
% From the RAM website: (http://memory.psych.upenn.edu/RAM)
% "The goal of RAM is to develop a fully implantable device that can electrically stimulate 
% the brain to improve memory function. The program?s immediate focus is to deliver new treatments 
% for those who have experienced a traumatic brain injury, such as veterans returning from combat. 
% In the long term, such therapies could help patients with a broad range of ailments, from Alzheimer's
% to dementia. RAM is part of a broader portfolio of programs within DARPA that support President Obama's 
% BRAIN initiative."
% Intracranial human EEG has been recorded in various tasks and is publically available at the above 
% website.
% 
% From the press release (https://news.upenn.edu/news/penns-restoring-active-memory-project-releases-extensive-human-brain-dataset):
% "The recently released dataset includes information from 700 sessions, and for every patient, 
% intracranial recording files from 100 to 200 electrode channels, neuro-anatomical information 
% indicating the location of each electrode, precise records of patient behavior and the experimental 
% design documents. To receive the raw dataset, interested researchers may request access through 
% the RAM website."
% 
%
% This example script illustrates how the data of a single subject can be read and segmented into trials.
% This script depends on the following functions, which should be on the MATLAB path:
%   read_upennram_header
%   read_upennram_data
%   read_upennram_event
%   rmr_upennram_trailfun 
% Additionally, it depends (apart from FieldTrip) on the toolbox JSONlab (by Qianqian Fang)
% from the MATLAB File Exchange
%
% A LIST OF ALL SUBJECTS/EXPERIMENTS/SESSIONS is present in .../protocols/r1.json.
%
% The function rmr_upennram_trialfun is used to obtain segmentation details. I.e. at which sample does 
% a trial start and at which does it end. It does so only for the free recall task (FR1/2). 
% 
% T=0 is defined as the start of the word presentation (encoding; presentation time 1600ms, ISI 750-1000ms)
% or start of the verbal report (recall) onset. Trial duration, and pre/poststimulus periods before
% and after this can be adjusted below using the cfg. A warning is issued if trials overlap with a 
% neighboring event. Selection of trials after creating the trl matrix can be done using the columns
% of data.trialinfo (see below).
%
% Reading in the raw recordings and segmenting it into trials is performed using FieldTrip.
% FieldTrip can be found on http://www.fieldtriptoolbox.org/
% For additional information on preprocessing and analysis options, see the tutorials in the Preprocessing
% section of the FieldTrip tutorial list, which can be found at: http://www.fieldtriptoolbox.org/tutorial 
%
% The MATLAB-structure 'data' produced below is a FieldTrip style data-structure. 
% It will contain, among others, the following important fields:
%            hdr: [1x1 struct]   - the original header information from the BESA/EDF file
%          label: {143x1 cell}   - Nchanx1 cell-array, containing the channel names (from the BESA/EDF file)
%           time: {1x60 cell}    - 1xNtrial cell-array, containing the time axis of each trial, to be used together with data.trial
%          trial: {1x60 cell}    - 1xNtrial cell-array, containing the data of each trial, as a NchanxNsamples matrix
%        fsample: 5000           - sampling rate of the data in Hz
%     sampleinfo: [60x2 double]  - the original sample numbers of each trial on disk
%      trialinfo: [60x9 double]  - NtrialxNvariable trial-specific info variables 
%            cfg: [1x1 struct]   - the cfg used to obtain the data
%
% The trialinfo field contains the following information in each column, each row being a trial:
% (These columns are created in rmr_upennram_trialfun.)
%  (1) taskphase     - phase of the experiment, encoding = 1, recall = 2
%  (2) stim          - indicating whether stimulation was present during encoding (1 = yes, 0 = no) (in case of recall, during encoding of the recalled word)
%  (3) subseqmem     - subsequent memory effect, for encoding: later remembered = 1, later forgotten =  0; for recall: 1 = succesfully remembered, 0 = new word
%  (4) list          - list number (i.e. task phase)
%  (5) serialpos     - serial position of word in list during encoding (for recall, NaN in case of new word)
%  (6) wordno        - numeric identifier of word presented/recalled (for recall, NaN in case of new word)
%  (7) timefromprev  - time in seconds from begsample till previous event (positive indicates overlap)
%  (8) timetonext    - time in seconds from endsample till next event     (negative indicates overlap)


% set the path to the data, and to the header/data/event files of a single subject
datapath   = '/Volumes/voyteklab/common/data2/kahana_ecog_RAMphase1/session_data/experiment_data/protocols/r1/subjects/'; % root directory of the datasets
subject    = 'R1001P'; % change this to read in different datasets;  which subjects have which sessions/experiments are described in .../protocols/r1.json
experiment = 'PAL1';    % change this to read in different datasets;  only FR1/2 can be segmented by rmr_upennram_trialfun
session    = '0';      % change this to read in different datasets;  session numbers are zero-indexed
headerfile = [datapath subject '/experiments/' experiment '/sessions/' session '/' 'behavioral/current_processed/index.json'];       % see READ_UPENNRAM_HEADER for details
datadir    = [datapath subject '/experiments/' experiment '/sessions/' session '/' 'ephys/current_processed/noreref/'];              % see READ_UPENNRAM_DATA   for details
eventfile  = [datapath subject '/experiments/' experiment '/sessions/' session '/' 'behavioral/current_processed/task_events.json']; % see READ_UPENNRAM_EVENT  for details

% obtaining segmentation details
cfg = []; % start with an empty cfg
cfg.header      = read_upennram_header(headerfile);
cfg.event       = read_upennram_event(eventfile);
cfg.encduration = 1.6; % during encoding, the period, in seconds, after/before pre/poststim periods 
cfg.recduration = 0.5; % during   recall, the period, in seconds, after/before pre/poststim periods 
cfg.encprestim  = 0;   % during encoding, the period, in seconds, before word onset that is additionally cut out (t=0 will remain word onset)
cfg.encpoststim = 0;   % during encoding, the period, in seconds, after cfg.encduration, that is additionally cut out 
cfg.recprestim  = 0;   % during   recall, the period, in seconds, before word onset that is additionally cut out (t=0 will remain word onset)
cfg.recpoststim = 0;   % during   recall, the period, in seconds, after cfg.recduration, that is additionally cut out 
trl = rmr_upennram_trialfun(cfg); % obtain the trl matrix, which contains the segmentation details (Note, this function can also be called from with ft_definetrial)

%%
% read in data and segment it (this is the stage where filtering the data is usually done, as it allows for data padding in a convenient way)
cfg = []; % start with an empty cfg
cfg.datafile     = datadir;
cfg.dataformat   = 'read_upennram_data';
cfg.headerfile   = headerfile;
cfg.headerformat = 'read_upennram_header';
cfg.trl          = trl;
data = ft_preprocessing(cfg); % obtain segmented data

% viewing the segmented data in ft_databrowser
cfg = []; % start with an empty cfg
cfg.viewmode = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
cfg.ylim     = [-40 40];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
ft_databrowser(cfg,data);  % opens a GUI for browsing through the data


% Below is an alternative to the above, which is most useful for the initial cleaning of the data. Since the trial definition can change 
% in the course of an analysis project (e.g. baselines), it is useful to make sure no artifacts remain outside of the trial boundaries. 
% For this reason, we read in the data *without* segmenting it, and store artifact information that preserves their exact location: samples
% of the raw data files on disk. Note that this often includes the prepratory stages with the patient moving, talking, etc. This can cause 
% the initial part of the recording to look very different from the when the experiment is running. 

% read in data without segmenting it, by not using a trl matrix. I.e., read all the possible data in at once.
cfg = []; % start with an empty cfg
cfg.datafile     = datadir;
cfg.dataformat   = 'read_upennram_data';
cfg.headerfile   = headerfile;
cfg.headerformat = 'read_upennram_header';
data = ft_preprocessing(cfg); % obtain data

% viewing the non-segmented, i.e. continuous, data in ft_databrowser
cfg = []; % start with an empty cfg
cfg.viewmode  = 'vertical'; % displays channels vertically, another option is a 'butterfly' plot
cfg.ylim      = [-40 40];   % a choice of voltage limits to ensure each subject is seen from the same perspective (can be modified in the GUI)
cfg.blocksize = 4;          % set the segment size to view at once to 4s
ft_databrowser(cfg,data);   % opens a GUI for browsing through the data




