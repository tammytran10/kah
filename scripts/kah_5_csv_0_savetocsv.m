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
    
    for ichan = 1:nchan
        for itrial = 1:ntrial
            linecurr = {info.subj{isubj}, info.age(isubj), ichan, chanregions{isubj}{ichan}, itrial, encoding{isubj}(itrial), ...
                preslope{isubj}(ichan, itrial), postslope{isubj}(ichan, itrial), pretheta{isubj}(ichan, itrial), posttheta{isubj}(ichan, itrial), ...
                hfabaseline{isubj}(ichan, itrial), hfaencoding{isubj}(ichan, itrial), tspac{isubj}.raw(ichan, itrial), tspac{isubj}.norm(ichan, itrial), tspac{isubj}.pvaltrial(ichan, itrial)};
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
