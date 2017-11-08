% Script for loading channel, recording, and FR1 trial number information for Kahana subjects.

clear

% Load constants for Kahana project.
info = kah_info('all');

% Creat struct for storing subject information.
subjinfo = struct;

for isubj = 1:length(info.subj)
    % Get current subject ID.
    subject = info.subj{isubj}; 
    subjinfo(isubj).subject = subject;
    
    % Get subject age.
    subjinfo(isubj).age = info.(subject).age;
    
    % Get whether subject had various channel types (ignoring whether or not the channels are clean). 
    subjinfo(isubj).depth = sum(strcmpi('d', info.(subject).allchan.type));
    subjinfo(isubj).surface = sum(~strcmpi('d', info.(subject).allchan.type));
    
    subjinfo(isubj).temporalsurface = sum(~strcmpi('d', info.(subject).allchan.type) & strcmpi('t', info.(subject).allchan.lobe));
    subjinfo(isubj).frontalsurface = sum(~strcmpi('d', info.(subject).allchan.type) & strcmpi('f', info.(subject).allchan.lobe));

    % Get sampling rate.
    subjinfo(isubj).srate = info.(subject).fs;
    
    % Initialize trial numbers.
    subjinfo(isubj).ncorrect = 0;
    subjinfo(isubj).ntrial = 0;
    
    % Continue if the subject did not perform FR1.
    if ~ismember('FR1', fieldnames(info.(subject)))
        disp([subject ' did not perform FR1. Skipping.'])
        continue
    end
    
    % Get trial numbers for each FR1 session and aggregate.
    for isess = 1:length(info.(subject).FR1.session)
        disp(['Processing subject ' subject ' (' num2str(isubj) '/' num2str(length(info.subj)) '), session (' num2str(isess) '/' num2str(length(info.(subject).FR1.session)) ').'])
        
        headerfile = info.(subject).FR1.session(isess).headerfile;
        datadir    = info.(subject).FR1.session(isess).datadir;
        eventfile  = info.(subject).FR1.session(isess).eventfile;

        cfg = [];              % start with an empty cfg
        cfg.encduration = 1.6; % during encoding, the period, in seconds, after/before pre/poststim periods 
        cfg.recduration = 0.5; % during   recall, the period, in seconds, after/before pre/poststim periods 
        cfg.encprestim  = 0;   % during encoding, the period, in seconds, before word onset that is additionally cut out (t=0 will remain word onset)
        cfg.encpoststim = 0;   % during encoding, the period, in seconds, after cfg.encduration, that is additionally cut out 
        cfg.recprestim  = 0;   % during   recall, the period, in seconds, before word onset that is additionally cut out (t=0 will remain word onset)
        cfg.recpoststim = 0;   % during   recall, the period, in seconds, after cfg.recduration, that is additionally cut out 
            
        try
            cfg.header = read_upennram_header(headerfile);
            cfg.event = read_upennram_event(eventfile);
            trl = rmr_upennram_trialfun(cfg); 
        catch
            disp('Error in getting trial info. Note that the segmentation function does not work on experiment PA. Skipping.')           
            continue
        end
        
        % Get indices for word presentation trials.
        trl = trl(trl(:, 4) == 1, :);
               
        % Get correct and total trial number.
        subjinfo(isubj).ncorrect = subjinfo(isubj).ncorrect + sum(trl(:, 6)); % remembered/forgotten is sixth column of trl structure
        subjinfo(isubj).ntrial = subjinfo(isubj).ntrial + size(trl, 1);
    end
end

save([info.path.src 'FR1_subjinfo.mat'], 'subjinfo')
disp('Done')
