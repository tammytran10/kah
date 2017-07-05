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
% >= age 18, sampling rate >= 500 Hz, temporal & frontal grids, FR1 task, >
% 20 correct trials
info.subj = {'R1032D', 'R1006P', 'R1086M', 'R1177M', 'R1128E', 'R1156D', 'R1039M', 'R1149N', 'R1034D', 'R1112M', ...
    'R1162N', 'R1033D', 'R1167M', 'R1102P', 'R1121M', 'R1175N', 'R1060M', 'R1089P', 'R1154D', 'R1003P', ...
    'R1053M', 'R1066P', 'R1068J', 'R1127P', 'R1159P', 'R1080E', 'R1142N', 'R1059J', 'R1067P', 'R1018P', ...
    'R1135E', 'R1147P', 'R1001P', 'R1020J', 'R1002P', 'R1036M', 'R1045E'};
    
% selected subjects' age, extracted from info.path.demfile
info.age = [19, 20, 20, 23, 26, 27, 28, 28, 29, 29, 30, 31, 33, 34, 34, 34, 36, 36, 36, 39, 39, 39, 39, 40, 42, 43, 43, 44, 45, 47, 47, 47, 48, 48, 49, 49, 51];
    
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
% Overall, not too bad.
info.R1032D.FR1.session(1).bsfilt.peak = [60, 120, 180, 240, 300, 360, 382.9, 420, 480, 540, 600.1, 660.1, 689.1, 720, 765.7, 766, 780.1];
info.R1032D.FR1.session(1).bsfilt.halfbandw = repmat(0.5, size(info.R1032D.FR1.session(1).bsfilt.peak));

info.R1032D.FR1.session(1).badchan.broken = {'LFS8', 'LID12', 'LOFD12', 'LOTD12', 'LTS8', 'RID12', 'ROFD12', 'ROTD12', 'RTS8'};
info.R1032D.FR1.session(1).badchan.spiky     = {};
info.R1032D.FR1.session(1).badchan.epileptic     = {};

info.R1032D.FR1.session(1).badsegment = []; 

%%%%%% R1128E %%%%%
% Mostly depth electrodes. Very frequency epileptic events that are present
% in temporal grids. Very unclean subject.

% z-thresh 0.9
info.R1128E.FR1.session(1).bsfilt.peak = [60, 119.9, 172.1, 179.9, 239.8, 299.7, 344.2, 359.7, 381.7, 382.3, 419.6, 459.5, 479.5, 482.7];
info.R1128E.FR1.session(1).bsfilt.halfbandw = [0.7000 0.5000 0.5000 0.7000 0.5000 1.2000 0.5000 0.5000 0.5000 0.5000 0.8000 0.5000 0.5000 0.5000];

info.R1128E.FR1.session(1).badchan.broken = {'RTRIGD10', 'RPHCD9'};
info.R1128E.FR1.session(1).badchan.spiky     = {};
info.R1128E.FR1.session(1).badchan.epileptic     = {};

info.R1128E.FR1.session(1).badsegment = []; 

%%%%%% R1156D %%%%%
% Different grids are differentially affected by reference noise. Will need
% to re-reference some channels separately from one another in order to
% find signal. 

% Bad grids are LAF, LIHG, LPF, RFLG, RFLG, ROFS, RPS, RTS
% OK grids that still need re-ref help are RFG, RIHG, RFPS; RFG1 should be
% thrown out.

%%%%%% R1149N %%%%%
% Lots of reference noise and also antenna channels. Channel TT6 is buzzy. Occasional line noise
% in channels even after filtering out line spectra. Lots of line spectra artifacts.

info.R1149N.FR1.session(1).bsfilt.peak =      [60, 120, 136, 180, 196.5, 211.6, 219.9, 226.7, 240, 241.9, 257, 272, 280, 287.2, 300, 332.5, 340, 347.7, 359.9, 360.9, 362.8, 377.9, 380, 393, 400, 408.1, 420, 423.3, 425.7, 438.4, 440, 460, 471, 480.1, 486.1];
info.R1149N.FR1.session(1).bsfilt.halfbandw = [0.5, 0.6, 0.5, 1.1, 0.5, 0.5, 0.5, 0.5, 1.6, 0.5, 0.5, 0.5, 0.5, 0.5, 1.8, 0.5, 0.6, 0.5, 1.6, 0.5, 0.5, 0.5, 0.5, 0.5, 0.6, 0.5, 1.4, 0.5, 0.5, 0.5, 0.5, 0.9, 0.5, 1.5, 0.5];

info.R1149N.FR1.session(1).badchan.broken = {'ALEX*', 'AST2', 'G1', 'LF2', 'LF3'};

