function phaseencoding = kah_getphaseencoding(info, subject, testtype, lengththreshtype, lengththresh, statthreshtype, timeoi, episodetype)

% Usage: 
%   phaseencoding = kah_getphaseencoding(info, subject, testtype, lengththreshtype, lengththresh, statthreshtype, timeoi, episodetype);

experiment = 'FR1';

% Get individual theta center frequencies.
load([info.path.processed.hd experiment '_thetabands_-800_1600.mat'], 'bands')
thetacfs = cellfun(@(x) nanmean(mean(x, 2)), bands);

% Load phase-encoding data to detect relevant channel pairs.
load([info.path.processed.hd subject '_' experiment '_phaseencode_' testtype '_-800_1600_nosamp.mat'], 'statA', 'statB', 'statbetween', 'pvalA', 'pvalB', 'pvalbetween', 'chanpairs', 'times', 'trialinfo', 'chans')

% Set episode time length.
switch lengththreshtype
    case 'cycle'
        % Set length threshold for episodes based on number of cycles.
        sampthresh = info.(subject).fs/thetacfs(isubj) * lengththresh;
    case 'time'
        % Set length threshold for episodes based on seconds.
        sampthresh = info.(subject).fs * lengththresh;
end

% To aggregate for the subject.
[phaseencoding.samp, phaseencoding.time, phaseencoding.strength] = deal(cell(size(chanpairs, 1), 1));

for ipair = 1:size(chanpairs, 1)
    % Find time points where phase encoding emerges (phase differences predict remembered/forgotten). 
    switch statthreshtype
        case 'relative'
            % Set strength threshold based on individual channel explained variance.
            statthresh = ((statbetween(ipair,:) .^ 2) > (statA(ipair,:) .^ 2)) & ((statbetween(ipair,:) .^ 2) > (statB(ipair,:) .^ 2));
        case 'pvalue'
            % Set strength threshold based on p-value.
            statthresh = (pvalbetween(ipair,:) < 0.05);
    end
    
    % Get start and end samples of encoding episodes.
    threshepisode = util_getepisode(statthresh);
    
    % Remove episodes that are too short.
    threshepisode = threshepisode(diff(threshepisode, [], 2) > sampthresh, :);
    
    % If any episodes remain, remove ones not in time window of interest.
    if ~isempty(threshepisode)
        % Get beginning and end times of episodes.
        starts = times(threshepisode(:, 1));
        ends = times(threshepisode(:, 2));
        
        % Only keep episodes that start and end only during word presentation.
        threshepisode = threshepisode(starts > timeoi(1) & ends < timeoi(2), :);
    end
    
    % If any episodes remain, get characteristics of episodes of interest.
    if ~isempty(threshepisode)
        % Choose episode of interest.
        switch episodetype
            case 'strongest'
                % Get strongest episode.
                epoi = 0;
                statmax = 0;
                for iep = 1:size(threshepisode, 1)
                    statcurr = mean(statbetween(threshepisode(iep, 1):threshepisode(iep, 2)) .^ 2);
                    if statcurr > statmax
                        epoi = iep;
                        statmax = statcurr;
                    end
                end
            case 'first'
                % Get first episode.
                epoi = 1;
            case 'longest'
                % Get longest episode.
                [~, epoi] = max(diff(threshepisode, [], 2));
            case 'all'
                % Keep all episodes.
                epoi = 1:size(threshepisode, 1);
        end
        
        % Keep only episode(s) of interest.
        threshepisode = threshepisode(epoi, :);
        
        % Get start and end times of episodes. 
        phaseencoding.samp{ipair} = threshepisode;
        phaseencoding.time{ipair} = times(threshepisode);
        
        % Get strength of episodes.
        for iep = 1:length(epoi)        
            phaseencoding.strength{ipair}{iep} = (statbetween(threshepisode(iep, 1):threshepisode(iep, 2)) .^ 2);
        end
        
    else
        phaseencoding.samp{ipair} = [];
        phaseencoding.time{ipair} = [];
        phaseencoding.strength{ipair} = [];
    end
end

% Get percentage of channel pairs and individual channels involved in phase encoding.
episode = cellfun(@(x) ~isempty(x), phaseencoding.samp);
phasechan = chanpairs(episode, :);
phaseencoding.percentpair = mean(episode);
phaseencoding.percentchan = length(unique(phasechan(:)))/length(chans);

% Get the number of episodes per channel.
phaseencoding.nepisode = cellfun(@(x) size(x, 1), phaseencoding.samp);

% Get onset of first episode per channel.
onset = cellfun(@(x) min(min(x)), phaseencoding.time, 'UniformOutput', false);
onset(cellfun(@isempty, onset)) = {nan};
phaseencoding.onset = cell2mat(onset);

% Get combined strength of all episodes per channel.
phaseencoding.totalstrength = cellfun(@(x) mean(cell2mat(x)), phaseencoding.strength);

% Get combined time of all episodes per channel.
phaseencoding.totaltime = cellfun(@(x) sum(diff(x, [], 2)), phaseencoding.time);

