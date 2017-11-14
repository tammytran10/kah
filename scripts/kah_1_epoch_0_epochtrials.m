%%
% Script for loading raw Kahana data, applying filters, epoching, and removing bad trials.
% Options are for broadband (< 200 Hz), theta phase (with individual bands option), and high gamma amplitude (multiple bands).
% The multiple bands for high gamma can be combined in kah_1_epoch_1_calculatehfa.m

clear; clc

% Load project info.
info = kah_info;

%%
clearvars('-except', 'info')

% Set current experiment.
experiment = 'FR1';

% Set which filters to apply and files to save.
bandtype = 'theta'; % broad, theta, gamma

% Set whether to filter for theta using individual filters. In this case, kah_2_psd_1_calclatethetabands.m should have been run.
doindividualtheta = 1;

% Set whether to use multiple gamma bands, or one canonical.
domultigamma = 1;

switch bandtype
    % Set theta bands (individual or default of 4-8 Hz), if necessary.
    case 'theta'
        if doindividualtheta
            load([info.path.processed.hd 'FR1_thetabands_-800_1600.mat'])
            thetacfs = cellfun(@(x) nanmean(mean(x, 2)), bands);
        else
            thetacfs = ones(length(info.subj), 1) * 6;
        end
        bands = [thetacfs - 2, thetacfs + 2];
        
        % Set gamma bands to multiple 20-Hz wide bands, or one canonical.
    case 'gamma'
        if domultigamma
            bands = ...
                [80, 100; ...
                90, 110; ...
                100, 120; ...
                110, 130; ...
                120, 140; ...
                130, 150];
        else
            bands = [80, 150];
        end
end

