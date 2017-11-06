function info = kah_info(varargin)

% kah_info() loads path, experiment, demographic, and electrode info for subjects in the RAM (Kahana) dataset.
% Information about line spectra and epileptic channels and segments is hardcoded below for preprocessed subjects.
% NOTE: artifact info is specific to experiment FR1 and surface channels only. Depth channels were not closely examined.
% Depth channels may or may not be marked as broken.
%
% Usage:
%   info = kah_info('all') returns information for all available subjects in the release specified below ('r1' currently).
%   For this usage, TSCC cluster storage must be available.
%
%   info = kah_info() returns information for a subset of subjects, hardcoded below.
%   For this usage, data from DATAHD (personal hard drive) is loaded if available, and from the cluster otherwise.

warning off

info = struct;

% Subjects with age >= 18, fs >= 999, FR1, at least 3 T/F
info.subj = {'R1020J' 'R1032D' 'R1033D' 'R1034D' 'R1045E' 'R1059J' 'R1075J' 'R1080E' 'R1120E' 'R1135E' ...
    'R1142N' 'R1147P' 'R1149N' 'R1151E' 'R1154D' 'R1162N' 'R1166D' 'R1167M' 'R1175N'};
    
% Set path to where source files are.
info.path.src = '/Users/Rogue/Documents/Research/Projects/KAH/src/';

% Set path to Kahana folder on shared VoytekLab server.
hdpath = '/Volumes/DATAHD/KAHANA/';
clusterpath = '/Volumes/voyteklab/common/data2/kahana_ecog_RAMphase1/';

% Use the cluster path if info for all subjects is desired.
if nargin > 0 && strcmpi(varargin{1}, 'all')
    if exist(clusterpath, 'dir')
        info.path.kah = clusterpath;
    else
        error('To load info for all subjects, cluster storage must be available.')
    end
    
% Otherwise, use personal hard drive if available, cluster path otherwise.
else    
    if exist(hdpath, 'dir')
        info.path.kah = hdpath;
    elseif exist(clusterpath, 'dir')
        info.path.kah = clusterpath;
    else
        error('Neither your personal hard drive nor cluster storage is available.')
    end
end

% Set path to .csv file with demographic information.
info.path.demfile = [info.path.kah 'Release_Metadata_20160930/RAM_subject_demographics.csv'];

% Set current release of Kahana data.
info.release = 'r1';

% Set path to experiment data.
info.path.exp = [info.path.kah 'session_data/experiment_data/protocols/' info.release '/subjects/'];

% Set path to anatomical data.
info.path.surf = [info.path.kah 'session_data/surfaces/'];

% Set path to where processed data will be saved.
info.path.processed.hd      = '/Volumes/DATAHD/Active/KAH/';
info.path.processed.cluster = '/Volumes/voyteklab/tamtra/KAH/';

% Get info from demographic file.
demfile = fopen(info.path.demfile);
deminfo = textscan(demfile, '%s %s %f %s %s %s %s %s %s %s %s %s', 'delimiter', ',', 'headerlines', 1);
fclose(demfile);

% Get all subject identifiers, if desired. Overrides any hardcoded subjects above.
if nargin > 0 && strcmpi(varargin{1}, 'all')
    info.subj = extractfield(dir(info.path.exp), 'name');
    info.subj(contains(info.subj, '.')) = [];
end

% Get gender, ages, and handedness of all subjects.
[info.gender, info.hand] = deal(cell(size(info.subj)));
info.age = nan(size(info.subj));
info.subj = info.subj(:); info.gender = info.gender(:); info.hand = info.hand(:); info.age = info.age(:); 

for isubj = 1:numel(info.subj)
    info.gender(isubj) = deminfo{2}(strcmpi(info.subj{isubj}, deminfo{1}));
    info.age(isubj) = deminfo{3}(strcmpi(info.subj{isubj}, deminfo{1}));
    info.hand(isubj) = deminfo{12}(strcmpi(info.subj{isubj}, deminfo{1}));
end

% Load anatomical atlases used for electrode region labelling.
talatlas = ft_read_atlas([info.path.src 'atlasread/TTatlas+tlrc.HEAD']);
mniatlas = ft_read_atlas([info.path.src 'atlasread/ROI_MNI_V4.nii']);

% For each subject, extract anatomical, channel, and electrophysiological info.
for isubj = 1:numel(info.subj)
    
    % Get current subject identifier.
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])

    % Get path for left- and right-hemisphere pial surf files.
    info.(subject).lsurffile = [info.path.surf subject '/surf/lh.pial'];
    info.(subject).rsurffile = [info.path.surf subject '/surf/rh.pial'];
    
    % Load cortical mesh for subject.
    info.(subject).mesh = ft_read_headshape({info.(subject).lsurffile, info.(subject).rsurffile});

    % Get experiment-data path for current subject.
    subjpathcurr = [info.path.exp subject '/'];
        
    % Get subject age.
    info.(subject).age = info.age(isubj);
    
    % Get path for contacts.json and get all contact information.
    info.(subject).contactsfile = [subjpathcurr 'localizations/0/montages/0/neuroradiology/current_processed/contacts.json'];
    contacts = loadjson(info.(subject).contactsfile);
    contacts = contacts.(subject).contacts;
    
    % Get labels for all channels.
    info.(subject).allchan.label = fieldnames(contacts);
    
    % Get info for each channel.
    for ichan = 1:length(info.(subject).allchan.label)
        % Get current channel. 
        chancurr = contacts.(info.(subject).allchan.label{ichan});
        
        % Get channel type (grid, strip, depth).
        info.(subject).allchan.type{ichan} = chancurr.type;
        
        % Get atlas-specific information.
        atlases = {'avg', 'avg_0x2E_dural', 'ind', 'ind_0x2E_dural', 'mni', 'tal', 'vox'};
        for iatlas = 1:length(atlases)
            % Get current atlas info for the channel.
            try
                atlascurr = chancurr.atlases.(atlases{iatlas});
            catch
                continue % if atlas not included for this subject.
            end
            
            % Extract region label for channel.
            if isempty(atlascurr.region)
                atlascurr.region = 'NA'; % if no region label is given in this atlas. For MNI and TAL, this will be filled in later.
            end
            info.(subject).allchan.(atlases{iatlas}).region{ichan} = atlascurr.region;
            
            % Convert xyz coordinates to double, if necessary (due to NaNs in coordinates).
            coords = {'x', 'y', 'z'};
            for icoord = 1:length(coords)
                if ischar(atlascurr.(coords{icoord}))
                    atlascurr.(coords{icoord}) = str2double(atlascurr.(coords{icoord}));
                end
            end
            
            % Extract xyz coordinates.
            info.(subject).allchan.(atlases{iatlas}).xyz(ichan,:) = [atlascurr.x, atlascurr.y, atlascurr.z];
        end
        
        % Get top anatomical label from MNI atlas.
        try
            mnilabel = lower(atlas_lookup(mniatlas, info.(subject).allchan.mni.xyz(ichan,:), 'inputcoord', 'mni', 'queryrange', 3));
            mnilabel = mnilabel{1};
        catch
            mnilabel = 'NA'; % if no label or atlas was found.
        end
        info.(subject).allchan.mni.region{ichan} = mnilabel;
        
        % Get top anatomical label from TAL atlas.
        try
            tallabel = lower(atlas_lookup(talatlas, info.(subject).allchan.tal.xyz(ichan,:), 'inputcoord', 'tal', 'queryrange', 3));
            tallabel = tallabel{1};
        catch
            tallabel = 'NA'; % if no label or atlas was found.
        end
        info.(subject).allchan.tal.region{ichan} = tallabel;
        
        % Get average anatomical annotations from Kahana group.
        avglabel = lower(info.(subject).allchan.avg.region{ichan});
        
        % Get individual anatomical annotations from Kahana group.
        indlabel = lower(info.(subject).allchan.ind.region{ichan});
        
        % Set terms to search for in region labels.
        frontalterms = {'frontal', 'opercularis', 'triangularis', 'precentral', 'rectal', 'rectus', 'orbital'};
        temporalterms = {'temporal', 'fusiform', 'hippocamp', 'bankssts', 'entorhinal'};
        
        % Determine lobe location based on individual labels only.
        frontal = contains(indlabel, frontalterms);
        temporal = contains(indlabel, temporalterms);
        
        if frontal
            info.(subject).allchan.lobe{ichan} = 'F';
        elseif temporal
            info.(subject).allchan.lobe{ichan} = 'T';
        else
            info.(subject).allchan.lobe{ichan} = 'NA';
        end
        
        % Determine lobe location based on majority vote across individual, MNI, and TAL.
        regions = {indlabel, mnilabel, tallabel};
        frontal = contains(regions, frontalterms);
        temporal = contains(regions, temporalterms);
        nolabel = strcmpi('NA', regions);
        
        if sum(frontal) > (sum(~nolabel)/2)
            info.(subject).allchan.altlobe{ichan} = 'F';
        elseif sum(temporal) > (sum(~nolabel)/2)
            info.(subject).allchan.altlobe{ichan} = 'T';
        else
            info.(subject).allchan.altlobe{ichan} = 'NA';
        end
    end
    
    % Re-format to column vectors.
    info.(subject).allchan.type = info.(subject).allchan.type(:);
    info.(subject).allchan.lobe = info.(subject).allchan.lobe(:);
    info.(subject).allchan.altlobe = info.(subject).allchan.altlobe(:);
    for iatlas = 1:length(atlases)
        info.(subject).allchan.(atlases{iatlas}).region = info.(subject).allchan.(atlases{iatlas}).region(:);
    end
    
    % Get experiments performed.
    experiments = extractfield(dir([subjpathcurr 'experiments/']), 'name');
    experiments(contains(experiments, '.')) = [];
    
    % Get experiment path info.
    for iexp = 1:numel(experiments)
        % Get current experiment path.
        expcurr = experiments{iexp};
        exppathcurr = [subjpathcurr 'experiments/' expcurr '/sessions/'];
        
        % Get session numbers.
        sessions = extractfield(dir(exppathcurr), 'name');
        sessions(contains(sessions, '.')) = [];
        
        % Get header file, data directory, and event file per session.
        for isess = 1:numel(sessions)
            info.(subject).(expcurr).session(isess).headerfile = [exppathcurr sessions{isess} '/behavioral/current_processed/index.json'];
            info.(subject).(expcurr).session(isess).datadir    = [exppathcurr sessions{isess} '/ephys/current_processed/noreref/'];
            info.(subject).(expcurr).session(isess).eventfile  = [exppathcurr sessions{isess} '/behavioral/current_processed/task_events.json'];
        end
    end
    
    % Get sampling rate from sources.json file.
    sourcesfile = [exppathcurr sessions{isess} '/ephys/current_processed/sources.json'];
    try
        sources = loadjson(sourcesfile);
    catch
        info.(subject).fs = 0; % if sources file not found.
        continue
    end
    sourcesfield = fieldnames(sources);
    info.(subject).fs = sources.(sourcesfield{1}).sample_rate;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% >= 3 T/F channels
% clean line spectra 80-150Hz
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  Subject - Sess - Temp - Front - Corr./All - Acc.     - Temp - Front - Corr./All - Acc.     - BAD - Notes

% 'R1020J' - 1    - 31T  - 32F   - 114/300   - 0.3800   - 19T  - 23F   - 104/283   - 0.3675   - :)  - Done. Core. 48.

% 'R1032D' - 1    - 14T  - 10F   - 95/300    - 0.3167   - 8T   - 10F   - 79/231    - 0.34199  - :)  - Done. 19.

% 'R1033D' - 1    - 19T  - 14F   - 23/108    - 0.2130   - 6T   - 13F   - 21/98     - 0.21429  - ??? - Done. Expansion? 

% 'R1034D' - 3    - 10T  - 67F   - 48/528    - 0.0909   - 8T   - 51F   - 41/475    - 0.0863   - ??? - Done. 29. Expansion.
% 'R1034D' - 1/3  - 10T  - 67F   - 21/132    - 0.1591   - 8T   - 51F   - 21/126    - 0.1667   - ??? - 
% 'R1034D' - 2/3  - 10T  - 67F   - 24/300    - 0.0800   - 8T   - 51F   - 17/268    - 0.0634   - ??? - 
% 'R1034D' - 3/3  - 10T  - 67F   - 3/96      - 0.0312   - 8T   - 51F   - 3/81      - 0.0370   - ??? - 

% 'R1045E' - 1    - 17T  - 26F   - 98/300    - 0.3267   - 12T  - 24F   - 77/236    - 0.3263   - :)  - Done. Core. 51.

% 'R1059J' - 2    - 53T  - 61F   - 36/444    - 0.0811   - 19T  - 47F   - 35/421    - 0.0831   - ??? - Done. Expansion. 44. 
% 'R1059J' - 1/2  - 53T  - 61F   - 8/144     - 0.0556   - 19T  - 47F   - 8/140     - 0.057143 - ??? - 
% 'R1059J' - 2/2  - 53T  - 61F   - 28/300    - 0.0933   - 19T  - 47F   - 27/281    - 0.096085 - ??? - 

% 'R1075J' - 2    - 7T   - 88F   - 150/600   - 0.2500   - 7T   - 37F   - 134/556   - 0.2410   - :)  - Done.
% 'R1075J' - 1/2  - 7T   - 88F   - 102/300   - 0.3400   - 7T   - 37F   - 99/294    - 0.33673  - :)  - 105 recall (3 words repeated)
% 'R1075J' - 2/2  - 7T   - 88F   - 48/300    - 0.1600   - 7T   - 37F   - 35/262    - 0.13359  - :)  - 48 recall
 
% 'R1080E' - 2    - 6T   - 10F   - 107/384   - 0.2786   - 6T   - 7F    - 106/376   - 0.2819   - :)  - Good pending clean. ***
% 'R1080E' - 1/2  - 6T   - 10F   - 47/180    - 0.2611   - 6T   - 7F    - 47/176    - 0.2670   - :)  - 47
% 'R1080E' - 2/2  - 6T   - 10F   - 60/204    - 0.2941   - 6T   - 7F    - 59/200    - 0.295    - :)  - 59

% 'R1120E' - 2    - 13T  - 3F    - 207/600   - 0.3450   - 7T   - 3F    - 207/599   - 0.3456   - :)  - Done. Core. 33.
% 'R1120E' - 1/2  - 13T  - 3F    - 97/300    - 0.3233   - 7T   - 3F    - 97/300    - 0.3233   - :)  - 97
% 'R1120E' - 2/2  - 13T  - 3F    - 110/300   - 0.3667   - 7T   - 3F    - 110/299   - 0.3679   - :)  - 112

% 'R1135E' - 4    - 7T   - 15F   - 107/1200  - 0.0892   - 6T   - 13F   - 31/370    - 0.0838   - ??? - Done. Expansion.
% 'R1135E' - 1/4  - 7T   - 15F   - 26/300    - 0.0867   - 6T   - 13F   - 10/61     - 0.16393  - ??? - 
% 'R1135E' - 2/4  - 7T   - 15F   - 43/300    - 0.1433   - 6T   - 13F   - 8/48      - 0.16667  - ??? - 
% 'R1135E' - 3/4  - 7T   - 15F   - 26/300    - 0.0867   - 6T   - 13F   - 6/105     - 0.057143 - ??? - 
% 'R1135E' - 4/4  - 7T   - 15F   - 12/300    - 0.0400   - 6T   - 13F   - 7/156     - 0.044872 - ??? -

% 'R1142N' - 1    - 19T  - 60F   - 48/300    - 0.1600   - 18T  - 57F   - 37/194    - 0.19072  - ??? - Done. Expansion. 50 recall. 

% 'R1147P' - 3    - 41T  - 33F   - 101/559   - 0.1807   - 10T   - 14F   - 69/401    - 0.1721   - :)  - Done. Core.
% 'R1147P' - 1/3  - 41T  - 33F   - 73/283    - 0.2580   - 10T   - 14F   - 50/204    - 0.2451   - :)  - 
% 'R1147P' - 2/3  - 41T  - 33F   - 11/96     - 0.1146   - 10T   - 14F   -   9/70    - 0.12857  - :)  - 
% 'R1147P' - 3/3  - 41T  - 33F   - 17/180    - 0.0944   - 10T   - 14F   - 10/127    - 0.07874  - :)  - 

% 'R1149N' - 1    - 47T  - 18F   - 64/300    - 0.2133   - 30T  - 18F   - 47/248    - 0.18952  - ??? - Done. Expansion. 67 recall.

% 'R1151E' - 3    - 7T   - 9F    - 208/756   - 0.2751   - 7T   - 9F    - 202/742   - 0.2722   - :)  - Good pending cleaning. Core.
% 'R1151E' - 1/3  - 7T   - 9F    - 77/300    - 0.2567   - 7T   - 9F    - 76/294    - 0.2585   - :)  - 
% 'R1151E' - 2/3  - 7T   - 9F    - 83/300    - 0.2767   - 7T   - 9F    - 81/296    - 0.2736   - :)  - 
% 'R1151E' - 3/3  - 7T   - 9F    - 48/156    - 0.3077   - 7T   - 9F    - 45/152    - 0.2961   - :)  -

% 'R1154D' - 3    - 40T  - 20F   - 271/900   - 0.3011   - 10T   - 19F   - 253/841   - 0.3008   - :)  -  Core.
% 'R1154D' - 1/3  - 40T  - 20F   - 63/300    - 0.2100   - 10T   - 19F   - 63/300    - 0.2100   - :)  - 
% 'R1154D' - 2/3  - 40T  - 20F   - 108/300   - 0.3600   - 10T   - 19F   - 98/263    - 0.37262  - :)  - 
% 'R1154D' - 3/3  - 40T  - 20F   - 100/300   - 0.3333   - 10T   - 19F   - 92/278    - 0.33094  - :)  - 

% 'R1162N' - 1    - 25T  - 11F   - 77/300    - 0.2567   - 15T  - 11F   - 75/275    - 0.27273  - :)  - Done. Expansion. 

% 'R1166D' - 3    - 5T   - 37F   - 129/900   - 0.1433   - 5T   - 19F   - 124/864   - 0.1435   - :)  - Done. Core. 
% 'R1166D' - 1/3  - 5T   - 37F   - 30/300    - 0.1000   - 5T   - 19F   - 30/295    - 0.1017   - :)  - 
% 'R1166D' - 2/3  - 5T   - 37F   - 49/300    - 0.1633   - 5T   - 19F   - 47/280    - 0.16786  - :)  - 
% 'R1166D' - 3/3  - 5T   - 37F   - 50/300    - 0.1667   - 5T   - 19F   - 47/289    - 0.16263  - :)  - 

% 'R1167M' - 2    - 42T  - 21F   - 166/372   - 0.4462   - 32T  - 19F   - 133/285   - 0.4508   - :)  - Done. Core. 33. Flat slope. 
% 'R1167M' - 1/2  - 42T  - 21F   - 80/192    - 0.4167   - 32T  - 19F   - 54/127    - 0.4252   - :)  - 
% 'R1167M' - 2/2  - 42T  - 21F   - 86/180    - 0.4778   - 32T  - 19F   - 79/158    - 0.5      - :)  - 

