% Script for loading raw Kahana data, applying filters, epoching, and removing bad trials.
% Options are for broadband (< 200 Hz), theta phase/amp (with individual bands option), and high gamma amplitude (multiple bands).
% The multiple bands for high gamma can be combined in kah_1_epoch_1_calculatehfa.m

clear; clc

% Load project info.
info = kah_info;

%%
clearvars('-except', 'info')

% Set current experiment.
experiment = 'FR1';

% Set which filters to apply and files to save.
dobroadband = 0;
dothetaphase = 0;
dothetaamp = 1;
dogammaamp = 0;

% Set whether to filter for theta using individual filters. In this case, kah_2_psd_1_calclatetheta_chans.m should have been run.
doindividualtheta = 0;

% Set whether to use multiple gamma bands, or one canonical.
domultigamma = 1;

% Set time window to epoch around word onset in ms.
timewin = [-1000; 2750];

%%
% Set theta bands (individual or default of 4-8 Hz), if necessary.
if dothetaphase || dothetaamp
    if doindividualtheta % individual center frequency
        load([info.path.processed.hd 'FR1_thetabands_-800_1600_chans.mat'])
        thetacfs = cellfun(@(x) nanmean(mean(x, 2)), bands);
        thetalabel = 'cf';
        
    else % canonical center frequency
        thetacfs = ones(length(info.subj), 1) * 6;
        thetalabel = 'canon';
    end
    
    % Set passband around center frequency.
    thetabands = [thetacfs - 2, thetacfs + 2];
end

% Set gamma bands to multiple 20-Hz wide bands, or one canonical, if necessary.
if domultigamma % multiple bands
    gammabands = ...
            [80, 100; ...
            90, 110; ...
            100, 120; ...
            110, 130; ...
            120, 140; ...
            130, 150]; 
    gammalabel = 'multi';

else % one canonical band
    gammabands = [80, 150];
    gammalabel = 'canon';
end
    
