clear; clc

info = kah_info;

%%
clearvars('-except', 'info')

experiment = 'FR1';

% For storing encoding pairs and encoding episodes. Second dimension is temporal-temporal, temporal-frontal,
% and frontal-frontal.
nregion = 3;
[npair, nencode] = deal(nan(length(info.subj), nregion));
[encodingtime, encodingstrength, pac] = deal(cell(length(info.subj), nregion));

% Get individual theta center frequencies.
load([info.path.processed experiment '_thetabands_-800_1600.mat'], 'bands')
thetacfs = cellfun(@(x) nanmean(mean(x, 2)), bands);

% Set number of permutations for PAC.
nperm = 100;

for isubj = 1:length(info.subj)
    disp([num2str(isubj) ' ' info.subj{isubj}])
    subject = info.subj{isubj};
    
    % Load phase-encoding data to detect relevant channel pairs.
    load([info.path.processed subject '_' experiment '_phaseencode_-800_1600.mat'], 'rhoA', 'rhoB', 'rhobetween', 'pvalA', 'pvalB', 'pvalbetween', 'chanpairs', 'times', 'trialinfo', 'chans')
    
    % Load subject theta phase data.
    load([info.path.processed '-1000_2750/' subject '_' experiment '_thetaphase.mat'], 'thetaphase')

    timewin = [-800, 1600];
    cfg = [];
    cfg.toilim = timewin ./ 1000;
    cfg.toilim(2) = cfg.toilim(2) - 1/thetaphase.fsample; % so that sample number is exactly srate or srate/2, etc.
    data = ft_redefinetrial(cfg, thetaphase);
   
    phase = nan(length(chans), length(times), size(trialinfo, 1));
    for itrial = 1:size(trialinfo, 1)
        phase(:,:,itrial) = data.trial{itrial};
    end
    clear data
    
    % Load all permutations of between-channel PAC and calculate average using running sum.
    pacbetween = zeros(size(chanpairs, 1), size(rhobetween, 2), 2, 2);
    for iperm = 1:nperm
        if mod(iperm, 10) == 0, disp(['Loading permutation ' num2str(iperm)]); end
        input = load([info.path.processed subject '_' experiment '_pacbetweenresamp_-800_1600_' num2str(iperm) '.mat'], 'pacbetween');
        pacbetween = pacbetween + input.pacbetween;
    end
    pacbetween = pacbetween ./ nperm;

    % Remove pairs of channels where one or more channels does not have theta.
    nothetachans = any(isnan(bands{isubj}), 2);
    nothetapairs = any(nothetachans(chanpairs), 2);
    rhoA(nothetapairs, :) = [];
    rhoB(nothetapairs, :) = [];
    rhobetween(nothetapairs, :) = [];
    chanpairs(nothetapairs, :) = [];
    
    % Get region of each electrode.
    nchan = length(chans);
    regions = cell(nchan, 1);
    for ichan = 1:nchan
        regions(ichan) = info.(subject).allchan.lobe(ismember(info.(subject).allchan.label, chans{ichan}));
    end
    temporal = strcmpi('t', regions);
    frontal = strcmpi('f', regions);

    % Get pairs where at least one channel is temporal or frontal.
    ttpairs = all(temporal(chanpairs), 2);
    ffpairs = all(frontal(chanpairs), 2);
    tfpairs = all(temporal(chanpairs) + frontal(chanpairs), 2) & ~ttpairs & ~ffpairs;
    
    pairsoi = [ttpairs, tfpairs, ffpairs];
    
%     % Set length threshold for episodes based on number of cycles.
%     freqthresh = thetacfs(isubj);
%     cyclethresh = 0.5;
%     sampthresh = info.(subject).fs/freqthresh * cyclethresh;
    
    % Set length threshold for episodes based on time.
    timethresh = 0.05; % seconds
    sampthresh = info.(subject).fs * timethresh;
    
    % To aggregate for the subject.
    [encodingtimecurr, encodingstrengthcurr, paccurr] = deal(cell(size(chanpairs, 1), 1));
    
    for ipair = 1:size(chanpairs, 1)
        % Set strength threshold based on individual channel explained variance.