% 'R1175N' - 1    - 39T  - 29F   - 68/300    - 0.2267   - 27T  - 26F   - 57/262    - 0.21756  - ??? - Done. 73 recall. 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1020J %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1020J' - 1    - 31T  - 32F   - 114/300   - 0.3800   - 19T  - 23F   - 104/283   - 0.3675   - :)  - Done. 48.

% Some broken channels, big fluctuations and flat lines. 
% Some channels have extra line noise, but notches are effective.
% Notches are narrow, only at harmonics or above 150Hz. Baseline flat and clean.
% Remaining channels are relatively free of interictal events.
% Some buzz in remaining channels, somewhat slinky, but relatively low amplitude.
% Lots of surface channels. 
% Other than periods of extended slinkiness, nothing that could be easily taken out. [NOTE: I'm not taking slinkiness out anymore.]
% Great accuracy, high number of trials.
% No notes from researchers.

% 'RFB6', 'RFB7', 'RSTB2', 'RSTB3' have buzz along with others, but after buzz, continue little spikelets for a little while
% I stopped marking the artifacts at the end of buzz across channels, but let the spikelets continue. I could extend these. [NOTE: I extended some.]
% RSTB7 has big fluctuations, but only occassionally.
% Channels are very slinky.
% Very little evidence of interictal spikes in surface, and not many in depths either.
% Buzz was removed if across multiple channels, not as much if only in one channel.

% Clean subject, great subject. Only concern are the buzzy channels I did not remove (RFB6, RFB7, RSTB2, RSTB3). [NOTE: looking at these channels, don't seem bad]
% A great pilot subject for phase encoding.
% Slightly careful with HFA and slope. [NOTE: after looking through the data again, great for slope]
% Some removal of additional buzz with jumps, but not much.

% Channel Info:
info.R1020J.badchan.broken = {'RSTB5', 'RAH7', 'RAH8', 'RPH7', 'RSTB8', 'RFB8', ... % my broken channels, fluctuations and floor/ceiling. Confirmed.
    'RFB4', ... % one of Roemer's bad chans
    'RFB1', 'RFB2', 'RPTB1', 'RPTB2', 'RPTB3'}; % Kahana broken channels

info.R1020J.badchan.epileptic = {'RAT6', 'RAT7', 'RAT8', 'RSTA2', 'RSTA3', 'RFA1', 'RFA2', 'RFA3', 'RFA7', ... % Kahana seizure onset zone
    'RSTB4', 'RFA8' ... % after buzzy episodes, continue spiky (like barbed wire)
    'RAT*' ... % synchronous little spikelets, intermittent buzz. Also very swoopy. Confirmed confirmed.
    }; 

% Line Spectra Info:
% Session 1/1 z-thresh 0.45, 1 manual (tiny tiny peak), using re-ref. Re-ref and non-ref similar spectra.
info.R1020J.FR1.bsfilt.peak      = [60  120 180 219.9 240 300 ...
    190.3];
info.R1020J.FR1.bsfilt.halfbandw = [0.5 0.5 0.7 0.5   0.5 0.8 ...
    0.5];
info.R1020J.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1020J.FR1.bsfilt.peak, ...
    info.R1020J.FR1.bsfilt.halfbandw, ...
    info.R1020J.fs);

% Bad Segment Info:
% Focused primarily on removal of buzzy episodes, also on some episodes where RSTB7 has big fluctuations
info.R1020J.FR1.session(1).badsegment = [222,425;21169,21462;94052,94252;306967,307168;447445,447647;499311,500554;508251,508716;553916,554937;578019,580740;668182,668792;937194,938417;948517,950659;1023532,1024720;1049122,1049977;1061343,1062002;1153784,1157155;1218605,1221167;1335219,1337563;1470021,1472000;1541100,1543946;1669122,1669848;1770421,1773973;1840485,1842900;1940356,1941288;1942113,1943574;1944162,1947058;1948727,1949010;1951509,1953930;2040513,2042489;2282545,2283013;2296392,2297288;2323413,2326543;2340670,2342784;2478525,2479570;2553863,2554364;2556896,2557381;2573988,2574872;2650561,2651735;2653851,2655606;2963848,2967067;3230319,3232379];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1032D %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1032D' - 1    - 14T  - 10F   - 95/300    - 0.3167   - 8T  - 10F   - 79/231 - 0.34199  - :)  - Done. 19.

% Mostly depth electrodes. 
% Lots of reference noise and flat-line channels.
% Only narrow lines at harmonics. Re-ref cleans baseline. Re-ref and non-ref very similar.
% Noise is consistent across channels.
% Mild slink, but low amplitude. 
% Channels LFS1-4 have periodic synchronous dips. Occasionally RFS1-3 as well. Big dips were marked for rejection.
% Consider removing these channels from analyses to see if results hold. 
% Slink periods relatively short. 
% Perhaps more dips in LFS1-4 could be removed. 
% Great accuracy, decent number of trials.
% No researcher notes.
% Removing deflections from surface channels if the deflections are reflected in the depths.
% Very little, if any buzz.
% Channel RFS8 gets spiky between segments 281 and 292.
% Interictal spikes in surface channels.
% Checked for spikes in depths that extended to surface.

% Data is very clean of buzz. 
% Synchronous dips in LFS, RFS are a little worrying for phase encoding.
% B/c of synchronous dips and middling coverage, would be an interesting test subject for phase encoding.
% Great for HFA and slope. [NOTE: VERY WRONG. JUMPS ALGORITHM IS DETECTING A LOT OF BUZZ]
% Lots of buzz detected by jumps.
% OK, after removing a ton of buzz channels, I am confident that no buzz remains.

% Channel Info:
info.R1032D.badchan.broken = {'LFS8', 'LID12', 'LOFD12', 'LOTD12', 'LTS8', 'RID12', 'ROFD12', 'ROTD12', 'RTS8', ... % flat-line channels
    };

info.R1032D.badchan.epileptic = {'RFS7', 'RFS8', ... % very spiky. Removing after using jump algorithm.
    'LTS1', 'LTS2', 'LTS7', 'LFS7', 'RTS1', 'RTS2', 'RTS7' ... % very spiky. Removing after using jump algorithm.
    };

% Some channels show large epileptic deviations, but are kept in to prioritize channels: 'LFS1x', 'LFS2x', 'LFS3x', 'LFS4x'

% Line Spectra Info:
% Session 1/1 z-thresh 1 re-ref, no manual. 
info.R1032D.FR1.bsfilt.peak      = [60   120  180  240  300];
info.R1032D.FR1.bsfilt.halfbandw = [0.5, 0.5, 0.5, 0.5, 0.5];
info.R1032D.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1032D.FR1.bsfilt.peak, ...
    info.R1032D.FR1.bsfilt.halfbandw, ...
    info.R1032D.fs);

% Bad Segment Info:
info.R1032D.FR1.session(1).badsegment = [295956,297228;318272,319731;323646,324666;347892,349415;380137,381092;382349,383266;401996,403228;411943,412718;423518,424112;428364,429396;437737,438531;455672,456196;498245,499870;506647,508486;510769,511531;575342,576101;604775,605989;642569,642789;693279,694441;771524,772286;811091,811653;815633,816409;852995,853531;860491,861550;890292,891260;920736,923506;926162,927795;959791,960559;966378,966972;976543,977254;985493,986278;989072,989834;992498,993415;1010691,1011169;1034124,1035563;1050131,1051189;1063330,1064035;1082311,1082983;1104014,1105318;1127421,1127764;1197318,1199234;1206072,1206718;1213672,1214305;1226994,1228208;1234642,1235747;1259820,1260782;1283646,1284982;1297923,1298827;1300111,1301789;1312318,1313306;1327098,1327725;1366911,1367815;1384272,1385041;1395253,1396254;1399046,1399763;1429292,1430092;1536718,1538867;1541523,1542202;1611640,1612247;1634466,1636086;1686033,1686950;1699588,1700131;1708460,1710030;1787672,1788725;1837040,1837738;1838892,1840138;1864285,1865093;1923091,1924028;1936795,1938195;1942878,1943705;1984382,1986067;2001414,2002124;2004047,2005609;2006246,2008679;2017105,2017473;2028056,2029115;2060252,2060531;2071556,2072769;2075124,2075815;2102575,2103537;2134085,2134480;2140562,2143208;2154046,2155234;2218188,2218937;2275840,2276383;2296136,2296769;2302240,2303731;2379240,2380105;2490021,2490486;2491234,2491873;2575782,2576976;2683169,2684047;2769040,2770731;2773872,2774402;2787653,2788899;2836318,2837015;2873924,2874473;2878446,2878970;2909427,2910299;2954453,2954673;3007272,3007944;3031504,3032144;3037711,3038208;3048930,3049770;3104111,3104751;3189285,3190144;3240588,3241376;3250570,3251785;3282078,3282602;3343072,3343667;3351188,3351808;3369575,3370196;3386492,3387054;3392214,3393009;3418892,3419667;3454246,3455021;3478498,3479073;3482918,3484080;3484956,3485531;3493789,3494465;3507201,3507783;3564590,3566094;3585137,3587221;3596424,3597255;3625111,3625738;3649853,3650396;3679416,3680366;3718348,3719571;3723743,3724473;3734614,3735350;3813557,3814279;3817580,3818101;3831169,3831828;3843285,3844060;3914453,3915131;3930743,3931893;3987918,3988338;4040356,4040506;4062736,4063511;4065769,4065983;4074446,4075021;4081124,4082815;4084260,4084738;4097917,4098209;4137227,4138550];
info.R1032D.FR1.session(1).jumps      = [390578,390775;401990,402543;424978,425778;967376,970286;976526,977052;992204,992765;1062401,1064673;1228285,1234395;1261898,1268293;1634618,1635432;1736221,1738479;2026551,2027673;2102590,2103123;2920190,2920362;3036690,3037490;3061200,3062032;3401504,3402880;3404462,3405264;3405585,3406403;3524524,3525387;3530969,3531792;3556860,3557689;3574333,3575436;3692027,3692846;3813564,3814145;4014368,4015170;4040274,4040510;4042680,4042929];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1033D %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1033D' - 1    - 19T  - 14F   - 23/108  - 0.2130   - 6T   - 13F   - 21/98 - 0.21429   - ??? - Done. Expansion? 

% Removed buzz and IED events, lots of large and some small blips that carry through from depths.
% Remaining surface channels have frequent slow drifts.
% Even if this subject had ended up with enough trials, I would not trust them. [EDIT: maybe not that bad].
% LTS6 and LTS7 were originally marked as broken/epileptic (high frequency noise/spiky slinkies). New cleaning kept them in.
% Stopped because patient was having trouble focusing.
% Prioritizing trials over channels.
% Not that bad of a subject, really.
% I'm guessing not too many ambiguous events remain. 
% Very clean lines.
% Some addition of buzz via jumps.

% Channel Info:
info.R1033D.badchan.broken = {'LFS8', 'LTS8', 'RATS8', 'RFS8', 'RPTS8', 'LOTD12', 'RID12', 'ROTD12'... % flat-line channels
    'LOTD6'}; % large voltage fluctuations; might be LOTD9

info.R1033D.badchan.epileptic = {'RATS*' ... % Kahana
    'RPTS*', ... % IED bleedthrough from depths. Prioritizing trials over channels.
    'LTS7' ... % constant high frequency noise. Removed after jumps.
    };
  
% Line Spectra Info:
info.R1033D.FR1.bsfilt.peak      = [60.1 120 180 240 300];
info.R1033D.FR1.bsfilt.halfbandw = [0.5  0.5 0.5 0.5 0.5];
info.R1033D.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1033D.FR1.bsfilt.peak, ...
    info.R1033D.FR1.bsfilt.halfbandw, ...
    info.R1033D.fs);

% Bad Segment Info:
info.R1033D.FR1.session(1).badsegment = [414945,420783;538621,538680;594181,598247;696949,699215;711098,715176;808988,813267;1176724,1181432;1336700,1339307;1387536,1392086;1395569,1399163;1402653,1406015;1618472,1621609;1637556,1639125;1656427,1660183];
info.R1033D.FR1.session(1).jumps      = [28115,28917;39804,40613;52925,56006;73056,73865;83175,83988;85883,86686;108201,109004;129871,132027;141085,142219;151314,153203;267876,269444;305614,306416;350496,351838;358212,359012;360692,361492;484182,487497;540859,543273;595029,595832;596011,596820;696936,698969;855201,859009;977872,979712;1176597,1178995;1336449,1340215;1441848,1443044;1618902,1627325;1637532,1638501;1641130,1643692;1656384,1659402];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1034D %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1034D' - 3    - 10T  - 67F   - 48/528    - 0.0909   - 8T   - 51F   - 41/475    - 0.0863   - ??? - Done. 29. Expansion.
% 'R1034D' - 1/3  - 10T  - 67F   - 21/132    - 0.1591   - 8T   - 51F   - 21/126    - 0.1667   - ??? - 
% 'R1034D' - 2/3  - 10T  - 67F   - 24/300    - 0.0800   - 8T   - 51F   - 17/268    - 0.0634   - ??? - 
% 'R1034D' - 3/3  - 10T  - 67F   - 3/96      - 0.0312   - 8T   - 51F   - 3/81      - 0.0370   - ??? - 

% Line spectra relatively clean.
% Channels are ropy in Session 1, need LP to clean.
% RIHG grid is very flat compared to others. Need to go through it separately to clean.
% Big deflections in LTS channels that are sometimes present in other channels, but being lenient in order to preserve trials.
% Not many IEDs or buzz, just wonkiness.
% Removing big deflections if in multiple grids (like in all of LTS, LFG, and RIHG)
% Session 2: more blips across grids, not necessarily big, but definitely more IED looking.
% This subject's IEDs are very subtle
% Lots of IEDs in Session 3 too. Very poor performance in Session 3.
% Looking at Session 1 again. Not many IEDs.
% LIHG17-18 are marked as epileptic by me, but could probably be kept in. That being said, we don't really need two more frontal channels.
% Same thing for LOFG10.
% So, I'm leaving them out.
% Only notes about two of three sessions. The first note says that the subject was not feeling good.
% Jumps is picking up stuff that with LP are removed. Not much change.

% A somewhat ambiguous subject, with large fluctuations (especially in LTS) that may or may not affect phase encoding.
% High frontal coverage, so interesting test subject for phase encoding.
% Great for HFA and slope. 

% Channel Info:
info.R1034D.badchan.broken = {'LFG1', 'LFG16', 'LFG24', 'LFG32', 'LFG8', 'LIHG16', 'LIHG24', 'LIHG8', 'LOFG12', 'LOFG6', 'LOTD12', 'LTS8', 'RIHG16', 'RIHG8', ... % flat-line channels
    'LOTD7'}; % large voltage fluctuations

info.R1034D.badchan.epileptic = {'LIHG17', 'LIHG18'... % big fluctuations and small sharp oscillations. Confirmed.
    'LOFG10', ... % frequent small blips, removed during second cleaning. Confirmed.
    'LFG13', 'LFG14', 'LFG15', 'LFG22', 'LFG23'}; % marked by Kahana

% Line Spectra Info:
% Combined re-ref, has spectra for all sessions. z-thresh 1 + manual
info.R1034D.FR1.bsfilt.peak      = [60  120 172.3 180 183.5 240 300 305.7 ...
    61.1 200 281.1 296.3 298.1];
info.R1034D.FR1.bsfilt.halfbandw = [0.5 0.5 0.5   0.5 0.5   0.6 0.9 0.5 ...
    0.5  0.5 0.5   0.5   0.5];
info.R1034D.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1034D.FR1.bsfilt.peak, ...
    info.R1034D.FR1.bsfilt.halfbandw, ...
    info.R1034D.fs);
     
% Bad Segment Info:
info.R1034D.FR1.session(1).badsegment = [418859,420105;443382,444751;576389,580731;927897,929035;1065949,1066828;1119020,1122286;1157962,1158977;1214827,1215892;1416659,1419518;1547646,1548234;1552020,1561253];
info.R1034D.FR1.session(1).jumps = [2248530,2248647;2267565,2267826];
info.R1034D.FR1.session(2).badsegment = [446407,448990;452969,454932;520027,521467;600181,601137;618395,619408;620442,621784;683201,683660;690562,691086;735233,735602;736563,737054;790337,790860;849659,850647;973789,974886;1073716,1081380;1104836,1108258;1229213,1230936;1370015,1370627;1444275,1445070;1493901,1494632;1693569,1694092;1734660,1735848;1765949,1769447;1771052,1772595;1890633,1891421;2028786,2030712;2056840,2058009;2083801,2084241;2099369,2099809;2193910,2194466;2244104,2244679;2246119,2246950;2259324,2259951;2409511,2410021;2436324,2437769;2440563,2441421;2509285,2510215;2694847,2696712;2745853,2747196;2748401,2749092;2750285,2751505;2790666,2791583;2937601,2943408;3079705,3080918;3112034,3112725;3123201,3124235;3193472,3194713;3200298,3201067;3342511,3346956;3378279,3379612;3428040,3428853;3491324,3492415;3571679,3572615;3628294,3629335;3692054,3698287;3731285,3732454;3772982,3773983;3775820,3777053;3790388,3791505;3796498,3797525;3860995,3863402;3871085,3872000;4015337,4016286;4017201,4018021;4027408,4027905;4134866,4136131;4301679,4302512;4312027,4313040];
info.R1034D.FR1.session(2).jumps = [1073978,1074298;2791145,2791466;3342529,3342865;3692103,3692425];
info.R1034D.FR1.session(3).badsegment = [334698,335280;337994,339200;356885,357847;376207,377460;425917,426750;475356,476105;514240,515241;516033,517182;521633,522744;523575,524621;527524,528376;570118,570938;571808,575021;600027,600731;659344,660473;663261,666830;668150,669692;672608,674589;749679,750680;819201,820873;858672,862415;868897,870569;972245,973578;977730,978724;1006576,1007434;1017918,1018751;1031201,1032486;1061788,1062866;1082782,1083654;1087343,1087711;1123820,1124466;1175814,1176898;1185298,1188208;1250105,1251034;1307872,1310615;1335620,1336737;1337177,1338529;1380414,1382376;1403666,1404234;1406710,1407079;1408885,1412931;1425388,1427200;1428892,1429609;1433354,1434687];
info.R1034D.FR1.session(3).jumps = [54931,55505;100734,101054;102527,102847;103066,103386;259321,259641;425825,426145;572907,573227;668093,668413;1031143,1031471;1186119,1186440;1250072,1250393;1381311,1381632];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1045E %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes: 

% 'R1045E' - 1    - 17T  - 26F   - 98/300    - 0.3267   - 12T  - 24F   - 77/236    - 0.3263   - :)  - Done. Core. 51.

