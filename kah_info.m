% Load information about subjects in Project Kahana. 
% Includes path, demographic, and channel, and artifact info. 
% Surface channels are prioritized. So, depth channels may or may not be
% noted as broken or epileptic. 

function info = kah_info
warning off

info = struct;

% Set path to Kahana folder on shared VoytekLab server.
info.path.kah = '/Volumes/voyteklab/common/data2/kahana_ecog_RAMphase1/';

% Set path to .csv file with demographic information.
info.path.demfile = [info.path.kah 'Release_Metadata_20160930/RAM_subject_demographics.csv'];

% Set current release of Kahana data.
info.release = 'r1';

% Set path to experiment data.
info.path.exp = [info.path.kah 'session_data/experiment_data/protocols/' info.release '/subjects/'];

% Set path to anatomical data.
info.path.surf = [info.path.kah 'session_data/surfaces/'];

% Get all subject identifiers.
info.subj = dir(info.path.exp);
info.subj = {info.subj.name};
info.subj(contains(info.subj, '.')) = [];

% Get info from demographic file.
demfile = fopen(info.path.demfile);
deminfo = textscan(demfile, '%s %s %f %s %s %s %s %s %s %s %s %s', 'delimiter', ',', 'headerlines', 1);
fclose(demfile);

% Get gender, ages, and handedness of all subjects.
[info.gender, info.hand] = deal(cell(size(info.subj)));
info.age = nan(size(info.subj));

for isubj = 1:numel(info.subj)
    info.gender(isubj) = deminfo{2}(strcmpi(info.subj{isubj}, deminfo{1}));
    info.age(isubj) = deminfo{3}(strcmpi(info.subj{isubj}, deminfo{1}));
    info.hand(isubj) = deminfo{12}(strcmpi(info.subj{isubj}, deminfo{1}));
end

% % OPTIONAL:
% % Select subjects for aging directional PAC + 1/f slope study.
% % >= age 18, sampling rate >= 999 Hz, temporal & frontal grids, FR1 task, > 20 correct trials, and relatively clean data
% info.subj = {'R1032D', 'R1128E', 'R1034D', 'R1167M', 'R1142N', 'R1059J', 'R1020J', 'R1045E'};
% 
% [info.gender, info.hand] = deal(cell(size(info.subj)));
% info.age = nan(size(info.subj));
% 
% for isubj = 1:numel(info.subj)
%     info.gender(isubj) = deminfo{2}(strcmpi(info.subj{isubj}, deminfo{1}));
%     info.age(isubj) = deminfo{3}(strcmpi(info.subj{isubj}, deminfo{1}));
%     info.hand(isubj) = deminfo{12}(strcmpi(info.subj{isubj}, deminfo{1}));
% end

% % All subjects >= 500 Hz
% info.subj = {'R1032D', 'R1006P', 'R1086M', 'R1177M', 'R1128E', 'R1156D', 'R1039M', 'R1149N', 'R1034D', 'R1112M', ...
%     'R1162N', 'R1033D', 'R1167M', 'R1102P', 'R1121M', 'R1175N', 'R1060M', 'R1089P', 'R1154D', 'R1003P', ...
%     'R1053M', 'R1066P', 'R1068J', 'R1127P', 'R1159P', 'R1080E', 'R1142N', 'R1059J', 'R1067P', 'R1018P', ...
%     'R1135E', 'R1147P', 'R1001P', 'R1020J', 'R1002P', 'R1036M', 'R1045E'};

% Load anatomical atlases.
talatlas = ft_read_atlas('TTatlas+tlrc.HEAD');
mniatlas = ft_read_atlas('ROI_MNI_V4.nii');

% For each subject, extract anatomical, channel, and electrophysiological info.
for isubj = 1:numel(info.subj)
    
    % Get current subject identifier.
    subjcurr = info.subj{isubj};
    disp([num2str(isubj) ' ' subjcurr])

    % Get path for left- and right-hemisphere pial surf files.
    info.(subjcurr).lsurffile = [info.path.surf subjcurr '/surf/lh.pial'];
    info.(subjcurr).rsurffile = [info.path.surf subjcurr '/surf/rh.pial'];
    
    % Get experiment-data path for current subject.
    subjpathcurr = [info.path.exp subjcurr '/'];
        
    % Get path for contacts.json and get all contact information.
    info.(subjcurr).contactsfile = [subjpathcurr 'localizations/0/montages/0/neuroradiology/current_processed/contacts.json'];
    contacts = loadjson(info.(subjcurr).contactsfile);
    contacts = contacts.(subjcurr).contacts;
    
    % Get labels for all channels.
    info.(subjcurr).allchan.label = fieldnames(contacts);
    
    % For each channel...
    for ichan = 1:length(info.(subjcurr).allchan.label)
        chancurr = contacts.(info.(subjcurr).allchan.label{ichan});
        
        % ...get channel type (grid, strip, depth)...
        info.(subjcurr).allchan.type{ichan} = chancurr.type;
        
        % and region labels and xyz coordinates per atlas.
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
            info.(subjcurr).allchan.(atlases{iatlas}).region{ichan} = atlascurr.region;
            
            % Convert xyz coordinates to double, if necessary (due to NaNs in coordinates).
            coords = {'x', 'y', 'z'};
            for icoord = 1:length(coords)
                if ischar(atlascurr.(coords{icoord}))
                    atlascurr.(coords{icoord}) = str2double(atlascurr.(coords{icoord}));
                end
            end
            
            % Extract xyz coordinates.
            info.(subjcurr).allchan.(atlases{iatlas}).xyz(ichan,:) = [atlascurr.x, atlascurr.y, atlascurr.z];
        end
        
        % Get top anatomical label from MNI atlas.
        try
            mnilabel = lower(atlas_lookup(mniatlas, info.(subjcurr).allchan.mni.xyz(ichan,:), 'inputcoord', 'mni', 'queryrange', 3));
            mnilabel = mnilabel{1};
        catch
            mnilabel = 'NA'; % if no label or atlas was found.
        end
        info.(subjcurr).allchan.mni.region{ichan} = mnilabel;
        
        % Get top anatomical label from TAL atlas.
        try
            tallabel = lower(atlas_lookup(talatlas, info.(subjcurr).allchan.tal.xyz(ichan,:), 'inputcoord', 'tal', 'queryrange', 3));
            tallabel = tallabel{1};
        catch
            tallabel = 'NA'; % if no label or atlas was found.
        end
        info.(subjcurr).allchan.tal.region{ichan} = tallabel;
        
        % Get anatomical annotations from Kahana group.
        avglabel = lower(info.(subjcurr).allchan.avg.region{ichan});
        
        % Get labels corresponding to particular lobes.
        regions = {mnilabel, tallabel, avglabel};
        frontal = contains(regions, {'frontal', 'opercularis', 'triangularis', 'precentral', 'rectal', 'rectus', 'orbital'});
        temporal = contains(regions, {'temporal', 'fusiform'});
        nolabel = strcmpi('NA', regions);
        
        % Determine lobe location based on majority vote across three labels.
        if sum(frontal) > (sum(~nolabel)/2)
            info.(subjcurr).allchan.lobe{ichan} = 'F';
        elseif sum(temporal) > (sum(~nolabel)/2)
            info.(subjcurr).allchan.lobe{ichan} = 'T';
        else
            info.(subjcurr).allchan.lobe{ichan} = 'NA';
        end
    end
    
    % Get experiments performed.
    experiments = extractfield(dir([subjpathcurr 'experiments/']), 'name');
    experiments(contains(experiments, '.')) = [];
    
    % For each experiment...
    for iexp = 1:numel(experiments)
        expcurr = experiments{iexp};
        
        % ...get subject experiment path, ...
        exppathcurr = [subjpathcurr 'experiments/' expcurr '/sessions/'];
        
        % ...get session numbers, ...
        sessions = extractfield(dir(exppathcurr), 'name');
        sessions(contains(sessions, '.')) = [];
        
        % ...and get header file, data directory, and event file per session.
        for isess = 1:numel(sessions)
            info.(subjcurr).(expcurr).session(isess).headerfile = [exppathcurr sessions{isess} '/behavioral/current_processed/index.json'];
            info.(subjcurr).(expcurr).session(isess).datadir    = [exppathcurr sessions{isess} '/ephys/current_processed/noreref/'];
            info.(subjcurr).(expcurr).session(isess).eventfile  = [exppathcurr sessions{isess} '/behavioral/current_processed/task_events.json'];
        end
    end
    
    % Get sampling rate from sources.json file.
    sourcesfile = [exppathcurr sessions{isess} '/ephys/current_processed/sources.json'];
    try
        sources = loadjson(sourcesfile);
    catch
        info.(subjcurr).fs = 0; % if sources file not found.
        continue
    end
    sourcesfield = fieldnames(sources);
    info.(subjcurr).fs = sources.(sourcesfield{1}).sample_rate;
end