%         rhothresh = ((rhobetween(ipair,:) .^ 2) > (rhoA(ipair,:) .^ 2)) & ((rhobetween(ipair,:) .^ 2) > (rhoB(ipair,:) .^ 2));
        
        % Set strength threshold based on p-value.
        rhothresh = (pvalbetween(ipair,:) < 0.05);
        
        % Get start and end samples of encoding episodes.
        threshepisode = util_getepisode(rhothresh);
        
        % Remove episodes that are too short.
        threshepisode = threshepisode(diff(threshepisode, [], 2) > sampthresh, :);
        
        % If any episodes are detected, remove ones not in time window of interest.
        if ~isempty(threshepisode)
            % Get beginning and end times of episodes.
            starts = times(threshepisode(:, 1));
            ends = times(threshepisode(:, 2));
            
            % Only keep episodes that start and end only during word presentation.
            timewin = [0, 1]; % seconds
            threshepisode = threshepisode(starts > timewin(1) & ends < timewin(2), :);
        end
        
        % If episodes remain, keep only the episode of interest.
        if ~isempty(threshepisode)            
%             % Get strongest episode.
%             epmax = 0;
%             rhomax = 0;
%             for iep = 1:size(threshepisode, 1)
%                 rhocurr = mean(rhobetween(threshepisode(iep, 1):threshepisode(iep, 2)) .^ 2);
%                 if rhocurr > rhomax
%                     epmax = iep;
%                     rhomax = rhocurr;
%                 end
%             end

            % Get first episode.
            epmax = 1;
            
%             % Get longest episode.
%             [~, epmax] = max(diff(threshepisode, [], 2));
            
            % Keep only episode of interest.
            encodingtimecurr{ipair} = times(threshepisode(epmax, :));
            encodingstrengthcurr{ipair} = mean(rhobetween(threshepisode(epmax, 1):threshepisode(epmax, 2)) .^ 2);         
        
%             % Calculate average PAC during entire encoding episode.
%             paccurr{ipair} = squeeze(mean(mean(pacbetween(ipair, threshepisode(epmax, 1):threshepisode(epmax, 2), :, :), 2), 3));
            
            % Calculate average PAC during first part of encoding episode.
            paccurr{ipair} = squeeze(mean(mean(pacbetween(ipair, threshepisode(epmax, 1):threshepisode(epmax, 1) + sampthresh - 1, :, :), 2), 3));
        else
            encodingtimecurr{ipair} = [];
            encodingstrengthcurr{ipair} = [];
            paccurr{ipair} = [];
        end
    end
    
    % Aggregate results per region.
    for iregion = 1:nregion
        regioncurr = pairsoi(:, iregion);
        
        npair(isubj, iregion) = sum(regioncurr);
        nencode(isubj, iregion) = sum(cellfun(@length, encodingtimecurr(regioncurr)) > 0);
        encodingtime{isubj, iregion} = encodingtimecurr(regioncurr);
        encodingstrength{isubj, iregion} = encodingstrengthcurr(regioncurr);
        pac{isubj, iregion} = paccurr(regioncurr);
    end
end

% Load accuracy.
load('fr1_subjinfo.mat')
subjkeep = ismember({subjinfo.subj}, info.subj);
acc = [subjinfo(subjkeep).ncorrect] ./ [subjinfo(subjkeep).ntrial];
acc = acc(:);

% Get proportion of encoding trials.
pencode = nencode ./ npair;

% Start time, length, and strength of episodes.
[onset, time, strength] = deal(nan(length(info.subj), nregion));
coupling = nan(length(info.subj), nregion, 2);
for isubj = 1:length(info.subj)
    for iregion = 1:nregion
        onset(isubj, iregion) = mean(cell2mat(cellfun(@min, encodingtime{isubj, iregion}, 'UniformOutput', false)));
        time(isubj, iregion) = mean(cell2mat(cellfun(@(x) diff(x, [], 2), encodingtime{isubj, iregion}, 'UniformOutput', false)));
        strength(isubj, iregion) = mean(cell2mat(encodingstrength{isubj, iregion}));
        
        couplingcurr = reshape(cell2mat(pac{isubj, iregion}), 2, []);
        for icorrect = 1:2
            coupling(isubj, iregion, icorrect) = mean(couplingcurr(icorrect, :));
        end
    end
end

%%
% Set subjects of interest.
subjcurr = all(nencode >= 3, 2); % 1:20; % [1:2, 5:8, 10:15, 17:20];
disp(sum(subjcurr))

