clearvars('-except', 'info')

directions = {'AB', 'BA'};
outcomes = {'remembered', 'forgotten'};
timelock = {'stim', 'encoding'};

erpac = cell(length(info.subj), 1);

experiment = 'FR1';
timewin = [-800, 1600];

load([info.path.processed.hd 'FR1_phaseencoding_0_1600.mat'], 'phaseencoding')

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])
    
    load([info.path.processed.hd subject '_' experiment '_pac_between_er_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp_mean.mat'], 'pacbetween', 'chanpairs', 'trialinfo', 'chans', 'temporal', 'frontal', 'times')
    
    erpac{isubj} = struct;
    
    for idirection = 1:length(directions)
        for icorrect = 1:length(outcomes)
            for itime = 1:length(timelock)
                if itime == 1
                    toi = dsearchn(times(:), [0; 500]);
                    erpac{isubj}.(directions{idirection}).(outcomes{icorrect}).(timelock{itime}) = squeeze(mean(pacbetween(:, toi(1):toi(2), idirection, icorrect), 2));
                else     
                    erpac{isubj}.(directions{idirection}).(outcomes{icorrect}).(timelock{itime}) = nan(size(pacbetween, 1), 1);
                    for ipair = 1:size(pacbetween, 1)
                        onsetcurr = phaseencoding{isubj}.onset(ipair);
                        
                        if ~isnan(onsetcurr)
                            toi = dsearchn(times(:), [onsetcurr; onsetcurr + 0.1]);
                            if toi(2) == length(times)
                                error('Window too long')
                            end
                            erpac{isubj}.(directions{idirection}).(outcomes{icorrect}).(timelock{itime})(ipair) = squeeze(mean(pacbetween(ipair, toi(1):toi(2), idirection, icorrect), 2));
                        end
                    end
                end
            end
        end
    end
end
save([info.path.processed.hd 'FR1_erpac_between.mat'], 'erpac')
%%
clearvars('-except', 'info')

figure;
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    experiment = 'FR1';
    timewin = [-800, 1600];

    load([info.path.processed.hd subject '_' experiment '_pac_between_er_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp_mean.mat'], 'pacbetween', 'chanpairs', 'trialinfo', 'chans', 'temporal', 'frontal', 'times')
    
    paccurr = pacbetween(:, :, 1, 1);
    subplot(4, 5, isubj)
    plot(times, paccurr')
end

%%
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    experiment = 'FR1';
    timewin = [-800, 1600];

    [~, ~, ~, times] = kah_loadftdata(info, subject, 'thetaphase', timewin, 0);
    
    save([info.path.processed.hd subject '_' experiment '_pac_between_er_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp_mean.mat'], 'times', '-append')
end