% Remove sessions with problems.
% info.R1156D.FR1.session(4) = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  Subject - Sess - Temp - Front - Corr./All - Acc.     - Temp - Front - Corr./All - Acc.     - BAD - Notes
% 'R1020J' - 1    - 28T  - 33F   - 114/300   - 0.3800   - 18T  - 24F   - 101/278   - 0.3633   - :)  - Cleaned. 48
% 'R1032D' - 1    - 14T  - 11F   - 95/300    - 0.3167   - 13T  - 11F   - 80/234    - 0.3419   - :)  - Cleaned. 19
% 'R1033D' - 1    - 19T  - 13F   - 23/108    - 0.2130   - 10T  - 13F   - 18/87**   - 0.2069   - !!! - Too few correct trials (18).
% 'R1034D' - 3    - 11T  - 47F   - 48/528    - 0.0909   - 9T   - 40F   - 41/484    - 0.0847   - :)  - Cleaned. 29
% 'R1045E' - 1    - 15T  - 25F   - 98/300    - 0.3267   - 9T   - 21F   - 79/235    - 0.3362   - :)  - Cleaned. 51
% 'R1059J' - 2    - 50T  - 58F   - 36/444    - 0.0811   - 45T  - 54F   - 31/335    - 0.0925   - :)  - Cleaned. 44
% 'R1075J' - 2    - 7T   - 83F   - 150/600   - 0.2500   - 7T   - 80F   -                      - :)  - Good pending clean.
% 'R1080E' - 2    - 6T   - 10F   - 107/384   - 0.2786   - 6T   - 7F    -                      - :)  - Good pending clean.
% 'R1084T' - 1    - 4T   - 40F   - 53/300    - 0.1767   - 4T   - 38F   -                      - :)  - Good pending clean.
% 'R1100D' - 3    - 28T  - 36F   - 11**/372  - 0.0296   -                                     - !!! - Too few correct (11)
% 'R1120E' - 2    - 12T  - 1F**  - 207/600   - 0.3450   -                                     - !!! - Only 1F before clean.
% 'R1128E' - 1    - 8T   - 10F   - 141/300   - 0.4700   - 2T** - 9F    - 130/277   - 0.4693   - !!! - Only 2T after clean.
% 'R1129D' - 2    - 2T** - 46F   - 40/228    - 0.1754** -                                     - !!! - Only 2T before clean.
% 'R1135E' - 4    - 7T   - 13F   - 107/1200  - 0.0892** -                                     - ??? - Performance, FR1 pre re-implant, not sure which implant with pial
% 'R1142N' - 1    - 17T  - 57F   - 48/300    - 0.1600   - 12T  - 54F   - 36/212    - 0.1698   - :)  - Cleaned. 43
% 'R1147P' - 3    - 43T  - 32F   - 101/559   - 0.1807   -                                     - ??? - Bad noise across different grids.
% 'R1149N' - 1    - 38T  - 16F   - 64/300    - 0.2133   - 22T  - 4F                           - :)  - Good pending clean.
% 'R1151E' - 3    - 8T   - 3F    - 208/756   - 0.2751   - 8T   - 3F    -                      - :)  - Line spectra still need to be cleaned.

% Below here, line spectra were cleaned using surface channels only.
% 'R1154D' - 3    - 39T  - 20F   - 271/900   - 0.3011   -                                     - ??? - Maybe too many line spectra. 
% 'R1155D' - 1    - 1T** - 59F   - 33/120    - 0.2750   -                                     - !!! - Only 1T before clean.
% 'R1156D' - 4    - 7T   - 95F   - 215/900   - 0.2389   - 7T   - 95F                          - !!! - Lots of line spectra.
% 'R1159P' - 1    - 45T  - 45F   - 40/168    - 0.2381   - 37T  - 44F                          - !!! - Bad line noise.
% 'R1162N' - 1    - 25T  - 11F   - 77/300    - 0.2567   - 24T  - 11F                          - :)  - Good pending clean.
% 'R1164E' - 1    - 6T   - 9F    - 0/0       - NaN**    -                                     - !!! - No available data.
% 'R1166D' - 3    - 4T   - 39F   - 129/900   - 0.1433   -                                     - ??? -  Maybe too many line spectra. 
% 'R1167M' - 2    - 37T  - 21F   - 166/372   - 0.4462   - 32T  - 19F   - 127/281   - 0.452    - :)  - Cleaned. 33. Flat slope. Reclean line spectra.
% 'R1175N' - 1    - 33T  - 30F   - 68/300    - 0.2267   - 29T  - 30F                          - :)  - Good pending clean.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1175N %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% No Kahana electrode info available.
% Lots of line noise, but baseline is pretty flat. Some additional, very small lines.
% Fair amount of reference noise, goes away with re-referencing.
% Some slinky channels, and some channels with sharp synchronous blips.
% Overall, what I would consider a good subject.
info.R1175N.badchan.broken = {'RAT8', 'RPST2', 'RPST3', 'RPST4', 'RPT6'};
info.R1175N.badchan.epileptic = {};

info.R1175N.FR1.bsfilt.peak = [60 120.1 180.1 220 240 280 300.1 ... % Session 1/1 z-thresh 0.5
    159.9 216.9 259.9]; % manual
info.R1175N.FR1.bsfilt.halfbandw = [0.6000 0.5000 1.1 0.5000 1.4 0.6000 3.80 ... % Session 1/1 z-thresh 0.5
    0.5 0.5 0.5]; % manual
     
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1156D %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% No Kahana electrode info available.
% Different grids are differentially affected by line noise. Will need
% to re-reference some channels separately from one another in order to
% find signal.

% Session 1 is corrupt after 3219 seconds.
% A TON of relatively wide line spectra, especially 80-150Hz.
% Line spectra not cleaned. Not sure if it is worth it considering the number of notches needed.