%%
p = ranksum(pencode(subjcurr, 1), pencode(subjcurr, 2))
p = ranksum(pencode(subjcurr, 1), pencode(subjcurr, 3))
p = ranksum(pencode(subjcurr, 2), pencode(subjcurr, 3))

[rho, p] = corr(info.age(subjcurr), pencode(subjcurr, 1), 'type', 'Spearman')
[rho, p] = corr(info.age(subjcurr), pencode(subjcurr, 2), 'type', 'Spearman')
[rho, p] = corr(info.age(subjcurr), pencode(subjcurr, 3), 'type', 'Spearman')

[rho, p] = corr(acc(subjcurr), pencode(subjcurr, 1), 'type', 'Spearman')
[rho, p] = corr(acc(subjcurr), pencode(subjcurr, 2), 'type', 'Spearman')
[rho, p] = corr(acc(subjcurr), pencode(subjcurr, 3), 'type', 'Spearman')

%%
p = ranksum(onset(subjcurr, 1), onset(subjcurr, 2))
p = ranksum(onset(subjcurr, 1), onset(subjcurr, 3))
p = ranksum(onset(subjcurr, 2), onset(subjcurr, 3))

[rho, p] = corr(info.age(subjcurr), onset(subjcurr, 1), 'type', 'Spearman')
[rho, p] = corr(info.age(subjcurr), onset(subjcurr, 2), 'type', 'Spearman')
[rho, p] = corr(info.age(subjcurr), onset(subjcurr, 3), 'type', 'Spearman')

[rho, p] = corr(acc(subjcurr), onset(subjcurr, 1), 'type', 'Spearman')
[rho, p] = corr(acc(subjcurr), onset(subjcurr, 2), 'type', 'Spearman')
[rho, p] = corr(acc(subjcurr), onset(subjcurr, 3), 'type', 'Spearman')

%%
p = ranksum(time(subjcurr, 1), time(subjcurr, 2))
p = ranksum(time(subjcurr, 1), time(subjcurr, 3))
p = ranksum(time(subjcurr, 2), time(subjcurr, 3))

[rho, p] = corr(info.age(subjcurr), time(subjcurr, 1), 'type', 'Spearman')
[rho, p] = corr(info.age(subjcurr), time(subjcurr, 2), 'type', 'Spearman')
[rho, p] = corr(info.age(subjcurr), time(subjcurr, 3), 'type', 'Spearman')

[rho, p] = corr(acc(subjcurr), time(subjcurr, 1), 'type', 'Spearman')
[rho, p] = corr(acc(subjcurr), time(subjcurr, 2), 'type', 'Spearman')
[rho, p] = corr(acc(subjcurr), time(subjcurr, 3), 'type', 'Spearman')

%%
p = ranksum(strength(subjcurr, 1), strength(subjcurr, 2))
p = ranksum(strength(subjcurr, 1), strength(subjcurr, 3))
p = ranksum(strength(subjcurr, 2), strength(subjcurr, 3))

[rho, p] = corr(info.age(subjcurr), strength(subjcurr, 1), 'type', 'Spearman')
[rho, p] = corr(info.age(subjcurr), strength(subjcurr, 2), 'type', 'Spearman')
[rho, p] = corr(info.age(subjcurr), strength(subjcurr, 3), 'type', 'Spearman')

[rho, p] = corr(acc(subjcurr), strength(subjcurr, 1), 'type', 'Spearman')
[rho, p] = corr(acc(subjcurr), strength(subjcurr, 2), 'type', 'Spearman')
[rho, p] = corr(acc(subjcurr), strength(subjcurr, 3), 'type', 'Spearman')

%%
ranksum(coupling(subjcurr, 1, 1), coupling(subjcurr, 1, 2))
ranksum(coupling(subjcurr, 2, 1), coupling(subjcurr, 2, 2))
ranksum(coupling(subjcurr, 3, 1), coupling(subjcurr, 3, 2))

[rho, p] = corr(info.age(subjcurr), coupling(subjcurr, 1, 1), 'type', 'Spearman')
[rho, p] = corr(info.age(subjcurr), coupling(subjcurr, 2, 1), 'type', 'Spearman')
[rho, p] = corr(info.age(subjcurr), coupling(subjcurr, 3, 1), 'type', 'Spearman')

