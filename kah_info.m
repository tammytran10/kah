function info = kah_info
info = struct;

% path to data on shared VoytekLab server
info.path.kah = '/Volumes/voyteklab/common/data2/kahana_ecog_RAMphase1/';
info.path.demfile = [info.path.kah 'Release_Metadata_20160930/RAM_subject_demographics.csv'];

info.release = 'r1';
info.path.data = [info.path.kah 'session_data/experiment_data/protocols/' info.release '/subjects/'];

% selected subjects for aging directional PAC + 1/f slope study
% selected based on output of kah_parsemetadata.m
info.subj = {'R1032D', 'R1128E', 'R1156D', 'R1149N', 'R1034D', 'R1162N', 'R1033D', 'R1167M', 'R1175N', 'R1154D', ...
    'R1068J', 'R1159P', 'R1080E', 'R1142N', 'R1059J', 'R1135E', 'R1147P', 'R1020J', 'R1045E'};

% selected subjects' age, extracted from info.path.demfile
info.age = [19, 26, 27, 28, 29, 30, 31, 33, 34, 36, 39, 42, 43, 43, 44, 47, 47, 48, 51];

% extract sessions from jsoninfo
for isubj = 1:numel(info.subj)
    subjcurr = info.subj{isubj};
    subjpath = [info.path.data subjcurr '/'];

    experiments = extractfield(dir([subjpath 'experiments/']), 'name');
    experiments(contains(experiments, '.')) = [];
    
    for iexp = 1:numel(experiments)
        expcurr = experiments{iexp};
        
        sessions = extractfield(dir([subjpath 'experiments/' expcurr '/sessions/']), 'name');
        sessions(contains(sessions, '.')) = [];
        
        for isess = 1:numel(sessions)
            info.(subjcurr).(expcurr).session(isess).headerfile = [subjpath 'experiments/' expcurr '/sessions/' sessions{isess} '/behavioral/current_processed/index.json'];
            info.(subjcurr).(expcurr).session(isess).datadir = [subjpath 'experiments/' expcurr '/sessions/' sessions{isess} '/ephys/current_processed/noreref/'];
            info.(subjcurr).(expcurr).session(isess).eventfile = [subjpath 'experiments/' expcurr '/sessions/' sessions{isess} '/behavioral/current_processed/task_events.json'];
        end
    end
end
% remove specific ones with problems
info.R1156D.FR1.session(4) = [];

%%%%%%
info.R1032D.FR1.session(1).bsfilt.peak = [];
info.R1020J.FR1.session(1).bsfilt.halfbandw = [];

info.R1020J.FR1.session(1).badchan     = {};
info.R1020J.FR1.session(1).trlartfctflg = []; 

end