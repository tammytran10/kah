%% Script for calculating individual theta bands per channel based on FOOOF output.
clear; clc

% Load project info.
info = kah_info;

%%
clearvars('-except', 'info')

% Choose to aggregate all theta peaks ('all') or just get the max peak ('max').
pickpeak = 'all';

%%
% Set default theta band.
default = [4, 8];

% For saving theta bands per subject.
bands = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    
    % Load FOOOF output for each subject.
    load([info.path.processed.hd subject '_FR1_fooof_-800_1600.mat'], 'fooof')

    % For saving bands per channel.
    nchan = length(fooof);
    bands{isubj} = nan(nchan, 2);
    
    for ichan = 1:nchan
        edges = [];
        
        % Continue if no peaks were detected.
        if isempty(fooof{ichan})
            continue
        end
        
        % Find FOOOF output for theta peaks.
        theta = fooof{ichan}(:, 1) > default(1) & fooof{ichan}(:, 1) < default(2);
        theta = fooof{ichan}(theta, :);

        % Continue if no thetas were detected.
        if isempty(theta)
            continue
        end
        
        % Get bands for detected thetas.
        switch pickpeak
            % Aggregate bandwidths.
            case 'all'
                edges = [max(default), min(default)];
                for itheta = 1:size(theta, 1)
                    edges(1) = min([edges(1), theta(itheta, 1) - (theta(itheta, 3)/2)]);
                    edges(2) = max([edges(2), theta(itheta, 1) + (theta(itheta, 3)/2)]);
                end
            % Use only the max peak.
            case 'max'
                [~, argmax] = max(theta(:, 1));
                edges(1) = theta(argmax, 1) - theta(argmax, 3)/2;
                edges(2) = theta(argmax, 1) + theta(argmax, 3)/2;
        end
        bands{isubj}(ichan, :) = edges;
    end
end

save([info.path.processed.hd 'FR1_thetabands_-800_1600.mat'], 'bands')
