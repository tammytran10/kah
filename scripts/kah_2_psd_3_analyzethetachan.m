clearvars('-except', 'info')

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