% End of segment goes bad. Samples 2603373 onward are bad.
% Enormous spikes in several channels, screwing up demeaning. 
% Will have to clean lines around spikes. 
% Spikes are at samples 431722:431752, 1078427:1078454, and 2204508:2204508
% Clean is [1:431721, 431753:1078426, 1078455:2204507, 2204534:2603373]
% Less spikes in re-ref vs. non-ref (3 vs. 9). Baselines similar. 
% Noise consistent across channels.
% LATS1-4 are coherent, strongly slinky, high amplitude. [NOTE: now removing.]
% Reference buzz remains in surface channels.
% LAFS and remaining LATS are very smooth and flat, whereas other surface channels have more high frequency activity.
% No more discrete events to remove (other than buzz), but does not look very clean.
% Right-hand channels have odd-number naming convention. Keeping them in, but consider removing them.
% 'RPTS7' was originally marked as broken, but keeping in. [NOTE: apparently taking it out]
% Removing buzzy episodes.
% Subject attentive and engaged.
% Jumps did not add any segments.

% Buzz is main concern, but these seem mostly discrete. Not great for slope, but not awful. Would be ok.
% But great coverage for phase encoding, though watch out for LATS1-4 [NOTE: these channels are now removed]

% Channel Info:
info.R1045E.badchan.broken = {'RPHD1', 'RPHD7', 'LIFS10', 'LPHD9', ... % large fluctuations
    'RAFS7', ... % very sharp spikes
    'RPTS7' ... % periodic sinusoidal bursts
    };

info.R1045E.badchan.epileptic = {'LAHD2', 'LAHD3', 'LAHD4', 'LAHD5', ... % Kahana
    'LMHD1', 'LMHD2', 'LMHD3', 'LMHD4', 'LPHD2', 'LPHD3', 'LPHGD1', 'LPHGD2', 'LPHGD3', ... % Kahana
    'LPHGD4', 'RAHD1', 'RAHD2', 'RAHD3', 'RPHGD1', 'RPHGD2', 'RPHGD3', ... % Kahana
    'LATS1', 'LATS2', 'LATS3', 'LATS4', 'LATS5' ... % constant coherent high amplitude slink with IEDs
    }; 

% Line Spectra Info:
% Session 1/1 z-thresh 2 on re-ref, no manual. 
info.R1045E.FR1.bsfilt.peak      = [59.9 179.8 299.6];
info.R1045E.FR1.bsfilt.halfbandw = [0.5  0.5   0.5];
info.R1045E.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1045E.FR1.bsfilt.peak, ...
    info.R1045E.FR1.bsfilt.halfbandw, ...
    info.R1045E.fs);
     
% Bad Segment Info:
% Have to remove sample 2603373 onward b/c of file corruption.
% Added bad segments of big spikes.
info.R1045E.FR1.session(1).badsegment = [426456,427376;430634,432786;489664,492021;573918,575147;603046,604538;668795,670121;763031,763858;777706,778508;878339,879120;889324,892020;960986,961515;983367,984697;1052995,1054103;1077390,1079768;1117845,1119861;1197221,1199374;1271357,1273408;1354645,1355991;1433457,1434735;1460994,1463412;1559206,1561104;1581212,1582413;1610941,1613273;1635295,1637809;1657760,1659643;1693909,1694523;1754297,1756481;1777092,1778705;1848710,1848868;1852916,1854144;1955418,1959202;1986013,1986985;2021977,2023589;2121877,2125386;2160249,2161836;2202546,2205761;2241007,2242652;2317358,2318906;2346414,2349258;2355489,2359704;2360718,2364755;2366930,2369073;2410999,2411604;2436867,2439423;2444171,2444981;2463933,2465227;2500654,2502823;2503692,2504760;2603221,2916214];
info.R1045E.FR1.session(1).jumps = [171692,172466;210724,210924;211037,211298;302424,303297;379905,380323;426736,426936;431159,431979;490205,490408;490632,491376;574195,574692;574694,574897;669110,669823;763432,763769;878794,879091;889872,890182;890388,890588;983704,984012;984263,984468;1053224,1053746;1078325,1078556;1118147,1118347;1118398,1118916;1119044,1119368;1198393,1198921;1272229,1272542;1272551,1272751;1355155,1355355;1462419,1463188;1611631,1611834;1611908,1612453;1612482,1612686;1658611,1658811;1658828,1659247;1755204,1755404;1755499,1755870;1957884,1958084;1958173,1958463;2022607,2023412;2122626,2122826;2124507,2124833;2124885,2125209;2160996,2161196;2161218,2161605;2161682,2161882;2204406,2204634];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1059J %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1059J' - 2    - 53T  - 61F   - 36/444  - 0.0811   - 19T  - 47F   - 35/421  - 0.0831   - ??? - Done. Expansion. 44. 
% 'R1059J' - 1/2  - 53T  - 61F   - 8/144   - 0.0556   - 19T  - 47F   - 8/140   - 0.057143 - ??? - 
% 'R1059J' - 2/2  - 53T  - 61F   - 28/300  - 0.0933   - 19T  - 47F   - 27/281  - 0.096085 - ??? - 

% LFB3 was marked as broken, but not sure why I did that.
% IEDs in depths/epileptic channels bleed into LSTA, LSTB
% 'Patient spoke words aloud during list 1 presentation, had no recall for several lists. Did not seem to understand instructions and had poor recall on most lists. Patient completed 12 lists.'
% 'Offered strategy after list 12 (had several lists with no recall).'
% RSTA and RSTB are slightly buzzy.
% Removing buzzy episodes.
% Several strong IED episodes in depths, hoping I removed enough of the bad surface channels to compensate.
% LFB grid has slow swoops that follow depth IEDs.
% Buzz is more ambiguous in Session 2.
% Long buzz episodes in Session 2.
% Really prioritizing trials over channels b/c of low trial number. 

% Buzz is concerning.
% Great coverage for phase encoding, and considering how many channels I threw out, I'm confident in what remains.

% Channel Info:
info.R1059J.badchan.broken = {'LDC*', 'RDC7', 'LFC1', 'LIHA1', 'RAT1', 'RAT8', 'RIHA1', 'RIHB1', ... % big fluctuations. Confirmed.
    };

info.R1059J.badchan.epileptic = {'LSTA8', ... % continuously spiky. Confirmed.
    'LSTA1', 'LSTA2', 'LSTA3', 'LSTA4', 'LSTA5', 'LSTB*', 'LPT5', 'LPT6', 'RPT1', ... % IEDs bleeding through. Removing to preserve trials. Confirmed.
    'LAT5', 'LAT6', 'LAT7', ... % strong slink that is accompanied by spikes in depths
    'RAT2', 'RAT3', 'RAT6', 'RAT7', 'RSTA2', 'RSTA3', 'RSTA5', 'RSTA6', 'RFB1', 'RFB2', ... % little spikelets with one another
    'LFB5', 'LFB6', 'LFB7', 'LFB8', ... % swoops that track depths
    'LFD1', ... % swoops with spiky oscillations atop (Session 2)
    'RPT8', 'RPTA8', 'RPTB8', ... % intermittent buzz (especially in Session 2)
    'RIHA2', 'RFC1', 'RFC3', ... % break (mildly) partway through Session 2, big swoops
    'LAT8', 'LSTA7', 'RPT7', 'RSTA8', ... % constant spiky. Removed after jumps.
    'LAT1', 'LAT2', 'LAT3', 'LAT4'}; % Kahana

% Line Spectra Info:
info.R1059J.FR1.bsfilt.peak      = [60  180 240 300];
info.R1059J.FR1.bsfilt.halfbandw = [0.5 0.5 0.5 0.5];
info.R1059J.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1059J.FR1.bsfilt.peak, ...
    info.R1059J.FR1.bsfilt.halfbandw, ...
    info.R1059J.fs);

% Bad Segment Info:
info.R1059J.FR1.session(1).badsegment = [463496,464961;560170,562393;562404,563017;670174,670659;670669,672979;792582,794626;967811,969215;969235,969602;988178,988349;1172964,1174707;1334311,1336000;1435101,1435312;1491812,1493448];
info.R1059J.FR1.session(1).jumps = [133,336;1444,1649;4217,4417;11194,11395;14400,14601;19424,19624;21392,21592;26401,26675;28301,28503;28521,28721;28787,29004;30613,30813;30877,31077;41260,41473;53530,53740;59526,59782;63666,63971;79875,80075;81382,81582;82645,82915;85017,85217;89073,89289;89728,90002;90409,90611;98386,98759;98804,99005;100897,101101;102260,102622;102744,102944;103599,103818;106191,106391;118480,118681;123206,123406;129303,129504;135671,135872;136997,137201;144532,144825;144948,145153;149575,149785;150358,150562;154352,154649;162235,162435;194413,194613;201540,201740;228125,228325;242360,242560;245940,246380;268008,268214;289382,289586;299434,299692;322829,323030;330360,330565];
info.R1059J.FR1.session(2).badsegment = [456154,458167;761303,763116;878336,881296;1154089,1164000;1164005,1170590;1425069,1428000;1469013,1473131;1546379,1547038;1657702,1664000;1960908,1961066;1968001,1971094;2089573,2094957;2162383,2162522;2392001,2397473;2411206,2414417;2470371,2470844;2521593,2523469];
info.R1059J.FR1.session(2).jumps = [261,464;1549,1754;3201,3407;20294,20495;22073,22273;22333,22533;25256,25456;26641,26845;27126,27326;27416,27717;27902,28102;28935,29135;33199,33467;33659,34036;34186,34550;34634,34834;35037,35458;35670,35931;36418,36647;37696,37899;38536,38793;41838,43471;43484,43684;43870,44075;44086,45240;45494,45765;46626,46826;46916,47116;47433,47633;47788,48023;48037,54372;54431,54640;54762,55669;56422,56622;56631,57067;57177,57499;59332,59532;62090,62293;64479,64746;64818,65116;65168,65439;65562,65868;66257,66538;66666,67725;74453,74820;75314,75514;89185,89385;100995,101196;136264,136465;153994,154194;159890,160091;165537,165737;194617,194817;205257,205457;216045,216245;242611,243402;244002,244403;244616,246802;247127,247328;315669,315876;451883,452089;732259,732459;878723,879121;879814,880795;942823,947715;948747,950876;1154201,1154401;1154470,1154670;1154817,1155027;1157836,1160369;1160458,1160658;1160768,1161377;1161409,1161966;1162011,1162211;1162248,1162579;1163782,1164180;1164227,1167286;1167613,1170242;1170883,1172570;1425236,1426090;1426182,1426503;1426602,1427007;1469401,1472401;1472425,1472625;1658076,1663602;2090572,2092117;2092146,2092346;2092509,2092709;2092729,2092937;2110222,2112131;2162355,2162556;2264001,2266493;2273460,2276522;2392001,2392232;2392258,2392665;2392797,2393138;2393161,2393470;2393474,2393772;2393797,2395085;2395121,2395619;2395712,2395912;2395945,2396145;2396271,2396471;2402257,2402457;2412198,2412637;2413075,2413276;2413810,2414010;2521910,2523266;2641398,2641605;2734045,2734695;2744207,2744965;2771525,2771725;2774584,2774784;2785761,2786137;2786665,2788161];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1075J %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1075J' - 2    - 7T   - 88F   - 150/600   - 0.2500   - 7T   - 37F   -   134/556 - 0.2410               - :)  - Done.
% 'R1075J' - 1/2  - 7T   - 88F   - 102/300   - 0.3400   - 7T   - 37F   -   99/294  - 0.33673              - :)  - 105 recall (3 words repeated)
% 'R1075J' - 2/2  - 7T   - 88F   - 48/300    - 0.1600   - 7T   - 37F   -   35/262  - 0.13359              - :)  - 48 recall

% First subject in which I'm scrolling until the end of recall trials too.

% Lots of high frequency (> 240 Hz) noise on half of the channels, especially surface. Squashed by lowpass filter.
% Re-referencing introduces weird side lobes on lines at harmonics. Using non-ref for peak detection.
% Additionally, left channels have the wide side lobes. Removing these. 
% Alternatively, could do an 'R*' and 'L*' specific re-ref.
% Saving L* channels goes from 7/34 to 7/79

% In 2 sessions, the second session has more apparent peaks at more frequencies. Combining both sessions captures all peaks.
% Peak detection on combined sessions.
% Relatively free of large interictal events, just slinky.
% Some occasional dips.
% Great accuracy and number of trials.
% Keeping 'RFB1', 'RFB3', 'RFB4' even though some slow drifts.
% Almost no buzz or IEDs.
% In Session 2, sharp buzz in ROF. Not sure if in Session 1. RPIH are dodgy too. Cannot remove ROF - these are the only temporal channels.
% Much more buzz in Session 2. Very slight. Hope I got them all.
% Had to remove a lot of buzz in ROF (temporal channels) of Session 2, but I left some in that seemed relatively small.
% All the same, baby with the bath water?

% Decent coverage for phase encoding.
% Again worrying for HFA.

% Channel Info:
info.R1075J.badchan.broken = {'LFB1', 'LFE4', ... % big fluctuations, LFE4 breaks in session 2
    'RFD1', 'LFD1', 'RFD8', 'LFC1', ... % sinusoidal noise + big fluctuations. Confirmed.
    'RFD2', 'RFD3', 'RFD4', ... % big drifts, almost look like eye channels. Confirmed.
    'L*', ... % bad line spectra (ringing side lobes)
    'RFA8' ... % buzzy. Confirmed.
    };

info.R1075J.badchan.epileptic = {}; % no Kahana channels

% Line Spectra Info:
% z-thresh 1
info.R1075J.FR1.bsfilt.peak      = [60  120 180 240 300];
info.R1075J.FR1.bsfilt.halfbandw = [0.5 0.5 0.5 0.5 0.5]; 
info.R1075J.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1075J.FR1.bsfilt.peak, ...
    info.R1075J.FR1.bsfilt.halfbandw, ...
    info.R1075J.fs);

% line spectra info if L* grid were kept in.
% info.R1075J.FR1.bsfilt.peak      = [60  120 178.7 180 181.4 220 238.7 240 280.1 300 ...
%     100.2 139.8 160.1 260];
% info.R1075J.FR1.bsfilt.halfbandw = [0.5 0.5 0.5   1.7 0.5   0.8 0.5   1.7 0.5   3.1 ...
%     0.5   0.5   0.5   0.5];
% info.R1075J.FR1.bsfilt.edge      = 3.1840;

% Bad Segment Info:
info.R1075J.FR1.session(1).badsegment = [499288,502539;1273396,1273957;2382362,2385083];
info.R1075J.FR1.session(1).jumps = [114,317;1134,1413;9440,9644;58478,58678;59956,60176;60720,60932;95430,95630;154270,154471;160134,160334;198650,198850;212332,212532;259877,260262;260407,260607;318742,318943;348062,348263;350866,351066;371653,372182;402449,402649;474569,475384;499898,500295;500398,500600;502908,503497;506242,507259;660416,660816;857823,860000;1082839,1084611;1151669,1152454;1591274,1594997;1642769,1642969;1774553,1776764;1932001,1933494;1944070,1944703;1945239,1946848;2039172,2039372;2335871,2337510;2361315,2361352;2381138,2382594;2382892,2383116;2383312,2383512;2385017,2386630;2560001,2560635;2866596,2866797];
info.R1075J.FR1.session(2).badsegment = [313863,314505;366283,366530;398972,399239;579045,579485;753718,754695;756332,756744;848723,849348;856082,857276;886117,889453;947593,948546;1052670,1056000;1183440,1185784;1198605,1199924;1200001,1205268;1216751,1217228;1217811,1218231;1218807,1219078;1270504,1270965;1375581,1375916;1376001,1376776;1389037,1396498;1438275,1440990;1444444,1447449;1460001,1461026;1492654,1494215;1600001,1601030;1621811,1622864;1842267,1843715;1846654,1848000;1967335,1975114;2042500,2042634;2060178,2068000;2125839,2126513;2162766,2164000;2167464,2175775;2185872,2186372;2212134,2215150;2250351,2258497;2304106,2305695;2468352,2469526;2498194,2499521;2528098,2528635;2606254,2607892;2608001,2610461;2625331,2625671;2667359,2667868;2729118,2730006;2741428,2746195];
info.R1075J.FR1.session(2).jumps = [154,357;1174,1469;36895,37095;50472,50674;167408,167608;170066,170266;178297,178497;199203,199403;200182,200385;202965,203166;209234,209434;240974,241174;265481,265683;277705,277905;281749,281949;314267,314467;371870,373421;399034,399236;407577,408000;591705,591906;696960,697739;756472,756672;852591,852791;856421,856621;1269202,1269506;1270612,1270812;1336944,1337961;1390906,1391106;1391353,1391555;1391603,1392037;1392052,1392319;1392477,1392810;1393601,1393801;1393937,1394473;1489855,1495163;1622147,1622347;1847140,1847500;1969747,1970076;1970097,1970482;1970622,1970870;1970982,1972853;1973601,1973833;1974649,1974849;2040247,2042002;2042456,2042656;2062287,2062581];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1080E %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1080E' - 2    - 6T   - 10F   - 107/384   - 0.2786   - 6T   - 7F    -    106/376  - 0.2819                - :)  - Good pending clean. ***
% 'R1080E' - 1/2  - 6T   - 10F   - 47/180    - 0.2611   - 6T   - 7F    -   47/176 - 0.2670                   - :)  - 47
% 'R1080E' - 2/2  - 6T   - 10F   - 60/204    - 0.2941   - 6T   - 7F    -  59/200 - 0.295                   - :)  - 59

% Lots of reference noise, but for surface channels, it goes away after re-referencing.
% A couple borderline slinky channels, but relatively low amplitude (RPTS7, RSFS2). Will keep them in. 
% Weird number naming conventions in surface channels.
% Re-referencing fixes very bad baseline of line spectra. 
% Doing line detection on individual re-ref sessions. 
% Noise consistent on channels.
% Low amplitude slink in remaining channels, no events.
% Buzz remains, use depth channels to detect strong buzz events.
% RPTS7 (high amplitude slink).
% Removing a lot of buzz episodes. Some mild ones (where I can barely tell they're there, except for the depths) might be left in.
% Seems like most of the buzz episodes are when the subject is on a break. 

% Again, buzz is worrying.
% Low channel number, but good data for phase encoding.

% Channel Info:
info.R1080E.badchan.broken = {'L9D7', 'R12D7', 'R10D1', ... sinusoidal noise, session 1
    'RLFS7', 'RLFS4', 'RSFS4', ... % sharp oscillations/buzz. RLFS4 on Session 2. Confirmed.
    'L5D10', 'R10D7', ... sinsusoidal noise, session 2
    };

info.R1080E.badchan.epileptic = { ...
    'R6D1', 'R4D1', 'R4D2', 'L1D8', 'L1D9', 'L1D10', 'L3D8', 'L3D9', 'L3D10', 'L7D7', 'L7D9'}; % Kahana

% Line Spectra Info:
info.R1080E.FR1.bsfilt.peak      = [59.9 179.8 239.7 299.7]; % 239.7 is apparent in session 2, but not 1
info.R1080E.FR1.bsfilt.halfbandw = [0.5  0.5   0.5   0.6];
info.R1080E.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1080E.FR1.bsfilt.peak, ...
    info.R1080E.FR1.bsfilt.halfbandw, ...
    info.R1080E.fs);

