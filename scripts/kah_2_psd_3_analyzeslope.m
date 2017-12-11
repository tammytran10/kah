clear; clc

info = kah_info;

%%
clearvars('-except', 'info')

timewin = [-800, 0];

slopes = cell(length(info.subj), 1);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    input = load([info.path.processed.hd subject '_FR1_slope_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'temporal', 'frontal', 'slopes', 'trialinfo');
    slopes{isubj} = input.slopes;
end

save([info.path.processed.hd 'FR1_slopes_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'slopes')
%%
clearvars('-except', 'info')

timewin = [300, 1300];

vals = nan(length(info.subj), 2);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    load([info.path.processed subject '_FR1_slope_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'temporal', 'frontal', 'slopes', 'trialinfo')
    
    recall = logical(trialinfo(:, 3));
    nchan = length(temporal);
    
    teststats = nan(nchan, 1);
    for ichan = 1:nchan
%         [~, ~, ~, stats] = ttest2(slopes(ichan, recall), slopes(ichan, ~recall), 'vartype', 'unequal');
%         teststats(ichan) = stats.tstat;
        [~, ~, stats] = ranksum(slopes(ichan, recall), slopes(ichan, ~recall));
        teststats(ichan) = stats.zval;
    end

    vals(isubj, 1) = mean(teststats(temporal));
    vals(isubj, 2) = mean(teststats(frontal));
end

[~, p] = ttest(vals(:, 1))
[~, p] = ttest(vals(:, 2))

%%
[rho, p] = corr(info.age, vals(:, 1), 'type', 'Spearman')

%%
clearvars('-except', 'info')

timewin = [-800, 0];

meanslopes = nan(length(info.subj), 2);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    load([info.path.processed subject '_FR1_slope_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'slopes', 'temporal', 'frontal')    
    
    meanslopes(isubj, 1) = median(median(slopes(temporal, :), 2));
    meanslopes(isubj, 2) = median(median(slopes(frontal, :), 2));
end

load('fr1_subjinfo.mat')
subjcurr = ismember({subjinfo.subj}, info.subj);
acc = [subjinfo(subjcurr).ncorrect] ./ [subjinfo(subjcurr).ntrial];
acc = acc(:);

%%
subjcurr = true(length(info.subj), 1); 
% subjcurr = ~ismember(info.subj, info.subj(abs(zscore(acc)) > 1.5));
% subjcurr = [1:6, 8, 10, 12:20];
thing1 = meanslopes(subjcurr, 1);
thing2 = acc(subjcurr);

figure; hold on
scatter(thing1, thing2, 'k', 'filled')
coeff = robustfit(thing1, thing2);
plot(thing1, coeff(1) + coeff(2)*thing1, 'k')
% ylim([0, 0.5])
% for isubj = 1:length(thing1)
%     scatter(thing1(isubj), thing2(isubj), 'filled')
% %     text(thing1(isubj), thing2(isubj), info.subj{isubj})
% end

[rho, p] = corr(thing1, thing2, 'type', 'Spearman')

%%
[z, p] = util_corrdiff(-0.1822, -0.4060, 20, 20)
%%
tbl = table(info.age, meanslopes(:, 1), meanslopes(:, 2), acc, 'VariableNames', {'age', 'temporal', 'frontal', 'acc'});
lm = fitlm(tbl, 'acc~age+temporal')

%%
lm = fitlm([info.age(subjcurr), meanslopes(subjcurr, :)], acc(subjcurr))

meanslopes = nan(length(info.subj), 2);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    load([info.path.processed subject '_FR1_slope_-800_0.mat'], 'slopes', 'temporal', 'frontal')    
    
    preslopes = slopes;
    
    load([info.path.processed subject '_FR1_slope_300_1300.mat'], 'slopes', 'temporal', 'frontal')    
    
    postslopes = slopes;
    
    clear slopes
    
    meanslopes(isubj, 1) = median(median(postslopes(temporal, :) - preslopes(temporal, :), 2));
    meanslopes(isubj, 2) = median(median(postslopes(frontal, :) - preslopes(frontal, :), 2));
end

load('fr1_subjinfo.mat')
subjcurr = ismember({subjinfo.subj}, info.subj);
acc = [subjinfo(subjcurr).ncorrect] ./ [subjinfo(subjcurr).ntrial];
acc = acc(:);

%%
subjcurr = true(length(info.subj), 1); 
% subjcurr = ~ismember(info.subj, {'R1032D'});
thing1 = meanslopes(subjcurr, 1);
thing2 = acc(subjcurr);

figure; hold on
for isubj = 1:length(thing1)
    scatter(thing1(isubj), thing2(isubj), 'filled')
    text(thing1(isubj), thing2(isubj), info.subj{isubj})
end

[rho, p] = corr(thing1, thing2, 'type', 'Spearman')

clear; clc

info = kah_info;

%%
clearvars('-except', 'info')

timewin = [0, 2400];

meanslopes = nan(length(info.subj), 2);
varslopes = nan(length(info.subj), 2);

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    load([info.path.processed subject '_FR1_slope_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'slopes', 'temporal', 'frontal', 'teststats', 'trialinfo')    

    recall = logical(trialinfo(:, 3));
    
    meanslopes(isubj, 1) = median(median(slopes(temporal, :), 2));
    meanslopes(isubj, 2) = median(median(slopes(frontal, :), 2));
    varslopes(isubj, 1) = median(iqr(slopes(temporal, :), 2));
    varslopes(isubj, 2) = median(iqr(slopes(frontal, :), 2));
end

vals = nan(length(info.subj), 2);

timewin = [300, 1300];

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    load([info.path.processed subject '_FR1_slope_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'slopes', 'temporal', 'frontal', 'teststats', 'trialinfo')    

    recall = logical(trialinfo(:, 3));

    vals(isubj, 1) = mean(teststats(temporal));
    vals(isubj, 2) = mean(teststats(frontal));
end

load('fr1_subjinfo.mat')
subjcurr = ismember({subjinfo.subj}, info.subj);
acc = [subjinfo(subjcurr).ncorrect] ./ [subjinfo(subjcurr).ntrial];
acc = acc(:);

%%
subjcurr = true(length(info.subj), 1); 
% subjcurr = ~ismember(info.subj, 'R1080E');
thing1 = meanslopes(subjcurr, 1);
thing2 = vals(subjcurr, 1);

figure; hold on
for isubj = 1:length(thing1)
    scatter(thing1(isubj), thing2(isubj), 'filled')
    text(thing1(isubj), thing2(isubj), info.subj{isubj})
end

[rho, p] = corr(thing1, thing2, 'type', 'Pearson')

%%
[z, p] = util_corrdiff(-0.1822, -0.4060, 20, 20)
%%
tbl = table(info.age, meanslopes(:, 1), meanslopes(:, 2), acc, 'VariableNames', {'age', 'temporal', 'frontal', 'acc'});
lm = fitlm(tbl, 'acc~age+temporal')

%%
lm = fitlm([info.age(subjcurr), meanslopes(subjcurr, :)], acc(subjcurr))


figure; hold on
hist(teststats(temporal), 8)
h = findobj(gca,'Type','patch');
set(h,'FaceColor','k','EdgeColor', 'k', 'facealpha', 0.75)
% ylim([0, 4])
plot([mean(teststats), mean(teststats)], [0, 7], 'k')

figure(2); clf
hold on
for ichan = 9
%     subplot(nrow, ncol, ichan)
    histogram(slopes(ichan,~recall), 20, 'FaceColor', [1, 0, 0], 'FaceAlpha', 0.75)
%     h = findobj(gca,'Type','patch');
%     set(h,'FaceColor','r','EdgeColor', 'w', 'facealpha', 0.75)
%     hold on
    histogram(slopes(ichan,recall), 20, 'FaceColor', [0, 0, 1], 'FaceAlpha', 0.75)
%     h = findobj(gca,'Type','patch');
%     set(h,'FaceColor', 'k', 'facealpha', 0.75)  
%     title(titles{ichan})
plot([mean(slopes(ichan,~recall)), mean(slopes(ichan,~recall))], [0, 30], 'k')
plot([mean(slopes(ichan,recall)), mean(slopes(ichan,recall))], [0, 30], 'k')

end


%% Clear workspace and load info about Project Kahana.
clear; clc

info = kah_info;

%% Choose subject and load broadband data.
clearvars('-except', 'info')

subject = 'R1020J';
timewin = [-800, 1600];

load([info.path.processed.hd subject '_FR1_psd_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'trialinfo', 'times', 'dat', 'freq', 'psds', 'chans', 'temporal', 'frontal')

%% Construct power spectra, calculate slope over a specified range, split into correct vs. incorrect, calculate t-stat.

% Set band of interest for plotting PSD and calculating slope.
freqoi = [30; 50];

% Calculate slope.
slopes = nan(nchan, ntrial);
for ichan = 1:nchan
    for itrial = 1:ntrial
        slopes(ichan, itrial) = util_slopefit(freq, squeeze(psds(ichan,:,itrial)), freqoi, [], 'robust');
    end
end

% Calculate t-stat for slope for correct vs. incorrect.
recall = logical(trialinfo(:,3));
ncorrect = sum(recall);

teststats = nan(nchan, 1);
for ichan = 1:nchan
%     [~, ~, ~, stats] = ttest2(slopes(ichan, recall), slopes(ichan, ~recall), 'vartype', 'unequal');
%     tstats(ichan) = stats.tstat;
    [~, ~, stats] = ranksum(slopes(ichan, recall), slopes(ichan, ~recall));
    teststats(ichan) = stats.zval;
end
[~, pvals(1)] = ttest(teststats(temporal));
[~, pvals(2)] = ttest(teststats(frontal));

% Calculate p-values for slope for correct vs. incorrect using permutation.
niteration = 1000;
teststatsrand = nan(nchan, niteration);
for it = 1:niteration
    randtrial = randperm(ntrial);
    trial1 = randtrial(1:ncorrect);
    trial2 = randtrial((ncorrect + 1):end);
    
    for ichan = 1:nchan
%         [~, ~, ~, stats] = ttest2(slopes(ichan, trial1), slopes(ichan, trial2), 'vartype', 'unequal');
%         teststatsrand(ichan, it) = stats.tstat;
        [~, ~, stats] = ranksum(slopes(ichan, trial1), slopes(ichan, trial2));
        teststatsrand(ichan, it) = stats.zval;
    end
end

pvalsrand = nan(nchan, 1);
for ichan = 1:nchan
    pvalsrand(ichan) = 2 * (1 - sum(teststats(ichan) > teststatsrand(ichan,:))/niteration);
end

%% Plot PSDs in frequency band of interest, slope histograms, and t-stat histogram.

% Plots PSDs.
freqplot = freqoi;
freqplot = dsearchn(freq(:), freqplot);
freqplot = freqplot(1):freqplot(2);

titles = cell(nchan, 1);
for ichan = 1:nchan
    if pvalsrand(ichan) < 0.05
        color = 'magenta';
    else
        color = 'black';
    end
    titles{ichan} = ['\color{' color '}' chans{ichan} ' ' regions{ichan} ' ' num2str(teststats(ichan)) ' ' num2str(pvalsrand(ichan))];
end
    
figure(1); clf
ncol = 10;
nrow = ceil(nchan/ncol);
for ichan = 1:nchan
    subplot(nrow, ncol, ichan)
    hold on
    plot((freq(freqplot)), log10(squeeze(median(psds(ichan,freqplot,recall), 3))))
    plot((freq(freqplot)), log10(squeeze(median(psds(ichan,freqplot,~recall), 3))))
%     title(titles{ichan})
end

% Plot slopes. 
figure(2); clf

for ichan = 1:nchan
    subplot(nrow, ncol, ichan)
    hist(slopes(ichan,~recall), 20)
    h = findobj(gca,'Type','patch');
    set(h,'FaceColor','r','EdgeColor', 'w', 'facealpha', 0.75)
    hold on
    hist(slopes(ichan,recall), 20)
    h = findobj(gca,'Type','patch');
    set(h,'facealpha', 0.75)  
    title(titles{ichan})
end

% Plot t-stats.
figure(3); clf 
subplot(1, 2, 1)
hist(teststats(temporal))
title(['Temporal: p = ' num2str(pvals(1))])
subplot(1, 2, 2)
hist(teststats(frontal))
title(['Frontal: p = ' num2str(pvals(2))])

% Plot t-stats on cortical surface.
figure(4); hold on

mesh = ft_read_headshape({info.(subject).lsurffile, info.(subject).rsurffile});
ft_plot_mesh(mesh, 'facecolor', [0.781 0.762 0.664], 'EdgeColor', 'none')
view([-90 25])
lighting gouraud
material shiny
camlight

for ichan = 1:nchan
    coords = info.(subject).allchan.ind.xyz;
    if teststats(ichan) > 0
        color = 'g';
    else
        color = 'r';
    end
    plot3(coords(ichan, 1), coords(ichan, 2), coords(ichan, 3), 'o', 'markerfacecolor', color, 'markeredgecolor', [0 0 0], 'markersize', abs(teststats(ichan)) * 20);
    text(coords(ichan, 1), coords(ichan, 2), coords(ichan, 3), chans{ichan}, 'fontsize', 8);
end

clear

info = kah_info;

%%
subj = subject;
eleccurr = ~strcmpi('D', info.(subj).allchan.type);

%%
figure
elec = [];
elec.label = info.(subj).allchan.label(eleccurr);
elec.elecpos = info.(subj).allchan.ind_0x2E_dural.xyz(eleccurr,:);
elec.unit = 'mm';

mesh = ft_read_headshape({info.(subj).lsurffile, info.(subj).rsurffile});
ft_plot_mesh(mesh, 'facecolor', [0.781 0.762 0.664], 'EdgeColor', 'none')
view([-90 25])
lighting gouraud
material shiny
camlight

% plot electrodes
hs = ft_plot_sens(elec, 'style', 'ko', 'label', 'on');
set(hs, 'MarkerFaceColor', 'k', 'MarkerSize', 6);

