function info = kah_info
info = struct;

% path to data on shared VoytekLab server
info.path.kah = '/Volumes/voyteklab/common/data2/kahana_ecog_RAMphase1/';
info.path.demfile = [info.path.kah 'Release_Metadata_20160930/RAM_subject_demographics.csv'];

% current release of Kahana data
info.release = 'r1';
info.path.data = [info.path.kah 'session_data/experiment_data/protocols/' info.release '/subjects/'];

% selected subjects for aging directional PAC + 1/f slope study
% selected based on output of kah_parsemetadata.m
info.subj = {'R1032D', 'R1128E', 'R1156D', 'R1149N', 'R1034D', 'R1162N', 'R1033D', 'R1167M', 'R1175N', 'R1154D', ...
    'R1068J', 'R1159P', 'R1080E', 'R1142N', 'R1059J', 'R1135E', 'R1147P', 'R1020J', 'R1045E'};

% selected subjects' age, extracted from info.path.demfile
info.age = [19, 26, 27, 28, 29, 30, 31, 33, 34, 36, 39, 42, 43, 43, 44, 47, 47, 48, 51];

% for each subject, extract experiments and sessions and store header,
% data, and event paths
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

%%%%%% R1032D %%%%%
% Mostly depth electrodes. Relatively frequent epileptic events, especially
% in depths. Very buzzy (reference noise?), removed by average referencing.
info.R1032D.FR1.session(1).bsfilt.peak = [60, 120, 180, 240, 300, 360, 382.9, 420, 480, 540, 600.1, 660.1, 689.1, 720, 765.7, 766, 780.1];
info.R1032D.FR1.session(1).bsfilt.halfbandw = repmat(0.5, size(info.R1032D.FR1.session(1).bsfilt.peak));

info.R1032D.FR1.session(1).badchan.broken = {'LFS8', 'LID12', 'LOFD12', 'LOTD12', 'LTS8', 'RID12', 'ROFD12', 'ROTD12', 'RTS8'};
info.R1032D.FR1.session(1).badchan.spiky     = {};
info.R1032D.FR1.session(1).badchan.epileptic     = {};

info.R1032D.FR1.session(1).badsegment = []; 

%%%%%% R1128E %%%%%
% Mostly depth electrodes. Very frequency epileptic events that are present
% in temporal grids.
info.R1128E.FR1.session(1).bsfilt.peak = [60, 119.9, 172.1, 179.9, 239.8, 299.7, 344.2, 359.7, 381.7, 382.3, 419.6, 459.5, 479.5, 482.7];
info.R1128E.FR1.session(1).bsfilt.halfbandw = [0.7000 0.5000 0.5000 0.7000 0.5000 1.2000 0.5000 0.5000 0.5000 0.5000 0.8000 0.5000 0.5000 0.5000];

info.R1128E.FR1.session(1).badchan.broken = {'RTRIGD10', 'RPHCD9'};
info.R1128E.FR1.session(1).badchan.spiky     = {};
info.R1128E.FR1.session(1).badchan.epileptic     = {};

info.R1128E.FR1.session(1).badsegment = []; 
end