clear

info = kah_info;

%% SINGLE-TRIAL, SINGLE-CHANNEL
clearvars('-except', 'info')

% Load slopes.
load([info.path.processed.hd 'FR1_slopes_-800_0.mat'], 'slopes');

% Load thetas analytic amplitudes using individualized bands.
load([info.path.processed.hd 'FR1_thetaamp_cf_-800_0.mat'], 'thetaamp')
pretheta_cf = thetaamp;

load([info.path.processed.hd 'FR1_thetaamp_cf_0_800.mat'], 'thetaamp')
earlytheta_cf = thetaamp;

load([info.path.processed.hd 'FR1_thetaamp_cf_800_1600.mat'], 'thetaamp')
latetheta_cf = thetaamp;

clear thetaamp

% Load thetas analytic amplitudes using canonical bands.
load([info.path.processed.hd 'FR1_thetaamp_canon_-800_0.mat'], 'thetaamp')
pretheta_canon = thetaamp;

load([info.path.processed.hd 'FR1_thetaamp_canon_0_800.mat'], 'thetaamp')
earlytheta_canon = thetaamp;

load([info.path.processed.hd 'FR1_thetaamp_canon_800_1600.mat'], 'thetaamp')
latetheta_canon = thetaamp;

clear thetaamp

% Load HFA amplitudes.
load([info.path.processed.hd 'FR1_hfa_-800_0.mat'], 'hfa');
prehfa = hfa;

load([info.path.processed.hd 'FR1_hfa_0_800.mat'], 'hfa');
earlyhfa = hfa;

load([info.path.processed.hd 'FR1_hfa_800_1600.mat'], 'hfa');
latehfa = hfa;

clear hfa

% Load within-channel tsPAC using canonical bands.
load([info.path.processed.hd 'FR1_pac_within_ts_0_1600_canon.mat']);
tspac_canon = tspac;

% Load within-channel tsPAC using individualized bands.
load([info.path.processed.hd 'FR1_pac_within_ts_0_1600_cf.mat']);
tspac_cf = tspac;

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'chans', 'chanlobes', 'chanregions', 'encoding')

% Set names of metrics.
header = {'subject', 'age', 'channel', 'lobe', 'region', 'trial', 'encoding', ...
    'preslope', ...
    'pretheta_cf', 'pretheta_canon', ...
    'earlytheta_cf', 'earlytheta_canon', ...
    'latetheta_cf', 'latetheta_canon', ...
    'prehfa', 'earlyhfa', 'posthfa', ...
    'tspac_cf', 'tspac_canon'};

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
            % Build current line.
            linecurr = {info.subj{isubj}, info.age(isubj), chans{isubj}{ipair}, chanlobes{isubj}{ipair}, chanregions{isubj}{ipair}, itrial, encoding{isubj}(itrial), ...
                -slopes{isubj}(ipair, itrial), ...
                pretheta_cf{isubj}(ipair, itrial), pretheta_canon{isubj}(ipair, itrial),...
                earlytheta_cf{isubj}(ipair, itrial), earlytheta_canon{isubj}(ipair, itrial), ...
                latetheta_cf{isubj}(ipair, itrial), latetheta_canon{isubj}(ipair, itrial), ...
                prehfa{isubj}(ipair, itrial), earlyhfa{isubj}(ipair, itrial), latehfa{isubj}(ipair, itrial),...
                tspac_cf{isubj}.norm(ipair, itrial), tspac_canon{isubj}.norm(ipair, itrial)};
            
            % Save current line.
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

% Load HFA p-values.
load([info.path.processed.hd 'FR1_hfa_0_800.mat'], 'hfapval');

% Load theta center frequencies.
load([info.path.processed.hd 'FR1_thetabands_-800_1600_chans.mat'])

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'chanregions', 'chans')

% Set names of metrics.
header = {'subject', 'age', 'channel', 'region', 'pvalhfa', 'thetabump'};

% Build CSV.
csv = [];

for isubj = 1:length(info.subj)
    disp(isubj)
    nchan = length(chans{isubj});
    
    % Pre-allocate per subject for speed.
    subjcurr = cell(nchan, length(header));
    
    for ipair = 1:nchan
        % Build current line.
        linecurr = {info.subj{isubj}, info.age(isubj), chans{isubj}{ipair}, chanregions{isubj}{ipair}, ...
            hfapval{isubj}(ipair), ...
            ~isnan(bands{isubj}(ipair, 1))};
        linecurr = cellfun(@string, linecurr, 'UniformOutput', false); % needs to be strings
        
        % Save current line.
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
load([info.path.processed.hd 'FR1_pac_between_ts_0_1600_cf.mat'], 'tspac');

