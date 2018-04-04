clear

info = kah_info;

%% 
% Extract and save aspects of phase encoding channel pairs.
clearvars('-except', 'info')

testtype = 'corrcl';
thetalabel = 'cf';

phaseencoding = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    % Extract episodes.
    encoding = kah_getphaseencoding(info, info.subj{isubj}, testtype, 'time', 0.04, 'pvalue', [0, 1.5], 'all', thetalabel);
    
    % Save episode characteristics.
    phaseencoding{isubj}.nepisode = encoding.nepisode; % number of episodes in the time window
    phaseencoding{isubj}.onset = encoding.onset; % first time point where there is significant phase encoding
    phaseencoding{isubj}.strength = encoding.totalstrength; % average test statistic across all time points for which there is significant phase encoding
    phaseencoding{isubj}.time = encoding.totaltime; % total time in the time window for which there is significant phase encoding
end

save([info.path.processed.hd 'FR1_phase_' testtype '_0_1600_' thetalabel '.mat'], 'phaseencoding')
