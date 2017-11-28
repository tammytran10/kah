%% Script for constructing and saving PSDs using a full time window of interest.
clear; clc

info = kah_info;

%% Choose subject and load broadband data.
clearvars('-except', 'info')

% Set time window of interest.
timewin = [-800, 0];

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};

    disp([num2str(isubj) ' ' subject])

    % Load relevant data and metadata.
    [dat, trialinfo, chans, times, temporal, frontal] = kah_loadftdata(info, subject, 'broadband', timewin, 1);

    % Construct PSDs.
    nfft = length(times); % use the full trial (no padding)
    nfreq = ceil(nfft/2) + 1;

    psds = nan(length(chans), nfreq, size(trialinfo, 1));
    for ichan = 1:length(chans)
        [freq, psds(ichan,:,:)] = util_taperpsd(squeeze(dat(ichan,:,:)), info.(subject).fs, nfft, 'hanning');
    end

    % Save PSDs.
    save([info.path.processed.hd subject '_FR1_psd_' num2str(timewin(1)) '_' num2str(timewin(2)) '.mat'], 'timewin', 'trialinfo', 'times', 'dat', 'freq', 'psds', 'chans', 'temporal', 'frontal', '-v7')
end
disp('Done')