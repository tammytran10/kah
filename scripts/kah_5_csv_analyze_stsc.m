%%
[~, trialinfo, chans, times] = deal(cell(length(info.subj), 1));
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp(subject)
    [~, trialinfo{isubj}, chans{isubj}, times{isubj}] = kah_loadftdata(info, subject, 'hfa', [-800, 1600], 1);
end
chanssave = chans;
%%
chans = chanssave;
timewins = {[-800, 0], [0, 800], [800, 1600]};

[thetaamp, hfa, slopes, pacwithin] = deal(cell(length(timewins), 1));
for iwin = 1:length(timewins)
    timewin = timewins{iwin};
    input = load([info.path.processed.hd 'FR1_thetaamp_cf_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat']);
    thetaamp{iwin} = input.thetaamp;

    input = load([info.path.processed.hd 'FR1_hfa_' num2str(timewin(1)) '_' num2str(timewin(2)) '_2_150.mat']);
    hfa{iwin} = input.hfa;
    
    input = load([info.path.processed.hd 'FR1_slopes_' num2str(timewin(1)) '_' num2str(timewin(2)) '_2_150.mat']);
    slopes{iwin} = input.slopes;
    
    pacwithin{iwin} = cell(length(info.subj), 1);
    input = load([info.path.processed.hd 'FR1_pac_within_ts_' num2str(timewin(1)) '_' num2str(timewin(2)) '_cf.mat']);
    for isubj = 1:length(info.subj)
        pacwithin{iwin}{isubj} = input.tspac{isubj}.raw;
    end
end

% Load theta center frequencies.
load([info.path.processed.hd 'FR1_thetabands_-800_1600_chans.mat'])
thetabump = cellfun(@(x) ~isnan(x(:, 1)), bands, 'UniformOutput', false);

for isubj = 1:length(info.subj)
    chans{isubj} = chans{isubj}(thetabump{isubj});
    for iwin = 1:length(timewins)
        thetaamp{iwin}{isubj} = thetaamp{iwin}{isubj}(thetabump{isubj}, :);
        hfa{iwin}{isubj} = hfa{iwin}{isubj}(thetabump{isubj}, :);
        slopes{iwin}{isubj} = slopes{iwin}{isubj}(thetabump{isubj}, :);
        pacwithin{iwin}{isubj} = pacwithin{iwin}{isubj}(thetabump{isubj}, :);
    end
end

%%
datacurr = pacwithin;

% Set subject.
isubj = 19;
subject = info.subj{isubj};

% Get sublobe names.
sublobes = {'ltl', 'lpfc'};
ax = [];

% Plot average HFA (correct vs. incorrect) across channels per region.
ctr = 0;
for iwin = 1:length(thetaamp)
    for isublobe = 1:length(sublobes)
        ctr = ctr + 1;
        axcurr = subplot(3, 2, ctr);
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

        %
        forgotten = median(datacurr{iwin}{isubj}(chancurr, ~encoding), 1);
        remembered = median(datacurr{iwin}{isubj}(chancurr, encoding), 1);
        pval = ranksum(forgotten, remembered);
        
        % Plot.
        histogram(forgotten, 20, 'FaceColor', [1, 0, 0], 'FaceAlpha', 0.75)
        histogram(remembered, 20, 'FaceColor', [0, 0, 1], 'FaceAlpha', 0.75)

        title([sublobe_curr ' ' num2str(median(forgotten)) ' ' num2str(median(remembered)) ' ' num2str(pval)])
    end
end
linkaxes(ax, 'xy');

%%
datacurr = pacwithin;
[pvals, teststats] = deal(nan(length(info.subj), 2, 2));

for isubj = 1:length(info.subj)
    % Set subject.
    subject = info.subj{isubj};
    
    if strcmpi(subject, 'R1120E') || strcmpi(subject, 'R1151E')
        continue
    end

    % Get sublobe names.
    sublobes = {'ltl', 'lpfc'};
%     ax = [];

    % Plot average HFA (correct vs. incorrect) across channels per region.
%     ctr = 0;
    for iwin = 2:length(thetaamp)
        for isublobe = 1:length(sublobes)
%             ctr = ctr + 1;
%             axcurr = subplot(2, 2, ctr);
%             ax = [ax; axcurr];
%             hold on

            % Get current region.
            sublobe_curr = sublobes{isublobe};

            % Get channels in current region across all channels.
            chancurr = info.(subject).allchan.label(strcmpi(sublobe_curr, info.(subject).allchan.sublobe));

            % Get channels in current region in clean surface channels.
            chancurr = ismember(chans{isubj}, chancurr);

            % Get correct vs. incorrect trial labels.
            encoding = logical(trialinfo{isubj}(:, 3));

            %
            forgotten = mean(datacurr{iwin}{isubj}(chancurr, ~encoding) - datacurr{1}{isubj}(chancurr, ~encoding), 1);
            remembered = mean(datacurr{iwin}{isubj}(chancurr, encoding) - datacurr{1}{isubj}(chancurr, encoding), 1);
%             [~, ~, stats] = ranksum(forgotten, remembered);
%             teststats(isubj, iwin - 1, isublobe) = stats.zval;
            try
                [~, pval, ~, stats] = ttest2(forgotten, remembered);
                pvals(isubj, iwin - 1, isublobe) = pval;
                teststats(isubj, iwin - 1, isublobe) = stats.tstat;

            catch
                continue
            end
%             % Plot.
%             histogram(forgotten, 20, 'FaceColor', [1, 0, 0], 'FaceAlpha', 0.75)
%             histogram(remembered, 20, 'FaceColor', [0, 0, 1], 'FaceAlpha', 0.75)
% 
%             title([sublobe_curr ' ' num2str(median(forgotten)) ' ' num2str(median(remembered)) ' ' num2str(pval)])
        end
    end
%     linkaxes(ax, 'xy');
end

%%
clc
[~, pval] = ttest(teststats(:, 1, 1))
[~, pval] = ttest(teststats(:, 1, 2))
[~, pval] = ttest(teststats(:, 2, 1))
[~, pval] = ttest(teststats(:, 2, 2))