[rho, p] = corr(acc(subjcurr), coupling(subjcurr, 1, 1), 'type', 'Spearman')
[rho, p] = corr(acc(subjcurr), coupling(subjcurr, 2, 1), 'type', 'Spearman')
[rho, p] = corr(acc(subjcurr), coupling(subjcurr, 3, 1), 'type', 'Spearman')

%%
[~, sortind] = sort(info.age(subjcurr));
subjkeep = find(subjcurr);
young = subjkeep(sortind(1:floor(sum(subjcurr/2))));
old = subjkeep(sortind((floor(sum(subjcurr/2)) + 1):end));

ranksum(pencode(young, 1), pencode(old, 1))
ranksum(pencode(young, 2), pencode(old, 2))
ranksum(pencode(young, 3), pencode(old, 3))

ranksum(onset(young, 1), onset(old, 1))
ranksum(onset(young, 2), onset(old, 2))
ranksum(onset(young, 3), onset(old, 3))

ranksum(time(young, 1), time(old, 1))
ranksum(time(young, 2), time(old, 2))
ranksum(time(young, 3), time(old, 3))

ranksum(strength(young, 1), strength(old, 1))
ranksum(strength(young, 2), strength(old, 2))
ranksum(strength(young, 3), strength(old, 3))

ranksum(coupling(young, 1, 1), coupling(old, 1, 1))
ranksum(coupling(young, 2, 1), coupling(old, 2, 1))
ranksum(coupling(young, 3, 1), coupling(old, 3, 1))

%%
[~, sortind] = sort(info.age);
subjkeep = 1:20;
young = subjkeep(sortind(1:10));
old = subjkeep(sortind(11:end));

ttest2(acc(young), acc(old))

%%
figure; hist(cell2mat(starttimes(pairsoi)))


%%
for iep = 1:size(threshepisode, 1)
    idx = threshepisode(iep, 1):threshepisode(iep, 2);
    plot(times(idx), rhobetween(ipair, idx), 'kx')
end
%%
iep = 1;
idx = threshepisode(iep, 1):threshepisode(iep, 2);
figure; plot(datA(idx,1) - datB(idx,1), 'kx')
hold on; plot(datA(idx, 1))
hold on; plot(datB(idx, 1))

% ipair = 1;
% figure; hold on;
% plot(times, rhoA(ipair,:))
% plot(times, rhoB(ipair,:))
% plot(times, rhobetween(ipair,:))

[rhomean, pvalmean, ntrial, ncorrect] = deal(nan(length(info.subj), 1));

for isubj = 1:length(info.subj)
    disp([num2str(isubj) ' ' info.subj{isubj}])
    subject = info.subj{isubj};
    
    % Load phase-encoding data to detect relevant channel pairs.
    load([info.path.processed subject '_' experiment '_phaseencode_-800_1600.mat'], 'rhobetween', 'pvalbetween', 'trialinfo')
    rhomean(isubj) = median(rhobetween(:));
    pvalmean(isubj) = median(pvalbetween(:));
    ntrial(isubj) = size(trialinfo, 1);
    ncorrect(isubj) = sum(trialinfo(:, 3));
end

clear; clc

info = kah_info;

%%
clearvars('-except', 'info')

isubj = 1;
subject = info.subj{isubj};

experiment = 'FR1';

timewin = [-800, 1600];

loadphase = 0;

loadhfa = 0;

loadpac = 0;
nperm = 100;

%%%%%%%%%%%% MOVING PARTS %%%%%%%%%%%%
% Remove or don't remove channels without theta.
thetathresh = 0;

% Set length threshold of encoding episodes based on cycle fraction ('cycle') or seconds ('time').
lengththreshtype = 'time';
lengththresh = 0.1;

% Set strength threshold based on p-values ('pvalue') or in comparison to single channels ('relative').
statthresh = 'pvalue';

% Set when to look for episodes. Episodes must start and stop within this window.
timeoi = [0, 1]; % seconds

% Set which episode(s) to analyze, 'first', 'strongest', 'longest', or 'all' within timeoi.
episodetype = 'first';

% Average PAC within the entire episode ('all') or for only the length threshold ('lengththresh').
pactype = 'lengththresh';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Get individual theta center frequencies.
load([info.path.processed experiment '_thetabands_-800_1600.mat'], 'bands')
thetacfs = cellfun(@(x) nanmean(mean(x, 2)), bands);