% Bad grids are LAF, LIHG, LPF, RFLG, RFLG, ROFS, RPS, RTS
% OK grids that still need re-ref help are RFG, RIHG, RFPS; RFG1 should be
% thrown out.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1162N %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% No Kahana electrode info available.
% Very clean, only occassional reference noise across channels. WRONG. I
% WAS WRONG. VERY SHITTY.
% Mostly only harmonics in line spectra. Baseline has slight wave to it.
% Data is ambiguously dirty (can't quite tell where bad things start and stop), but not so bad that this subject is untrustworthy.
info.R1162N.badchan.broken = {'AST2'};
info.R1162N.badchan.epileptic = {};

info.R1162N.FR1.bsfilt.peak = [60 120.1 180 238.5 239.9 300 ... % Session 1/1 z-thresh 0.5
    220]; % manual, tiny tiny peak
info.R1162N.FR1.bsfilt.halfbandw = [0.5000 0.5000 0.5000 0.5 0.8000 0.6000 ... % Session 1/1 z-thresh 0.5
    0.5]; % manual, tiny tiny peak

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1166D %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Seizure onset zone "unreported".
% LFPG seem kinda wonky. Needs re-referencing and LP filter before cleaning. Lots of buzz still.
% Session 2: maybe some slight buzz and "ropiness" on LFPG temporal channels (24, 30-32).
% Lots and lots of line spectra, some of which are pretty wide.
info.R1166D.badchan.broken = {'LFPG14', 'LFPG15', 'LFPG16' ...
    };
info.R1166D.badchan.epileptic = { ...
    };

% Session 1 z-thresh 0.5 (1st two rounds only)
info.R1166D.FR1.bsfilt.peak = [60  72.5 89.1 99.5 100.2 108.9 120 140.2 148.4 178.3 179.1 180.5 200 217.8 219.6 223.2 237.7 240 260.2 287.2 287.6 299.9 ... % round 1
    160 168.3 198 ... % round 2
    160]; % manual 
info.R1166D.FR1.bsfilt.halfbandw = [0.5 0.5  1.6  0.5  0.7   0.5   0.5 1.8   0.5   0.5   0.5   2     0.5 1     1.8   0.6   0.5   0.5 1.9   0.5   0.5   0.6 ...
    0.5 2.4   1 ...
    0.6];
info.R1166D.FR1.bsfilt.edge = 3.1840;

% Session 1 z-thresh 0.5 (1st two rounds), 160 with 0.6 manual
% info.R1166D.FR1.bsfilt.peak = [60 72.5 89.1 99.4 100.2 108.9 120 140.2 148.4 178.3 179.1 180.5 200 217.8 219.6 223.2 237.7 240 160];
% info.R1166D.FR1.bsfilt.halfbandw = [0.5 0.5 1.6 0.5 0.7 0.5 0.5 1.8 0.5 0.5 0.5 2 0.5 1 1.8 0.6 0.5 0.5 0.6];
% info.R1166D.FR1.bsfilt.edge = 3.1840;

% Session 2 z-thresh 0.5
info.R1166D.FR1.bsfilt.peak = [60.0000   93.8000  100.1000  109.4000  120.0000  140.2000  160.1000  180.0000  200.1000  219.3000  224.4000 234.4000  240.0000  260.1000  280.0000  300.0000  301.5000  156.4000  203.0000 ...
    80 112.1 121.5 156.4]; % manual
info.R1166D.FR1.bsfilt.halfbandw = [0.5000    2.5000    0.6000    0.5000    0.5000    1.5000    0.5000    0.8000    0.5000    2.2000    0.8000 0.5000    0.5000    1.3000    0.9000    0.6000    0.5000    0.5000    0.5000 ...
    0.7 0.5 1 2];    
info.R1166D.FR1.bsfilt.edge = 3.1840;

% Session 2 z-thresh 0.5 (no iteration), 80 onward are manual
% info.R1166D.FR1.bsfilt.peak = [60 93.8 100.1 109.4 120.1 140.2 160.1 180 200.1 219.3 224.4 234.4 240 80 112.1 121.5 156.4];
% info.R1166D.FR1.bsfilt.halfbandw = [0.5 2.5 0.6 0.5 0.5 1.5 0.5 0.8 0.5 2.2 0.8 0.5 0.5 0.7 0.5 1 2];
% info.R1166D.FR1.bsfilt.edge = 3.1840;

% Session 3 z-thresh 0.5 (2 iteration)
info.R1166D.FR1.bsfilt.peak = [60  61.1 79.9 91.2 99.3 100.1 109.1 120 140.1 160.1 180.2 200 218.3 219.8 223.7 236.3 240 259.9 280.1 300 300.9 301.4 ...
    145.3 163.5 196.2]; % round 2
info.R1166D.FR1.bsfilt.halfbandw = [0.5 0.5  0.6  1.7  0.5  1.1   0.5   0.5 1.5   0.7   1.9   0.9 0.9   1.6   0.7   0.5   0.5 1.4   0.5   1.4 0.5   0.5 ...
    0.8   2.2   0.5];
info.R1166D.FR1.bsfilt.edge = 3.1840;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1154D %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% No Kahana electrode info available.
% Lots of line spectra, though remaining baseline is flat.
% Needs LP.
% Some buzz that can be removed by re-ref.
% Discrete large events, decent number of slinky channels, decent number of low-amplitude fluctuating channels.
% Nothing that makes me distrust this subject.

% Session 2 is corrupt after 2738 seconds.
% Session 2 still has buzzy episodes after re-ref and LP.
% Very slinky channels in Session 2, might be worse than Session 1.

% First 230 seconds of Session 3 are corrupted.
% Line spectra are much clearer in Session 3. Still some small ones.
info.R1154D.badchan.broken = {'LOTD*', 'LTCG23' ...
    };
info.R1154D.badchan.epileptic = { ...
    };

info.R1154D.FR1.bsfilt.peak = [60 80 90.6 92.5 100.1 120 140.2 160.1 180 196.2 199.9 219 222.7 240 260.2 280.1 300 ... Session 1/3 z-thresh 0.6
    109.3 301.4]; % Session 1/3 manual
info.R1154D.FR1.bsfilt.halfbandw = [1 0.5000 0.5000 3.3000 0.8000 0.5000 1.6000 0.6000 1.4000 0.5000 1 3 1.5000 0.5000 1.7000 0.7000 0.7000 ...
    0.5 0.5];

info.R1154D.FR1.bsfilt.peak = [60.0000   80.0000  100.1000  112.1000  120.0000  138.7000  140.1000  160.0000  172.3000  180.0000  200.0000  219.9000 222.3000  225.1000  240.0000  260.1000  280.1000  300.0000 ... Session 2/3 z-thresh 0.6
    205.9 277.3]; % Session 2/3 manual
info.R1154D.FR1.bsfilt.halfbandw = [0.5000    0.5000    0.9000    1.9000    0.5000    0.5000    1.3000    0.6000    0.5000    0.6000    0.7000    2.0000 2.2000    0.8000    0.5000    1.5000    0.7000    0.6000 ...
    0.5, 0.5];
    
info.R1154D.FR1.bsfilt.peak = [60.0000   80.1000   99.9000  109.1000  120.0000  140.1000  160.0000  179.9000  180.9000  200.1000  220.0000  221.8000 223.8000  240.0000  260.0000  279.9000  300.0000  301.0000 ... Session 3/3 z-thresh 0.6
    173.5 186.5 213.3 293.5 306.5]; 
info.R1154D.FR1.bsfilt.halfbandw = [1.4000    1.2000    1.4000    1.7000    0.7000    1.5000    0.9000    1.2000    0.5000    1.3000    1.8000    0.8000 0.7000    0.6000    1.7000    1.6000    0.9000    0.5000 ...
    0.5 0.5 1 0.5 0.5];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1159P %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% REALLY REALLY SHITTY AND I CAN'T EVEN RIGHT NOW
% Awful, awful line spectra. Notch and LP filter help. Lots of broken channels, not sure if I got them all.
% Re-referencing adds little spikes everywhere, and there's bad spikes everywhere too.

% 
info.R1159P.badchan.broken = {'LG38', 'LG49', 'LG64', 'LG33', 'LG34', 'LG35', 'LG36', 'LG56', 'LO5', 'LG1', 'LG32', 'LG24', 'LG31', 'LG16'
    };

info.R1159P.badchan.epileptic = {'RDA1', 'RDA2', 'RDA3', 'RDA4', 'RDH1', 'RDH2', 'RDH3', 'RDH4' ... % Kahana
    };

% z-thresh 1, surface channels only, only up to 250, peak at 80 with bandwidth 0.7 is manual
info.R1159P.FR1.bsfilt.peak = [60 100.1000 113.4000 120 123.8000 139.9000 160.2000 180 200 219.8000 222.7000 224.8000 240 80];
info.R1159P.FR1.bsfilt.halfbandw =  [0.5000 0.6000 3.8000 0.5000 3.2000 1.1000 0.5000 0.6000 0.5000 1.5000 1.4000 1.5000 0.5000 0.7];
info.R1159P.FR1.bsfilt.edge = 3.1840;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1149N %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Lots of reference noise and also antenna channels. Occasional line noise
% in channels even after filtering out line spectra. Lots of line spectra artifacts.
% Lots of low buzz in channels. Remaining channels are very slinky.
info.R1149N.badchan.broken = {'ALEX*', 'AST2', 'G1', 'LF2', 'LF3'};
info.R1149N.badchan.epileptic = {'PST1', 'TT1', 'MST1', 'MST2', 'AST1', ... % Kahana
    'TT*', 'OF*', 'LF*', 'G9', 'AST3', 'AST4', 'G18', 'G2', 'G26', 'G27', 'G28', 'G29', 'G3', 'MST4' ... % buzzy channels
    };

info.R1149N.FR1.bsfilt.peak =      [60, 120, 136, 180, 196.5, 211.6, 219.9, 226.7, 240, 241.9, 257, 272, 280, 287.2, 300, 332.5, 340, 347.7, 359.9, 360.9, 362.8, 377.9, 380, 393, 400, 408.1, 420, 423.3, 425.7, 438.4, 440, 460, 471, 480.1, 486.1];
info.R1149N.FR1.bsfilt.halfbandw = [0.5, 0.6, 0.5, 1.1, 0.5, 0.5, 0.5, 0.5, 1.6, 0.5, 0.5, 0.5, 0.5, 0.5, 1.8, 0.5, 0.6, 0.5, 1.6, 0.5, 0.5, 0.5, 0.5, 0.5, 0.6, 0.5, 1.4, 0.5, 0.5, 0.5, 0.5, 0.9, 0.5, 1.5, 0.5];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1147P %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Dominated by line noise. Cannot tell which channels are broken without prior filtering. Even after notch filtering,
% really bad noise. LP filter helps, but now lots of spikes across channels. Spikes are different across electrodes.
% Re-referencing does not work, introduces spikes into clean channels.

info.R1147P.badchan.broken = {'LGR64', 'LGR1' ... % big fluctuations
    };

info.R1147P.badchan.epileptic = {'LDH2', 'LDA2', 'LMST2', 'LDH3', 'LDA3' ... Kahana epileptic
    };

% Session 1
info.R1147P.FR1.bsfilt.peak = [60 79.9000 100.3000 109.5000 120 140 160.1000 162 180 199.9000 219.9000 221.9000 240];
info.R1147P.FR1.bsfilt.halfbandw = [0.5000 0.8000 2.5000 2.4000 0.5000 1.2000 0.9000 0.5000 1.3000 1 1.8000 1.2000 0.5000];
info.R1147P.FR1.bsfilt.edge = 3.1840;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1135E %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequent interictal events, and lots of channels show bursts of 20Hz
% activity. RSUPPS grid goes bad in Session 3. Session 3 has lots of
% reference noise. FR1 was done prior to a re-implant, so I'm not sure if the pial surfaces match the pre or post re-implant.

info.R1135E.badchan.broken = {'RAHCD3', ... Kahana broken
    'RROI1*', 'RROI2*', 'RROI3*', 'RROI4',  ... Kahana brain lesion
    'LHCD9', 'RPHCD1', 'RPHCD9', 'RSUPPS*' ... mine, 
    };

info.R1135E.badchan.epileptic = {'LROI3D7', 'LIPOS3' ... Kahana epileptic
    };

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1084T %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Besides epileptic channels, looks very very clean.

info.R1084T.badchan.broken = {'PG37', 'PG45' ... sinusoidal noise
    };
info.R1084T.badchan.epileptic = {'PS3', ... % Kahana
    'PS1', 'PS2', 'PS4', 'PS5', 'PS6', 'PG41', 'PG42', 'PG43', 'PG44' ... % follow Kahana bad channel closely
    }; 

% Relatively clean baseline. 
info.R1084T.FR1.bsfilt.peak = [60 93.5000 120 180.1000 187.1000 218.2000 240 249.4000 155.8];
info.R1084T.FR1.bsfilt.halfbandw = [1 0.5000 0.5000 0.9000 0.5000 0.5000 0.5000 0.5000 0.5];
info.R1084T.FR1.bsfilt.edge = 3.1340;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1151E %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Pretty bad noise specific to surface channels. Notch filters and re-referencing removes it, though some spikes remain.
% Remaining channels are kinda coherent and slinky. Session 3 line spectra are awful, baseline is moving.

info.R1151E.badchan.broken = {'RPHD8', 'LOFMID1' ... sinusoidal noise and fluctuations, session 1
    };

info.R1151E.badchan.epileptic = {'LAMYD1', 'LAMYD2', 'LAMYD3', 'LAHD1', 'LAHD2', 'LAHD3', 'LMHD1', 'LMHD2', 'LMHD3', ... % Kahana
    }; 

% Lots of line spectra, but baseline is pretty ok. 

% Session 1. 74.8 is manual. z-thresh 1.
% [60  80  100 120 140 160 180 200 210.3 215 220 240 74.8];
% [0.5 0.5 0.5 0.5 0.5 0.5 0.6 0.5 1     0.7 0.6 0.5 3];
% 3.1840;

info.R1151E.FR1.bsfilt.peak      = [59.9, 80.7, 103, 108.6, 113.3, 156.5, 179.8, 189.1 72.1000   88.2000   97.5000   99.3000  110.3000  115.4000  129.5000  132.7000  138.2000  140.1000 171.2000 195.1000  209.8000  247.4000];
info.R1151E.FR1.bsfilt.halfbandw = repmat(0.5, size(info.R1151E.FR1.bsfilt.peak));
info.R1151E.FR1.bsfilt.edge      = 3.1852;

% line spectra at 60Hz +/- 0.5Hz - 
% line spectra at 75.2Hz +/- 2Hz +
% line spectra at 79.7Hz +/- 0.5Hz +
% line spectra at 100.3Hz +/- 0.7Hz
% line spectra at 120Hz +/- 0.5Hz - 
% line spectra at 139.7Hz +/- 0.8Hz +
% line spectra at 140.7Hz +/- 0.5Hz +
% line spectra at 160.3Hz +/- 0.5Hz +
% line spectra at 180Hz +/- 0.7Hz +
% line spectra at 199.6Hz +/- 0.5Hz +
% line spectra at 200Hz +/- 0.5Hz -
% line spectra at 210.2Hz +/- 1Hz + 
% line spectra at 215Hz +/- 1Hz
% line spectra at 220.3Hz +/- 0.7Hz
% line spectra at 240Hz +/- 0.5Hz
% 
% [60 120.1000 121 136.9000 175.3000 180.2000 185.3000 215.3000 218.7000 223.7000 240.1000]
%      halfbandw: [2.6000 0.5000 0.5000 0.5000 0.5000 0.7000 0.5000 0.5000 0.5000 0.5000 0.5000]
%       filttype: 'but'
%        filtord: 2
%        filtdir: 'twopass'
%     edgeartlen: 3.0960
%     
%     found 12 line spectra in pass 1
% line spectra at 59.1Hz +/- 0.5Hz
% line spectra at 60.1Hz +/- 0.9Hz
% line spectra at 61Hz +/- 0.5Hz
% line spectra at 120.1Hz +/- 0.5Hz
% line spectra at 175.3Hz +/- 0.5Hz
% line spectra at 180.3Hz +/- 0.9Hz
% line spectra at 185.3Hz +/- 0.5Hz
% line spectra at 209.8Hz +/- 0.5Hz
% line spectra at 214.9Hz +/- 0.5Hz
% line spectra at 218.7Hz +/- 0.5Hz
% line spectra at 220.1Hz +/- 0.5Hz
% line spectra at 223.7Hz +/- 0.5Hz
% applying filter for peak at 59.1Hz +/- 0.5Hz
% applying filter for peak at 60.1Hz +/- 0.9Hz
% applying filter for peak at 61Hz +/- 0.5Hz

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1080E %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Lots of reference noise, but for surface channels, it goes away after re-referencing.
% A couple borderline slinky channels, but relatively low amplitude (RPTS7, RSFS2). Will keep them in. 
% Weird number naming conventions in surface channels.

info.R1080E.badchan.broken = {'RLFS7', 'L9D7', 'R12D7', 'R10D1', ... sinusoidal noise, session 1
    'L5D10', 'R10D7', 'RSFS4' ... sinsusoidal noise, session 2
    'RLFS4' ... sharp buzz, as if re-referencing was less effective. Saw on Session 2, but maybe on Session 1 too.
    };

info.R1080E.badchan.epileptic = {'R6D1', 'R4D1', 'R4D2', 'L1D8', 'L1D9', 'L1D10', 'L3D8', 'L3D9', 'L3D10', 'L7D7', 'L7D9'}; % Kahana

% Generally very noise baseline, lots of other peaks that could be added. Except for 60 and 180, the rest are
% somewhat comparable to baseline.
% Combining Session 1 and 2, removing 60Hz and 179.8 from Sess2
info.R1080E.FR1.bsfilt.peak      = [59.9, 80.7, 103, 108.6, 113.3, 156.5, 179.8, 189.1 72.1000   88.2000   97.5000   99.3000  110.3000  115.4000  129.5000  132.7000  138.2000  140.1000 171.2000 195.1000  209.8000  247.4000];
info.R1080E.FR1.bsfilt.halfbandw = repmat(0.5, size(info.R1080E.FR1.bsfilt.peak));
info.R1080E.FR1.bsfilt.edge      = 3.1852;

% FR1 session 1: [59.9, 80.7, 103, 108.6, 113.3, 156.5, 179.8, 189.1]
% FR1 session 2: [60.0000   72.1000   88.2000   97.5000   99.3000  110.3000  115.4000  129.5000  132.7000  138.2000  140.1000 171.2000  179.8000  195.1000  209.8000  247.4000];
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1075J %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Lots of high frequency (> 240 Hz) noise on half of the channels, especially surface. Squashed by lowpass filter.
% Otherwise, very clean.

info.R1075J.badchan.broken = {'LFB1', 'LFE4', ... % big fluctuations, LFE4 breaks in session 2
    'RFD1', 'LFD1', 'RFD8', 'LFC1' ... % sinusoidal noise + big fluctuations
    };

info.R1075J.badchan.epileptic = {}; % no Kahana channels

% FR1 Session 1 (z-thresh 1), but 120 and 180 bandwidths are manual. No additional found in Session 2, so just using Session 1.
% info.R1075J.FR1.bsfilt.peak      = [60   120 180 220 240.1];
% info.R1075J.FR1.bsfilt.halfbandw = [0.5, 5,  5,  0.7 0.6];   
% info.R1075J.FR1.bsfilt.edge      = 3.1840;

% FR1 Session 2 (z-thresh 1)
% info.R1075J.FR1.bsfilt.peak      = [60.0000   75.2000   79.7000  100.3000  120.0000  139.7000  140.7000  160.3000  180.0000  199.6000  200.0000 210.2000  215.0000  220.3000  240.0000];
% info.R1075J.FR1.bsfilt.halfbandw = [0.5000 2 0.5000 0.7000 0.5000 0.8000 0.5000 0.5000 0.7000 0.5000 0.5000 1 1 0.7000 0.5000];
% info.R1075J.FR1.bsfilt.edge      = 3.1840;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1033D %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Lots of what looks like buzz across channels, but not enough clean surface channels to re-reference out.
% Remaining surface channels have frequent slow drifts.
% Even if this subject had ended up with enough trials, I would not trust them.

info.R1033D.badchan.broken = {'LFS8', 'LTS8', 'RATS8', 'RFS8', 'RPTS8', 'LOTD12', 'RID12', 'ROTD12'... % flat-line channels
    'LTS6', ... % sinusoidal noise
    'LOTD6'}; % large voltage fluctuations; might be LOTD9

info.R1033D.badchan.epileptic = {'RATS*', ... % Kahana
    'LTS7'}; % very spiky slinkies 

info.R1033D.FR1.bsfilt.peak      = [60.1, 120, 180, 240.1]; % FR1 Session 1 (z-thresh 2); there were a couple of smaller ones that could be added
info.R1033D.FR1.bsfilt.halfbandw = [0.5,  0.5, 0.5, 0.5];   % FR1 Session 1 (z-thresh 2)
info.R1033D.FR1.bsfilt.edge      = 3.2225;
     
info.R1033D.FR1.session(1).badsegment = [16033,16621;29788,31234;140336,142280;154518,157163;160621,167783;268046,269209;299057,307744;335556,341047;411672,419679;468272,472421;540537,542202;594175,598234;696949,699215;711111,715118;809001,812800;934401,935867;1053008,1054621;1157639,1160609;1176852,1179138;1273200,1274168;1280001,1280551;1336730,1338215;1387533,1391785;1395576,1399041;1402679,1405976;1426766,1427542;1441969,1443183;1518047,1519647;1528291,1529331;1531937,1533189;1618497,1621570;1637601,1639099;1656433,1660183;1678240,1680299;1703401,1704338;1729743,1730415;1734401,1735467;1792105,1795873;1808420,1811200;1811215,1817600;1852285,1855557;1913601,1914841;1917575,1920000];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1032D %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Mostly depth electrodes. Relatively frequent epileptic events, especially
% in depths. Very buzzy (reference noise?), removed by average referencing.
% Overall, not too bad.

% Age 19

info.R1032D.badchan.broken = {'LFS8', 'LID12', 'LOFD12', 'LOTD12', 'LTS8', 'RID12', 'ROFD12', 'ROTD12', 'RTS8', ... % flat-line channels
    };

info.R1032D.badchan.epileptic = {};

info.R1032D.FR1.bsfilt.peak      = [60, 63.8, 120.1, 180, 240.1]; % FR1 Session 1 (z-thresh 2)
info.R1032D.FR1.bsfilt.halfbandw = [0.5, 0.5, 0.5,   0.5, 0.5];   % FR1 Session 1 (z-thresh 2)
info.R1032D.FR1.bsfilt.edge      = 3.2237;

info.R1032D.FR1.session(1).badsegment = [6692,7487;13550,14138;16620,17202;22614,23776;50403,51060;76023,79445;105550,106673;109098,109835;111814,112641;130627,131144;200285,200602;201414,201744;209220,209679;212756,215299;219092,219596;250892,251686;259595,260415;266788,267557;292356,292866;296059,297176;318349,319531;323672,324570;344181,344550;348124,349557;357439,357969;382427,383111;402069,403201;412014,412654;428382,429360;437782,438486;455788,456189;498574,499487;506866,508486;510852,511511;527982,528376;539098,539647;575342,575946;594846,595189;605395,605879;687833,688131;693808,694351;751459,751996;771666,772157;811162,811570;815672,816009;853027,853512;860537,861467;890382,891183;920767,921644;922143,923377;926197,927739;959846,960559;966434,966932;976575,976783;985539,986278;989088,989801;992511,993370;1010723,1011118;1024866,1025486;1032666,1033118;1034453,1035479;1050156,1051189;1063382,1063970;1090143,1090564;1104091,1105002;1115866,1116480;1135117,1135602;1138098,1138711;1154001,1154299;1181962,1182273;1197356,1199254;1206098,1206660;1219466,1220537;1227027,1228215;1234660,1235756;1259834,1260701;1283666,1284976;1297917,1298827;1300150,1301783;1312337,1313286;1324249,1325135;1327095,1327735;1366917,1367795;1384279,1385041;1395261,1396202;1399066,1399742;1429305,1430067;1458581,1459163;1511801,1512254;1611640,1611963;1629491,1629983;1634472,1636021;1672382,1672989;1686053,1686925;1687782,1688421;1699608,1700131;1708478,1710021;1787685,1788615;1837124,1837667;1838898,1839673;1847517,1848047;1864324,1865015;1923291,1924008;1936943,1938131;1943014,1943686;1984324,1985699;2004072,2005589;2006749,2008441;2016995,2017422;2028111,2028933;2071556,2072782;2075137,2075809;2102608,2102892;2118995,2119428;2140582,2143137;2154072,2154989;2218195,2218847;2272692,2273254;2296201,2296718;2303175,2303692;2317305,2317731;2328414,2329008;2379246,2380066;2472246,2472654;2474717,2475183;2476308,2477066;2491943,2492247;2535408,2535944;2575827,2576931;2580060,2580602;2667614,2667969;2673117,2673512;2683556,2683970;2767698,2767918;2769078,2770544;2772756,2773260;2785505,2785828;2787685,2788815;2878446,2878899;2909582,2910189;2923723,2924157;2971337,2971667;3007279,3007918;3023311,3023705;3029117,3029422;3031582,3032099;3037782,3038150;3049182,3049680;3086814,3087305;3088349,3088757;3189324,3190022;3240685,3241351;3250588,3251730;3282104,3282557;3343092,3343641;3351233,3351770;3369608,3370157;3386537,3387054;3398795,3399228;3419001,3419635;3454278,3454963;3478511,3478731;3484966,3485505;3493789,3494401;3507260,3507744;3564608,3566032;3585930,3587228;3596461,3597228;3607814,3608350;3625130,3625692;3649872,3650376;3679434,3680338;3707879,3708415;3734652,3735319;3817627,3818086;3828221,3828570;3843317,3844054;3852334,3852845;3914459,3914957;3919034,3919531;3930769,3931860;3956750,3957409;3958993,3959925;3973306,3974688;3987943,3988331;4037685,4038156;4062788,4063505;4081136,4081505;4082252,4082757;4084305,4084635;4116272,4117396;4165427,4166279;4174601,4175015;4236783,4237139;4256169,4256577;4264356,4264789;4270492,4270970];

info.R1032D.thetapeak = 7.3043;

% IGNORED b/c favoring keeping channels; info.R1032D.FR1.session(1).badchan.epileptic = {
%     'LFS1x', 'LFS2x', 'LFS3x', 'LFS4x', ... % Large deviations, many related to epileptic activity in depths
%     };

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1128E %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Mostly depth electrodes. Very frequency epileptic events that are present
% in temporal grids.

% Age 26

info.R1128E.badchan.broken = {'RTRIGD10', 'RPHCD9', ... % one is all line noise, the other large deviations
    'RINFPS*', 'RSUPPS*'}; % odd-number naming scheme
info.R1128E.badchan.epileptic = {'RANTTS1', 'RANTTS2', 'RANTTS3', 'RANTTS4', ... % interictal events
    'RINFFS1'}; % marked as bad by Kahana Lab

info.R1128E.FR1.bsfilt.peak      = [60, 119.9, 172.1, 179.9, 239.8]; % FR1 Session 1 (z-thresh 1)
info.R1128E.FR1.bsfilt.halfbandw = [0.7, 0.5,  0.5,   0.7,   0.5];   % FR1 Session 1 (z-thresh 1)
info.R1128E.FR1.bsfilt.edge      = 3.0971;

info.R1128E.FR1.session(1).badsegment = [99207,99478;135550,135784;213726,214090;220313,221010;240744,241075;252563,252825;262689,263399;264985,265663;277002,277164;490763,491336;571506,572235;583916,584840;646804,647352;676159,676623;766217,767189;828860,829244;830359,831105;872631,873655;1018759,1019307;1299921,1300619;1807973,1808643;1815413,1815930;1819433,1819765;1831655,1833078;1868574,1869154;1982802,1983754;2159589,2160001;2285284,2285854;2372943,2373480;2440251,2440784;2595946,2596451;2608393,2609014;2665639,2666566;2675616,2676290;2760076,2760818;2965178,2966194];

info.R1128E.thetapeak = 6.6818;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1034D %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Lots of spiky channels, particularly in Session 1. Lots of reference noise in Session 3, reref helps.

info.R1034D.badchan.broken = {'LFG1', 'LFG16', 'LFG24', 'LFG32', 'LFG8', 'LIHG16', 'LIHG24', 'LIHG8', 'LOFG12', 'LOFG6', 'LOTD12', 'LTS8', 'RIHG16', 'RIHG8', ... % flat-line channels
    'LOTD7'}; % large voltage fluctuations

% Age 29

info.R1034D.badchan.epileptic = {'LIHG17', ... % big fluctuations and small sharp oscillations
    'LIHG18', ... % small sharp oscillations
    'LFG13', 'LFG14', 'LFG15', 'LFG22', 'LFG23'}; % marked by Kahana

info.R1034D.FR1.bsfilt.peak         = [60, 120, 180, 180.1, 240, 240.1, 172.3, 183.5, 200, 212];
info.R1034D.FR1.bsfilt.halfbandw    = [0.6, 0.5, 0.5, 0.5,  0.6, 0.5,   0.5,   0.5,   0.5, 0.5];
info.R1034D.FR1.bsfilt.edge         = 3.1612;

% Session 1 (z-thresh 1): [60, 120, 180.1, 183.5, 240]
% Session 1 (z-thresh 1): [0.6, 0.5, 0.5,  0.5,   0.6]
% Session 1 (manual):     [172.3, 212]
% Session 1 (manual):     [0.5,   0.5]
% Session 2 (z-thresh 1): [60, 120, 172.3, 180, 240.1]
% Session 2 (z-thresh 1): [0.5, 0.5, 0.5,  0.5, 0.5]
% Session 3 (z-thresh 1): [60, 120, 172.3, 180, 240]
% Session 3 (z-thresh 1): [0.6, 0.5, 0.5,  0.5, 0.5]
% Session 3 (manual):     [200]
% Session 3 (manual):     [0.5]

info.R1034D.FR1.session(1).badsegment = [76801,77572;93764,94659;102208,102963;161824,162333;166173,166941;208310,208857;220358,221472;330990,331360;362431,363606;364801,365654;371201,371950;383154,384353;403812,404492;668336,669120;712323,712858;722060,723055;765115,766006;858349,858909;911304,912126;915704,916527;934152,935017;1417355,1418204;1562986,1563576;1626014,1626535;1762697,1763300;1994383,1995283;2144001,2144363;2265601,2268402;2272607,2273451;2280740,2281627;2324272,2325357;2446530,2447116;2558091,2559627;2572438,2573874;2608886,2609494;2634981,2636251;2641696,2643693;2680362,2680874;2682126,2682944;2694091,2695192];
info.R1034D.FR1.session(2).badsegment = [84629,85886;129373,129967;401329,402049;414413,414986;502327,502931;520018,521365;683230,683717;690585,690999;917209,917584;1222814,1223813;1307549,1308574;1436543,1438259;1448379,1450724;1562560,1563193;1789871,1791494;1875795,1877283;1956555,1958400;2037820,2039184;2083841,2084014;2158444,2159593;2189266,2189886;2244031,2244659;2270043,2271193;2387911,2388609;2399484,2400115;2402982,2403479;2764020,2764660;2802869,2803882;2817291,2818120;2827149,2828800;2838059,2839499;2934685,2935299;2953382,2953860;3067240,3068847;3071147,3072817;3123254,3124058;3174120,3175580;3256558,3258791;3335795,3336731;3649988,3650776;3790382,3791202;3833601,3838892;3862046,3863202;3956795,3958054;3985833,3987098;4262401,4263519;4462872,4464067;4495866,4496925];
info.R1034D.FR1.session(3).badsegment = [306485,307734;376117,377389;405640,408253;570137,570622;571872,572312;572949,573454;574207,574686;606594,608000;953731,955641;1116479,1118195;1380465,1382060];

info.R1034D.thetapeak = 6.2448;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1167M %%%%%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Lots of reference noise, reref helps. Some ambiguous spiky channels remain.
% LPT channels were wonky, so careful if they are the ones showing the
% effects.

% Age 33

info.R1167M.badchan.broken = {'LP7', ... % sinusoidal noise
    'LP8'}; % spiky and large fluctuations

info.R1167M.badchan.epileptic = {'LP1', 'LAT8', 'LAT11', 'LAT12', 'LAT13', 'LAT16', ... % Kahana
    'LAI1', 'LAI2'}; % high frequency noise on top

info.R1167M.FR1.bsfilt.peak      = [60, 100.3, 120, 180, 219.2, 220.2, 221.8, 239.9, 100, 219.8, 220.8, 221.3, 240, 58.7, 59.3, 61.3, 80, 95.3, 140, 160.1, 199.9];
info.R1167M.FR1.bsfilt.halfbandw = [0.5, 0.5,  0.5, 0.5, 0.5,   0.7,   0.5,   0.5,   0.6, 1,     0.5,   0.5,   0.5, 1,    1,    1,    1,  1,    1,   1,     1];
info.R1167M.FR1.bsfilt.edge      = 3.1840;

% Session 1 (z-thresh 1.75): [60, 100.3, 120, 180, 219.2, 220.2, 221.8, 239.9]
% Session 1 (z-thresh 1.75): [0.5, 0.5, 0.5, 0.5, 0.5, 0.7, 0.5, 0.5]
% Session 2 (z-thresh 1.75): [60, 100, 120, 180, 219.8, 220.8, 221.3, 240]
% Session 2 (z-thresh 1.75): [0.5, 0.6, 0.5, 0.5, 1, 0.5, 0.5, 0.5]
% Session 2 (manual):        [58.7, 59.3, 61.3, 80, 95.3, 140, 160.1, 199.9]
% Session 2 (manual):        [1, 1, 1, 1, 1, 1, 1, 1]

info.R1167M.FR1.session(1).badsegment = [3574,5023;5468,6466;7684,8419;20092,21001;27678,28668;37140,37356;41003,41646;62699,63278;65901,66791;89033,89431;91999,92000;117221,117660;136656,137620;139916,140708;142906,143850;158062,159796;163129,163485;176904,177536;178280,180360;182616,183404;184001,185219;209113,209972;213277,214219;219404,220959;259244,259901;270057,270925;280401,281423;282387,283598;284780,285743;307205,308623;319716,320842;389334,390109;392839,394052;394845,396647;397072,400425;407347,408154;410753,411077;448796,449321;451728,452340;470126,471264;477097,477888;484632,485845;497535,498200;530239,531114;544917,546668;549464,551091;551159,552783;554487,555525;556390,557297;557584,558549;562140,562842;568202,568926;572160,574191;575718,576623;583653,584163;585261,586133;587840,588728;591693,592906;600541,600942;602554,603178;605148,605853;606908,607832;611812,612292;616001,616598;619218,619861;620621,621442;626484,630783;633465,634036;635083,636000;645339,645810;653232,653797;715236,716000;721656,722391;722954,723589;727312,728000;743640,743893;758970,759971;774882,776000;828001,828835;839301,840492;848726,849310;851048,852000;863818,864484;868917,869466;883059,883592;907337,908687;919666,920226;921205,921545;927640,927896;931485,932478;959740,961379;972001,972703;973484,974176;982567,983157;995021,995686;1003231,1004000;1031196,1031888;1058946,1060429;1066766,1067399;1082519,1083262;1083661,1085216;1122833,1123525;1141299,1142536;1148001,1148475;1149057,1150058;1157874,1158837;1223363,1224324;1244224,1245262;1258919,1259622;1278387,1279286;1296151,1296902;1297925,1298592;1303105,1304000;1344863,1346254;1346844,1347455;1378288,1380000;1380210,1380905;1398360,1398953;1413788,1415528;1430742,1431880;1439836,1440518;1441744,1442148;1447690,1448192;1448949,1449491;1455724,1457234;1480608,1481886;1496329,1498259;1503299,1504292;1520423,1521429;1568001,1568416;1573672,1574388;1581436,1582313;1586035,1586697;1587339,1587982;1592941,1593603;1601057,1602203;1603220,1604612;1607180,1607904;1613344,1614060;1614766,1615568;1619000,1619560;1637113,1637899;1651049,1652599;1704187,1705249;1706114,1706731;1707254,1708883;1716406,1716609;1721742,1722157;1727302,1728131;1730910,1732190;1742024,1742603;1750967,1753644;1833041,1833878;1835602,1836443;1866556,1867323;1870594,1871616;1873557,1874275;1914645,1916000;1921750,1922738;1936519,1937198;1938019,1938848;1939298,1939923;1952208,1952773;1957008,1957982;1989807,1990248;1992377,1993832;2005624,2007073;2027457,2027804;2029132,2029418;2037909,2038130;2041406,2041843;2052001,2052515;2055811,2056541;2068847,2069706;2077003,2077808];
info.R1167M.FR1.session(2).badsegment = [59923,60574;63558,64259;69264,70353;74277,75329;102823,103434;127279,127974;140041,140469;143352,143708;165656,166595;194006,194872;196796,197321;227866,228426;262261,263082;326290,326686;393207,394528;396286,397297;409847,410939;434011,435772;463086,464000;467599,469173;497213,498318;508046,511313;535693,536462;542731,543452;543464,544739;580001,582189;589987,592945;595029,596000;628842,629840;640616,641133;646293,647020;685600,686654;687189,688501;691394,692094;701613,701974;709258,709829;724557,725550;727522,728055;733223,733601;750261,750853;752001,752561;760151,761310;764643,766106;777127,778127;806581,807243;828060,831995;832001,835990;836001,839998;840001,855998;856001,860000;940957,941894;990261,991638;1014148,1014660;1038067,1038590;1097304,1097824;1106930,1107807;1115905,1116544;1121645,1122168;1122869,1124147;1138997,1140902;1142895,1143396;1164041,1164953;1216001,1217700;1220001,1220649;1304001,1304399;1311371,1312212;1329422,1330205;1348001,1349012;1399360,1400948;1447118,1447458;1460001,1460512;1486406,1486987;1505089,1505947;1581997,1582662;1607836,1608403;1632952,1633012;1654379,1655022;1692001,1692558;1704256,1706160;1776734,1777310;1810737,1811420;1821799,1823014;1832780,1836000;1836288,1838958;1848208,1848875;1859519,1860319];

% First cleaning, where I was relatively unaggressive in cleaning out big fluctuations.
% info.R1167M.FR1.session(1).badsegment = [37142,37344;89033,89429;163129,163469;259250,259900;407368,408122;410755,411081;530291,530437;554512,555489;774886,776472;827947,828821;883069,883578;907727,908612;921239,921429;1082561,1083227;1083681,1085205;1223384,1224281;1345533,1346147;1430762,1431691;1496380,1497558;1607234,1607799;1651123,1652462;1707308,1708777;1866573,1867287;1870621,1871562;1873577,1874239;2037952,2038078];
% info.R1167M.FR1.session(2).badsegment = [60001,60466;165698,166300;194025,194836;196835,197284;262307,263038;393231,394324;409884,410917;434073,435727;463097,464000;497222,498260;508763,511304;535722,536436;543769,544591;777198,778018;1038105,1038546;1139014,1140845;1164066,1164917;1215904,1217661;1303928,1304374;1348001,1348978;1399379,1400925;1447166,1447384;1654424,1654977;1704279,1706082;1821823,1822985];

info.R1167M.thetapeak = 6.5490;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1142N %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Looks very, very clean.

% Age 43

info.R1142N.badchan.broken = {'ALT6'}; % flat line

info.R1142N.badchan.epileptic = {'PD1', 'PD2', 'PD3', 'AD1', 'AD2', 'AALF1', 'AALF2', 'MLF2', ... % Kahana
    'AST1', 'AST2', 'PST1', 'PST2'}; % buzzy channels, though Roemer says they're ok

info.R1142N.FR1.bsfilt.peak      = [60, 120, 180, 240];
info.R1142N.FR1.bsfilt.halfbandw = [0.5, 0.5, 0.5, 0.5];
info.R1142N.FR1.bsfilt.edge      = 3.1840;

% Session 1 (z-thresh 5): [60, 180]
% Session 1 (z-thresh 5): [0.5, 0.5]
% Session 1 (manual):     [120, 240]
% Session 1 (manual):     [0.5, 0.5]

info.R1142N.FR1.session(1).badsegment = [1,1915;7459,7503;15373,15544;20396,21061;35838,35877;45968,46098;46986,47041;50210,50275;64458,64502;82156,82219;82629,82665;83172,83235;83855,83904;83981,84016;84605,84631;85033,85066;86548,86579;88345,88442;88955,88996;89516,89558;91976,92004;92535,92596;103922,103960;104186,104227;104802,104840;105339,105450;105530,105558;112261,112287;112640,112674;112707,112746;115328,115439;118556,118582;119072,119103;122605,122630;122750,122778;122882,122998;123336,123369;125143,125187;130180,130213;130608,130649;130718,130759;134565,134622;135349,135399;137404,137439;137793,137883;139906,139950;162280,162342;162403,162482;162661,162781;162852,162896;165559,165611;167782,168518;169425,170047;170680,171718;172001,173184;173793,174953;175508,177219;177734,178058;180001,180098;182110,184000;185183,186407;187102,192000;192777,197372;198927,200000;202540,207388;208001,215995;216001,232000;233000,236000;240525,240905;244001,244321;245441,249982;252057,252101;253428,253482;254680,254719;255140,255176;255717,255864;256135,256988;258586,259853;261782,262713;266651,266695;268850,269370;270046,270084;270532,270969;273331,273372;278573,278619;285484,285512;286180,286222;287099,287143;287309,287393;288780,288819;291787,291837;316226,317047;318137,318313;318978,319643;321559,321601;334199,334375;334438,334471;334890,334928;335916,335979;372092,372735;377551,377571;383083,383122;386796,386834;433573,433603;514100,514160;525648,525711;652363,652545;712705,712760;2978,3154;6479,7036;16498,17176;23583,23995;25506,26211;29605,30170;32562,33144;33417,33998;36151,36762;38320,39641;44001,44776;48001,48703;50938,51401;53054,53566;54376,55014;57495,58176;58629,59114;60122,60381;61903,62630;63349,64137;66374,66437;74591,75168;81675,81722;82250,82281;86578,86638;87802,88711;92828,92889;103419,104000;105183,105254;109885,110514;120933,121587;133465,133499;133605,134281;136001,137079;142218,142867;159712,159772;160001,160749;161562,162047;163223,163920;165025,165544;180089,182119;184001,185192;186355,187149;192001,192808;207384,208000;241557,241888;242731,243254;244323,245466;264624,265246;272275,272692;280267,280754;284001,284504;297928,298587;312952,313840;314470,314850;315615,315659;320052,320719;333694,333719;335551,336000;336323,336800;345495,346168;347148,347705;376001,376574;380001,380980;384170,384803;389839,390434;392619,393577;398532,400000;418532,419073;420001,420571;432952,433509;437917,438547;439314,440000;442667,443383;450556,451079;457831,458283;459699,460287;468001,469512;478309,479374;480001,480641;481430,482380;485140,486160;490922,491538;510836,511458;515301,516000;518866,520000;522264,523667;530968,531452;536885,537644;541895,542297;545879,546488;576901,577574;587341,587377;602935,602966;616140,616768;632001,632663;648718,649241;659137,659826;669398,669896;670556,670939;674796,675213;705288,705802;707771,708000;709054,709547;712001,712383;734497,734912;737390,738101;742341,743087;747091,747692;748291,749104;761995,762727;789191,789792;822952,824000;832001,832582;834393,835606;836401,837015;838387,838936;855519,855987;857745,858222;858857,859423;892130,892905;901189,901945;915527,916000;918067,918600;920896,920964;929146,929633;932221,932800;934414,935108;948726,949241;968511,969149;972949,973364;1000474,1000966;1002382,1002842;1005796,1007049;1017019,1018246;1025008,1025910;1032879,1033534;1035505,1035915;1037519,1039211;1048425,1049023;1053245,1054076;1057522,1057998;1060154,1060214;1065968,1066633;1071134,1071557;1072487,1073265;1077911,1078469;1091188,1091305;1101893,1102466;1127602,1128000;1130195,1130698;1131678,1132310;1133393,1134032;1136342,1136860;1137068,1137754;1143616,1144780;1153202,1153829;1159075,1159761;1167376,1168000;1175513,1176000;1193116,1193813;1230852,1231630;1248272,1248840;1254274,1255197;1266855,1267721;1286624,1287151;1295056,1295662;1313070,1313783;1318820,1319364;1321793,1321861;1332001,1332510;1337172,1337595;1362831,1363291;1374083,1374563;1376581,1377343;1380054,1380596;1383626,1384000;1393847,1394504;1397331,1397883;1410524,1410971;1429003,1429617;1441113,1441708;1476810,1476846;1503024,1503541;1509035,1509544;1514003,1514547;1525154,1525797;1527468,1528000;1535659,1536257;1547263,1547737;1576001,1576590;1588699,1589302;1592793,1593426;1595355,1596101;1604296,1604800;1614307,1614832;1629960,1630590;1642312,1642721;1707301,1707864;1712976,1713491;1716159,1716692;1742540,1743149;1752584,1753149;1771218,1771619;1786341,1786751;1816253,1816786;1819505,1820000;1835255,1836000;1860885,1861558;1880269,1880864;1891933,1892313;1901237,1901848;1926006,1927176;1964659,1965235;1975700,1976268;1981844,1982289;1985301,1985802;2012753,2013208;2031864,2032640;2095193,2095979;2099395,2099901;2100001,2100579;2106309,2107151;2108052,2108437;2110653,2111170;2121637,2122195;2144724,2145184;2192001,2192561;2214554,2215111;2252449,2253052;2262427,2263036;2306785,2307404;2312398,2312907;2336987,2337515;2343231,2343761;2351296,2352518;2355654,2356188;2371766,2372433;2385694,2386267;2387567,2388000;2406914,2407356;2429782,2430345;2449178,2449759;2450237,2450885;2456001,2456808;2504546,2505179;2527072,2527571;2554710,2555533;2560573,2561582;2568001,2568708;2592001,2592469;2595013,2596000;2606444,2607006;2620573,2621141;2670261,2670880;2673086,2673727;2676251,2676932;2680605,2681144;2724001,2724448;2752995,2753566;2754621,2755149;2772001,2772848;2785809,2787033;2793807,2794369;2818909,2820000;2831325,2832000;2857920,2858361;2873785,2874380;2912095,2912563;2917371,2918087;2932291,2932867;2946527,2949077;2960828,2961380;2966100,2967340;2972001,2972657;2981253,2981843;2985116,2985902;3000304,3000843;3005503,3006144;3020748,3021310;3035046,3037259;3047132,3047767;3056001,3056499;3060001,3061052;3068490,3069036;3088001,3088534;3196589,3196918;3197328,3197835;3202925,3203388;3204001,3204674;3221121,3221687;3233718,3234380;3239207,3240000;3242264,3243341;3259440,3260068;3268487,3269036;3280576,3281101;3300850,3301507;3312001,3312464;3355807,3356511;3435929,3436469;3456001,3456598;3474538,3475181;3498212,3498678;3576573,3577203;3619841,3620191;3621482,3621922;3671296,3671780;3686745,3687240;3688643,3689101;3696001,3696434;3754239,3755364;3764057,3764706;3765127,3765730;3767244,3767791;3793215,3793757;3828108,3828633;3861283,3861942;3965358,3965719;3972372,3972792;3996640,3996717;4004296,4004948;4013213,4013797;4021011,4021746;4062667,4063254;4118368,4118842;4121597,4122149;4174954,4175466;4176651,4177257;4209129,4209679;4227745,4228411;4234680,4235245];

% 1, 1200000
info.R1142N.thetapeak = 6.2008;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1059J %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Relatively clean, though many channels occasionally break.

% Age 44

info.R1059J.badchan.broken = {'LDC*', 'RDC7', 'LFC1', 'LIHA1', 'RAT1', 'RAT8', 'RIHA1', 'RIHB1', 'LFB3'};
info.R1059J.badchan.epileptic = {'LSTA8', ... % spiky
    'LAT1', 'LAT2', 'LAT3', 'LAT4'}; % Kahana

info.R1059J.FR1.bsfilt.peak      = [60, 120, 180, 240];
info.R1059J.FR1.bsfilt.halfbandw = [0.5, 0.5, 0.5, 0.5];
info.R1059J.FR1.bsfilt.edge      = 3.1840;

info.R1059J.FR1.session(1).badsegment = [1,1880;26479,26533;53245,54052;61729,62197;70339,71071;78957,79810;81710,81875;82726,82867;89143,89203;89809,89896;102479,102531;125086,125211;140917,141095;143357,143514;149395,149520;149651,149808;150325,150480;190570,190756;200202,200410;209836,210251;212001,212160;219212,219976;234355,235565;255548,255673;284783,285719;291507,292192;343161,343482;348737,349058;438067,438434;469094,469259;486782,487168;498014,498939;502231,502367;560616,562007;586035,587503;593154,594845;598169,599345;650624,651264;691307,693972;728697,731761;734943,736000;774809,775987;776001,776389;796554,797324;842124,842488;843296,844000;844275,844622;855038,855237;882900,883442;957460,957611;988186,988343;989189,990165;991626,992037;1018925,1019025;1034777,1035759;1064372,1067275;1068487,1068864;1097925,1099423;1100148,1100475;1184377,1186173;1197293,1197410;1299302,1303415;1385903,1386996;1387403,1388027;1388506,1388870;1391623,1392301;1430089,1430786;1435110,1435315;1455705,1456744;1458517,1459513;1460028,1460260;1490395,1490807;1500487,1500741;1507317,1507874;1508237,1508553;1509232,1509770;1511486,1511990;1513726,1518125;1522804,1525853;1539239,1539482;1566250,1567627;1568001,1570447;1581355,1582283;1621842,1622649;1647129,1647909;1657417,1658146;1667521,1667614;1689038,1689122;1774441,1774821;1776124,1776504;1779674,1780090;1788218,1788808;1823070,1823159;1864498,1864585;1865586,1865708;1908173,1908235;1916750,1916837;1944119,1944238;1947666,1948085;1953129,1953434;1954893,1955061;1955779,1956202;2043406,2044593;2045728,2045957;2046796,2048000;2059571,2061085;2063110,2063662;2083290,2083990;2086659,2086775;2099908,2100464;2101605,2101764;2102718,2102915;2120710,2120929;2143391,2143943;2184476,2184800;2194694,2195006;2233863,2234850;2237272,2237998;2240001,2242848;2246973,2247616;2273680,2274227;2281758,2282340;2300194,2300668;2301976,2302477;2303185,2303455;2318135,2318582;2328498,2329227;2335258,2335729;2335892,2336894;2339067,2339568;2356904,2361235;2363851,2364626;2367634,2368589;2395865,2396509;2423309,2423622;2463704,2464278;2470309,2471315;2471791,2472165;2474695,2477766;2484315,2485439;2486849,2487544;2488699,2490063;2514140,2514488;2553726,2554759;2559546,2560892;2568793,2571079;2592979,2593568;2600001,2601337;2605492,2606023;2623425,2624000;2682793,2683377;2728181,2728741;2742261,2743899;2744001,2744438;2766274,2768959;2770505,2771175;2789119,2789544;2822669,2823135];
info.R1059J.FR1.session(2).badsegment = [1,1744;3270,3324;6013,6135;27597,27622;41863,43203;43960,43989;44001,45195;48001,56000;63383,65385;66355,66518;67331,67537;89839,90026;102710,103279;108078,108304;109787,110288;119836,121302;161876,162211;167675,169118;171557,172000;173851,174046;184973,185671;242295,243638;244005,248000;254581,255562;270654,271348;279760,280639;281459,282595;337380,337744;362424,363316;364977,365530;372243,373139;419262,420000;438436,438965;469674,470207;614472,614820;654065,654530;673589,674522;679673,679860;706956,707574;752243,752744;785142,785848;793114,793518;814988,815537;817460,818179;839621,840106;887809,890502;994476,995231;996997,997429;1000682,1001627;1046541,1046981;1060001,1060425;1075892,1076589;1129549,1130606;1132561,1134925;1137803,1138344;1139755,1140007;1154166,1160000;1160005,1164000;1164009,1170175;1183581,1184000;1205057,1205643;1225295,1225647;1274847,1275779;1340573,1341312;1362670,1365405;1405146,1405655;1417956,1418296;1469077,1472000;1475129,1476000;1494057,1494731;1546400,1547005;1549343,1550320;1564182,1564893;1608162,1608728;1657738,1663997;1700457,1701038;1731194,1732000;1778037,1778896;1800001,1801352;1804001,1806380;1888360,1889054;1960900,1961074;1967432,1967852;1968001,1971110;2048118,2048909;2167254,2168000;2180590,2181602;2202400,2202824;2225033,2226042;2239730,2240000;2301525,2302046;2312098,2312296;2324457,2324953;2367057,2368000;2392013,2396845;2458287,2458921;2470379,2470816;2473751,2474171;2476529,2477296;2483881,2484418;2504001,2506131;2508807,2509631;2521634,2523425;2564912,2565179;2566033,2566401;2584001,2586086;2606863,2608000;2654138,2654586;2655905,2656653;2710508,2712000;2712009,2716466;2784690,2788000];

info.R1059J.thetapeak = 6.8384;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1020J %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Relatively clean, some reference noise (and different across grids).

% Age 48

info.R1020J.badchan.broken = {'RSTB5', 'RAH7', 'RPH7', 'RSTB8', 'RFB8', 'RAH8', 'RFB4', ... % my broken channels + one of Roemer's
    'RFB1', 'RFB2', 'RPTB1', 'RPTB2', 'RPTB3'}; % Kahana broken channels
info.R1020J.badchan.epileptic = {'RAT6', 'RAT7', 'RAT8', 'RSTA2', 'RSTA3', 'RFA1', 'RFA2', 'RFA3', 'RFA7', ... % Kahana
    'RAT4', 'RAT5', 'RAT*'}; % big deflections + spikes (removing whole RAT grid after talking to Roemer)

info.R1020J.FR1.bsfilt.peak      = [60, 120, 180, 240];  % z-thresh 1
info.R1020J.FR1.bsfilt.halfbandw = [0.5, 0.5, 0.6, 0.5]; % z-thresh 1
info.R1020J.FR1.bsfilt.edge      = 3.1840;

info.R1020J.FR1.session(1).badsegment = [1,2146;20947,21937;46669,47299;85793,86138;98094,98896;148350,149144;151454,152000;264839,265442;268001,268561;272001,272601;301702,302329;308251,309974;447347,448000;572001,572918;578266,580000;598812,600000;630943,632000;641025,645614;668205,668733;687666,688000;800001,800819;887763,888542;891196,892000;948651,950399;982014,983584;996001,998369;1154204,1156000;1218384,1219810;1226164,1227434;1236001,1236424;1280001,1281224;1284001,1284743;1390989,1391356;1541589,1543262;1669151,1669786;1770680,1773028;1840772,1842587;1853546,1854853;1940377,1941165;1945269,1946950;1952001,1953684;2040261,2042127;2108068,2108899;2180001,2180725;2282586,2282716;2296264,2297015;2324001,2326076;2340777,2342783;2574043,2574783;2652423,2653087;2653858,2655576;2918344,2919049;2964001,2966772;3076259,3076840;3167062,3167759;3230511,3232383];

info.R1020J.thetapeak = 6.6047;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% R1045E %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Looks very clean.

% Age 51
info.R1045E.badchan.broken = {'RPHD1', 'RPHD7', 'RPTS7', 'LIFS10', 'LPHD9', ... % large fluctuations and sinusoidal noise
    'R*'}; % odd-number naming convention

info.R1045E.badchan.epileptic = {'LAHD2', 'LAHD3', 'LAHD4', 'LAHD5', ...
    'LMHD1', 'LMHD2', 'LMHD3', 'LMHD4', 'LPHD2', 'LPHD3', 'LPHGD1', 'LPHGD2', 'LPHGD3', ...
    'LPHGD4', 'RAHD1', 'RAHD2', 'RAHD3', 'RPHGD1', 'RPHGD2', 'RPHGD3'}; % all Kahana

% have to remove sample 2603373 onward b/c of file corruption.
info.R1045E.FR1.bsfilt.peak      = [59.9, 119.9, 172.1, 179.8, 239.7]; % z-thresh 2 except for 172.1 (manual)
info.R1045E.FR1.bsfilt.halfbandw = [0.5,  0.5,   0.5,   0.5,   0.5,];
info.R1045E.FR1.bsfilt.edge      = 3.1852;

info.R1045E.FR1.session(1).badsegment = [171293,172850;302034,303412;379153,380800;384913,386115;426457,427358;430641,432517;489846,491741;573928,575086;603397,604300;623377,623925;668820,670096;763042,763823;878373,879120;889330,891384;960993,961455;983374,984663;1053011,1054077;1077440,1079687;1117865,1119832;1197280,1199336;1258278,1258740;1266733,1267088;1271811,1273616;1354645,1355644;1434161,1434641;1438561,1438623;1461991,1463351;1559450,1560847;1581226,1582347;1611315,1612935;1635678,1637096;1658341,1659574;1693987,1694304;1754752,1756251;1777132,1778646;1848757,1848828;1853043,1854083;1955661,1959014;1986013,1986790;2021977,2023548;2121877,2125336;2160321,2161836;2203502,2205522;2241090,2242587;2317681,2318718;2346544,2348846;2355903,2358552;2360828,2362948;2367601,2368912;2411103,2411472;2437117,2438888;2444287,2444916;2464552,2464966;2500943,2502743;2503969,2504623;2573425,2573538;2603373,2916214];

info.R1045E.thetapeak = 6.9667;

end
















% origunclean = {'R1162N', 'R1033D', 'R1156D', 'R1149N', 'R1175N', 'R1154D', 'R1068J', 'R1159P', 'R1080E', 'R1135E', 'R1147P'};








%%%%%% R1068J %%%%%
% Looks funny, but relatively clean. Reference noise in grids RPT and RF go
% haywire by themselves, might need to re-reference individually.
% info.R1068J.FR1.session(1).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};
% info.R1068J.FR1.session(2).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};
% info.R1068J.FR1.session(3).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};



