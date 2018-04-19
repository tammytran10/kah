clear; clc

info = kah_info('all');

%% Determine which subjects have temporal lobe epilepsy and in which hemisphere.
clearvars('-except', 'info')

% Keep track of subjects with info about their seizure onset zone.
chaninfo_available = false(length(info.subj), 1);

% See who has MTL/LTL/lPFC epilepsy, split by left and right.
regions = {'mtl', 'ltl', 'lpfc'};
epilepsy = false(length(info.subj), length(regions), 2);

% Keep track of the number of surface channels.
nsurface_regions = zeros(length(info.subj), length(regions), 2);
nsurface_total = zeros(length(info.subj), 2);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    
    % Check if any channels are listed as being in the seizure onset zone.
    chaninfo_available(isubj) = ~isempty(info.(subject).badchan.kahana);
    
    % Get indices of onset zone channels. 
    seizurechans = ismember(info.(subject).allchan.label, info.(subject).badchan.kahana);
        
    % Get indices of left hemisphere channels.
    leftchan = info.(subject).allchan.lefthemisphere;
    
    % Get sublobes of onset zone channels.
    leftseizureregions = info.(subject).allchan.sublobe(seizurechans & leftchan);
    rightseizureregions = info.(subject).allchan.sublobe(seizurechans & ~leftchan);

    % Get indices of surface channels.
    surfacechan = ~strcmpi('d', info.(subject).allchan.type);
    
    % Get sublobes of surface channels.
    leftsurfaceregions = info.(subject).allchan.sublobe(surfacechan & leftchan);
    rightsurfaceregions = info.(subject).allchan.sublobe(surfacechan & ~leftchan);
    
    % Get number of surface channels irrespective of region.
    nsurface_total(isubj, 1) = sum(surfacechan & leftchan);
    nsurface_total(isubj, 2) = sum(surfacechan & ~leftchan);
    
    % Determine if any onset zones are in MTL/LTL.
    for iregion = 1:length(regions)
        epilepsy(isubj, iregion, 1) = sum(strcmpi(regions{iregion}, leftseizureregions)) > 0;
        epilepsy(isubj, iregion, 2) = sum(strcmpi(regions{iregion}, rightseizureregions)) > 0;
        
        nsurface_regions(isubj, iregion, 1) = sum(strcmpi(regions{iregion}, leftsurfaceregions));
        nsurface_regions(isubj, iregion, 2) = sum(strcmpi(regions{iregion}, rightsurfaceregions));
    end
end

% Load subject info and behavioral performance.
load([info.path.processed.hd 'FR1_subjinfo_previous_version.mat'])

subjects = {subjinfo.subject};
ncorrect = [subjinfo.ncorrect];
ntrial = [subjinfo.ntrial];
ages = [subjinfo.age];
subjects = subjects(:); ages = ages(:); ncorrect = ncorrect(:); ntrial = ntrial(:);

recall = ncorrect ./ ntrial;

% Keep only subjects with FR1, reported age, and reported seizure onset zone.
subj_to_keep = ~isnan(recall) & ages >= 18 & chaninfo_available;

subjects = subjects(subj_to_keep);
recall = recall(subj_to_keep);
ages = ages(subj_to_keep);
epilepsy = epilepsy(subj_to_keep, :, :);
ncorrect = ncorrect(subj_to_keep);
ntrial = ntrial(subj_to_keep);
nsurface_regions = nsurface_regions(subj_to_keep, :, :);
nsurface_total = nsurface_total(subj_to_keep, :);

%% Determine number of patients with >= 3 clean LTL and lPFC channels
sublobes = {'ltl', 'lpfc'};
nchan = nan(length(info.subj), length(sublobes));
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    surface = ~strcmpi('d', info.(subject).allchan.type);
    broken = ismember(info.(subject).allchan.label, ft_channelselection(info.(subject).badchan.broken, info.(subject).allchan.label));
    epileptic = ismember(info.(subject).allchan.label, ft_channelselection(info.(subject).badchan.epileptic, info.(subject).allchan.label));

    clean_surface_chans = info.(subject).allchan.label(surface & ~(broken | epileptic));

    % Plot average HFA (correct vs. incorrect) across channels per region.
    for isublobe = 1:length(sublobes)
        % Get current region.
        sublobe_curr = sublobes{isublobe};

        % Get channels in current region across all channels.
        chancurr = info.(subject).allchan.label(strcmpi(sublobe_curr, info.(subject).allchan.sublobe));

        % Get channels in current region in clean surface channels.
        chancurr = ismember(clean_surface_chans, chancurr);
        nchan(isubj, isublobe) = sum(chancurr);
    end
end

