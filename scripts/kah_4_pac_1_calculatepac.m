clear

% Load Kahana info.
info = kah_info;

%%
clearvars('-except', 'info')

% if isempty(gcp), parpool('local', 2); end % open up second pool

% Set experiment.
experiment = 'FR1';

% Set number of resampling runs.
load([info.path.processed.hd experiment '_trialsubsets_default_pac.mat'], 'subtrials')
nperm = size(subtrials, 3);
ntrialsub = size(subtrials, 4);

for isubj = 1:length(info.subj)
    % Get current subject identifier.
    subject = info.subj{isubj};
        
    % Choose time window.
    timewin = [-800, 1600]; % ms
    
    % Skip subject if all permutations have already been run. 
    if exist([info.path.processed.hd subject '_' experiment '_pac_between_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp_' num2str(nperm) '.mat'], 'file')
        disp(['Skipping ' subject])
        continue
    end

    disp([num2str(isubj) ' ' subject])

    % Load subject theta phase and HFA data.
    [thetaphase, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'thetaphase', timewin, 1);
    hfaamp = kah_loadftdata(info, subject, 'hfa', timewin, 1);

    ntrial = size(trialinfo, 1);
    encoding = trialinfo(:, 3);
    nchan = length(chans);
    nsamp = length(times);
    
    % Calculate within-channel PAC.
    pacwithin = nan(nchan, nsamp, 2, nperm);
    for icorrect = 1:2
        trialcurr = encoding == (2 - icorrect); % correct vs. incorrect (in that order)
        for iperm = 1:nperm
            subtrialcurr = subtrials(isubj, icorrect, iperm, :);
            for ichan = 1:nchan
                phasecurr = squeeze(thetaphase(ichan, :, trialcurr));
                ampcurr = squeeze(hfaamp(ichan, :, trialcurr));
                for isamp = 1:nsamp
                    pacwithin(ichan, isamp, icorrect, iperm) = abs(sum(ampcurr(isamp, subtrialcurr) .* exp(1i .* phasecurr(isamp, subtrialcurr)))) / (sqrt(ntrialsub) * sqrt(sum(ampcurr(isamp, subtrialcurr) .^ 2)));
                end
            end           
        end
    end
    save([info.path.processed.hd subject '_' experiment '_pac_within_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp.mat'], 'pacwithin', 'times', 'trialinfo', 'chans')
    clear pacwithin
        
    % Get all unique pairs of channels.
    chanpairs = nchoosek(1:nchan, 2);
    nchanpair = size(chanpairs, 1);
       
    % Calculate between-channel PAC in both directions for all channel pairs and trial subsets.
    for iperm = 1:nperm
        % Skip permutation if already run.
        filecurr = [info.path.processed.hd subject '_' experiment '_pac_between_' num2str(timewin(1)) '_' num2str(timewin(2)) '_resamp_' num2str(iperm) '.mat'];
        if exist(filecurr, 'file')
            disp(['Skipping ' subject ' ' num2str(iperm) '/' num2str(nperm)])
            continue
        end
        
        % Calculate separately for correct and incorrect trials.
        pacbetween = nan(nchanpair, nsamp, 2, 2);
        
        for icorrect = 1:2
            disp([num2str(isubj) ' ' subject ' ' num2str(iperm) '/' num2str(nperm) ' ' num2str(icorrect)])
           
            % Get current trial subset. 
            trialcurr = encoding == (2 - icorrect); % correct vs. incorrect (in that order)
            subtrialcurr = subtrials(isubj, icorrect, iperm, :);            
            
            % Switch phase and amp data based on direction.
            for idirection = 1:2
                if idirection == 1
                    phasechan = 1; ampchan = 2;
                else
                    phasechan = 2; ampchan = 1;
                end
                
                for ipair = 1:nchanpair                    
                    phasecurr = squeeze(thetaphase(chanpairs(ipair, phasechan), :, trialcurr));
                    ampcurr = squeeze(hfaamp(chanpairs(ipair, ampchan), :, trialcurr));
                    
                    % Calculate PAC across trials per sample.
                    for isamp = 1:nsamp
                        pacbetween(ipair, isamp, idirection, icorrect) = abs(sum(ampcurr(isamp, subtrialcurr) .* exp(1i .* phasecurr(isamp, subtrialcurr)))) / (sqrt(ntrialsub) * sqrt(sum(ampcurr(isamp, subtrialcurr) .^ 2)));
                    end
                end
            end
        end
        
        % Save.
        save(filecurr, 'pacbetween', 'chanpairs', 'times', 'trialinfo', 'chans')
    end
end
disp('Done.')