% Load phase-encoding data to detect relevant channel pairs.
load([info.path.processed subject '_' experiment '_phaseencode_-800_1600.mat'], 'rhoA', 'rhoB', 'rhobetween', 'pvalA', 'pvalB', 'pvalbetween', 'chanpairs', 'times', 'trialinfo', 'chans')

% Load subject theta phase data, if necessary.
if loadphase
    load([info.path.processed '-1000_2750/' subject '_' experiment '_thetaphase.mat'], 'thetaphase')

    cfg = [];
    cfg.toilim = timewin ./ 1000;
    cfg.toilim(2) = cfg.toilim(2) - 1/thetaphase.fsample; % so that sample number is exactly srate or srate/2, etc.
    thetaphase = ft_redefinetrial(cfg, thetaphase);

    phase = nan(length(chans), length(times), size(trialinfo, 1));
    for itrial = 1:size(trialinfo, 1)
        phase(:,:,itrial) = thetaphase.trial{itrial};
    end
    clear thetaphase
end

% Load HFA amplitude, if necessary.
if loadhfa
    load([info.path.processed subject '_' experiment '_hfa_-800_1600.mat'], 'hfa')
end

% Load between-channel PAC, if necessary.
if loadpac
    save([info.path.processed subject '_' experiment '_pacbetweenresamp_-800_1600_mean.mat'], 'pacbetween')
end

% Remove pairs of channels where one or more channels does not have theta, if necessary.
if thetathresh 
    nothetachans = any(isnan(bands{isubj}), 2);
    nothetapairs = any(nothetachans(chanpairs), 2);
    rhoA(nothetapairs, :) = [];
    rhoB(nothetapairs, :) = [];
    rhobetween(nothetapairs, :) = [];
    chanpairs(nothetapairs, :) = [];
end

% Get region of each electrode.
nchan = length(chans);
regions = cell(nchan, 1);
for ichan = 1:nchan
    regions(ichan) = info.(subject).allchan.lobe(ismember(info.(subject).allchan.label, chans{ichan}));
end
temporal = strcmpi('t', regions);
frontal = strcmpi('f', regions);

% Get pairs where at least one channel is temporal or frontal.
ttpairs = all(temporal(chanpairs), 2);
ffpairs = all(frontal(chanpairs), 2);
tfpairs = all(temporal(chanpairs) + frontal(chanpairs), 2) & ~ttpairs & ~ffpairs;
pairsoi = [ttpairs, tfpairs, ffpairs];

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
[encodingtimesubj, encodingstrengthsubj, pacsubj] = deal(cell(size(chanpairs, 1), 1));

for ipair = 1:size(chanpairs, 1)
    % Find time points where phase encoding emerges (phase differences predict remembered/forgotten). 
    switch statthresh
        case 'relative'
            % Set strength threshold based on individual channel explained variance.
            rhothresh = ((rhobetween(ipair,:) .^ 2) > (rhoA(ipair,:) .^ 2)) & ((rhobetween(ipair,:) .^ 2) > (rhoB(ipair,:) .^ 2));
        case 'pvalue'
            % Set strength threshold based on p-value.
            rhothresh = (pvalbetween(ipair,:) < 0.05);
    end
    
    % Get start and end samples of encoding episodes.
    threshepisode = util_getepisode(rhothresh);
    
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
                rhomax = 0;
                for iep = 1:size(threshepisode, 1)
                    rhocurr = mean(rhobetween(threshepisode(iep, 1):threshepisode(iep, 2)) .^ 2);
                    if rhocurr > rhomax
                        epoi = iep;
                        rhomax = rhocurr;
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
        encodingtimesubj{ipair} = times(threshepisode);
        
        % Get strength of episodes.
        for iep = 1:length(epoi)        
            encodingstrengthsubj{ipair}{iep} = rhobetween(threshepisode(iep, 1):threshepisode(iep, 2)) .^ 2;
        end
        
        % Get PAC of episodes.
        if loadpac
            for iep = 1:length(epoi)
                % Choose time window over which to extract PAC.
                switch pactype
                    case 'all'
                        % Extract PAC during entire encoding episode.
                        pacsubj{ipair}{iep} = pacbetween(ipair, threshepisode(iep, 1):threshepisode(iep, 2), :, :);
                    case 'lengththresh'
                        % Extract PAC during first part of encoding episode.
                        pacsubj{ipair}{iep} = pacbetween(ipair, threshepisode(iep, 1):threshepisode(iep, 1) + sampthresh - 1, :, :);
                end
            end
        end
    else
        encodingtimesubj{ipair} = [];
        encodingstrengthsubj{ipair} = [];
        pacsubj{ipair} = [];
    end