% Bad Segment Info:
info.R1080E.FR1.session(1).badsegment = [412427,416452;430126,432416;560790,560980;568339,572606;608428,611388;874141,875004;877988,878751;879193,882295;957043,957410;994263,997785;1069144,1070928;1098078,1100618;1243373,1246052;1336276,1337328;1342657,1344128;1360034,1361449;1387330,1389651;1408880,1411963;1513731,1517627;1606550,1606688;1657378,1657753;1658631,1661379;1679513,1680847;1684194,1686813;1693241,1695699;1699884,1704525;1793491,1796119;1914617,1917392;1926182,1929433;1962565,1965928;2052180,2056362;2057941,2060624;2084958,2085615;2086553,2088616;2134940,2137003;2138155,2140355;2247485,2251284;2368448,2371108;2378044,2381616;2429081,2431648];
info.R1080E.FR1.session(1).jumps = [869718,869792;968608,968842;1100584,1100779;1306217,1306621;1316546,1316837;1370750,1371878;1478521,1479521;1513590,1513784;1658341,1658729;1661277,1661503;2480896,2481516];
info.R1080E.FR1.session(2).badsegment = [280893,282336;309485,311688;488910,490095;504653,507159;581350,582833;715378,717433;832450,836519;861195,863448;943822,947658;1039513,1042345;1153382,1155212;1272827,1274463;1373384,1374544;1374625,1376990;1537904,1540359;1646776,1647768;1691851,1692956;1693342,1694854;1927692,1929304];
info.R1080E.FR1.session(2).jumps = [409792,412057;1591855,1591880;1802059,1802766];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1120E %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes: 

% 'R1120E' - 2    - 13T  - 3F    - 207/600   - 0.3450   - 7T   - 3F    - 207/599  - 0.3456    - :)  - Done. Core. 33.
% 'R1120E' - 1/2  - 13T  - 3F    - 97/300    - 0.3233   - 7T   - 3F    - 97/300   - 0.3233    - :)  - 97
% 'R1120E' - 2/2  - 13T  - 3F    - 110/300   - 0.3667   - 7T   - 3F    - 110/299  - 0.3679    - :)  - 112

% When switching to channel labels using individual atlases, channel numbers go to 14T and 4F (vs. 12T and 1F)
% Very clean line spectra.
% Remaining channels very slinky. Not a particularly clean subject.
% Cleaning individual re-ref sessions, baseline too wavy on combined. Same peaks on both sessions. 
% Lots of slinky episodes, some large amplitude episodes.
% Perhaps some ambiguous IED episodes in surfaces. Keeping them in mostly.
% Ambiguous buzz. Mostly leaving them in.
% LPOSTS10 has oscillation with spike atop. Not a T or F channel.
% LANTS5-8 are a little dodgy (spiky). Could take out. [TAKEN OUT]

% Not super for either HFA (buzz) or phase encoding (coverage, IEDs). 

% Channel Info:
info.R1120E.badchan.broken = {
    };
info.R1120E.badchan.epileptic = {'RAMYD1', 'RAMYD2', 'RAMYD3', 'RAMYD4', 'RAMYD5', 'RAHD1', 'RAHD2', 'RAHD3', 'RAHD4', 'RMHD1', 'RMHD2', 'RMHD3' ... % Kahana
    'LPOSTS1', ... % spiky. Confirmed.
    'LANTS10', 'LANTS2', 'LANTS3', 'LANTS4' ... % big fluctuations with one another
    'LANTS5', 'LANTS6', 'LANTS7', 'LANTS8'}; % spikes, especially Session 2

% Line Spectra Info:
% session 2 z-thresh 1 + 2 manual
info.R1120E.FR1.bsfilt.peak      = [60  179.8 299.7 ...
    119.9 239.8]; % manual
info.R1120E.FR1.bsfilt.halfbandw = [0.5 0.5   1 ...
    0.5   0.5]; % manual
info.R1120E.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1120E.FR1.bsfilt.peak, ...
    info.R1120E.FR1.bsfilt.halfbandw, ...
    info.R1120E.fs);

% Bad Segment Info:
info.R1120E.FR1.session(1).badsegment = [170475,171499;177831,179269;353469,354723;387613,388601;979690,980806];
info.R1120E.FR1.session(1).jumps = []; 
info.R1120E.FR1.session(2).badsegment = [334134,334682;432274,434280;438585,439560;1164557,1164646;1380526,1381908;2021263,2021976;2318696,2321676;2327103,2329025];
info.R1120E.FR1.session(2).jumps = [2003415,2003508];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1135E %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1135E' - 4    - 7T   - 15F   - 107/1200  - 0.0892 - 6T - 13F - 31/370   -  0.0838                         - ??? - Done. Expansion.
% 'R1135E' - 1/4  - 7T   - 15F   - 26/300    - 0.0867 - 6T - 13F - 10/61 - 0.16393                     - ??? - 
% 'R1135E' - 2/4  - 7T   - 15F   - 43/300    - 0.1433 - 6T - 13F - 8/48 - 0.16667                               - ??? - 
% 'R1135E' - 3/4  - 7T   - 15F   - 26/300    - 0.0867 - 6T - 13F - 6/105 - 0.0571436                                    - ??? - 
% 'R1135E' - 4/4  - 7T   - 15F   - 12/300    - 0.0400 - 6T - 13F - 7/156 - 0.044872                                 - ??? -

% Frequent interictal events, and lots of channels show bursts of 20Hz activity. 
% RSUPPS grid goes bad in Session 3. 
% Session 3 has lots of reference noise. 
% FR1 was done prior to a re-implant. Localization folder 0 is the same in both releases. This one is presumably the pre-re-implant.
% Line detect on individual re-ref; combo makes wavy baseline.
% An amazing amount of IEDs in RANTTS1-3-5, RPOSTS3. Removal of these would lead to only 2T. Likely to lose more than half of trials.
% Ambiguous IEDs remain.
% Sessions 3 and 4 could probably use a re-clean. Session 1 has been extensively re-cleaned, Session 2 kinda.
% Not bothering to run jumps algorithm. Hardly any buzz, mostly IED. [NOTE: FOUND SPIKY CHANNEL USING JUMPS]
% RANTTS have IEDs, but not being removed b/c these spikes extend to multiple channels. They also get buzzy in Session 3.

% Channel Info:
info.R1135E.badchan.broken = {'RAHCD3', ... Kahana broken
    'RROI1*', 'RROI2*', 'RROI3*', 'RROI4*',  ... Kahana brain lesion
    'LHCD9', 'RPHCD1', 'RPHCD9', 'RSUPPS*' ... mine, 
    };

info.R1135E.badchan.epileptic = {'RLATPS1' ... % periodic bursts of middling frequency
    'LROI3D7', 'LIPOS3' ... Kahana epileptic
    'RLATPS3', 'RPOSTS3', 'RLATFS1', ... funky IED-like oscillations
    'RLATPS7', ... % weirdly discontinuous oscillations
    'RSUPFS6' ... % spikes on top
    };

% Line Spectra Info:
% Re-referncing prior to peak detection.
info.R1135E.FR1.bsfilt.peak      = [60  119.9 179.8 239.7 299.7];
info.R1135E.FR1.bsfilt.halfbandw = [0.5 0.5   0.5   0.5   0.5];
info.R1135E.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1135E.FR1.bsfilt.peak, ...
    info.R1135E.FR1.bsfilt.halfbandw, ...
    info.R1135E.fs);

