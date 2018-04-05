clear; clc

info = kah_info('all');

load([info.path.processed.hd 'other/FR1_subjinfo_previous_version.mat'])

subjects = {subjinfo.subject};
recall = [subjinfo.ncorrect]./[subjinfo.ntrial];
ages = [subjinfo.age];

subj_to_keep = ~isnan(recall) & ages > 0;

subjects = subjects(subj_to_keep);
recall = recall(subj_to_keep);
ages = ages(subj_to_keep);

% Analyze number of surface channels vs. recall
nsurface = nan(length(subjects), 1);
for isubj = 1:length(subjects)
    nsurface(isubj) = sum(~strcmpi('d', info.(subjects{isubj}).allchan.type));
end












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
chaninfo = cell(length(info.subj), 1);
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp(subject)

    filename = ['/Volumes/DATAHD/KAHANA/Release_Metadata_20160930/electrode_categories/electrode_categories_' subject '.txt'];
    fileID = fopen(filename);

    C = textscan(fileID, '%s');
    C = C{1};
    zone = find(strcmpi('zone', C));
    interictal = find(strcmpi('interictal', C));
    if interictal
        epileptic = C(zone + 1:interictal - 1);
        chaninfo{isubj} = kah_chaninfo(info, subject, epileptic);
    end
end

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


