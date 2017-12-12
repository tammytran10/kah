clear

info = kah_info;

%% SINGLE-TRIAL, SINGLE-CHANNEL
clearvars('-except', 'info')

% Load slopes.
load([info.path.processed.hd 'FR1_slopes_-800_0.mat'], 'slopes');
preslope = slopes;

load([info.path.processed.hd 'FR1_slopes_300_1300.mat'], 'slopes');
postslope = slopes;

clear slopes

% Load thetas amplitudes.
load([info.path.processed.hd 'FR1_thetabands_-800_0_trials_padded.mat'], 'amplitudes');
pretheta = amplitudes;

load([info.path.processed.hd 'FR1_thetabands_0_1600_trials.mat'], 'amplitudes');
posttheta = amplitudes;

clear amplitudes

% Load HFA amplitudes.
load([info.path.processed.hd 'FR1_hfa.mat'], 'hfabaseline');
load([info.path.processed.hd 'FR1_hfa.mat'], 'hfaencoding');

% Load within-channel tsPAC.
load([info.path.processed.hd 'FR1_tspac_within_0_1600.mat']);

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'chanregions', 'chans', 'encoding')

% Set names of metrics.
header = {'subject', 'age', 'channel', 'region', 'trial', 'encoding', 'preslope', 'postslope', 'pretheta', 'posttheta', 'prehfa', 'posthfa', 'rawtspac', 'normtspac', 'pvaltspac'};

% Build CSV.
csv = [];

for isubj = 1:length(info.subj)
    disp(isubj)
    nchan = length(chans{isubj});
    ntrial = length(encoding{isubj});
    
    % Pre-allocate per subject for speed.
    subjcurr = cell(nchan * ntrial, length(header));
    linenum = 1; % next line to fill in for the current subject.
    
    for ipair = 1:nchan
        for itrial = 1:ntrial
            linecurr = {info.subj{isubj}, info.age(isubj), ipair, chanregions{isubj}{ipair}, itrial, encoding{isubj}(itrial), ...
                preslope{isubj}(ipair, itrial), postslope{isubj}(ipair, itrial), pretheta{isubj}(ipair, itrial), posttheta{isubj}(ipair, itrial), ...
                hfabaseline{isubj}(ipair, itrial), hfaencoding{isubj}(ipair, itrial), tspac{isubj}.raw(ipair, itrial), tspac{isubj}.norm(ipair, itrial), tspac{isubj}.pvaltrial(ipair, itrial)};
            linecurr = cellfun(@string, linecurr, 'UniformOutput', false); % needs to be strings
            subjcurr(linenum, :) = linecurr;
            linenum = linenum + 1;
        end
    end
    
    % Append subject.
    csv = [csv; subjcurr];
    clear subjcurr
end

% Save.
util_cell2csv([info.path.csv 'kah_singletrial_singlechannel.csv'], csv, header)

%% SINGLE-CHANNEL
clearvars('-except', 'info')

% Load thetas p-values..
load([info.path.processed.hd 'FR1_thetabands_-800_0_trials_padded.mat'], 'thetapvals');
prethetapvals = thetapvals;

load([info.path.processed.hd 'FR1_thetabands_0_1600_trials.mat'], 'thetapvals');
postthetapvals = thetapvals;

clear thetapvals

% Load HFA p-values.
load([info.path.processed.hd 'FR1_hfa.mat'], 'hfapval');

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'chanregions', 'chans')

% Set names of metrics.
header = {'subject', 'age', 'channel', 'region', 'pvalpretheta', 'pvalposttheta', 'pvalhfa'};

% Build CSV.
csv = [];

for isubj = 1:length(info.subj)
    disp(isubj)
    nchan = length(chans{isubj});
    
    % Pre-allocate per subject for speed.
    subjcurr = cell(nchan, length(header));
    
    for ipair = 1:nchan
        linecurr = {info.subj{isubj}, info.age(isubj), ipair, chanregions{isubj}{ipair}, ... 
            prethetapvals{isubj}(ipair), postthetapvals{isubj}(ipair), hfapval{isubj}(ipair)};
        linecurr = cellfun(@string, linecurr, 'UniformOutput', false); % needs to be strings
        subjcurr(ipair, :) = linecurr;
    end
    
    % Append subject.
    csv = [csv; subjcurr];
    clear subjcurr
end

% Save.
util_cell2csv([info.path.csv 'kah_singlechannel.csv'], csv, header)

%% MULTI-CHANNEL
clearvars('-except', 'info')

% Load pair p-values for tsPAC.
load([info.path.processed.hd 'FR1_tspac_between_0_1600.mat'], 'tspac');

% Load erPAC.
load([info.path.processed.hd 'FR1_erpac_between.mat'], 'erpac');

% Load phase-encoding.
load([info.path.processed.hd 'FR1_phaseencoding_0_1600.mat'], 'phaseencoding');

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'pairs', 'pairregions')

% Set names of metrics.
header = {'subject', 'age', 'channelA', 'channelB', 'regionA', 'regionB', 'pvaltspacAB', 'pvaltspacBA', ...
    'erpacAB_remembered_stim', 'erpacAB_forgotten_stim', 'erpacAB_remembered_phase', 'erpacAB_forgotten_phase', ...
    'erpacBA_remembered_stim', 'erpacBA_forgotten_stim', 'erpacBA_remembered_phase', 'erpacBA_forgotten_phase', ...
    'encodingonset', 'encodinglength', 'encodingstrength', 'encodingepisodes'};

% Build CSV.
csv = [];

for isubj = 1:length(info.subj)
    disp(isubj)
    npair = size(pairs{isubj}, 1);
    
    % Pre-allocate per subject for speed.
    subjcurr = cell(npair, length(header));
    
    for ipair = 1:npair
        linecurr = {info.subj{isubj}, info.age(isubj), pairs{isubj}(ipair, 1), pairs{isubj}(ipair, 2), ...
            pairregions{isubj}{ipair, 1}, pairregions{isubj}{ipair, 2}, ... 
            tspac{isubj}.AB.pvalpair(ipair), tspac{isubj}.BA.pvalpair(ipair), ... 
            erpac{isubj}.AB.remembered.stim(ipair), erpac{isubj}.AB.forgotten.stim(ipair), erpac{isubj}.AB.remembered.encoding(ipair), erpac{isubj}.AB.forgotten.encoding(ipair), ...
            erpac{isubj}.BA.remembered.stim(ipair), erpac{isubj}.BA.forgotten.stim(ipair), erpac{isubj}.BA.remembered.encoding(ipair), erpac{isubj}.BA.forgotten.encoding(ipair), ...
            phaseencoding{isubj}.onset(ipair), phaseencoding{isubj}.time(ipair), phaseencoding{isubj}.strength(ipair), phaseencoding{isubj}.nepisode(ipair)};
        linecurr = cellfun(@string, linecurr, 'UniformOutput', false); % needs to be strings
        
        missing = cellfun(@ismissing, linecurr);        
        if sum(missing)
            linecurr(missing) = {num2str(nan)};
        end
        subjcurr(ipair, :) = linecurr;
    end
    
    % Append subject.
    csv = [csv; subjcurr];
    clear subjcurr
end

% Save.
util_cell2csv([info.path.csv 'kah_multichannel.csv'], csv, header)
