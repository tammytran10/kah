%% Clear workspace and load info about Project Kahana.
clear; clc

info = kah_info;

%% Choose subject and load broadband data.
clearvars('-except', 'info')

% Set time window of interest.
timewin = [300, 1300];

% Set band of interest for plotting PSD and calculating slope.
freqoi = [30; 50];
pad = 'yes';
resolution = 0.05;

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};

    disp([num2str(isubj) ' ' subject])

    % Load broadband data in Fieldtrip format.
    [data, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'broadband', timewin, 0);

    ntrial = size(trialinfo, 1);
    nchan = length(chans);
    nsamp = length(times);

    switch pad
        % Construct power spectra using Hanning-windowed, non-padded FFT using native frequency resolution.
        case 'no'
            cfg = [];
            cfg.method = 'mtmfft';
            cfg.foilim = [0, data.fsample/2];
            cfg.taper = 'hanning';
            cfg.keeptrials = 'yes';
            psds = ft_freqanalysis(cfg, data);
            
        % Construct power spectra using Hanning-windowed, padded FFT to construct arbitrary frequency axis.
        case 'yes'
            cfg = [];
            cfg.method = 'mtmfft';
            cfg.foi = round(10 .^ linspace(log10(freqoi(1)), log10(freqoi(2)), 20) ./ resolution) * resolution;
            cfg.keeptrials = 'yes';
            cfg.pad = 1/resolution;
            cfg.taper = 'hanning';
            psds = ft_freqanalysis(cfg, data);
    end
    
    % Extract frequency axis and PSDs from Fieldtrip format.
    freq = psds.freq;
    psds = permute(nanmean(psds.powspctrm, 4), [2, 3, 1]); % converting to format 'chan x frequency x trial'
    
    % Indicate notched frequencies to be avoided during slope fitting.
    fexclude = [(info.(subject).FR1.bsfilt.peak - info.(subject).FR1.bsfilt.halfbandw).', ...
            (info.(subject).FR1.bsfilt.peak + info.(subject).FR1.bsfilt.halfbandw).'];
    
    % Calculate slope.
    slopes = nan(nchan, ntrial);
    for ichan = 1:nchan
        for itrial = 1:ntrial
            switch pad
                case 'no'
                    [slopes(ichan, itrial)] = util_slopefit(freq, squeeze(psds(ichan, :, itrial)), freqoi, fexclude, 'robust');
                case 'yes'
                    [B, S] = robustfit(log10(freq), log10(squeeze(psds(ichan, :, itrial))));
                    slopes(ichan, itrial) = B(2);
            end
        end
    end
    
    save([info.path.processed.hd subject '_FR1_slope_' num2str(timewin(1)) '_' num2str(timewin(2)) '_' pad '.mat'], 'timewin', 'freqoi', 'trialinfo', 'times', 'freq', 'psds', 'slopes', 'chans', 'temporal', 'frontal')
end
disp('Done')