% Preprocess data per subject.
for isubj = 1:length(info.subj)
    subject = info.subj{isubj};
    disp([num2str(isubj) ' ' subject])
            
    % Pre-allocate. Processing for broadband (< 200 Hz), theta (4-8 Hz or individual) phase/amplitude,
    % and high gamma (80-150 Hz) amplitude.
    broadband  = struct;
    thetaphase = struct;
    thetaamp = struct;
    gammaamp   = cell(size(gammabands, 1), 1); % each element is a Fieldtrip struct, one per narrow band

    % Get broadband activity, theta phase, and gamma amplitude for each session.
    for isess = 1:length(info.(subject).(experiment).session)
        
        % Specify trial windows.
        cfg = [];
        cfg.header      = read_upennram_header(info.(subject).(experiment).session(isess).headerfile);
        cfg.event       = read_upennram_event(info.(subject).(experiment).session(isess).eventfile);
        cfg.encprestim  = abs(timewin(1))/1000;    % during encoding, the period in seconds before word onset
        cfg.encduration = abs(timewin(2))/1000; % during encoding, the period in seconds after word onset
        cfg.recprestim  = 1;    % during recall, the period in seconds before verbalization
        cfg.recduration = 0;    % during recall, the period in seconds after verbalization 

        % Get size (in seconds) of longest trial.
        wintime = cfg.encprestim + cfg.encduration;

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

        % Extract trial info for clean encoding trials.
        trl = cfg.trl;

        % Specify data directory and header file.
        cfg = [];
        cfg.datafile     = info.(subject).(experiment).session(isess).datadir;
        cfg.dataformat   = 'read_upennram_data';
        cfg.headerfile   = info.(subject).(experiment).session(isess).headerfile;
        cfg.headerformat = 'read_upennram_header';

        % Specify trial segmentation info.
        cfg.trl = trl;

        % Specify to de-mean the data.
        cfg.demean = 'yes';

        % Specify to keep only clean surface channels.
        surface = ~strcmpi('d', info.(subject).allchan.type);
        broken = ismember(info.(subject).allchan.label, ft_channelselection(info.(subject).badchan.broken, info.(subject).allchan.label));
        epileptic = ismember(info.(subject).allchan.label, ft_channelselection(info.(subject).badchan.epileptic, info.(subject).allchan.label));
        
        cfg.channel = info.(subject).allchan.label(surface & ~(broken | epileptic));
        
        % Specify average referencing channels (all clean surface only).
        cfg.reref      = 'yes';
        cfg.refchannel = 'all';

        % Set data padding parameters for filtering. Use edge length for bandstop filters (this is
        % longer than the filters for theta and gamma.
        cfg.padding = wintime + (info.(subject).(experiment).bsfilt.edge * 2);

        % Set bandstop filtering parameters for line spectra.
        cfg.bsfilter    = 'yes';
        cfg.bsfreq      = [(info.(subject).(experiment).bsfilt.peak - info.(subject).(experiment).bsfilt.halfbandw).', ...
            (info.(subject).(experiment).bsfilt.peak + info.(subject).(experiment).bsfilt.halfbandw).'];
        cfg.bsfilttype  = 'but';
        cfg.bsfiltord   = 2;
        cfg.bsfiltdir   = 'twopass';
        
        % Get broadband data.
        if dobroadband
            % Remove pre-existing filter parameters.
            if isfield(cfg, 'bpfilter')
                cfg = rmfield(cfg, {'bpfilter', 'bpfreq', 'bpfilttype'});
            end
            
            % Set lowpass filtering parameters and preprocess.
            cfg.lpfilter    = 'yes';
            cfg.lpfreq      = 200;
            cfg.lpfilttype  = 'firws';
            broadbandcurr = ft_preprocessing(cfg);

            % Combine trials from multiple sessions, if necessary.
            if isess == 1
                broadband = broadbandcurr;
            else
                broadband = ft_appenddata([], broadband, broadbandcurr);
            end
            clear broadbandcurr
        end

        % Get thetaband data.
        if dothetaphase || dothetaamp
            % Remove pre-existing filter parameters.
            if isfield(cfg, 'lpfilter')
                cfg = rmfield(cfg, {'lpfilter', 'lpfreq', 'lpfilttype'});
            end
            
            % Set theta bandpass filtering parameters.
            cfg.bpfilter      = 'yes';
            cfg.bpfreq        = thetabands(isubj, :);
            cfg.bpfilttype    = 'firws';
            cfg.bpfiltwintype = 'hamming';
            
            % Calculate theta phase.
            if dothetaphase
                cfg.hilbert = 'angle';    
                thetacurr   = ft_preprocessing(cfg);
                
                % Combine trials from multiple sessions, if necessary.
                if isess == 1
                    thetaphase = thetacurr;
                else
                    thetaphase = ft_appenddata([], thetaphase, thetacurr);
                end
                clear thetacurr
            end
            
            % Calculate theta amplitude.
            if dothetaamp
                cfg.hilbert = 'abs';
                thetacurr   = ft_preprocessing(cfg);
                
                % Combine trials from multiple sessions, if necessary.
                if isess == 1
                    thetaamp = thetacurr;
                else
                    thetaamp = ft_appenddata([], thetaamp, thetacurr);
                end
                clear thetacurr
            end
        end

        % Get gamma-band data.
        if dogammaamp
            for iband = 1:size(gammabands, 1)
                % Remove pre-existing filter parameters.
                if isfield(cfg, 'lpfilter')
                    cfg = rmfield(cfg, {'lpfilter', 'lpfreq', 'lpfilttype'});
                end
                    
                % Set gamma bandpass filtering parameters and preprocess.
                cfg.bpfilter      = 'yes';
                cfg.bpfreq        = gammabands(iband,:);
                cfg.bpfilttype    = 'firws';
                cfg.bpfiltwintype = 'hamming';
                cfg.bpfiltord     = round(info.(subject).fs ./ 1000 * 100 * 2)/2; % floor(info.(subject).fs ./ 1000 * 100);
                cfg.hilbert       = 'abs';
                gammaampcurr = ft_preprocessing(cfg);
                                
                % Combine trials from multiple sessions, if necessary.
                if isess == 1
                    gammaamp{iband} = gammaampcurr;
                else
                    gammaamp{iband} = ft_appenddata([], gammaamp{iband}, gammaampcurr);
                end
                clear gammaampcurr
            end
        end
    end

    pathname = [info.path.processed.hd subject '/' subject '_' experiment]; % common file name start
    endname = ['_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'];
    
    % Save broadband data, if necessary. 
    if dobroadband
        save([pathname '_broadband' endname], 'broadband', '-v7.3')
    end

    % Save theta phase data, if necessary.
    if dothetaphase
        save([pathname '_thetaphase_' thetalabel endname], 'thetaphase', '-v7.3')
    end

    % Save theta amplitude data, if necessary.
    if dothetaamp
        save([pathname '_thetaamp_' thetalabel endname], 'thetaamp', '-v7.3')
    end
    
    % Save gamma amplitude data, if necessary.
    if dogammaamp     
        if ~domultigamma
            gammaamp = gammaamp{1}; % just save a struct if there's only one
        end
        save([pathname '_gammaamp_' gammalabel endname], 'gammaamp', '-v7.3')
    end
end
disp('Done.')

