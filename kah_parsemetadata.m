%% Get age, experiment list, sampling rate, and channel information for all 147 subjects
clear

% get subject identifiers
subjs = extractfield(dir(info.path.data), 'name');
subjs(contains(subjs, '.')) = []; % remove non-folders

% get demographic information of subjects
fid = fopen(info.path.demfile);
deminfo = textscan(fid, '%s %s %f %s %s %s %s %s %s %s %s %s', 'delimiter', ',', 'headerlines', 1);
fclose(fid);

% struct for storing subject information
subjinfo = struct;

for sidx = 1:length(subjs)
    disp(['Processing subject ' num2str(sidx) ' of ' num2str(length(subjs))])
    subjcurr = subjs{sidx}; % current subject identifier
    subjinfo(sidx).subj = subjcurr;
    
    if ~ismember(subjcurr, deminfo{1}) % no demographic info in .csv file
        subjinfo(sidx).age = 0;
        subjinfo(sidx).hand = 'none';
    else
        subjinfo(sidx).age = deminfo{3}(strcmpi(deminfo{1}, subjcurr)); % age is third column in .csv file
        subjinfo(sidx).hand = deminfo{12}{strcmpi(deminfo{1}, subjcurr)}; % handedness is 12th column
    end
    
    % get names of experiments that subject performed
    exps = extractfield(dir([subjpath subjcurr '/experiments/']), 'name');
    exps(contains(exps, '.')) = [];
    subjinfo(sidx).exp = exps;

    % get sampling rate from sources.json
    sourcefile = [subjpath subjcurr '/experiments/' exps{1} '/sessions/0/ephys/current_processed/sources.json'];
    sourceinfo = loadjson(sourcefile);
    field = fieldnames(sourceinfo);
    subjinfo(sidx).fs = sourceinfo.(field{1}).sample_rate;
    
    % get channel information, including labels and electrode type 
    chanfile = [subjpath subjcurr '/localizations/0/montages/0/neuroradiology/current_processed/contacts.json'];   
    chaninfo = loadjson(chanfile);

    channame = fieldnames(chaninfo.(subjcurr).contacts); % channel labels
    chanloc = cell(1, length(channame)); % for storing channel labels and types together
    for chidx = 1:length(channame)        
        chantype = chaninfo.(subjcurr).contacts.(channame{chidx}).type; % grid (G), strip (S), depth (D)
        chanloc{chidx} = [chantype, channame{chidx}]; % store channel type and label together
    end
    subjinfo(sidx).chan = chanloc;
end

%% Find subjects over 18 and with the right task (FR1), sampling rate, and grid coverage
[task, samp, temp, front] = deal(zeros(1,length(subjinfo)));

for sidx = 1:length(subjinfo)
    task(sidx) = any(ismember(subjinfo(sidx).exp, {'FR1'})); % find FR1 task only 

    samp(sidx) = subjinfo(sidx).fs >= 999; % sampling rate threshold
    
    % determine if temporal or frontal grid or strip is present
    for chidx = 1:length(subjinfo(sidx).chan)
        chancurr = subjinfo(sidx).chan{chidx};
        gridorstrip = strcmpi(chancurr(1), 'S') | strcmpi(chancurr(1), 'G');
        if contains(chancurr, 'T') && gridorstrip % temporal electrode present
            temp(sidx) = temp(sidx) + 1;
        elseif contains(chancurr, 'F') && gridorstrip % frontal electrode present
            front(sidx) = front(sidx) + 1;
        end            
    end
end
subjkeep = (task & samp & temp & front) & ([subjinfo.age] >= 18);

% get desired subject identifiers and sort by age
subjname = {subjinfo(subjkeep).subj};
age = [subjinfo(subjkeep).age];

[age, sortind] = sort(age);
subjname = subjname(sortind);

%% Get number of correct trials per subject
accuracy = cell(1, length(subjname));
ntrial = cell(1, length(subjname));

experiment = 'FR1';

for sidx = 1:length(subjname)
    % set the path to the data, and to the header/data/event files of a single subject
    info.path.data   = '/Volumes/voyteklab/common/data2/kahana_ecog_RAMphase1/session_data/experiment_data/protocols/r1/subjects/'; % root directory of the datasets
    subject = subjname{sidx};
    
    nsession = extractfield(dir([info.path.data subject '/experiments/' experiment '/sessions/']), 'name');
    nsession = length(nsession(~contains(nsession, '.')));
    
    accuracy{sidx} = [];
    ntrial{sidx} = [];
    
    for sessidx = 0:nsession - 1
        disp(['Processing subject ' subject ' session ' num2str(sessidx)])
        session    = num2str(sessidx);      % change this to read in different datasets;  session numbers are zero-indexed
        headerfile = [info.path.data subject '/experiments/' experiment '/sessions/' session '/' 'behavioral/current_processed/index.json'];       % see READ_UPENNRAM_HEADER for details
        datadir    = [info.path.data subject '/experiments/' experiment '/sessions/' session '/' 'ephys/current_processed/noreref/'];              % see READ_UPENNRAM_DATA for details
        eventfile  = [info.path.data subject '/experiments/' experiment '/sessions/' session '/' 'behavioral/current_processed/task_events.json']; % see READ_UPENNRAM_EVENT for details

        try
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

            % get indices for encoding trials with no electrical stimulation
            encoding = trl(:, 4) == 1;
            nostim = trl(:, 5) == 0;

            accuracy{sidx} = [accuracy{sidx}, mean(trl(encoding & nostim, 6))];
            ntrial{sidx} = [ntrial{sidx}, sum(encoding & nostim)];
        catch % for one of the desired subjects, one data file could not be unambiguously identified
            accuracy{sidx} = [accuracy{sidx}, 0];
            ntrial{sidx} = [ntrial{sidx}, 0];
        end
    end
end

% Combine number of trials across sessions 
ncorrect = nan(1, length(subjname));
for sidx = 1:length(subjname)
    ncorrect(sidx) = sum(accuracy{sidx} .* ntrial{sidx});
end

ntrial = cellfun(@sum, ntrial);

%% Find subjects with more than 20 correct trials.
nmintrial = 20;
subjkeep = ncorrect > nmintrial;

ntrial = ntrial(subjkeep);
subjname = subjname(subjkeep);
age = age(subjkeep);
ncorrect = ncorrect(subjkeep);
