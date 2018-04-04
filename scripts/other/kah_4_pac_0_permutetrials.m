clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

rng('default')

% Set experiment.
experiment = 'FR1';

% Set number of resampling runs.
nperm = 100;
ntrialsub = 20;

% For trial indices of subsets.
subtrials = nan(length(info.subj), 2, nperm, ntrialsub);

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    disp([num2str(isubj) ' ' subject])
    
    % Load subject HFA data.
    [~, trialinfo] = kah_loadftdata(info, subject, 'hfa', [-800, 1600], 0);
    for iperm = 1:nperm        
        for icorrect = 1:2           
            trialcurr = trialinfo(:, 3) == (2 - icorrect); % correct vs. incorrect (in that order)
            subtrials(isubj, icorrect, iperm, :) = randperm(sum(trialcurr), ntrialsub);   
        end       
    end
end

save([info.path.processed.hd experiment '_trialsubsets_default_pac.mat'], 'subtrials')
disp('Done.')
