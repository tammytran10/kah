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

subtrials = nan(length(info.subj), 2, nperm, ntrialsub);

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    disp([num2str(isubj) ' ' subject])
    
    % Load subject HFA data.
    load([info.path.processed subject '_' experiment '_hfa_-800_1600.mat'], 'hfa')
          
    for iperm = 1:nperm        
        for icorrect = 1:2           
            trialcurr = hfa.trialinfo(:, 3) == (2 - icorrect); % correct vs. incorrect (in that order)
            subtrials(isubj, icorrect, iperm, :) = randperm(sum(trialcurr), ntrialsub);   
        end       
    end
end

save([info.path.processed experiment '_trialsubsets_default_pac.mat'], 'subtrials')
disp('Done.')