end
encodingtimesubj = cellfun(@(x) sum(diff(x, [], 2)), encodingtimesubj);
encodingtimesubj(encodingtimesubj == 0) = nan;

encodingstrengthsubj = cellfun(@(x) mean(cell2mat(x)), encodingstrengthsubj);

%%
encodingpair = cellfun(@(x) ~isempty(x), encodingtimesubj);
encodingchan = chanpairs(encodingpair, :);
encodingchan = unique(encodingchan(:));

nconnect = nan(length(encodingchan), 1);
for ichan = 1:length(encodingchan)
    chancurr = encodingchan(ichan);
    nconnect(ichan) = sum(reshape(chanpairs(encodingpair, :), [], 1) == chancurr);
end
figure; hist(nconnect)
length(encodingchan)

%%
length(chans(~nothetachans))

%%
% Aggregate results per region.
for iregion = 1:nregion
    regioncurr = pairsoi(:, iregion);
    
    npair(iregion) = sum(regioncurr);
    nencode(iregion) = sum(cellfun(@length, encodingtimesubj(regioncurr)) > 0);
    encodingtime{iregion} = encodingtimesubj(regioncurr);
    encodingstrength{iregion} = encodingstrengthsubj(regioncurr);
    pac{iregion} = pacsubj(regioncurr);
end

%%
for isubj = 1:length(info.subj)
    disp([num2str(isubj) ' ' info.subj{isubj}])
    subject = info.subj{isubj};
    
    load([info.path.processed subject '_' experiment '_phaseencode_-800_1600.mat'])
    
    % Set length threshold for episodes based on time.
    timethresh = 0.05; % seconds
    sampthresh = info.(subject).fs * timethresh;
    
    for ipair = 1:size(chanpairs, 1)
        figure(1); clf; hold on
        plot(times, rhobetween(ipair, :))
        
        % Set strength threshold based on p-value.
        rhothresh = logical(pvalbetween(ipair,:) < 0.05);
        
        % Get start and end samples of encoding episodes.
        threshepisode = util_getepisode(rhothresh);
        
        % Remove episodes that are too short.
        threshepisode = threshepisode(diff(threshepisode, [], 2) > sampthresh, :);
        
        for iep = 1:size(threshepisode, 1)
            plot(times(threshepisode(iep, 1):threshepisode(iep, 2)), rhobetween(ipair, threshepisode(iep, 1):threshepisode(iep, 2)), 'kx')
        end
        
        paircurr = chanpairs(ipair, :);
        
        titlecurr = [];
        for ichan = 1:2
            titlecurr = [titlecurr, chans(chanpairs(ipair, ichan))];
            chancurr = 'NA';
            if temporal(paircurr(:, ichan))
                chancurr = 'T';
            elseif frontal(paircurr(:, ichan))
                chancurr = 'F';
            end
            titlecurr = [titlecurr, chancurr];
            
            chanind = ismember(info.(subject).allchan.label, chans(chanpairs(ipair, ichan)));
            titlecurr = [titlecurr, info.(subject).allchan.ind.region{chanind}];
        end
        
        title(strjoin(string(titlecurr)))
        drawnow
        
        figure(2); clf; hold on
        eleccurr = ismember(info.(subject).allchan.label, chans(chanpairs(ipair, :)));
        elec = [];
        elec.label = info.(subject).allchan.label(eleccurr);
        elec.elecpos = info.(subject).allchan.ind_0x2E_dural.xyz(eleccurr,:);
        elec.unit = 'mm';
        
        ft_plot_mesh(info.(subject).mesh, 'facecolor', [0.781 0.762 0.664], 'EdgeColor', 'none')
        view([-90 25])
        lighting gouraud
        material shiny
        camlight
        
        % plot electrodes
        hs = ft_plot_sens(elec, 'style', 'ko', 'label', 'on');
        set(hs, 'MarkerFaceColor', 'k', 'MarkerSize', 8);
        return
        x = input(num2str(ipair));
    end
end