%% Determine if there is a relationship between total number of surface channels and recall.
nsurface_total_noside = sum(nsurface_total, 2);
to_use = (nsurface_total_noside > 0) & (nsurface_total_noside < 200);
figure;
scatter(nsurface_total_noside(to_use), recall(to_use))
[rho, pval] = corr(nsurface_total_noside(to_use), recall(to_use), 'type', 'Spearman')

%% Determine if there is a relationship between total number of surface channels and age.
nsurface_total_noside = sum(nsurface_total, 2);
to_use = nsurface_total_noside > 0;
figure;
scatter(nsurface_total_noside(to_use), ages(to_use))
[rho, pval] = corr(nsurface_total_noside(to_use), ages(to_use), 'type', 'Spearman')

%% Determine if there is a relationship between recall and age.
figure;
scatter(ages, recall, 'filled')
[rho, pval] = corr(ages, recall, 'type', 'Spearman')

%% Determine if there is a relationship between the number of left surface channels and recall.
nsurface_oneside = nsurface_total(:, 1);
to_use = nsurface_oneside > 0;
figure;
scatter(nsurface_oneside(to_use), recall(to_use))
[rho, pval] = corr(nsurface_oneside(to_use), recall(to_use), 'type', 'Spearman')

%% Break up subjects by seizure locations.
left_mtl = epilepsy(:, 1, 1);
right_mtl = epilepsy(:, 1, 2);
mtl = left_mtl | right_mtl;

left_ltl = epilepsy(:, 2, 1);
right_ltl = epilepsy(:, 2, 2);
ltl = left_ltl | right_ltl;

left_tl = any(epilepsy(:, 1:2, 1), 2);

tl = any(any(epilepsy(:, 1:2, :), 2), 3);

left_lpfc = epilepsy(:, 3, 1);
right_lpfc = epilepsy(:, 3, 2);
lpfc = left_lpfc | right_lpfc;

%% Is there a relationship between age and seizure onset zone region?
epilepsy_region = tl;

ages_region = ages(epilepsy_region);
ages_notregion = ages(~epilepsy_region);

pval = ranksum(ages_region, ages_notregion);

figure
hold on
histogram(ages_region, 10, 'FaceColor', [1, 0, 0], 'FaceAlpha', 0.5)
plot([median(ages_region), median(ages_region)], [0, 10], 'r', 'LineWidth', 2)
histogram(ages_notregion, 10, 'FaceColor', [0, 0, 1], 'FaceAlpha', 0.75)
plot([median(ages_notregion), median(ages_notregion)], [0, 10], 'b', 'LineWidth', 2)
title(['Region Onset (Red) vs. Everywhere Else (Blue), p-value = ' num2str(pval)])
xlabel('Free Recall')
ylabel('Number of Patients')

%% Do patients with left TL epilepsy perform worse?
figure(1); clf

recall_tl = recall(left_tl);
recall_nontl = recall(~left_tl);

pval = ranksum(recall_tl, recall_nontl);

hold on
histogram(recall_tl, 15, 'FaceColor', [1, 0, 0], 'FaceAlpha', 0.5)
plot([median(recall_tl), median(recall_tl)], [0, 7], 'r', 'LineWidth', 2)
histogram(recall_nontl, 15, 'FaceColor', [0, 0, 1], 'FaceAlpha', 0.75)
plot([median(recall_nontl), median(recall_nontl)], [0, 7], 'b', 'LineWidth', 2)
title(['Left Temporal Lobe Onset (Red) vs. Everywhere Else (Blue), p-value = ' num2str(pval)])
xlabel('Free Recall')
ylabel('Number of Patients')

%% Do patients with MTL epilepsy perform worse?
figure(1); clf

recall_tl = recall(mtl);
recall_nontl = recall(~mtl);

pval = ranksum(recall_tl, recall_nontl);

hold on
histogram(recall_tl, 15, 'FaceColor', [1, 0, 0], 'FaceAlpha', 0.5)
plot([median(recall_tl), median(recall_tl)], [0, 10], 'r', 'LineWidth', 2)
histogram(recall_nontl, 15, 'FaceColor', [0, 0, 1], 'FaceAlpha', 0.75)
plot([median(recall_nontl), median(recall_nontl)], [0, 10], 'b', 'LineWidth', 2)
title(['MTL Onset (Red) vs. Everywhere Else (Blue), p-value = ' num2str(pval)])
xlabel('Free Recall')
ylabel('Number of Patients')
    
%% Do patients with MTL epilepsy (split up by hemispheres) perform worse?
contrasts = {left_mtl, right_mtl, mtl};
control = ~mtl;
titles = {'Left MTL', 'Right MTL', 'MTL'};

figure(1); clf
ax = nan(length(contrasts), 1);

