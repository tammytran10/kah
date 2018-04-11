clear; clc

info = kah_info('all');

%% Determine which subjects have temporal lobe epilepsy and in which hemisphere.
clearvars('-except', 'info')

% Keep track of subjects with info about their seizure onset zone.
chaninfo_available = false(length(info.subj), 1);

% See who has MTL/LTL/lPFC epilepsy, split by left and right.
regions = {'mtl', 'ltl', 'lpfc'};
epilepsy = false(length(info.subj), length(regions), 2);

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

    % Determine if any onset zones are in MTL/LTL.
    for iregion = 1:length(regions)
        epilepsy(isubj, iregion, 1) = sum(strcmpi(regions{iregion}, leftseizureregions)) > 0;
        epilepsy(isubj, iregion, 2) = sum(strcmpi(regions{iregion}, rightseizureregions)) > 0;
    end
end

%% Load subject info and behavioral performance.
load([info.path.processed.hd 'other/FR1_subjinfo_previous_version.mat'])

subjects = {subjinfo.subject};
ncorrect = [subjinfo.ncorrect];
ntrial = [subjinfo.ntrial];
ages = [subjinfo.age];
subjects = subjects(:); ages = ages(:); ncorrect = ncorrect(:); ntrial = ntrial(:);

recall = ncorrect ./ ntrial;

% Keep only subjects with FR1, reported age, and reported seizure onset zone.
subj_to_keep = ~isnan(recall) & ages > 0 & chaninfo_available;

subjects = subjects(subj_to_keep);
recall = recall(subj_to_keep);
ages = ages(subj_to_keep);
epilepsy = epilepsy(subj_to_keep, :, :);
ncorrect = ncorrect(subj_to_keep);
ntrial = ntrial(subj_to_keep);

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
seizureregions = {};

for isubj = 1:length(subjects)
    if right_ltl(isubj)
        subject = subjects{isubj};
        
        % Get indices of onset zone channels. 
        seizurechans = ismember(info.(subject).allchan.label, info.(subject).badchan.kahana);

        % Get indices of left hemisphere channels.
        leftchan = info.(subject).allchan.lefthemisphere;

        % Get sublobes of onset zone channels.
        rightseizureregions = info.(subject).allchan.ind.region(seizurechans & ~leftchan);
        
        seizureregions = unique([seizureregions; rightseizureregions]);
    end
end




%%
compare = mtl_epilepsy;
close all
figure;
histogram(recall(compare), 20, 'FaceColor', [0, 0, 1], 'FaceAlpha', 0.75)
figure;
histogram(recall(~compare), 20, 'FaceColor', [1, 0, 0], 'FaceAlpha', 0.75)

[~, pval] = ttest2(recall(compare), recall(~compare))

%%
% Analyze number of surface channels vs. recall
[nsurface, ndepth] = deal(nan(length(subjects), 1));
for isubj = 1:length(subjects)
    nsurface(isubj) = sum(~strcmpi('d', info.(subjects{isubj}).allchan.type));
    ndepth(isubj) = sum(strcmpi('d', info.(subjects{isubj}).allchan.type));
end

%%
percent_depthonly = sum(nsurface == 0)/length(nsurface);
percent_surfaceonly = sum(ndepth == 0)/length(nsurface);
percent_depthandurface = 1 - percent_depthonly - percent_surfaceonly;

