function [data, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, datatype, timewin, reformat)
% KAH_LOADFTDATA loads Fieldtrip-style structs from memory, re-epochs, extracts metadata, and reformats the data to an nchan x nsample x ntrial matrix, if desired.
% Usage:
%   [data, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, 'R1020J', 'thetaphase', [-800, 1600], 1);

% Find subject file to load.
pathname = [info.path.processed.hd subject '/data/' subject '_FR1_'];

if datatype == 'hfa'
    filecurr = [pathname 'hfa_-800_1600.mat'];
else
    filecurr = [pathname datatype '_-1000_2750.mat'];
end

% Load subject data.
input = load(filecurr);
varname = fieldnames(input);
data = input.(varname{1});

if ~strcmpi(datatype, 'gammaamp_multi')
    data = {data}; % so cellfun can be used for all datatypes, keeps code more condensed
end

% Re-epoch.
if ~isempty(timewin)
    data = cellfun(@(x) kah_epoch(x, timewin), data, 'UniformOutput', false);
end

% Extract data from Fieldtrip struct.
trialinfo = data{1}.trialinfo;
chans = data{1}.label;
times = data{1}.time{1};

% Convert data to format nchan x nsamp x ntrial, if necessary.
if reformat
    data = cellfun(@kah_reformat, data, 'UniformOutput', false);
end

if ~strcmpi(datatype, 'gammaamp_multi')
    data = data{1}; % if only one struct, remove from cell array
end

% Get region of each electrode.
regions = cell(length(chans), 1);
for ichan = 1:length(chans)
    regions(ichan) = info.(subject).allchan.lobe(ismember(info.(subject).allchan.label, chans{ichan}));
end
temporal = strcmpi('t', regions);
frontal = strcmpi('f', regions);

end

% Subfunction for re-epoching Fieldtrip-style data.
% Enables cellfun use above.
function data = kah_epoch(data, timewin)
    cfg = [];
    cfg.toilim = timewin ./ 1000;
    cfg.toilim(2) = cfg.toilim(2) - 1/data.fsample; % so that sample number is exactly srate or srate/2, etc.

    data = ft_redefinetrial(cfg, data);
end

% Subfunction for re-formating Fieldtrip-style data to EEGLAB-style data.
% Enables cellfun use above.
function dat = kah_reformat(data)
    dat = nan(length(data.label), length(data.time{1}), size(data.trialinfo, 1));
    for itrial = 1:size(dat, 3)
        dat(:, :, itrial) = data.trial{itrial};
    end           
end