% Bad Segment Info:
info.R1135E.FR1.session(1).badsegment = [180030,181179;185367,186633;187673,188593;190276,190973;192530,193747;194560,195435;196147,197030;198157,199173;200103,203410;207313,212225;214576,216096;221855,222372;236792,237151;240933,241474;242830,244477;250929,252246;255743,255744;258616,260789;269672,270716;277783,279097;284176,284972;287571,289091;291922,292866;294895,295704;301227,302223;305819,307359;312885,314735;316776,318497;319108,319680;320148,320830;355068,355644;361713,363636;364285,366413;388330,389845;393395,394095;395605,397044;398497,399371;400789,401541;405393,407247;409852,410530;411387,413801;414698,416698;438537,440146;444403,445523;449208,450224;451549,452879;457643,459066;460197,460798;461414,461952;463363,473213;477579,479110;489361,489906;491618,492553;493370,493842;495311,496710;498280,499143;501619,503496;504480,505363;508347,509636;515920,516747;552073,552864;554685,555444;568573,569520;575522,576082;582530,583925;587671,589329;594856,596586;597451,599400;603687,604236;606721,607756;609020,610124;611389,612800;613326,616220;644320,647115;650102,650942;651788,652478;654367,654954;655842,657317;661246,664288;674212,674938;688910,690286;691103,693066;700783,702777;704086,705449;706273,706939;708256,710629;711486,714077;717717,718935;731438,732756;757492,758645;760099,762891;765698,766452;772369,773014;776047,777991;786640,787212;800651,801417;802266,803196;806415,807192;808764,809630;811189,815855;818910,819180;820639,822833;824131,825208;826165,826649;828071,829323;852917,853780;864418,865474;866911,868443;871129,871684;883963,884588;887113,895104;900152,901667;907476,908367;909997,912653;915552,916238;918319,919583;920201,920874;924390,925402;938685,939060;941985,943056;963271,964609;971581,972061;972491,975401;978509,982409;991009,993451;1001208,1001732;1005925,1006992;1012596,1014059;1014985,1017048;1018134,1019512;1021361,1021966;1022977,1024605;1025792,1026972;1027001,1028718;1031899,1032835;1034094,1034964;1050949,1051751;1057285,1057793;1059815,1060927;1064983,1066932;1068834,1070928;1073184,1074418;1076407,1078067;1078646,1081789;1082917,1084436;1090207,1091492;1095563,1096553;1098082,1099546;1100363,1101101;1102556,1104867;1105229,1106301;1109839,1110440;1112641,1114313;1118881,1119683;1122465,1125655;1128858,1130466;1142857,1143861;1148250,1149085;1159135,1160175;1161487,1162237;1164577,1167100;1170325,1171869;1173181,1173850;1178821,1179611;1182817,1185073;1200182,1202652;1207651,1209553;1252614,1252989;1265004,1266530;1269037,1269605;1270559,1272462;1284018,1285420;1286261,1286712;1292219,1292510;1294914,1296502;1298701,1300297;1303668,1305469;1311696,1312806;1313963,1314684;1315297,1318552;1320683,1321920;1323176,1325984;1337126,1337884;1359334,1360684;1370080,1371226;1374113,1375903;1381545,1383244;1392176,1392873;1399950,1401115;1404643,1405103;1410256,1411520;1419765,1422576;1426395,1427154;1428115,1428684;1431705,1432104;1459785,1460854;1466533,1467428;1473296,1474030;1478021,1478786;1479582,1481772;1482435,1484516;1494045,1494784;1496414,1497708;1498706,1499533;1502186,1504789;1506493,1509784;1510489,1511312;1513491,1514484;1517763,1521257;1523041,1524546;1530323,1531553;1551363,1552023;1553419,1554444;1557326,1560617;1563307,1564206;1565689,1566432;1569345,1570095;1571361,1572216;1578233,1580240;1582114,1582640;1595458,1596085;1615891,1616623;1619589,1622376;1626814,1628573;1649728,1650348;1652971,1653443;1658709,1659752;1661200,1662336;1662353,1663023;1665750,1667135;1670329,1671526;1689442,1690308;1690913,1691673;1693825,1695420;1700162,1700835;1725787,1726977;1728484,1729874;1736085,1737528;1738212,1742548;1743513,1746252;1747638,1748821;1750249,1751245;1759308,1760723;1765139,1766232;1767723,1768662;1772178,1773705;1780964,1782216;1786624,1788346;1791570,1792473;1795091,1795966;1797531,1798200;1798676,1799895;1802777,1803221;1816535,1817448;1818644,1819338;1839995,1841150;1842157,1843580;1844626,1845289;1845890,1847487;1852972,1853839;1858568,1859622;1862856,1863523;1870346,1871395;1876074,1876788;1885687,1887995;1896030,1897694;1898101,1899290;1904572,1906092;1907680,1908772;1911426,1912782;1920864,1921533;1928018,1928966;1932002,1933074;1935913,1936736;1948417,1949095;1952276,1954044;1968196,1970028;2005993,2008676;2036301,2037176;2045586,2045952;2048391,2049049;2050209,2051194;2061344,2062363;2072500,2073924;2074930,2075787;2081917,2084918;2087796,2088467;2095963,2097482;2099127,2099769;2101328,2103453;2104780,2106188;2117913,2118700;2135190,2136045;2137034,2139976;2142457,2143028;2146751,2148572;2154397,2156226;2160886,2161620;2162385,2165402;2168072,2169483;2179045,2179779;2184854,2185438;2193431,2194050;2195106,2197338;2208026,2209788;2214518,2216404;2222099,2223131;2247666,2249431;2250583,2251490;2252471,2253744;2257993,2258562;2263408,2276030;2280693,2282421;2286456,2288481;2296645,2297700;2299145,2300193;2301697,2302630;2305693,2306812;2308730,2310773;2312673,2317680;2319272,2321676;2333269,2333664;2354398,2356950;2357382,2358637;2363224,2364848;2367852,2368457;2372819,2373624;2377109,2377781;2406604,2407362;2409589,2410343;2480094,2481516;2503776,2504261;2506862,2507439;2539829,2540825;2600361,2601230;2608158,2609053;2616164,2617380;2665369,2665924;2672853,2676328;2679319,2680862;2694155,2695642;2701297,2703380;2707754,2708548;2712827,2713608;2717545,2718706;2719909,2721276;2721285,2722124;2723262,2724403;2728610,2729176;2749412,2750605;2757843,2758875;2760483,2762126;2764676,2769228;2770570,2773947;2776356,2777220;2784705,2785212;2786917,2788569;2792902,2796186;2797201,2798708;2801197,2803000;2804455,2805192;2808415,2808931;2810868,2811417;2814152,2815381;2817181,2819324;2820512,2821176;2823179,2824827;2825403,2826120;2842204,2843045;2846196,2846860;2855467,2856275;2858555,2861136;2869638,2871663;2873459,2874902;2875807,2877786;2878671,2879339;2882281,2882987;2887276,2889108;2891936,2892585;2896045,2897100;2899908,2902010;2903276,2904400;2906827,2908604;2909089,2910596;2912774,2913084;2914128,2919136;2922676,2924247;2925073,2926492;2927683,2928940];
info.R1135E.FR1.session(1).jumps = [280051,283246;791209,794541;1598566,1610123;1610389,1611171;1630977,1631836;1650349,1650894;1730829,1732284;2400191,2401596;2442801,2442915;2699766,2700935;2752507,2753144;2871650,2873124;2886442,2887466;2889109,2891740;2905286,2905787];
info.R1135E.FR1.session(2).badsegment = [156908,158291;161027,163309;164594,165094;166004,168795;170036,170713;174998,177632;181700,182865;184045,185896;187972,189568;190090,190748;191625,192857;197492,199128;208451,209763;214022,215010;217452,218533;222568,223776;225444,228557;230906,235764;238020,243756;247753,250311;253807,258964;260160,261337;264349,266146;274474,275405;278206,279960;283878,284729;286168,296368;325147,325698;328511,329919;334651,339660;340692,341311;342361,356159;358106,358453;361667,363636;367633,368705;369514,370034;372016,372721;381401,382385;386619,387948;390347,391608;393327,395604;400561,401541;402311,402860;422432,423045;433047,434927;440207,441276;444119,447552;448620,449950;452749,454041;456407,457650;459541,463536;468067,471528;480302,487512;489515,490581;494356,495993;498397,498941;500461,503496;530437,531468;537563,542889;547453,549254;553157,554410;556689,557919;561120,562027;563965,566994;575425,576227;583417,584505;590683,591408;593094,594414;600404,601897;605403,605969;609660,610636;612986,613720;640775,641567;647772,648480;651231,654966;656573,658536;659667,661517;663981,664888;668094,670499;671329,672387;674225,674707;675325,676317;685931,687312;688187,691308;693379,694634;695305,697948;700296,707076;708251,710099;712525,713855;718052,719280;753899,755244;761456,763236;764461,765562;774773,777064;779497,780487;783081,783641;787680,791208;794008,797731;799201,799762;801134,802706;803853,804815;807193,808616;810495,811188;812037,813127;815362,816181;818950,820471;821972,823064;827769,828362;848089,848707;860345,860990;865501,866418;868585,869379;870923,872701;878701,879440;880583,882153;887290,888954;889634,890219;892827,894050;896450,898139;901127,901784;902810,910010;910939,911485;913924,915859;917838,919517;921811,923076;925570,927072;964386,965011;966388,966807;968881,971636;974037,974763;975025,975805;977590,978840;981804,982477;987359,991864;1011468,1014325;1015694,1017201;1021148,1022441;1025885,1026550;1027589,1029717;1036270,1036996;1042179,1042956;1059867,1061817;1072685,1073318;1078731,1079305;1081974,1082916;1085869,1087268;1090674,1093610;1094687,1096352;1098485,1098900;1101261,1102337;1103658,1104239;1107688,1110888;1113474,1114884;1119995,1122876;1124991,1126265;1127747,1130313;1132399,1134309;1137036,1137584;1140057,1148247;1186813,1188721;1191186,1198604;1198801,1201224;1203244,1205752;1207337,1209390;1210789,1211569;1226349,1226772;1235570,1237609;1238761,1239964;1243158,1245668;1248098,1248816;1251047,1253746;1260320,1262736;1276569,1277326;1278721,1279419;1297588,1301916;1302611,1303270;1305568,1310688;1311615,1317743;1318681,1319334;1323289,1323906;1326100,1326672;1394605,1395250;1399020,1400150;1401241,1402596;1405549,1406090;1436961,1438170;1444901,1446552;1449002,1449679;1451822,1453013;1455959,1457103;1461155,1462536;1476547,1477260;1478521,1480024;1481630,1482516;1484567,1486512;1487661,1488606;1490509,1494504;1498501,1501353;1506896,1512761;1522815,1523384;1528632,1529398;1544064,1544981;1546453,1549817;1553552,1554444;1555766,1557136;1564565,1569338;1570836,1571376;1576837,1577807;1586413,1588524;1589784,1590408;1591525,1593503;1594643,1595381;1596543,1597819;1599627,1600790;1606393,1609302;1611082,1615441;1650550,1651103;1657148,1657824;1660119,1661413;1664222,1664873;1666123,1666660;1667412,1668489;1669885,1670328;1672395,1675248;1676778,1678320;1682941,1683653;1684971,1685653;1689257,1690308;1692633,1693709;1696037,1698300;1699767,1700491;1707392,1708471;1709793,1710288;1711860,1714556;1719920,1720930;1722277,1724674;1740194,1741266;1742623,1743269;1749382,1749991;1751373,1751800;1754245,1757234;1758901,1760332;1762237,1765607;1767715,1771744;1773608,1774140;1775204,1777609;1786982,1788226;1789727,1790838;1792801,1794204;1796448,1797814;1799401,1801295;1802777,1805110;1806568,1807134;1810085,1811211;1812853,1814184;1815786,1820665;1822177,1823763;1824950,1826172;1830989,1832031;1858658,1862388;1869915,1871415;1873053,1875519;1877113,1879826;1886620,1888170;1891128,1893545;1897327,1900992;1903229,1903872;1909244,1910088;1912747,1917356;1918081,1920829;1922077,1925715;1957327,1958040;1959628,1960752;1963483,1965618;1967052,1967655;1968693,1970028;1971873,1973832;1979998,1980624;1989553,1990244;1992160,1993643;1996854,1998000;2001997,2002667;2005993,2006679;2016097,2016906;2018839,2019537;2021098,2021976;2044621,2045952;2059959,2060610;2066827,2068568;2079435,2081027;2083701,2084661;2087637,2088479;2093905,2095682;2105507,2107320;2110113,2112200;2114137,2114794;2124160,2124677;2126815,2129005;2136036,2136576;2145853,2147463;2157978,2158547;2180547,2182249;2183672,2184935;2185813,2186456;2189809,2193056;2194228,2197800;2215740,2216819;2235893,2237038;2238999,2239576;2259885,2260418;2280822,2281716;2284651,2285712;2287892,2288632;2290458,2293704;2294587,2295256;2297007,2297700;2300564,2302741;2305693,2309688;2322786,2324123;2326837,2327490;2335779,2337023;2338718,2339839;2347669,2348423;2352778,2353644;2355554,2356769;2359558,2360175;2361774,2362256;2377270,2378262;2380376,2381212;2395027,2395829;2404134,2405233;2405891,2407173;2408416,2409588;2411139,2413584;2414338,2417184;2419148,2420256;2433565,2434216;2442391,2444697;2445553,2446454;2453012,2454243;2456775,2457540;2468940,2469528;2506149,2508800;2516679,2519351;2521477,2524225;2543734,2544352;2547422,2548863;2553445,2556319;2557920,2558630;2563402,2565133;2568161,2569428;2574428,2575085;2581755,2582399;2602893,2604457;2608281,2608974;2612264,2614135;2619175,2619746;2622239,2625372;2626517,2627468;2629239,2630778;2634648,2637360;2641663,2648523;2653247,2655889;2659371,2661336;2662759,2664787;2665512,2666609;2674126,2675366;2700265,2700999;2702646,2704274;2707001,2709288;2722646,2727195;2730501,2732564;2736289,2737046;2741873,2743008;2744292,2745252;2746161,2747785;2748563,2748959;2749249,2750351;2761978,2762664;2764096,2765232;2770689,2773456;2787464,2788049;2802554,2802990;2804620,2805192;2808604,2809188];
info.R1135E.FR1.session(2).jumps = [155845,158287;263345,263736;1039541,1040065;1250039,1250656;1355136,1356519;1457263,1458513;1794978,1795495;1948828,1950048;2042235,2044568;2668506,2668918;2669603,2670788;2676353,2677320;2728732,2729268];
info.R1135E.FR1.session(3).badsegment = [243757,244962;253312,253913;256087,259740;260877,263736;266572,269248;270673,273285;277034,278497;291084,291556;308225,308689;311481,316995;318029,319680;320970,321543;322101,322489;324994,325563;326536,327672;336744,337349;338637,339158;340732,342247;347028,347652;349046,350920;353703,355214;359282,360971;363024,365003;365933,367375;369639,370256;372000,372528;375358,376637;402972,403596;405107,405749;415157,416025;419391,423576;427016,429048;438279,440363;442449,442925;444221,447552;448805,451388;451549,453249;454006,454546;457933,459279;460536,461052;474847,475412;478940,479400;511303,512755;515013,515484;515960,518426;519787,520304;522236,522829;523477,525629;526888,528590;530501,532042;533624,539460;556061,556541;566973,567344;570087,570350;573366,575115;577718,579420;581185,582571;583868,586233;611687,612675;617080,618608;620770,622338;623957,624852;627788,628965;650301,650878;651905,654161;657761,660542;672851,673299;689882,690415;697145,698576;706019,710290;711071,712071;713593,716692;733995,734548;735265,736293;745722,747252;753750,754854;755245,756418;757677,759240;774012,776559;777653,778524;796606,797683;800828,801353;826018,826682;830306,831101;831181,833349;838091,838585;845444,845937;850218,850766;866790,867311;875661,876294;883117,884751;916599,916910;917960,919080;923294,923859;925155,926751;929485,930135;932406,933631;937828,939396;942770,943056;944881,945499;951262,954139;961739,962771;965361,966139;967255,968343;982029,982526;985965,988222;989433,990542;1026973,1027522;1029047,1029636;1032012,1033060;1043448,1047302;1053180,1054944;1057023,1057538;1066473,1067047;1068415,1069145;1082030,1087413;1089901,1091647;1120665,1121145;1122877,1123998;1127791,1129319;1131650,1133057;1138457,1139615;1145148,1145774;1149724,1150848;1151441,1152707;1154031,1154519;1216182,1218016;1219925,1221206;1222639,1223116;1274890,1276639;1313693,1315544;1318681,1321723;1335523,1337791;1381170,1383315;1389066,1390608;1392272,1395665;1424868,1425357;1446117,1446552;1450549,1451198;1467451,1468793;1471230,1471863;1486371,1486824;1490763,1491807;1493211,1494504;1496684,1497969;1503306,1507593;1543701,1544282;1545779,1546292;1546876,1547517;1548253,1548846;1550359,1550943;1551524,1551980;1554932,1556141;1558441,1559308;1562437,1580995;1583424,1584009;1593240,1593765;1594405,1594817;1595649,1596069;1597297,1597886;1601905,1602396;1606627,1607058;1609426,1610002;1615186,1617237;1625550,1625954;1626957,1628001;1641506,1642356;1649414,1650075;1651054,1656154;1665188,1665681;1678490,1679148;1681261,1681870;1686159,1686749;1710289,1710942;1713064,1713616;1726099,1726934;1727521,1728296;1739427,1741403;1742257,1747466;1750913,1757077;1761491,1762236;1763300,1764989;1772504,1773158;1777741,1779406;1780436,1781226;1785705,1786212;1787127,1789359;1791341,1793371;1794051,1798200;1798656,1800546;1801813,1804856;1824658,1825174;1848581,1850148;1855981,1858069;1858141,1859737;1860211,1861920;1862987,1864796;1865685,1867290;1882596,1883673;1892554,1893122;1894363,1895669;1944506,1946231;1954045,1955669;1962283,1963907;1967205,1967721;1983205,1983778;2006351,2008600;2018782,2020378;2039580,2041462;2064486,2065932;2070714,2072141;2074710,2075336;2087274,2088254;2092797,2093390;2094155,2094663;2100970,2101494;2102960,2103692;2107893,2109317;2110924,2111432;2116104,2117880;2122759,2123159;2146292,2147340;2149849,2151106;2155496,2157785;2158409,2158817;2160020,2160633;2162397,2164693;2166594,2168335;2186272,2187058;2192886,2193290;2196616,2197406;2210961,2212742;2215633,2220665;2243388,2243884;2246309,2247077;2256238,2257740;2259859,2260255;2260999,2261697;2263203,2265242;2285713,2288150;2290877,2291454;2294591,2295168;2301697,2305692;2307413,2307869;2309535,2311245;2314716,2318121;2365350,2366045;2369629,2370117;2388996,2393604;2399524,2400006;2405137,2405592;2406793,2407265;2408976,2409588;2411727,2412288;2413585,2414150;2415796,2417580;2423651,2424796;2451253,2452591;2455410,2456792;2459486,2461536;2467965,2468542;2469419,2470033;2471772,2473524;2476493,2479447;2507946,2508937;2510319,2510908;2513174,2513484;2529469,2530328;2562202,2562598;2563962,2564507;2567141,2568434;2580723,2581416;2583237,2584016;2602984,2605392;2608067,2609388;2611624,2612116;2618577,2619613;2623914,2624358;2629369,2630441;2653247,2653773;2659669,2661336;2671826,2672455;2679721,2680346;2682199,2682780;2699621,2700963;2703882,2704798;2706147,2706981;2707701,2708572;2716982,2717564;2722850,2724041;2726046,2726885;2728257,2728834;2763875,2765232;2771537,2772963;2776926,2778374;2779786,2781116;2786993,2789208;2806864,2807502;2808709,2810297;2811903,2813184;2815174,2816025;2816725,2817180;2819090,2820339;2832234,2835900;2859312,2859872;2863529,2864561;2866458,2867317;2886345,2886870;2889745,2890326;2905238,2905750;2913721,2914165;2915803,2916364;2920291,2921493;2924303,2925751;2927147,2927647;2933065,2933505;2963562,2964719;2967026,2967495;2975284,2977944;2989988,2990846;2995244,2995849;3008662,3009393;3010958,3011463;3011977,3012984;3013565,3013892;3018620,3020976;3023208,3023656;3032965,3033494;3035204,3039467;3047490,3048087];
info.R1135E.FR1.session(3).jumps = [];
info.R1135E.FR1.session(4).badsegment = [147938,151829;157275,159084;161162,162891;163711,164092;203341,203796;206910,207527;238443,240769;249318,249824;254173,255415;263737,264117;265316,265961;276273,276854;278681,279463;280309,280866;310480,310880;325030,325418;333473,334602;343233,343815;344684,350960;359641,362091;367951,369253;370545,371259;372632,374312;381425,382510;387613,389539;408729,409245;422662,423239;427573,429608;431057,431568;432610,433370;434952,438949;442175,442852;445583,450099;456536,459540;477313,477850;479521,486357;517374,529033;537825,545214;551993,552453;556770,557411;558627,559095;559441,561206;563114,566128;568565,570430;580335,582100;585882,587412;587844,590153;604778,606402;619405,620123;623050,623942;625443,625806;627828,629235;631663,632320;635812,638491;638808,639360;660706,663336;664300,664836;716191,717284;731704,732200;736095,737960;739386,739979;745617,746194;747994,748925;751378,753437;767233,767705;770394,770915;828723,831702;835165,838102;843366,847525;918762,919080;919596,921096;932535,933647;985590,988512;991190,992383;1039690,1040601;1044093,1046952;1051412,1056557;1061168,1062936;1069808,1070486;1073470,1074091;1077104,1078920;1079171,1079566;1086469,1087466;1095010,1095599;1101303,1102896;1102994,1104046;1105760,1106892;1142917,1143456;1151644,1152284;1155199,1155825;1157716,1161919;1166379,1166832;1168134,1169850;1176114,1177919;1183864,1184441;1196009,1196554;1198051,1198559;1211832,1212759;1250079,1250748;1251530,1253956;1259840,1262736;1266846,1267511;1285580,1286202;1286615,1287121;1288191,1290383;1293234,1293710;1295994,1297956;1343410,1344204;1347591,1348273;1349122,1349735;1351950,1352841;1354794,1355460;1374149,1376285;1378201,1378620;1381931,1382616;1404224,1405000;1414786,1415246;1418193,1418799;1419821,1424926;1438690,1439202;1448361,1449570;1450549,1452620;1454214,1456185;1458702,1466532;1468619,1470528;1470827,1471847;1474996,1476858;1489799,1490288;1492680,1493466;1495270,1496431;1507911,1508387;1511335,1514179;1519909,1520902;1554090,1555574;1558578,1559586;1562691,1564762;1567444,1569797;1570542,1571231;1590409,1592971;1604926,1608790;1612056,1612661;1617289,1617898;1618570,1619292;1646353,1648561;1655654,1657076;1662337,1662954;1667275,1668690;1681708,1682316;1698139,1699405;1719803,1720280;1754245,1755349;1762006,1764598;1776907,1777569;1778547,1779672;1791457,1791942;1792935,1793698;1819433,1820175;1821149,1821794;1822177,1822710;1849637,1851000;1858435,1859121;1860722,1861420;1862137,1863117;1866657,1868212;1882653,1883137;1894274,1894634;1901053,1901634;1902931,1903576;1904912,1906092;1907905,1909461;1911974,1912567;1916819,1917372;1918935,1919492;1925867,1926304;1948361,1949316;1952131,1954044;1962242,1962856;1989126,1991174;2002951,2003657;2005291,2007573;2026855,2027375;2047661,2049208;2054607,2055843;2060583,2060981;2078396,2078852;2088261,2089144;2090441,2092886;2093654,2094144;2099387,2099920;2104172,2104922;2106856,2107267;2110533,2111843;2117175,2117700;2119335,2119944;2142070,2142847;2144209,2144810;2150159,2151243;2153845,2154998;2157723,2159177;2160958,2161535;2162920,2164995;2168745,2169414;2170308,2170720;2172773,2173334;2196258,2196532;2203070,2203483;2205164,2205792;2220302,2222036;2260411,2261048;2262977,2264613;2269789,2270360;2278982,2279583;2303860,2311273;2314821,2315369;2320669,2321323;2322124,2322689;2326648,2329166;2358986,2361636;2361951,2362814;2370032,2372546;2373625,2380719;2395453,2395881;2396992,2397600;2402253,2403146;2420030,2420594;2422088,2422738;2424465,2424937;2468654,2471370;2473887,2474392;2481960,2483282;2495901,2497500;2499825,2500724;2508127,2508744;2518162,2521937;2523974,2524800;2526230,2526743;2547060,2547532;2555817,2556342;2563253,2563935;2564679,2566936;2573614,2574207;2577421,2578666;2581590,2584918;2586698,2587160;2613104,2613742;2624675,2625252];
info.R1135E.FR1.session(4).jumps = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1142N %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1142N' - 1    - 19T  - 60F   - 48**/300  - 0.1600   - 18T  - 57F   - 37/194 - 0.19072   - ??? - Done. Expansion. 50 recall. 

% 'AST1', 'AST2', 'PST1', 'PST2' buzzy channels, though Roemer says they're ok
% Lots of slow swoops, and I'm not sure how I feel about them.
% Removing swoops if they are preceded by spikes and are in both ALF/AALF and MLF/PLF
% Lots of these swoopy IEDS
% IEDs are very widespead, unlikely I can narrow down where they are from

% Good for HFA.
% Would be great coverage for phase encoding, but swoops are annoying.

% Channel Info:
info.R1142N.badchan.broken = {'ALT6'}; % flat line

info.R1142N.badchan.epileptic = {'PD1', 'PD2', 'PD3', 'AD1', 'AD2', 'AALF1', 'AALF2', 'MLF2', ... % Kahana
    }; 

% Line Spectra Info:
% Session 1/1 eyeballing
info.R1142N.FR1.bsfilt.peak      = [60  120 180 240 300];
info.R1142N.FR1.bsfilt.halfbandw = [0.5 0.5 0.5 0.5 0.5];
info.R1142N.FR1.bsfilt.edge = util_calculatebandstopedge(info.R1142N.FR1.bsfilt.peak, ...
    info.R1142N.FR1.bsfilt.halfbandw, ...
    info.R1142N.fs);