%%%%%% R1034D %%%%%
% Lots of spiky channels, particularly in Session 1. Lots of reference noise in Session 3, reref helps.
info.R1034D.FR1.session(1).badchan.broken = {'LFG1', 'LFG16', 'LFG24', 'LFG32', 'LFG8', 'LIHG16', 'LIHG24', 'LIHG8', 'LOFG12', 'LOFG6', 'LOTD12', 'LTS8', 'RIHG16', 'RIHG8'};
info.R1034D.FR1.session(2).badchan.broken = {'LFG1', 'LFG16', 'LFG24', 'LFG32', 'LFG8', 'LIHG16', 'LIHG24', 'LIHG8', 'LOFG12', 'LOFG6', 'LOTD12', 'LTS8', 'RIHG16', 'RIHG8'};
info.R1034D.FR1.session(3).badchan.broken = {'LFG1', 'LFG16', 'LFG24', 'LFG32', 'LFG8', 'LIHG16', 'LIHG24', 'LIHG8', 'LOFG12', 'LOFG6', 'LOTD12', 'LTS8', 'RIHG16', 'RIHG8'};

%%%%%% R1162N %%%%%
% Very clean, only occassional reference noise across channels.
info.R1162N.FR1.session(1).badchan.broken = {'AST2'};

%%%%%% R1033D %%%%%
% Very unclean, lots of reference noise and wayward channels.
info.R1033D.FR1.session(1).badchan.broken = {'LFS8', 'LOTD12', 'LTS8', 'RATS8', 'RFS8', 'RID12', 'ROTD12', 'RPTS8', 'LTS6', 'LOTD9'};

%%%%%% R1167M %%%%%
% Lots of reference noise, reref helps. Some ambiguous spiky channels remain.
info.R1167M.FR1.session(1).badchan.broken = {'LP7', 'LP8', 'LPT19', 'LPT20', 'LP5'};
info.R1167M.FR1.session(2).badchan.broken = {'LP7', 'LP8', 'LPT19', 'LPT20', 'LP5'};

%%%%%% R1175N %%%%%
% Lots of reference noise, reref helps some, but sinusoidal channels
% remain.
info.R1175N.FR1.session(1).badchan.broken = {'RAT8', 'RPST2', 'RPST3', 'RPST4', 'RPT6'};

%%%%%% R1154D %%%%%
% Very noisy, even after reref. First 230 seconds of Session 3 are
% corrupted.
info.R1154D.FR1.session(1).badchan.broken = {'LOTD*', 'LTCG23'};
info.R1154D.FR1.session(2).badchan.broken = {'LOTD*', 'LTCG23'};
info.R1154D.FR1.session(3).badchan.broken = {'LOTD*', 'LTCG23'};

%%%%%% R1068J %%%%%
% Looks funny, but relatively clean. Reference noise in grids RPT and RF go
% haywire by themselves, might need to re-reference individually.
info.R1068J.FR1.session(1).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};
info.R1068J.FR1.session(2).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};
info.R1068J.FR1.session(3).badchan.broken = {'RAMY7', 'RAMY8', 'RATA1', 'RPTA1'};

%%%%%% R1159P %%%%%
% REALLY REALLY SHITTY AND I CAN'T EVEN RIGHT NOW

%%%%%% R1080E %%%%%
% Lots of noise (spikes) across channels, reref helps. 'L5D10', 'R10D7',
% and 'RSFS4' go wonky in the second session only.
info.R1080E.FR1.session(2).badchan.broken = {'L9D7', 'R10D1', 'R12D7', 'RLFS7', 'L5D10', 'R10D7', 'RSFS4'};
info.R1080E.FR1.session(2).badchan.broken = {'L9D7', 'R10D1', 'R12D7', 'RLFS7', 'L5D10', 'R10D7', 'RSFS4'};

%%%%%% R1142N %%%%%
% Looks very, very clean.
info.R1142N.FR1.session(1).badchan.broken = {'ALT6'};

%%%%%% R1059J %%%%%
% Relatively clean, though many channels occasionally break. Still need to
% track down all of the breaking channels.
info.R1059J.FR1.session(1).badchan.broken = {'LDC*', 'LFB3'};
info.R1059J.FR1.session(2).badchan.broken = {'LDC*', 'LFB3'};

%%%%%% R1135E %%%%%
% Frequent interictal events, and lots of channels show bursts of 20Hz
% activity. RSUPPS grid goes bad in Session 3. Session 3 has lots of
% reference noise.
info.R1135E.FR1.session(1).badchan.broken = {'LHCD9', 'RPHCD1', 'RPHCD9', 'RSUPPS*'};
info.R1135E.FR1.session(2).badchan.broken = {'LHCD9', 'RPHCD1', 'RPHCD9', 'RSUPPS*'};
info.R1135E.FR1.session(3).badchan.broken = {'LHCD9', 'RPHCD1', 'RPHCD9', 'RSUPPS*'};
info.R1135E.FR1.session(4).badchan.broken = {'LHCD9', 'RPHCD1', 'RPHCD9', 'RSUPPS*'};

%%%%%% R1147P %%%%%
% Dominated by reference noise, and different across grids. In session 2,
% LGR grid looks clean.

%%%%%% R1020J %%%%%
% Relatively clean, some reference noise (and different across grids).
info.R1020J.FR1.session(1).badchan.broken = {'RSTB5', 'RAH7', 'RPH7'};

%%%%%% R1045E %%%%%
% Looks very clean.
info.R1045E.FR1.session(1).badchan.broken = {'RPHD1', 'RPHD7', 'RPTS7', 'LIFS10', 'LPHD9'};

end