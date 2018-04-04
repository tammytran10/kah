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

% For saving permutations.
permtrials = cell(length(info.subj), nperm);

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
    
    disp([num2str(isubj) ' ' subject])
    
    % Load subject HFA data.
    [~, trialinfo] = kah_loadftdata(info, subject, 'broadband', [], 0);
    
    % Get trial outcome (remembered/forgotten) info.
    encoding = trialinfo(:, 3);
          
    % Permute trial outcome 
    for iperm = 1:nperm     
        permtrials{isubj, iperm} = encoding(randperm(length(encoding)));
    end
end

save([info.path.processed.hd experiment '_trialperms_default_phaseencode.mat'], 'permtrials')
disp('Done.')