% Preprocess data per subject.
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])
    
    % Pre-allocate. Processing for broadband (< 200 Hz), theta (4-8 Hz) phase,
    % and high gamma (80-150 Hz) amplitude.
    data = cell(size(bands, 1), 1);
    
    % Get broadband activity, theta phase, and gamma amplitude for each session.
    for isess = 1:length(info.(subject).(experiment).session)
        
        % Figure out which trials to keep.
        % Specify trial windows.
        cfg = [];
        cfg.header      = read_upennram_header(info.(subject).(experiment).session(isess).headerfile);
        cfg.event       = read_upennram_event(info.(subject).(experiment).session(isess).eventfile);
        cfg.encprestim  = 0.8;    % during encoding, the period in seconds before word onset
        cfg.encduration = 1.6; % during encoding, the period in seconds after word onset
        cfg.recprestim  = 1;    % during recall, the period in seconds before verbalization
        cfg.recduration = 0;    % during recall, the period in seconds after verbalization
        
        % Obtain the trl matrix, which contains the segmentation details.
        trl = rmr_upennram_trialfun(cfg);
        
        % Specify encoding trials only.
        trl = trl(trl(:, 4) == 1, :);
        
        % Remove recall trials and trials with artifacts.
        cfg              = [];
        cfg.trl          = trl;
        cfg.dataformat   = 'read_upennram_data';
        cfg.headerformat = 'read_upennram_header';
        cfg.headerfile   = info.(subject).(experiment).session(isess).headerfile;
        cfg.datafile     = info.(subject).(experiment).session(isess).datadir;
        cfg.artfctdef.xxx.artifact = ...
            info.(subject).(experiment).session(isess).badsegment;
        cfg = ft_rejectartifact(cfg);
        
        % Find which trials to keep.
        trialkeep = ismember(trl(:, 1), cfg.trl(:, 1));
        clear trl
        
        % Specify looooong trial windows to load and eventually filter.
        cfg = [];
        cfg.header      = read_upennram_header(info.(subject).(experiment).session(isess).headerfile);
        cfg.event       = read_upennram_event(info.(subject).(experiment).session(isess).eventfile);
        cfg.encprestim  = 10;    % during encoding, the period in seconds before word onset
        cfg.encduration = 10; % during encoding, the period in seconds after word onset
        cfg.recprestim  = 1;    % during recall, the period in seconds before verbalization
        cfg.recduration = 0;    % during recall, the period in seconds after verbalization
        trl = rmr_upennram_trialfun(cfg);
        trl = trl(trl(:, 4) == 1, :);
        
        % Specify data directory and header file.
        cfg = [];
        cfg.datafile     = info.(subject).(experiment).session(isess).datadir;
        cfg.dataformat   = 'read_upennram_data';
        cfg.headerfile   = info.(subject).(experiment).session(isess).headerfile;
        cfg.headerformat = 'read_upennram_header';
        
        % Specify trial segmentation info for long trials.
        cfg.trl = trl(1:5, :);
        
        % Specify to de-mean the data.
        cfg.demean = 'yes';
        
        % Specify to keep only clean surface channels.
        surface = ~strcmpi('d', info.(subject).allchan.type);
        bad = ismember(info.(subject).allchan.label, info.(subject).badchan.all);
        cfg.channel = info.(subject).allchan.label(surface & ~bad);
        
        % Specify average referencing channels (all clean surface only).
        cfg.reref      = 'yes';
        cfg.refchannel = 'all';
        
        % Load data.
        datasess = ft_preprocessing(cfg);
        
        % Keep only clean trials.
        datasess.trialinfo = datasess.trialinfo(trialkeep, :);
        datasess.trial = datasess.trial(trialkeep);
        datasess.time = datasess.time(trialkeep);
        
        for itrial = 1:length(datasess.trial)
            datasess.fsample = 500;
            datasess.trial{itrial} = ft_preproc_resample(datasess.trial{itrial}, 1000, datasess.fsample, 'resample');
            datasess.time{itrial} = linspace(-10, 10, length(datasess.trial{itrial}));
            
            datasess.trial{itrial} = ft_preproc_bandstopfilter(datasess.trial{itrial}, datasess.fsample, ...
                [(info.(subject).(experiment).bsfilt.peak - info.(subject).(experiment).bsfilt.halfbandw).', ...
                (info.(subject).(experiment).bsfilt.peak + info.(subject).(experiment).bsfilt.halfbandw).'], ...
                2, 'but', 'twopass', 'no');
            
            for iband = 1:length(data)
                switch bandtype
                    case 'broad'
                        datasess.trial{itrial} = ft_preproc_lowpassfilter(datasess.trial{itrial}, datasess.fsample, 200, [], 'firws', [], []);
                    case 'theta'
                        datasess.trial{itrial} = ft_preproc_bandpassfilter(datasess.trial{itrial}, datasess.fsample, bands(isubj, :), [], 'firws', [], []);
                    case 'gamma'
                        datasess.trial{itrial} = ft_preproc_bandpassfilter(datasess.trial{itrial}, datasess.fsample, bands(iband,:), round(info.(subject).fs ./ 1000 * 100 * 2)/2, 'firws', [], []);
                end
            end
            
            
            
        end
        
        cfg = [];
        cfg.toilim = [-1, 2.75] ./ 1000;
        cfg.toilim(2) = cfg.toilim(2) - 1/databand.fsample; % so that sample number is exactly srate or srate/2, etc.
        databand = ft_redefinetrial(cfg, databand);
        if isess == 1
            data{iband} = databand;
        else
            data{iband} = ft_appenddata([], data{iband}, databand);
        end
    end
end

% Save broadband data, if necessary.
if dobroadband
    save([info.path.processed.hd '-1000_2750/' subject '_' experiment '_broadband.mat'], 'broadband', '-v7.3')
end

% Save theta phase data, if necessary.
if dothetaphase
    save([info.path.processed.hd '-1000_2750/' subject '_' experiment '_thetaphase.mat'], 'thetaphase', '-v7.3')
end

% Save gamma amplitude data, if necessary.
if dogammaamp
    if ~domultigamma
        gammaamp = gammaamp{1}; % just save a struct if there's only one
        save([info.path.processed.hd '-1000_2750/' subject '_' experiment '_gammaamp_single.mat'], 'gammaamp', '-v7.3')
    else
        save([info.path.processed.hd '-1000_2750/' subject '_' experiment '_gammaamp_multi.mat'], 'gammaamp', '-v7.3')
    end
end
end
disp('Done.')

