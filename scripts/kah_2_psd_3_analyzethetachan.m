clearvars('-except', 'info')

load([info.path.processed.hd 'FR1_thetabands_-800_1600_chans.mat'], 'bands')

percent_theta_total = cellfun(@(x) sum(~isnan(mean(x, 2)))/size(x, 1), bands);

sublobes = {'ltl', 'lpfc'};
percent_theta_region = nan(length(info.subj), length(sublobes));

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    surface = ~strcmpi('d', info.(subject).allchan.type);
    broken = ismember(info.(subject).allchan.label, ft_channelselection(info.(subject).badchan.broken, info.(subject).allchan.label));
    epileptic = ismember(info.(subject).allchan.label, ft_channelselection(info.(subject).badchan.epileptic, info.(subject).allchan.label));

    clean_surface_chans = info.(subject).allchan.label(surface & ~(broken | epileptic));

    for isublobe = 1:length(sublobes)
        % Get current region.
        sublobe_curr = sublobes{isublobe};

        % Get channels in current region across all channels.
        chancurr = info.(subject).allchan.label(strcmpi(sublobe_curr, info.(subject).allchan.sublobe));

        % Get channels in current region in clean surface channels.
        chancurr = ismember(clean_surface_chans, chancurr);
        
        percent_theta_region(isubj, isublobe) = sum(~isnan(bands{isubj}(chancurr, 1)))/size(bands{isubj}, 1);
    end
end

%%
drop_subj = any(percent_theta_region == 0, 2);

mean(percent_theta_region(~drop_subj, :))
[~, p] = ttest(percent_theta_region(~drop_subj, 1), percent_theta_region(~drop_subj, 2))
ranksum(percent_theta_region(~drop_subj, 1), percent_theta_region(~drop_subj, 2))
%%
load([info.path.processed.hd 'FR1_thetabands_-800_1600_chans.mat'], 'bands', 'amplitudes')
old_f = bands;

load([info.path.processed.hd 'FR1_thetabands_-800_1600_chans_newfooof.mat'], 'bands', 'amplitudes')
new_f = bands;

clear bands amplitudes

%%
isubj = 19;
[old_f{isubj}, new_f{isubj}];

thetachan_old = find(~isnan(old_f{isubj}(:, 1)))';
thetachan_new = find(~isnan(new_f{isubj}(:, 1)))';

[length(thetachan_old), length(thetachan_new)]

thetachan_old(~ismember(thetachan_old, thetachan_new))
thetachan_new(~ismember(thetachan_new, thetachan_old))

%%
cf_old = cellfun(@(x) nanmean(mean(x, 2)), old_f);
cf_new = cellfun(@(x) nanmean(mean(x, 2)), new_f);

figure;
subplot(1, 2, 1)
hist(cf_old)

subplot(1, 2, 2)
hist(cf_new)

%%
figure
hist(cf_old - cf_new)