% Bad Segment Info:
info.R1142N.FR1.session(1).badsegment = [1,1915;2978,3154;6479,7036;7459,7503;15373,15544;16498,17176;20396,21061;23583,23995;25506,26211;29605,30170;32562,33144;33417,33998;35838,35877;36151,36762;38320,39641;44001,44776;45968,46098;46986,47041;48001,48703;50210,50275;50938,51401;53054,53566;54376,55014;57495,58176;58629,59114;60122,60381;61903,62630;63349,64137;64458,64502;66374,66437;74591,75168;81675,81722;82156,82219;82250,82281;82629,82665;83172,83235;83855,83904;83981,84016;84605,84631;85033,85066;86548,86638;87802,88711;88955,88996;89516,89558;91976,92004;92535,92596;92828,92889;103419,104000;104186,104227;104802,104840;105183,105254;105339,105450;105530,105558;109885,110514;112261,112287;112640,112674;112707,112746;115328,115439;118556,118582;119072,119103;120933,121587;122605,122630;122750,122778;122882,122998;123336,123369;125143,125187;130180,130213;130608,130649;130718,130759;133465,133499;133605,134281;134565,134622;135349,135399;136001,137079;137404,137439;137793,137883;139906,139950;142218,142867;159712,159772;160001,160749;161562,162047;162280,162342;162403,162482;162661,162781;162852,162896;163223,163920;165025,165544;165559,165611;167782,168518;169425,170047;170680,171718;172001,173184;173793,174953;175508,177219;177734,178058;180001,197372;198927,200000;202540,215995;216001,232000;233000,236000;240525,240905;241557,241888;242731,243254;244001,244321;244323,249982;252057,252101;253428,253482;254680,254719;255140,255176;255717,255864;256135,256988;258586,259853;261782,262713;264624,265246;266651,266695;268850,269370;270046,270084;270532,270969;272275,272692;273331,273372;278573,278619;280267,280754;284001,284504;285484,285512;286180,286222;287099,287143;287309,287393;288780,288819;291787,291837;297928,298587;312952,313840;314470,314850;315615,315659;316226,317047;318137,318313;318978,319643;320052,320719;321559,321601;333694,333719;334199,334375;334438,334471;334890,334928;335551,336000;336323,336800;345495,346168;347148,347705;372092,372735;376001,376574;377551,377571;380001,380980;383083,383122;384170,384803;386796,386834;389839,390434;392619,393577;398532,400000;418532,419073;420001,420571;432952,433509;433573,433603;437917,438547;439314,440000;442667,443383;450556,451079;457831,458283;459699,460287;468001,469512;478309,479374;480001,480641;481430,482380;485140,486160;490922,491538;510836,511458;514100,514160;515301,516000;518866,520000;522264,523667;525648,525711;530968,531452;536885,537644;541895,542297;545879,546488;576901,577574;587341,587377;602935,602966;616140,616768;632001,632663;648718,649241;652363,652545;659137,659826;669398,669896;670556,670939;674796,675213;705288,705802;707771,708000;709054,709547;712001,712383;712705,712760;734497,734912;737390,738101;742341,743087;747091,747692;748291,749104;761995,762727;789191,789792;822952,824000;832001,832582;834393,835606;836401,837015;838387,838936;855519,855987;857745,858222;858857,859423;892130,892905;901189,901945;915527,916000;918067,918600;920896,920964;929146,929633;932221,932800;934414,935108;948726,949241;968511,969149;972949,973364;1000474,1000966;1002382,1002842;1005796,1007049;1017019,1018246;1025008,1025910;1032879,1033534;1035505,1035915;1037519,1039211;1048425,1049023;1053245,1054076;1057522,1057998;1060154,1060214;1065968,1066633;1071134,1071557;1072487,1073265;1077911,1078469;1091188,1091305;1101893,1102466;1127602,1128000;1130195,1130698;1131678,1132310;1133393,1134032;1136342,1136860;1137068,1137754;1143616,1144780;1153202,1153829;1159075,1159761;1167376,1168000;1175513,1176000;1193116,1193813;1230852,1231630;1248272,1248840;1254274,1255197;1266855,1267721;1286624,1287151;1294847,1296000;1313070,1313783;1332001,1332510;1376581,1377343;1380054,1380596;1393847,1394504;1397162,1397877;1410396,1411138;1429003,1429617;1441113,1441708;1477549,1478630;1509035,1509544;1514003,1514547;1527468,1528000;1535659,1536257;1547263,1547737;1549368,1550114;1576001,1576590;1584001,1584913;1588699,1589302;1592646,1593421;1595355,1596101;1598823,1599731;1604296,1604800;1614307,1614832;1622113,1622784;1629960,1630590;1642312,1642721;1707301,1707864;1712888,1713659;1716159,1716692;1745884,1746582;1749819,1750679;1771218,1771619;1819505,1820000;1835255,1836000;1855266,1856000;1860885,1861558;1863653,1864000;1865988,1866888;1880269,1880864;1891834,1892628;1901237,1901848;1925988,1927586;1961106,1962788;1964659,1965235;1975700,1976268;1981775,1982546;1985301,1985802;2027149,2027937;2031864,2032640;2066791,2068485;2095193,2095979;2099331,2100579;2108052,2108437;2116848,2119009;2121581,2122449;2144724,2145184;2179069,2179767;2192001,2192812;2236461,2237292;2252449,2253052;2255307,2256389;2262427,2263036;2264001,2264667;2266226,2266824;2306785,2307404;2312398,2312907;2336987,2337515;2344311,2345026;2351296,2352518;2355654,2356188;2371766,2372433;2385009,2386413;2387567,2388000;2406914,2407356;2429782,2430345;2432759,2433469;2443825,2444716;2449178,2449759;2450237,2450885;2456001,2456808;2527072,2527571;2554710,2555533;2557702,2564000;2568001,2568708;2584066,2586239;2606444,2607006;2620573,2621141;2669646,2671187;2673086,2673727;2676251,2676932;2724001,2724448;2752995,2753566;2754621,2755149;2772001,2772848;2785809,2787033;2793807,2794369;2816569,2820000;2852324,2852941;2873785,2874380;2932291,2932867;2946527,2949077;2955790,2956611;2966100,2967340;2972001,2972657;2981253,2981843;2985116,2985902;3000304,3000843;3005503,3006144;3018073,3018872;3020748,3021310;3035046,3037259;3047132,3047767;3056001,3056499;3060001,3061052;3068490,3069036;3107661,3109211;3196589,3196918;3197328,3197835;3204001,3204674;3221121,3221687;3233718,3234380;3239207,3240000;3254208,3261587;3280576,3281101;3288505,3289240;3300850,3301507;3313033,3313776;3355807,3356511;3364271,3365042;3365404,3366110;3408904,3409719;3435929,3436469;3456001,3456598;3468670,3469417;3471367,3472000;3474538,3475181;3478738,3479312;3497589,3498856;3547295,3548000;3600719,3601631;3619841,3620191;3621440,3622268;3671296,3671780;3673605,3682800;3686745,3687240;3688643,3689101;3696001,3696434;3705561,3706610;3754239,3755364;3764057,3764706;3765127,3765730;3767244,3767791;3769654,3770763;3784190,3785002;3793215,3793757;3812815,3813643;3828108,3828633;3861283,3861942;3894694,3895388;3911081,3911767;3965315,3965981;4004296,4004948;4013213,4013797;4021011,4021746;4024997,4025796;4026787,4027469;4034831,4035457;4036614,4038679;4062667,4063254;4118368,4118842;4121597,4122149;4123340,4124357;4174954,4175466;4176651,4177257;4200070,4201054;4209129,4209679;4212440,4213082;4227745,4228411;4234680,4235245];
info.R1142N.FR1.session(1).jumps = [8360,8401;8840,8865;12299,12341;13166,13211;2556001,2560000;2586162,2586457;2676860,2678534;2924001,2932000;2943424,2943787;2944094,2944913;3002170,3006223;3009404,3009514;3456001,3457506;3603085,3604389;3831726,3832474;4116444,4118042];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1147P %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes: 

% 'R1147P' - 3    - 41T  - 33F   - 101/559   - 0.1807   - 10T   - 14F   - 69/401 -0.1721                   - :)  - Done. Core.
% 'R1147P' - 1/3  - 41T  - 33F   - 73/283    - 0.2580   - 10T   - 14F   - 50/204 - 0.2451                    - :)  - 
% 'R1147P' - 2/3  - 41T  - 33F   - 11/96     - 0.1146   - 10T   - 14F   -   9/70 - 0.12857                   - :)  - 
% 'R1147P' - 3/3  - 41T  - 33F   - 17/180    - 0.0944   - 10T   - 14F   - 10/127 - 0.078746                   - :)  - 

% Dominated by line noise. Cannot tell which channels are broken without prior filtering. 
% Must be re-referenced prior to line detection.
% Individual session lines show up in combined, so using re-ref combined for line detection.
% Have to throw out grids to preserve 80-150 Hz activity.

% Could do grid specific re-ref.
% LGR is not saveable. LSP and LPT can be re-referenced with one another. But these are parietal.
% So, maybe not worth it to save LSP and LPT. {{'all', '-LSP*', '-LPT*'}, {'LSP*', 'LPT*'}};

% Good number of trials.
% Interictal spikes, deflections, buzz. Will require intensive cleaning.
% 'LAST1', 'LAST2', 'LAST3', 'LPST1' have a fair amount of IEDs
% Lots of buzz and ambiguous IEDs remain, though was somewhat aggressive in cleaning out little blips. Could add them back in.
% Adding a lot more buzz using jumps.

% Channel Info:
info.R1147P.badchan.broken = {'LGR64', 'LGR1' ... % big fluctuations
    'LGR*', 'LSP*', 'LPT*'}; % bad line spectra

info.R1147P.badchan.epileptic = {'LDH2', 'LDA2', 'LMST2', 'LDH3', 'LDA3' ... Kahana epileptic
    'LPST6' ... % bad spikes. Confirmed.
    'LMST3', 'LMST4', ... % IEDs and ambiguous slinkies
    'LPST1' ... % breaks in Session 2
    }; 

% Line Spectra Info:
% z-thresh 0.5 + 1 manual
info.R1147P.FR1.bsfilt.peak      = [60  83.2 100 120 140 166.4 180 200 221.4 240 260 280 300 ...
    160 ...
    ]; % 80]; % from LSP* and LPT*
info.R1147P.FR1.bsfilt.halfbandw = [0.5 0.5  0.5 0.5 0.5 0.5   0.5 0.5 3.6   0.5 0.7 0.5 0.5 ...
    0.5 ...
    ]; % 0.5];
info.R1147P.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1147P.FR1.bsfilt.peak, ...
    info.R1147P.FR1.bsfilt.halfbandw, ...
    info.R1147P.fs);
     
% Bad Segment Info: 
info.R1147P.FR1.session(1).badsegment = [392626,393232;401231,401328;414750,414860;416606,416945;434662,436365;441734,442683;453489,454034;458174,459001;470851,471844;479335,481534;481984,482759;485053,486332;488001,489397;493638,493695;498827,500000;511698,511844;520783,525223;528940,529054;539303,540000;543230,544000;548001,549022;554029,554868;562764,563505;569456,573223;577400,578239;578970,579582;582488,584000;592860,593848;595444,596000;624537,625558;634049,634771;644001,644828;655335,656000;660432,661268;667037,671751;674807,675783;676920,677929;680178,680280;682109,682364;692755,693461;707214,708437;721251,722143;742117,742848;765904,766844;776334,778685;783266,785554;794496,795247;796997,797623;804775,804897;810670,811203;823500,824349;829400,829905;846146,847078;853767,854187;858948,860175;876211,877885;892336,893488;895024,897377;903595,903785;904001,905163;907295,907505;919609,920000;929738,930582;933581,933715;943299,944000;949589,950187;955178,956000;974123,975070;981146,981868;994242,999082;1005057,1005667;1013694,1014022;1020658,1021127;1042254,1042586;1058101,1058796;1065166,1065304;1079464,1080361;1108928,1109691;1112001,1115590;1116666,1116881;1126710,1127336;1162904,1163054;1177364,1178006;1216001,1217639;1264368,1264998;1320130,1321086;1331730,1332316;1336759,1337490;1340912,1344000;1348521,1349264;1366948,1367570;1372936,1373175;1384436,1385066;1410770,1411384;1433138,1433284;1437900,1441215;1468186,1468566;1489130,1489953;1514210,1514441;1517960,1518695;1546533,1549881;1571766,1572788;1580485,1581264;1619754,1620000;1621372,1622171;1652001,1654231;1658339,1658751;1674533,1674675;1701992,1702151;1758178,1759703;1761964,1762538;1768473,1769324;1776001,1778433;1795133,1795670;1813698,1814376;1841307,1841993;1847798,1848244;1884791,1888000;1936521,1937514;1966879,1967630;1984049,1987017;2009464,2010155;2088001,2090163;2097372,2097490;2100001,2101832;2120686,2121679;2122436,2122638;2141859,2142747;2168823,2169236;2169682,2170163;2204852,2208000;2222750,2222989;2267214,2267300;2268001,2268566;2314448,2314977;2400154,2400772;2404158,2404925;2410500,2411433;2420001,2420925;2424001,2424812;2429489,2429929;2433751,2434348;2439020,2440000;2462138,2462719;2528956,2530905;2531077,2531271;2545831,2546538;2556876,2557449;2621799,2622687;2650319,2650755;2681783,2682610;2686379,2689421;2738976,2740615;2784255,2784941;2804299,2804841;2817892,2818473;2859133,2859699;2924247,2926872;2953489,2954308];
info.R1147P.FR1.session(1).jumps = [483496,484808;540001,542900;552892,553695;566448,567110;605110,605606;649771,651896;680001,682945;768001,770634;984928,992000;1096263,1098868;1184094,1185417;1192150,1192974;1210517,1212945;1214343,1219683;1335597,1336421;1473247,1473727;1480969,1483009;1496823,1497369;1543585,1545574;1550569,1552000;1624207,1624836;1642952,1643529;1650597,1652000;1695492,1696000;1778775,1780000;1823351,1823775;1868001,1870860;1988001,1991755;1996094,1996768;2006561,2007158;2085126,2085546;2086275,2087344;2098714,2100000;2306351,2311489;2525589,2527610;2583464,2584000;2611573,2613852;2629190,2629695;2661988,2662566;2716001,2719670;2721670,2723670;2753420,2753973;2763730,2765187;2774097,2774501;2792533,2793687;2831274,2832000];
info.R1147P.FR1.session(2).badsegment = [330001,331747;334835,335130;335762,336599;340831,342227;343601,345175;353073,353615;357972,358804;369122,370296;376182,376816;391008,394304;456844,457348;462525,463324;494448,494755;495065,497610;523718,524000;552807,553361;564408,564635;592448,596000;608001,609961;620001,620272;629525,629901;631242,631594;645444,645921;648001,649941;704856,706264;744001,745397;805678,807320;810198,812000;830150,832000;871170,872000;946908,948986;950549,952000;958920,961397;1024130,1024413;1149347,1150368;1164324,1168953;1181420,1182195;1190996,1191163;1198105,1198469];
info.R1147P.FR1.session(2).jumps = [526105,528000;551589,552752;579315,580554;754101,755380;787448,789453;795210,795981;838408,842401;894678,897147;952582,954066;1052573,1054800;1057553,1058368;1060223,1062570];
info.R1147P.FR1.session(3).badsegment = [151117,152000;155722,156000;172614,172832;194375,194743;228916,231791;250553,250715;274738,276000;282811,283050;374835,375163;376001,377739;378492,378715;396795,397183;430533,430820;435532,435679;436001,436429;438359,438598;448263,449510;473944,474179;482779,483118;495141,495344;495561,495787;496178,496752;528134,528526;533908,534195;564787,566126;589682,590054;598202,598598;630017,630763;669634,670973;768658,769788;789388,791025;800001,806122;893412,894679;902202,909949;918388,919634;1084299,1084449;1085767,1086663;1110392,1112000;1231915,1233324;1238694,1239062];
info.R1147P.FR1.session(3).jumps = [496819,498550;543653,544522;559770,561703;639573,640925;808694,810300;881932,883812;884146,886852;892848,894767;909807,915840;969779,971352;1017823,1019396;1089956,1091610;1296815,1298602;1300880,1302590;1332001,1334667;1339778,1340107;1391206,1392312;1461936,1464365;1529541,1531404;1552025,1552933;1554654,1555501;1636122,1638457;1650581,1651118;1661710,1662397];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1149N %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1149N' - 1    - 47T  - 18F   - 64/300  - 0.2133   - 30T  - 18F - 47/248 - 0.18952                          - ??? - Done. Expansion. 67 recall.
% ALEX grid is particularly affected by wide line noise, needs to be removed.
% Remaining channels are slinky, periods of high amp slink that will need to be removed.
% Lots of intermittently buzzy channels, hopefully got them all. 
% Both slink episodes and interictal spikes need to be removed. Not the cleanest.
% Re-ref cleans spectra baseline, using re-ref for peak detection.
% Could be a good subject, but perhaps not enough trials will remain after cleaning.
% 'AST3', 'AST4', 'MST2', 'MST3', 'MST4', 'OF*', 'TT*', 'LF*', 'G1', 'G2', 'G3', 'G18', 'G19', 'G2', 'G20', 'G26', 'G27', 'G28', 'G29', 'G3', 'G9' ... % buzzy channels
% IEDs + ambiguous ones, long buzz + ambiguous

% Channel Info:
info.R1149N.badchan.broken = {'ALEX1', 'ALEX8', 'AST2', ... % flatlines, big fluctuations
    'ALEX*' ... % wide line noise. Not worth saving.
    };
info.R1149N.badchan.epileptic = {'PST1', 'TT1', 'MST1', 'MST2', 'AST1', ... % Kahana
    'TT*' ... % oscillation with spikes
    };
info.R1149N.refchan = {'all'};

% Line Spectra Info:
% Session 1/1 z-thresh 0.5 + manual (small)

% with a bunch of buzzy channels removed, see above for list
% info.R1149N.FR1.bsfilt.peak      = [60  120 180 211.6 220.1000 226.8000 240 241.9000 257.1000 272.2000 280 287.3000 300 ...
%     136 196.5];
% info.R1149N.FR1.bsfilt.halfbandw = [0.6 0.5 1   0.5   0.5000 0.5000 1.3000 0.5000 0.5000 0.5000 0.5000 0.5000 1.4000 ...
%     0.5 0.5];
% info.R1149N.FR1.bsfilt.edge      = 3.0980;

% with only TT* removed
info.R1149N.FR1.bsfilt.peak      = [60  120 180 196.5 211.7 219.9 220.2 226.8 240 241.9 257.1 272.1 279.9 287.3 300 ...
    105.8 120.9 136];
info.R1149N.FR1.bsfilt.halfbandw = [0.5 0.5 0.7 0.5   0.5   0.5   0.5   0.5   0.9 0.5   0.5   0.5   0.5   0.5   0.9 ...
    0.5   0.5   0.5];
info.R1149N.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1149N.FR1.bsfilt.peak, ...
    info.R1149N.FR1.bsfilt.halfbandw, ...
    info.R1149N.fs);

% Bad Segment Info:
info.R1149N.FR1.session(1).badsegment = [626178,628000;637077,638433;663872,665116;668739,670481;696001,697223;858641,860000;899831,902896;941783,942626;1055847,1057467;1091379,1092000;1113110,1114973;1123113,1123832;1146182,1148776;1151726,1153687;1177662,1178771;1225057,1226062;1278984,1279489;1414081,1414759;1426186,1426985;1578512,1584373;1665872,1666562;1667520,1669143;1673638,1676724;1678476,1680441;1683097,1683485;1692759,1694199;1714654,1715134;1719729,1720392;1752545,1755779;1765972,1767211;1771516,1773115;1806138,1806751;1828344,1830159;1850093,1851892;1857460,1858090;1888424,1888986;1948118,1954360;1959415,1984000;2006940,2007767;2021198,2024000;2099872,2101019;2101571,2102216;2126271,2127243;2136461,2141151;2154206,2155054;2237364,2242969;2295726,2296413;2308001,2308466;2335948,2336341;2348219,2349530;2378589,2387118;2403807,2404252;2495815,2499187;2555407,2556776;2567194,2568000;2586130,2586594;2677013,2680000;2688029,2691703;2696332,2696965;2705638,2706477;2761384,2764000;2772203,2773570;2819835,2820558;2836610,2837232;2910448,2912000;2943081,2944000;2951460,2952000;2984529,2985272;3005372,3006082;3017231,3018763;3021287,3023816;3040162,3040853;3059057,3059715;3084001,3086989;3090202,3095106;3102198,3103614;3104001,3107517;3114633,3118909;3153351,3153901;3158226,3161300;3241307,3241574;3242702,3244000;3260001,3260941;3262766,3264000;3268001,3269764;3276001,3279711;3285190,3289437;3318561,3320000;3320497,3322582;3366658,3369179;3378275,3379001;3457162,3458393;3488670,3489381;3505130,3506804;3526581,3528881];
info.R1149N.FR1.session(1).jumps = [958198,958663;1554158,1555376;1622210,1623324;2042214,2045187;2549787,2551029;3079750,3080820];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1151E %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1151E' - 3    - 7T   - 9F    - 208/756   - 0.2751   - 7T   - 9F    -  202/742 -   0.2722               - :)  - Good pending cleaning. Core.
% 'R1151E' - 1/3  - 7T   - 9F    - 77/300    - 0.2567   - 7T   - 9F    -  76/294 - 0.2585                   - :)  - 
% 'R1151E' - 2/3  - 7T   - 9F    - 83/300    - 0.2767   - 7T   - 9F    -  81/296 -0.2736                    - :)  - 
% 'R1151E' - 3/3  - 7T   - 9F    - 48/156    - 0.3077   - 7T   - 9F    -  45/152 -0.2961                    - :)  -

% Pretty bad noise specific to surface channels. Re-ref before line spectra helps find sharp spectra.
% Using combined re-ref for detecting peaks
% Remaining channels are kinda coherent and slinky, but nothing major.
% No spikes, just occasional buzz. Relatively clean.
% Session 3 goes bad from time 2100 onward, also between 1690 and 1696.
% Great trial number and accuracy, but poor coverage.
% Exceptionally clean. Barely any IDEs, and no buzz.
% Lots of tiny spikes. Removing a few with jumps. Probably overkill. 
% TRY THIS SUBJECT FOR PHASE ENCODING. Very curious if channel pairs will be present.

% Channel Info:
info.R1151E.badchan.broken = {'RPHD8', 'LOFMID1' ... sinusoidal noise and fluctuations, session 1
    };
info.R1151E.badchan.epileptic = {'LAMYD1', 'LAMYD2', 'LAMYD3', 'LAHD1', 'LAHD2', 'LAHD3', 'LMHD1', 'LMHD2', 'LMHD3', ... % Kahana
    }; 