for iplot = 1:length(contrasts)
    recall_tl = recall(contrasts{iplot});
    recall_nontl = recall(control);
    
    pval = ranksum(recall_tl, recall_nontl);
    
    ax(iplot) = subplot(1, length(contrasts), iplot);
    hold on
    histogram(recall_tl, 20, 'FaceColor', [1, 0, 0], 'FaceAlpha', 0.75)
    plot([median(recall_tl), median(recall_tl)], [0, 7], 'k')
    histogram(recall_nontl, 20, 'FaceColor', [0, 0, 1], 'FaceAlpha', 0.75)
    plot([median(recall_nontl), median(recall_nontl)], [0, 7], 'k--')
    title([titles{iplot} ', p-value = ' num2str(pval)])
    xlabel('Recall')
    ylabel('Number of Patients')
end
linkaxes(ax, 'y')

%% Do patients with LTL epilepsy perform worse?
contrasts = {left_ltl, right_ltl, ltl};
titles = {'Left LTL', 'Right LTL', 'LTL'};
control = ~ltl;

figure(1); clf
ax = nan(length(contrasts), 1);

for iplot = 1:length(contrasts)
    recall_tl = recall(contrasts{iplot});
    recall_nontl = recall(control);
    
    pval = ranksum(recall_tl, recall_nontl);
    
    ax(iplot) = subplot(1, length(contrasts), iplot);
    hold on
    histogram(recall_tl, 20, 'FaceColor', [1, 0, 0], 'FaceAlpha', 0.75)
    plot([median(recall_tl), median(recall_tl)], [0, 7], 'k')
    histogram(recall_nontl, 20, 'FaceColor', [0, 0, 1], 'FaceAlpha', 0.75)
    plot([median(recall_nontl), median(recall_nontl)], [0, 7], 'k--')
    title([titles{iplot} ', p-value = ' num2str(pval)])
    xlabel('Recall')
    ylabel('Number of Patients')
end
linkaxes(ax, 'y')

%% Do patients with lPFC epilepsy perform worse?
contrasts = {left_lpfc, right_lpfc, lpfc};
control = ~lpfc;
titles = {'Left lPFC', 'Right lPFC', 'lPFC'};

figure(1); clf
ax = nan(length(contrasts), 1);

for iplot = 1:length(contrasts)
    recall_tl = recall(contrasts{iplot});
    recall_nontl = recall(control);
    
    pval = ranksum(recall_tl, recall_nontl);
    
    ax(iplot) = subplot(1, length(contrasts), iplot);
    hold on
    histogram(recall_tl, 20, 'FaceColor', [1, 0, 0], 'FaceAlpha', 0.75)
    plot([median(recall_tl), median(recall_tl)], [0, 7], 'k')
    histogram(recall_nontl, 20, 'FaceColor', [0, 0, 1], 'FaceAlpha', 0.75)
    plot([median(recall_nontl), median(recall_nontl)], [0, 7], 'k--')
    title([titles{iplot} ', p-value = ' num2str(pval)])
    xlabel('Recall')
    ylabel('Number of Patients')
end
linkaxes(ax, 'y')

%%








bad_subjects = {'R1100D', 'R1128E', 'R1156D', 'R1159P'};

enough_temporal = [subjinfo_new_localization.temporalsurface] >= 3;
enough_frontal = [subjinfo_new_localization.frontalsurface] >= 3;
fr1 = [subjinfo_old_localization.ntrial] > 0;
age_reported = [subjinfo_old_localization.age] > 0;
age_over_18 = [subjinfo_old_localization.age] >= 18;
srate_over_999 = [subjinfo_old_localization.srate] >= 999;
bad_noise = ismember({subjinfo_old_localization.subject}, bad_subjects);
enough_correct = [subjinfo_old_localization.ncorrect] >= 20;

age = [subjinfo_old_localization.age];
recall = [subjinfo_old_localization.ncorrect]./[subjinfo_old_localization.ntrial];

subjects_all = fr1 & age_reported;
subjects_curr = enough_temporal & enough_frontal & fr1 & age_over_18 & srate_over_999 & ~bad_noise;
subjects_possible = enough_temporal & enough_frontal & fr1 & age_over_18 & ~bad_noise;

%%
subjects_to_use = 'subjects_possible';
to_use = eval(subjects_to_use);
thing1 = age(to_use);
thing2 = recall(to_use);
figure(1); clf
scatter(thing1, thing2, 'filled')
xlabel('Age')
ylabel('Recall')

[rho, pval] = corr(thing1', thing2', 'type', 'Spearman');
title(['Subjects with enough coverage and correct trials' newline 'Spearman rho = ' num2str(rho) ', p-value = ' num2str(pval)])


clc

load([info.path.processed.hd 'other/FR1_subjinfo_previous_version.mat'])
subject_all = {subjinfo.subject};
recall = [subjinfo(ismember(subject_all, info.subj)).ncorrect]./[subjinfo(ismember(subject_all, info.subj)).ntrial];

ages = [subjinfo(ismember(subject_all, info.subj)).age];



