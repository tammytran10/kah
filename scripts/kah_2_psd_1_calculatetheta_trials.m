%% Script for calculating individual theta bands per channel based on FOOOF output.
clear; clc

% Load project info.
info = kah_info;

%%
clearvars('-except', 'info')

% Choose time window.
timewin = [-800, 0];

% Choose to aggregate all theta peaks ('all') or just get the max peak ('max').
pickpeak = 'all';

%%
% Set default theta band.
default = [4, 8];

% For saving theta bands per subject.
[bands, amplitudes] = deal(cell(length(info.subj), 1));

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    
    % Load FOOOF output for each subject.
    load([info.path.processed.hd subject '_FR1_fooof_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'fooof')
    [nchan, ntrial] = size(fooof);
    
    % For saving bands per channel.
    bands{isubj} = nan(nchan, ntrial, 2);
    amplitudes{isubj} = nan(nchan, ntrial);
    
    for ichan = 1:nchan
        for itrial = 1:ntrial
            fooofcurr = fooof{ichan, itrial};
            edges = []; amp = [];
            
            % Continue if no peaks were detected.
            if isempty(fooofcurr)
                continue
            end
            
            % Find FOOOF output for theta peaks.
            theta = fooofcurr(:, 1) > default(1) & fooofcurr(:, 1) < default(2);
            theta = fooofcurr(theta, :);
            
            % Continue if no thetas were detected.
            if isempty(theta)
                continue
            end
            
            % Get bands for detected thetas.
            switch pickpeak
                % Aggregate bandwidths.
                case 'all'
                    edges = [max(default), min(default)];
                    amp = 0;
                    for itheta = 1:size(theta, 1)
                        edges(1) = min([edges(1), theta(itheta, 1) - (theta(itheta, 3)/2)]);
                        edges(2) = max([edges(2), theta(itheta, 1) + (theta(itheta, 3)/2)]);
                        amp = amp + theta(itheta, 2);
                    end
                % Use only the max peak.
                case 'max'
                    [~, argmax] = max(theta(:, 1));
                    edges(1) = theta(argmax, 1) - theta(argmax, 3)/2;
                    edges(2) = theta(argmax, 1) + theta(argmax, 3)/2;
                    amp = theta(argmax, 2);
            end
            bands{isubj}(ichan, itrial, :) = edges;
            amplitudes{isubj}(ichan, itrial) = amp;
        end
    end
end
save([info.path.processed.hd 'FR1_thetabands_' num2str(timewin(1)) '_' num2str(timewin(2)) '_trials.mat'], 'bands', 'amplitudes')
disp('Done.')