% Line Spectra Info:
% Lots of line spectra, but baseline is pretty ok. 
info.R1151E.FR1.bsfilt.peak      = [60  180 210.2 215 220.1 300 ...
    100 120 123.7 139.9 239.9 247.3 260];
info.R1151E.FR1.bsfilt.halfbandw = [0.5 0.5 0.5   0.5 0.5   0.5 ...
    0.5 0.5 0.5   0.5   0.5   0.5   0.5];
info.R1151E.FR1.bsfilt.edge = util_calculatebandstopedge(info.R1151E.FR1.bsfilt.peak, ...
    info.R1151E.FR1.bsfilt.halfbandw, ...
    info.R1151E.fs);

% Bad Segment Info:
info.R1151E.FR1.session(1).badsegment = [1158351,1158997;1187480,1188000;2215746,2216458;2442105,2445397;2804473,2804651;2821460,2822175;2936114,2936732;2984501,2984957;3211246,3211896;3236166,3236542;3326883,3326993];
info.R1151E.FR1.session(1).jumps = [];
info.R1151E.FR1.session(2).badsegment = [443827,444183;580086,580449;592670,592937;1261920,1262280;1350787,1350961;1535335,1535554;1623488,1624000;1781710,1783521;1829077,1829236;2129376,2129695;2540642,2540965];
info.R1151E.FR1.session(2).jumps = [2860497,2862203];
info.R1151E.FR1.session(3).badsegment = [706948,707650;1130569,1131340;1169130,1169619;1211544,1212191;1282444,1282993;1284473,1285469;1379367,1380000;1477158,1477562;1480279,1480764;1507073,1520000];
info.R1151E.FR1.session(3).jumps = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1154D %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1154D' - 3    - 40T  - 20F   - 271/900   - 0.3011   - 10T  - 19F   - 253/841 -0.3008                      - :)  -  Core.
% 'R1154D' - 1/3  - 40T  - 20F   - 63/300    - 0.2100   - 10T  - 19F   - 63/300    - 0.2100                     - :)  - 
% 'R1154D' - 2/3  - 40T  - 20F   - 108/300   - 0.3600   - 10T  - 19F   - 98/263 - 0.37262                     - :)  - 
% 'R1154D' - 3/3  - 40T  - 20F   - 100/300   - 0.3333   - 10T  - 19F   - 92/278 - 0.33094                     - :)  - 

% No Kahana electrode info available.
% Lots of line spectra, though remaining baseline is flat.
% Needs LP.
% Some buzz that can be removed by re-ref.
% Discrete large events, decent number of slinky channels, decent number of low-amplitude fluctuating channels.
% Using combined session re-ref for line detection, plus manual adding of other peaks from individual sessions
% Nothing that makes me distrust this subject.
% Session 2 is corrupt after 2738 seconds.
% Session 2 still has buzzy episodes after re-ref and LP.
% Very slinky channels in Session 2, might be worse than Session 1.
% First 242 seconds of Session 3 are corrupted.
% Session 3 is very buzzy too.
% Buzzy. No IEDs. Jumps help a lot.
% LTCG* saved by re-referencing separately. From 10/19 to 37/19. {{'all', '-LTCG*'}, {'LTCG*'}};

% Channel Info:
info.R1154D.badchan.broken = {'LOTD*', 'LTCG23', ... % heavy sinusoidal noise
    'LTCG*', ... % bad line spectra
    'LOFG14' ... % big fluctuations in Session 2
    }; 
info.R1154D.badchan.epileptic = {'LSTG1', ... % intermittent buzz LSTG2
    'LSTG7' ... % oscillation + spikes
    };

% Line Spectra Info: 
info.R1154D.FR1.bsfilt.peak      = [60 120 138.6 172.3 180 200 218.5 220 222.9 225.1 240 260 280 300 ... % combined z-thresh 0.5
    99.9 140 160 205.9 277.2 ... % manual combined
    111.5 ... % manual session 1
    ]; % 80 196.2]; % tiny one from LTCG
info.R1154D.FR1.bsfilt.halfbandw = [0.5 0.5 0.5  0.5   0.5 0.5 0.5   0.7 2.5   0.5   0.5 0.5 0.5 0.5 ...
    0.5  0.5 0.5 0.5   0.5 ...
    0.5 ...
    ]; % 0.5 0.5];
info.R1154D.FR1.bsfilt.edge = util_calculatebandstopedge(info.R1154D.FR1.bsfilt.peak, ...
    info.R1154D.FR1.bsfilt.halfbandw, ...
    info.R1154D.fs);

% Bad Segment Info:
info.R1154D.FR1.session(1).badsegment = [492223,495142;2129384,2131856;2332001,2334453;2639109,2642489];
info.R1154D.FR1.session(1).jumps = [];
info.R1154D.FR1.session(2).badsegment = [228001,229457;334726,338215;348469,350812;372497,374739;385069,388000;432880,436000;540860,545119;550057,552000;586819,589268;644001,646767;649472,651832;675319,677361;691238,694022;747831,750735;751045,753856;1001299,1004000;1029122,1031138;1035520,1036990;1065102,1067957;1085347,1088000;1158678,1162401;1165726,1169006;1176368,1180000;1260001,1263481;1266585,1268506;1327162,1327590;1410343,1411231;1566279,1570691;1663750,1665276;1744001,1746711;1768094,1772000;1779097,1781433];
info.R1154D.FR1.session(2).jumps = [226718,228000;884920,886235;927520,928000;1058605,1059509;1060981,1061881;1183407,1184236;1587162,1588611;1772001,1773796;1789372,1789868;1872356,1873542;1881622,1882977;1969730,1971864;2055069,2055896;2090823,2093030;2268340,2269598;2272948,2274389;2276779,2278909;2317388,2317981;2384340,2386776;2388360,2390300;2393303,2393937;2397436,2399308;2469489,2472982;2475351,2476000;2476711,2477945];
info.R1154D.FR1.session(3).badsegment = [530658,535759;536311,540000;540489,543759;548001,550949;554662,555751;564001,566433;634105,636000;641908,644000;660190,664792;739395,741631;742512,744000;768803,769848;850762,852961;857702,858840;863016,866304;1039299,1040760;1041803,1043848;1073900,1076000;1342823,1348000;1359508,1362655;1530404,1533812;1546299,1548000;1552001,1554078;1556001,1557957;1578654,1579888;1826222,1828000;1856598,1857780;1947226,1950884;1956001,1960000;1970198,1972000;2040001,2040712;2141521,2143078];
info.R1154D.FR1.session(3).jumps = [757843,758163;1098609,1099606;1254210,1255114;1320565,1320643;1451831,1452994;1643182,1644635;1700001,1700796;1700823,1701453;1761827,1762445;2053440,2055090;2082936,2084804;2161102,2162481;2169501,2171715;2178142,2178812;2196001,2197610;2263024,2266340;2337726,2338723;2376303,2378344;2410408,2411489;2419702,2421086;2488848,2489917;2594811,2594896;2604775,2606393;2613529,2613881;2644082,2644550;2649892,2650937;2674025,2675695;2787081,2788000;2802295,2803751;2893468,2894397;2974492,2975727;2976247,2978965;2988001,2988998;3034464,3035558;3097037,3098207];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1162N %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1162N' - 1    - 25T  - 11F   - 77/300  - 0.2567   - 15T  - 11F - 75/275 - 0.27273                          - :)  - Done. Expansion. 

% No Kahana electrode info available.
% Very clean, only occassional reference noise across channels. WRONG. I
% WAS WRONG. VERY SHITTY.
% Mostly only harmonics in line spectra. Baseline has slight wave to it.
% Line detection on re-ref. 
% Data is ambiguously dirty (can't quite tell where bad things start and stop), but not so bad that this subject is untrustworthy.
% Not as bad.
% info.R1162N.badchan.epileptic = {'AST*', 'ATT*' ... % buzzy and synchronous spikes 'PST2', 'PST3'}; % intermittent buzz 
% Ambiguous swoops and IEDs. Virtually no buzz.

% Channel Info:
info.R1162N.badchan.broken = {'AST2'};
info.R1162N.badchan.epileptic = {'AST1', 'AST2', 'AST3', 'ATT3', 'ATT4', 'ATT5', 'ATT6', 'ATT7', 'ATT8', ... % synchronous spikes on bump
    'ATT1' ... % bleed through from depths
    };

% Line Spectra Info:
info.R1162N.FR1.bsfilt.peak      = [60  120 180 239.5 300 ... % Session 1/1 z-thresh 1
    220]; % manual, tiny tiny peak
info.R1162N.FR1.bsfilt.halfbandw = [0.5 0.5 0.5 0.5   0.6 ...
    0.5]; % manual, tiny tiny peak
info.R1162N.FR1.bsfilt.edge = util_calculatebandstopedge(info.R1162N.FR1.bsfilt.peak, ...
    info.R1162N.FR1.bsfilt.halfbandw, ...
    info.R1162N.fs);

% Bad Segment Info:
info.R1162N.FR1.session(1).badsegment = [665485,666054;671935,672472;684932,685498;801243,801659;882766,883167;929392,930578;966887,967247;1047569,1048000;1075238,1075578;1152001,1153074;1163605,1164000;1285791,1286376;1661231,1661727;1671311,1672599;1677069,1677776;1717089,1717699;1741283,1741744;1910355,1911005;1958609,1959223;1960928,1961530;1962738,1964000;2106226,2106707;2127077,2127550;2142617,2143820;2151238,2151876;2419129,2419687;2432590,2433361;2446666,2447263;2584763,2586054;2587617,2588000;2709489,2710042;2712541,2713086];
info.R1162N.FR1.session(1).jumps = [561726,561768;742081,742792;1422621,1422711;1541863,1543868;1789343,1790780;2755012,2755759;2822920,2823513];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1166D %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1166D' - 3    - 5T   - 37F   - 129/900   - 0.1433   - 5T   - 19F   - 124/864 - 0.1435   - :)  - Done. Core. 
% 'R1166D' - 1/3  - 5T   - 37F   - 30/300    - 0.1000   - 5T   - 19F   - 30/295   - 0.1017    - :)  - 
% 'R1166D' - 2/3  - 5T   - 37F   - 49/300    - 0.1633   - 5T   - 19F   - 47/280   - 0.16786    - :)  - 
% 'R1166D' - 3/3  - 5T   - 37F   - 50/300    - 0.1667   - 5T   - 19F   - 47/289 - 0.16263    - :)  - 

% Seizure onset zone "unreported".
% LFPG seem kinda wonky. Needs re-referencing and LP filter before cleaning. Lots of buzz still.
% Session 2: maybe some slight buzz and "ropiness" on LFPG temporal channels (24, 30-32).
% A few line spectra between 80 and 150Hz, but much smaller with re-ref
% Line detection on re-ref. 
% Buzzy episodes need to be cleaned out.
% No major events or slink, but buzz is worrying. 
% Lots of trials, low accuracy, ok coverage.
% Buzzy. No avoiding the buzz.
% LSFPG* can be re-refed separately. 5/19 to 5/35. {{'all', '-LSFPG*'}, {'LSFPG*'}};
% Adding a couple of things with jumps, but is still very buzzy. Cannot be helped.

% Channel Info:
info.R1166D.badchan.broken = {'LFPG14', 'LFPG15', 'LFPG16', ... % big deflections
    'LSFPG*', ... % bad line spectra
    'LFPG10' ... % big fluctuations in Session 3
    };
info.R1166D.badchan.epileptic = { ...
    'LFPG5', 'LFPG6', 'LFPG7', 'LFPG8'}; % wonky fluctuations together with one another

% Line Spectra Info:
info.R1166D.FR1.bsfilt.peak      = [60  120 180 200 217.8 218.2 218.8 220.1 223.7 240 300 ...
    100.1 140 160 260 280];
info.R1166D.FR1.bsfilt.halfbandw = [0.5 0.5 0.5 0.5 0.5   0.5   0.5   0.5   1.6   0.5 0.5 ...
    0.5   0.5 0.5 0.5 0.5];
info.R1166D.FR1.bsfilt.edge = util_calculatebandstopedge(info.R1166D.FR1.bsfilt.peak, ...
    info.R1166D.FR1.bsfilt.halfbandw, ...
    info.R1166D.fs);

% Bad Segment Info:
info.R1166D.FR1.session(1).badsegment = [20271,22642;467702,472510;607544,607626;620856,622376;717557,722586;1064001,1066534;1160453,1163199;1171198,1175638;1176287,1177518;1284001,1285558;1309480,1311090;1313227,1315408;1331815,1333816;1335637,1335699;1336001,1338006;1429799,1431533;1549158,1552369;1557089,1558671;1771383,1773953;1775274,1776000;1844001,1848000;1878762,1883110;1964831,1968000;1972001,1976000;1976448,1978312;2156372,2158255;2294383,2298634;2310613,2312000;2452001,2452764;2485932,2487384;2500860,2504329;2505428,2505949];
info.R1166D.FR1.session(2).badsegment = [288505,289856;511186,512486;552888,556736;740001,742570;995629,996635;1220594,1223840;1224791,1226711;1300682,1302066;1304618,1306183;1496368,1497260;1506549,1508000;1654371,1656619;2364372,2366304;2368964,2370860;2465271,2467348;2470170,2472965;2485880,2487541;2576706,2579130;2692783,2694401;2793791,2800925];
info.R1166D.FR1.session(3).badsegment = [498605,500204;634779,636000;732162,733558;852259,854981;874895,880000;880537,883687;910130,912873;1040787,1043094;1112549,1114647;1233775,1237405;1244001,1248000;1253924,1254042;1291379,1293699;1304690,1307308;1430125,1438384;1440001,1441659;1442662,1445570;1603335,1606255;1607524,1612000;1716420,1718554;1760307,1764873;1926621,1927570;1987307,1989409;2037932,2040000;2280642,2284000;2405686,2408000];
info.R1166D.FR1.session(1).jumps = [575831,576921;610960,614018;2190702,2191429;2672328,2675783;2710670,2711699;2812844,2814324;2917162,2920000;3095794,3096000;3125690,3128000;3132082,3134876;3235432,3238219];
info.R1166D.FR1.session(2).jumps = [2268211,2269490;2815399,2816000];
info.R1166D.FR1.session(3).jumps = [315069,315118;636186,636224;908831,908889;1765231,1766921;2077210,2077288;2533468,2547550;2549464,2551179;2680324,2681816;2784134,2785344;2894686,2899029;2948106,2948603;2990299,2992784];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1167M %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1167M' - 2    - 42T  - 21F   - 166/372   - 0.4462   - 32T  - 19F   - 133/285   - 0.4508 - :)  - Done. Core. 33. Flat slope. 
% 'R1167M' - 1/2    - 42T  - 21F   - 80/192   - 0.4167  - 32T  - 19F   - 54/127 - 0.4252    - :)  - 
% 'R1167M' - 2/2    - 42T  - 21F   - 86/180   - 0.4778  - 32T  - 19F   - 79/158 - 0.5    - :)  - 

% Line detection on re-ref. Quite a few little line spectra 80-150Hz. 
% LPT channels were wonky, so careful if they are the ones showing the effects.
% Has a bit of buzz still. Could go through and clean these out.
% Ambiguous IEDs and persistent buzz.
% Huge IEDs in depths in Session 2 that bleed into surfaces.
% LAT1-4 have synchronous spikes 

% Channel Info:
info.R1167M.badchan.broken = {'LP7', ... % sinusoidal noise
    'LP8'}; % spiky and large fluctuations
info.R1167M.badchan.epileptic = {'LP1', 'LAT8', 'LAT11', 'LAT12', 'LAT13', 'LAT16', ... % Kahana
    'LAI1', 'LAI2' ... % high frequency noise on top
     'LPT4', 'LPT5', 'LPT6', 'LPT9' % frequent little spikes. Removed after jumps. Probably could keep, but would need to remove more trials.
    }; 

% Line Spectra Info:
% z-thresh 0.45 + manual on combined re-ref. 
info.R1167M.FR1.bsfilt.peak      = [60  100.2 120 180 199.9 220.5 240 259.8 280 300 ...
    95.3 96.9 139.6 140.7 160 181.3];
info.R1167M.FR1.bsfilt.halfbandw = [0.5 0.5   0.5 0.5 0.5   2.9   0.5 0.8   0.5 0.5 ...
    0.5  0.5  0.5   0.5   0.5 0.5];
info.R1167M.FR1.bsfilt.edge = util_calculatebandstopedge(info.R1167M.FR1.bsfilt.peak, ...
    info.R1167M.FR1.bsfilt.halfbandw, ...
    info.R1167M.fs);