% Load phase-encoding.
load([info.path.processed.hd 'FR1_phase_corrcl_0_1600_cf.mat'], 'phaseencoding');

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'pairs', 'pairregions')

% Set names of metrics.
header = {'subject', 'age', 'pair', 'channelA', 'channelB', 'regionA', 'regionB', 'pvaltspacAB', 'pvaltspacBA', ...
    'encodingonset', 'encodinglength', 'encodingstrength', 'encodingepisodes'};

% Build CSV.
csv = [];

for isubj = 1:length(info.subj)
    disp(isubj)
    npair = size(pairs{isubj}, 1);
    
    % Pre-allocate per subject for speed.
    subjcurr = cell(npair, length(header));
    
    for ipair = 1:npair
        % Build current line.
        linecurr = {info.subj{isubj}, info.age(isubj), ipair, pairs{isubj}{ipair, 1}, pairs{isubj}{ipair, 2}, ...
            pairregions{isubj}{ipair, 1}, pairregions{isubj}{ipair, 2}, ...
            tspac{isubj}.AB.pvalpair(ipair), tspac{isubj}.BA.pvalpair(ipair), ...
            phaseencoding{isubj}.onset(ipair), phaseencoding{isubj}.time(ipair), phaseencoding{isubj}.strength(ipair), phaseencoding{isubj}.nepisode(ipair)};
        linecurr = cellfun(@string, linecurr, 'UniformOutput', false); % needs to be strings
        
        % Replace <missing> with NaNs. Missings are when the channel pair did not show any phase encoding.
        missing = cellfun(@ismissing, linecurr);
        if sum(missing)
            linecurr(missing) = {num2str(nan)};
        end
        
        % Save current line.
        subjcurr(ipair, :) = linecurr;
    end
    
    % Append subject.
    csv = [csv; subjcurr];
    clear subjcurr
end

% Save.
util_cell2csv([info.path.csv 'kah_multichannel.csv'], csv, header)
disp('Done.')

%% SINGLE-TRIAL, MULTI-CHANNEL
clearvars('-except', 'info')

% Load tsPAC.
load([info.path.processed.hd 'FR1_pac_between_ts_0_1600_cf.mat'], 'tspac');

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'pairs', 'pairregions', 'encoding')

% Set names of metrics.
header = {'subject', 'age', 'pair', 'channelA', 'channelB', 'regionA', 'regionB', 'trial', 'encoding', ...
    'rawtspacAB', 'rawtspacBA', 'normtspacAB', 'normtspacBA', 'pvaltspacAB', 'pvaltspacBA'};

for isubj = 1:length(info.subj)
    % Skip this subject if their data has already been saved.
    filecurr = [info.path.csv 'kah_singletrial_multichannel_' info.subj{isubj} '.csv'];
    if exist(filecurr, 'file')
        disp(['Skipping subject ' num2str(isubj)])
        continue
    end
    
    npair = size(pairs{isubj}, 1);
    ntrial = length(encoding{isubj});
    
    % Pre-allocate per subject for speed.
    subjcurr = cell(npair * ntrial, length(header));
    linenum = 1; % next line to fill in for the current subject.
    
    for ipair = 1:npair
        disp([num2str(isubj) ' ' num2str(ipair) '/' num2str(npair)])
        
        for itrial = 1:ntrial
            % Build current line.
            linecurr = {info.subj{isubj}, info.age(isubj), ipair, pairs{isubj}{ipair, 1}, pairs{isubj}{ipair, 2}, ...
                pairregions{isubj}{ipair, 1}, pairregions{isubj}{ipair, 2}, ...
                itrial, encoding{isubj}(itrial), ...
                tspac{isubj}.AB.raw(ipair, itrial), tspac{isubj}.BA.raw(ipair, itrial), ...
                tspac{isubj}.AB.norm(ipair, itrial), tspac{isubj}.BA.norm(ipair, itrial), ...
                tspac{isubj}.AB.pvaltrial(ipair, itrial), tspac{isubj}.BA.pvaltrial(ipair, itrial), ...
                };
            linecurr = cellfun(@string, linecurr, 'UniformOutput', false); % needs to be strings
            
            % Replace <missing> with NaNs.
            missing = cellfun(@ismissing, linecurr);
            if sum(missing)
                disp('here')
                return
                linecurr(missing) = {num2str(nan)};
            end
            
            % Save current line.
            subjcurr(linenum, :) = linecurr;
            linenum = linenum + 1;            
        end
               
    end

    % Save current line right to disk.
    disp('Saving.')
    util_cell2csv(filecurr, subjcurr, header, [])
end
disp('Done.')