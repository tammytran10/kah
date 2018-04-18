%% Script for plotting HFA time courses by region and accuracy
clear; close all

% Load Kahana info.
info = kah_info;

%%
[hfaamp, trialinfo, chans, times] = deal(cell(length(info.subj), 1));
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp(subject)
    [hfaamp{isubj}, trialinfo{isubj}, chans{isubj}, times{isubj}] = kah_loadftdata(info, subject, 'hfa', [-800, 1600], 1);
end

%%
thetaamp = cell(length(info.subj), 1);
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp(subject)
    thetaamp{isubj} = kah_loadftdata(info, subject, 'thetaamp_cf', [-800, 1600], 1);
    
    % Z-score across baseline and encoding periods.
    thetaamp{isubj} = zscore(reshape(thetaamp{isubj}, length(chans{isubj}), []), [], 2);
    thetaamp{isubj} = reshape(thetaamp{isubj}, length(chans{isubj}), length(times{isubj}), []);
end

%%
% Set subject.
isubj = 19;
subject = info.subj{isubj};

figure(1); clf;
suptitle([num2str(isubj) ' ' subject])
ax = [];

% Get sublobe names.
sublobes = fieldnames(info.sublobe_regions);
sublobes = sublobes(1:8);

% Plot average HFA (correct vs. incorrect) across channels per region.
for isublobe = 1:length(sublobes)
    axcurr = subplot(2, 4, isublobe);
    ax = [ax; axcurr];
    hold on
    
    % Get current region.
    sublobe_curr = sublobes{isublobe};
    
    % Get channels in current region across all channels.
    chancurr = info.(subject).allchan.label(strcmpi(sublobe_curr, info.(subject).allchan.sublobe));
    
    % Get channels in current region in clean surface channels.
    chancurr = ismember(chans{isubj}, chancurr);
    
    % Get correct vs. incorrect trial labels.
    encoding = logical(trialinfo{isubj}(:, 3));
    
    % Plot.
    plot(times{isubj}, mean(mean(hfaamp{isubj}(chancurr, :, encoding), 1), 3))
    plot(times{isubj}, mean(mean(hfaamp{isubj}(chancurr, :, ~encoding), 1), 3))
    
%     plot(times{isubj}, mean(mean(thetaamp{isubj}(chancurr, :, encoding), 1), 3))
%     plot(times{isubj}, mean(mean(thetaamp{isubj}(chancurr, :, ~encoding), 1), 3))
%     plot(times{isubj}, mean(mean(hfaamp{isubj}(chancurr, :, encoding), 1), 3) - mean(mean(hfaamp{isubj}(chancurr, :, ~encoding), 1), 3))
%     plot([-0.8, 1.6], [0, 0], 'k--')
    title([sublobe_curr ' ' num2str(sum(chancurr))])
    xlim([-0.8, 1.6])
end
linkaxes(ax, 'xy');

%%
regions = {'mtl', 'ltl', 'lpfc'};