% Bad Segment Info:
info.R1167M.FR1.session(1).badsegment = [3574,5023;5468,6466;7684,8419;20092,21001;27678,28668;37140,37356;41003,41646;62699,63278;65901,66791;89033,89431;91999,92000;117221,117660;136656,137620;139916,140708;142906,143850;158062,159796;163129,163485;176904,177536;178280,180360;182616,183404;184374,184726;196840,197115;200702,201207;209113,209972;213277,214219;216001,216449;219404,220959;236920,237300;253114,253582;254158,254578;255641,256000;259244,259901;276787,277252;280757,281423;281884,282380;282387,283598;284780,285743;307205,308623;310029,310469;319716,320842;350932,351009;361291,361631;388969,389514;389527,390109;390130,391017;392979,394052;394845,396647;397072,400425;407347,408154;409368,414888;428844,430280;448796,449321;451728,452340;477097,477888;484158,487566;497791,498131;500888,501232;522440,523038;523476,525796;530239,530838;544917,546668;549464,551091;551159,552783;554487,555525;556390,557297;557584,558549;562140,562842;568202,568926;572646,574098;575718,576623;583653,584163;585261,586133;586674,587743;587840,588728;591693,592906;600541,600942;602554,603178;605148,605853;611812,612292;619218,619861;620621,621442;621464,622324;626484,628000;629243,629816;633465,634036;635083,636000;642791,643106;643690,645336;645339,645810;653232,653797;711488,711820;722954,723589;725126,725578;727312,728000;729960,730945;743640,743893;751424,751848;758970,759971;777323,777768;778730,779134;790460,790860;797517,800663;817089,817441;828001,828835;839301,840492;848726,849310;851048,852000;855561,856405;856565,857369;863818,864484;868917,869466;877763,880000;907337,908687;919839,920226;921205,921545;927640,927896;931485,932478;942456,942856;956811,959122;959125,961379;973484,974176;982567,983157;987855,988357;995021,995686;1018851,1019154;1031196,1031888;1060001,1063199;1064666,1064965;1066766,1067399;1082519,1083262;1084001,1084665;1122833,1123525;1137674,1138074;1140299,1143364;1148001,1148475;1149057,1150058;1150174,1150848;1152001,1153308;1169976,1170328;1220513,1220949;1223363,1224324;1244224,1245262;1258919,1259622;1275375,1276000;1286025,1286638;1296151,1296902;1297925,1298592;1344863,1346254;1346844,1347455;1398360,1398953;1402517,1404732;1413788,1415528;1422408,1423844;1430742,1431880;1439836,1440518;1441744,1442148;1496329,1498259;1503432,1504000;1573672,1574388;1588989,1591699;1594698,1595034;1604001,1604612;1607180,1607904;1637113,1637899;1651157,1651654;1663041,1663916;1704674,1705143;1706114,1706731;1716406,1716609;1720831,1724000;1730910,1732000;1742024,1742603;1750967,1753644;1754001,1754562;1826432,1828000;1833041,1833878;1835602,1836443;1888001,1888449;1914645,1916000;1921750,1922738;1936519,1937198;1938019,1938848;1939298,1939923;1940001,1941873;1952208,1952773;1957008,1957982;1975835,1976458;1977872,1978622;2027457,2027804;2029132,2029418;2037909,2038130;2041406,2041843;2052001,2052515;2055811,2056541;2068847,2069706;2077003,2077808];
info.R1167M.FR1.session(2).badsegment = [59923,60574;63558,64259;69264,70353;74277,75329;102823,103434;127279,127974;140041,140469;143352,143708;165656,166595;194006,194872;196796,197321;227866,228426;262261,263082;372457,373615;373872,375779;393207,394044;410005,410590;433952,434667;434867,435163;463230,463880;497213,498318;508046,511313;543768,544568;589987,592945;592977,595287;686174,686594;691394,692094;701613,701974;752090,752441;760151,761310;764501,766046;777127,778127;828060,831995;832001,835990;836001,839998;840001,855998;856001,860000;886379,886792;1001275,1003537;1097158,1097691;1115905,1116544;1140001,1140902;1164041,1164953;1212364,1214106;1216001,1217700;1311371,1312212;1348001,1349012;1365110,1365506;1381464,1384353;1400001,1400476;1418069,1418135;1422694,1424957;1447118,1447458;1607836,1608403;1632952,1633012;1654379,1655022;1704256,1706160;1729771,1731679;1776734,1777310;1810319,1812000;1821799,1823014;1832780,1836000;1836288,1838958;1848208,1848875;1859519,1860319];
info.R1167M.FR1.session(1).jumps = [248489,248534;295774,295828;338404,338993;358871,358909;472827,472889;529452,529490;563936,563973;729053,731231;846428,847356;1265876,1265937;1495851,1495908;1637081,1638219;1718613,1718659;1727371,1727421;1782605,1782659;1790130,1790179;1873863,1873933;1948190,1948252];
info.R1167M.FR1.session(2).jumps = [617678,617723;1318843,1318888;1414706,1414747;1421859,1421901;1501480,1501510;1606791,1607545];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1175N %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1175N' - 1    - 39T  - 29F   - 68/300  - 0.2267   - 27T  - 26F - 57/262 - 0.21756                       - ??? - Done. 73 recall. 

% No Kahana electrode info available.
% Lots of line noise, but baseline is pretty flat. Some additional, very small lines.
% Fair amount of reference noise, goes away with re-referencing.
% Lots of slinky channels, and some channels with sharp synchronous blips.
% Interictal spikes that will need to be removed.
% Possible that too many trials will be removed.
% Line detect on NON re-ref. Re-ref makes very fat line spectra. Using non-reref lines on re-ref data works well enough.
% Lots of sharp discontinuities, very brief.
% Lots of IEDs, ambiguous.
% Could remove more channels in order to get more trials.
% Was more aggressive in removing channels in order to preserve trials.
% Removing a bunch of discontinuities using jumps. Looks like most of these are in non-trial data.

% Channel Info:
info.R1175N.badchan.broken    = {'RAT8', 'RPST2', 'RPST3', 'RPST4', 'RPT6', 'RSM6', 'RAF4'};
info.R1175N.badchan.epileptic = {'RAT2', 'RAT3', 'RAT4', 'RAT5', 'RAT6' ... % synchronous spike on bump
    'RAT1', 'RMF3', ... % IEDs isolated to single channels
    'LPST1', 'RAST1', 'RAST2', 'RAST3', 'RAST4' ... % more IEDs
    };

% Line Spectra Info:
info.R1175N.FR1.bsfilt.peak      = [60  120 180 220 240 280 300.2 ... % Session 1/1 z-thresh 0.5
    159.9 186 200 216.9 259.9]; % manual
info.R1175N.FR1.bsfilt.halfbandw = [0.6 0.8 1.6 0.5 3   0.5 4.6 ... % Session 1/1 z-thresh 0.5
    0.5   0.5 0.5 0.5   0.5]; % manual
info.R1175N.FR1.bsfilt.edge      = util_calculatebandstopedge(info.R1175N.FR1.bsfilt.peak, ...
    info.R1175N.FR1.bsfilt.halfbandw, ...
    info.R1175N.fs);

% Bad Segment Info:
info.R1175N.FR1.session(1).badsegment = [1410383,1411227;1428582,1429357;1448287,1449038;1452001,1452316;1454843,1456000;1464174,1464272;1552997,1553344;1554537,1554578;1555782,1555808;1568747,1569155;1569726,1569816;1573239,1573332;1574029,1574110;1584146,1584832;1656358,1658774;1661714,1662376;1704414,1705359;1727085,1727328;1763593,1764000;1766758,1768000;1804082,1805744;1820741,1821056;1824235,1826066;1863363,1863461;1939452,1940000;1943524,1944296;1946424,1947110;1948166,1948752;1951327,1951739;1954460,1955267;2071784,2072000;2106879,2107836;2122956,2124000;2164247,2165074;2176416,2176542;2206444,2207094;2212275,2212304;2214307,2214441;2254488,2255118;2283315,2283715;2294343,2294642;2298202,2298231;2299117,2299316;2321972,2322759;2437932,2438876;2483819,2484288;2485323,2485985;2490303,2491340;2558553,2559977;2567045,2567812;2571153,2572264;2573872,2573941;2595295,2597226;2605255,2606574;2638557,2639134;2690545,2691271;2700912,2701985;2711682,2712510;2714343,2716000;2736001,2736836;2739669,2740454;2759214,2760000;2786940,2788000;2806779,2807558;2814412,2815064;2904864,2904974;2906154,2906247;2920126,2920806;2933747,2934759;2948328,2949199;2978287,2979154;3054541,3055239;3056416,3056897;3059099,3060000;3092162,3093141;3113098,3113723;3132315,3133167;3180779,3181582;3190920,3191614;3194899,3195840;3244219,3244841;3250381,3252000;3262791,3263495;3270662,3271400;3283686,3284000;3286631,3287263;3311295,3312000;3324805,3325631;3376118,3376901;3441988,3443062;3502811,3503219;3556473,3557288;3579109,3579860;3583544,3584264;3598444,3599223;3602125,3603348;3615540,3616000;3649098,3649844;3656384,3657054;3676436,3680000;3691033,3692000;3696001,3716000;3758553,3759062;3763363,3764000;3798440,3799130;3806178,3806808;3820372,3820994;3838670,3839376;3933787,3934292;3958077,3958384;4036384,4037397;4093335,4094018;4102009,4102562;4118936,4119356;4140981,4141490;4187504,4188000;4225077,4226264;4228616,4228818;4232791,4233437;4234436,4234751;4245041,4246630;4264299,4265937;4281892,4283275;4303900,4304977;4306621,4307481;4337222,4337860;4367488,4368000];
info.R1175N.FR1.session(1).jumps = [1375355,1375416;1417940,1417993;1446488,1446550;1446815,1446872;1447516,1447570;1447629,1447679;1452352,1452393;1453569,1453651;1454795,1454860;1466121,1466227;1470456,1470505;1532694,1532732;1548061,1548099;1548823,1548869;1569162,1569300;1571915,1572000;1574839,1574905;1578315,1578372;1629150,1629256;1652448,1652510;1655561,1656000;1656066,1656155;1658738,1658852;1661485,1661582;1678718,1678767;1686005,1686062;1732408,1732462;1733807,1733856;1741529,1741562;1748771,1748816;1750045,1750332;1750887,1750973;1802061,1802191;1802730,1803058;1803480,1803650;1814146,1814187;1818452,1818518;1819420,1819529;1820283,1820385;1835053,1835304;1849686,1849776;1857573,1857739;1882069,1882143;1973029,1973187;1973589,1973973;1975649,1976502;1978831,1978880;1979315,1979864;1980344,1980712;2017069,2017179;2057549,2057647;2057928,2058022;2066891,2066985;2073650,2073727;2074730,2074804;2075794,2075949;2077214,2077280;2077839,2077941;2081126,2081195;2081380,2081502;2089682,2089788;2094686,2094808;2182770,2182888;2187786,2187928;2190432,2190550;2196211,2196502;2196936,2197050;2199270,2199352;2205622,2205695;2213130,2213211;2213480,2213578;2215936,2216385;2287137,2287247;2294158,2294260;2294706,2294848;2297884,2297989;2312396,2312486;2406327,2407372;2444315,2444417;2452118,2452208;2514093,2514159;2518787,2518836;2528876,2528949;2563020,2563102;2590968,2591054;2592001,2592381;2592694,2592800;2650327,2650389;2657432,2657550;2659625,2659687;2662823,2662921;2666210,2666284;2667174,2667243;2672852,2672913;2675125,2675296;2675823,2675937;2676396,2676478;2679790,2679872;2684848,2685014;2694432,2694518;2708831,2708877;2712396,2712466;2712694,2712756;2712908,2713034;2713533,2713602;2721497,2721574;2727399,2727485;2733928,2734006;2744090,2744167;2744844,2744921;2752223,2752530;2756848,2756893;2760368,2760433;2769057,2769127;2769734,2769897;2771492,2771550;2772948,2773046;2781952,2782030;2786512,2786558;2788203,2788264;2789001,2789115;2790234,2790324;2790762,2790856;2791492,2791650;2810138,2810223;2880533,2880655;2883383,2883453;2884114,2884167;2886533,2886582;2889122,2889207;2905396,2905449;2909037,2909082;2913323,2913449;2960061,2960131;2987178,2987271;3076823,3076869;3076977,3077034;3077960,3078034;3098920,3099126;3099371,3099425;3103540,3103638;3108352,3108389;3110190,3110292;3126041,3126122;3129823,3129945;3203516,3203618;3206944,3207086;3214178,3214215;3239940,3240123;3240755,3240873;3444057,3444139;3446355,3446413;3453609,3453655;3454166,3454251;3458613,3458679;3461319,3462788;3468840,3468913;3475686,3475791;3484001,3484075;3636082,3636280;3689690,3689735;3692001,3696000;4191137,4191215;4231359,4231465];

end




% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%% R1084T %%%%%% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % Notes: 
% 
% % 'R1084T' - 1    - 2T   - 42F   - 53/300    - 0.1767                                         - !!! - Only 2T. Confirmed.
% 
% % Besides epileptic channels, looks very very clean.
% % Only two temporal channels, confirmed by looking at individual atlas region labels.
% 
% % Channel Info:
% info.R1084T.badchan.broken = {'PG37', 'PG45' ... sinusoidal noise
%     };
% info.R1084T.badchan.epileptic = {'PS3', ... % Kahana
%     'PS1', 'PS2', 'PS4', 'PS5', 'PS6', 'PG41', 'PG42', 'PG43', 'PG44' ... % follow Kahana bad channel closely
%     }; 
% 
% % Line Spectra Info:
% % Session 1/1 z-thresh 0.5 + manual (tiny)
% info.R1084T.FR1.bsfilt.peak      = [60 93.5 120 180.1 187 218.2 240 249.4 280.5 298.8 300.1 ...
%     155.8]; % manual
% info.R1084T.FR1.bsfilt.halfbandw = [1  0.5  0.5 0.9   0.5 0.5   0.5 0.5   0.5   0.5   1.8 ...
%     0.5]; % manual
% 
% % Bad Segment Info:
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%% R1100D %%%%%% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % Notes: 
% 
% % 'R1100D' - 3    - 26T  - 39F   - 11**/372  - 0.0296   -                                     - !!! - Too few correct trials.
% 
% % Not enough trials. Not even worth it.
% 
% % Channel Info:
% info.R1100D.badchan.broken = {
%     };
% info.R1100D.badchan.epileptic = {
%     }; 
% 
% % Line Spectra Info:
% Bad Segment Info:
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%% R1129D %%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% % 'R1129D' - 2    - 0T   - 52F   - 40/228    - 0.1754                                         - !!! - No T before clean. Confirmed.
% 
% % No T. Confirmed.
% 
% info.R1129D.badchan.broken = {
%     };
% info.R1129D.badchan.epileptic = {
%     }; 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%% R1155D %%%%%% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % Notes: 
% 
% % 'R1155D' - 1    - 1T - 59F   - 33/120  - 0.2750                                         - !!! - Only 1T. Confirmed.
% 
% % Channel Info:
% info.R1155D.badchan.broken = {
%     };
% info.R1155D.badchan.epileptic = {
%     }; 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%% R1156D %%%%%% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% % 'R1156D' - 3    - 7T   - 98F   - 215/900   - 0.2389   - 7T   - 53F                          - !!! - All temporal channels bad noise.
% % 'R1156D' - 1/3  - 7T   - 98F   - 63/300    - 0.2100   - 7T   - 53F                          - !!! - 
% % 'R1156D' - 2/3  - 7T   - 98F   - 74/300    - 0.2467   - 7T   - 53F                          - !!! - 
% % 'R1156D' - 3/3  - 7T   - 98F   - 78/300    - 0.2600   - 7T   - 53F                          - !!! - 
% 
% % No Kahana electrode info available.
% % Different grids are differentially affected by line noise. Will need
% % to re-reference some channels separately from one another in order to
% % find signal.
% 
% % Session 1 is corrupt after 3219 seconds.
% % A TON of relatively wide line spectra, especially 80-150Hz.
% % Line spectra not cleaned. Not sure if it is worth it considering the number of notches needed.
% 
% % Bad grids are LAF, LIHG, LPF, RFLG, ROFS, RPS
% 
% % OK grids that still need re-ref help are RFG, RIHG, RFPS; RFG1 should be
% % thrown out.
% 
% % Can potentially save RTS* (the only grid with temporal channels) by re-ref separately.
% 
% info.R1156D.badchan.broken = {'RFG1', 'LAF*', 'LIHG*', 'LPF*', 'RFLG*', 'ROFS*', 'RPS*'};
% info.R1156D.badchan.epileptic = {};
% info.R1156D.refchan = {{'RFPS*'}, {'RIHG*'}, {'RFG*'}, {'RTS*'}};
% 
% info.R1156D.FR1.bsfilt.peak = [60 120 180 200 219.3000 220.1000 224 259.9000 300 ...
%     80 100 112 140 160 240 269.8 280];
% info.R1156D.FR1.bsfilt.halfbandw = [0.5000 0.5000 0.5000 0.5000 0.5000 0.5000 0.5000 0.6000 0.5000 ...
%     05 0.5 0.5 0.5 0.5 0.5 0.5   0.5];
% 
% [60 100 120 140 179.4000 180 200 219.9000 224.9000 240 260.1000 269.8000 280 300 ...
%     79.7 112.4 160.1 172.3];
% [0.5000 0.5000 0.5000 0.7000 0.5000 0.7000 0.5000 1 0.5000 0.5000 1.1000 0.5000 0.5000 0.5000];
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%% R1159P %%%%%% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% % 'R1159P' - 1    - 42T  - 47F   - 40/168    - 0.2381                                         - !!! - All temporal channels bad noise.
% 
% % REALLY REALLY SHITTY AND I CAN'T EVEN RIGHT NOW
% % Awful, awful line spectra. Notch and LP filter help. Lots of broken channels, not sure if I got them all.
% % Re-referencing adds little spikes everywhere, and there's bad spikes everywhere too.
% 
% info.R1159P.badchan.broken = {'LG38', 'LG49', 'LG64', 'LG33', 'LG34', 'LG35', 'LG36', 'LG56', 'LO5', 'LG1', 'LG32', 'LG24', 'LG31', 'LG16' ... floor/ceiling
%     };
% 
% info.R1159P.badchan.epileptic = {'RDA1', 'RDA2', 'RDA3', 'RDA4', 'RDH1', 'RDH2', 'RDH3', 'RDH4' ... % Kahana
%     };
% origunclean = {'R1162N', 'R1033D', 'R1156D', 'R1149N', 'R1175N', 'R1154D', 'R1068J', 'R1159P', 'R1080E', 'R1135E', 'R1147P'};
%%%%%% R1068J %%%%%
% Looks funny, but relatively clean. Reference noise in grids RPT and RF go
% haywire by themselves, might need to re-reference individually.
% info.R1068J.FR1.session(1).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};
% info.R1068J.FR1.session(2).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};
% info.R1068J.FR1.session(3).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};


% 'R1128E' - 1    - 8T   - 10F   - 141/300   - 0.4700   - 4T   - 9F    - 134/276   - 0.48551  - :)  - Done. Core. 26. 147 recall. 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1128E %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Notes:

% 'R1128E' - 1    - 8T   - 10F   - 141/300   - 0.4700   - 4T - 9F    - 134/276 - 0.48551   - :) - Done. Core. 26. 147 recall. 

% Mostly depth electrodes. Very frequency epileptic events that are present
% in temporal grids.
% Ambiguous IEDs, not sure if I got them all OR if I was too aggressive. 
% RANTTS5 is mildly buzzy, but keeping in

% Not great for phase encoding.

% Channel Info:
% info.R1128E.badchan.broken = {'RTRIGD10', 'RPHCD9', ... % one is all line noise, the other large deviations
%     };
% info.R1128E.badchan.epileptic = {'RANTTS1', 'RANTTS2', 'RANTTS3', 'RANTTS4', ... % synchronous swoops with spikes on top
%     'RINFFS1'}; % marked as bad by Kahana Lab
% info.R1128E.refchan = {'all'};
% 
% % Line Spectra Info:
% info.R1128E.FR1.bsfilt.peak      = [60  179.9 239.8 299.7];
% info.R1128E.FR1.bsfilt.halfbandw = [0.5 0.5   0.5   0.7];
% info.R1128E.FR1.bsfilt.edge      = 3.1852;
% 
% % Bad Segment Info:
% info.R1128E.FR1.session(1).badsegment = [240728,241107;278500,278928;339661,340117;366194,366654;377155,377797;457180,457435;462388,462852;472334,473000;487250,487512;751091,751673;778825,779287;811298,811903;851544,852080;856877,857482;945783,947052;1056745,1057354;1059291,1060215;1062937,1063458;1067803,1068927;1081370,1081596;1088020,1089028;1122046,1122559;1211260,1212163;1280042,1280526;1306023,1306692;1571722,1572790;1638470,1638894;1703062,1703764;1710123,1710551;1815353,1816167;1816803,1817247;1819425,1819849;1911358,1911874;1939914,1940656;2038859,2039464;2133429,2133864;2323550,2324143;2331405,2331849;2333257,2333664;2338720,2339212;2341287,2342142;2384541,2384808;2675600,2676282;2676897,2677320;2906172,2906769];
% info.R1128E.FR1.session(1).jumps = [844877,847152;1502497,1507730;1510489,1514484;1659364,1660412;1669905,1670328];