%%
% columns temporal, frontal, hippocampal, total
[nsurface, ndepth] = deal(nan(length(subjects), 3));
for isubj = 1:length(subjects)
    nsurface(isubj, 1) = sum(~strcmpi('d', info.(subjects{isubj}).allchan.type) & strcmpi('t', info.(subjects{isubj}).allchan.lobe));
    nsurface(isubj, 2) = sum(~strcmpi('d', info.(subjects{isubj}).allchan.type) & strcmpi('f', info.(subjects{isubj}).allchan.lobe));
    nsurface(isubj, 3) = sum(~strcmpi('d', info.(subjects{isubj}).allchan.type) & cell2mat(info.(subjects{isubj}).allchan.hipp));
    nsurface(isubj, 4) = sum(~strcmpi('d', info.(subjects{isubj}).allchan.type));
    ndepth(isubj, 1) = sum(strcmpi('d', info.(subjects{isubj}).allchan.type) & strcmpi('t', info.(subjects{isubj}).allchan.lobe));
    ndepth(isubj, 2) = sum(strcmpi('d', info.(subjects{isubj}).allchan.type) & strcmpi('f', info.(subjects{isubj}).allchan.lobe));
    ndepth(isubj, 3) = sum(strcmpi('d', info.(subjects{isubj}).allchan.type) & cell2mat(info.(subjects{isubj}).allchan.hipp));
    ndepth(isubj, 4) = sum(strcmpi('d', info.(subjects{isubj}).allchan.type));
end

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

%%
clc
chaninfo = cell(length(info.subj), 1);
chans = {};
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp(subject)

    electrode_notes_file = ['/Volumes/DATAHD/KAHANA/Release_Metadata_20160930/electrode_categories/electrode_categories_' subject '.txt'];
    fileID = fopen(electrode_notes_file);

    electrode_notes = textscan(fileID, '%s');
    electrode_notes = upper(electrode_notes{1});
    
    zone = find(contains(electrode_notes, 'ONSET'), 1);
    interictal = find(strcmpi('interictal', electrode_notes), 1);
    
    if ~isempty(zone) && ~isempty(interictal)
        epileptic = electrode_notes(zone + 1:interictal - 1);
%         if sum(cellfun(@(x) isnumeric(x(end)), epileptic)) ~= length(epileptic)
%             disp(epileptic)
%         end
        epileptic(contains(epileptic, 'ZONE')) = [];
        epileptic(contains(epileptic, 'UNREPORTED')) = [];
        info.(subject).badchan.kahana = epileptic;
        chans = unique([chans; upper(epileptic)]);
        chaninfo{isubj} = kah_chaninfo(info, subject, epileptic);
    end
end

%%
left = strcmpi(cellfun(@(x) x(1), chans, 'UniformOutput', false), 'L');
right = strcmpi(cellfun(@(x) x(1), chans, 'UniformOutput', false), 'R');
comma = contains(chans, ',');
unreported = contains(chans, {'-', 'UNREPORTED'});
single_letter = cellfun(@(x) length(x) == 1, chans);

% comma (R1118N), 'SPREAD' (R1169P), 'AND' (R1169P), single_letter (R1118N, R1157C)
%%
[ntemporal_seizure, nhipp_seizure] = deal(nan(length(info.subj), 1));
for isubj = 1:length(info.subj)
    if isempty(chaninfo{isubj})
        continue
    end
%     try
        ntemporal_seizure(isubj) = sum(strcmpi('t', chaninfo{isubj}(2:end, 3)) | strcmpi('t', chaninfo{isubj}(2:end, 4)));
        
        nhipp_seizure(isubj) = 0;
        for ichan = 2:size(chaninfo{isubj}, 1)
            try
                nhipp_seizure(isubj) = nhipp_seizure(isubj) + contains(chaninfo{isubj}(ichan, 6), {'hippocamp', 'entorhinal'});
            catch
                continue
            end
        end
%     catch
%         continue
%     end
end

%%
to_use = ~isnan(ntemporal_seizure);
thing1 = nhipp_seizure(to_use);
thing2 = recall(to_use);
figure(1); clf
scatter(thing1, thing2, 'filled')
xlabel('Number of temporal channels in seizure zone')
ylabel('Recall')
[rho, pval] = corr(thing1, thing2')

%%
recall = [subjinfo.ncorrect]./[subjinfo.ntrial];
nsurface = [subjinfo.surface];
ages = [subjinfo.age];

to_use = nsurface > 0 & ~isnan(recall);
thing1 = nsurface(to_use);
thing2 = recall(to_use);

figure(1); clf
scatter(thing1, thing2, 'filled')
[rho, pval] = corr(thing1(:), thing2(:), 'type', 'Spearman')


