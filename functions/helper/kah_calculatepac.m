function kah_calculatepac(subject, chanA, chanB, pairnum, clusterpath, thetalabel)
% Load theta phase data for only channels of interest. 
theta = matfile([clusterpath 'thetaphase/' subject '_FR1_thetaphase_' thetalabel '_-1000_2750.mat']);
times = theta.times;
thetaphase = theta.data([chanA, chanB], :, :);

% Load HFA amplitude data for only channels of interest.
hfa = matfile([clusterpath 'hfa/' subject '_FR1_hfaamp_-800_1600.mat']);
hfaamp = hfa.data([chanA, chanB], :, :);
hfaamp = flip(hfaamp, 1); % so that theta and HFA from opposite channels are matched up
[ndirection, ~, ntrial] = size(hfaamp);

% Limit to post-stimulus period.
timewin = dsearchn(times(:), [0; 1.6]);
thetaphase = thetaphase(:, timewin(1):timewin(2), :);
hfaamp = hfaamp(:, timewin(1):timewin(2), :);

% Load samples to shift by. 
shifttrials = matfile([clusterpath 'shifttrials/' subject '_FR1__pac_between_ts_trialshifts_default.mat']);
shifts = squeeze(shifttrials.shifttrials(pairnum, :, :, :));
nsurrogate = size(shifts, 3);

% Calculate tsPAC in both directions for each trial, + surrogate PAC.
pacbetween = nan(ntrial, ndirection, nsurrogate + 1);
for itrial = 1:ntrial
    for idirection = 1:ndirection
        phasechan = thetaphase(idirection, :, itrial);
        ampchan = hfaamp(idirection, :, itrial);
        
        [pacbetween(itrial, idirection, nsurrogate + 1), pacbetween(itrial, idirection, 1:nsurrogate)] = ...
            calculatepac(phasechan, ampchan, 'ozkurt', squeeze(shifts(itrial, idirection, :)));
    end
end

outputfile = [clusterpath 'tspac/' subject '_FR1_pac_between_ts_0_1600_pair_' num2str(pairnum) '_resamp_ ' thetalabel '.mat'];
save(outputfile, 'pacbetween');
end

% output = matfile(outputfile, 'Writable', true);
% output.(['pair' num2str(pairnum)]) = pacbetween;