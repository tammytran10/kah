clear

info = kah_info;

%% SINGLE-TRIAL, SINGLE-CHANNEL
clearvars('-except', 'info')

% Load single-trial, single-channel measures.
timewins = {[-800, 0], [0, 800], [800, 1600]};
[thetaamp, hfa, slopes, pacwithin_raw, pacwithin_norm] = kah_loadstsc(info, timewins);

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'chans', 'chanlobes', 'chanregions', 'encoding')

% Set names of metrics.
header = {'subject', 'age', 'channel', 'lobe', 'region', 'trial', 'encoding', ...
    'pretheta', 'earlytheta', 'latetheta', ...
    'prehfa', 'earlyhfa', 'latehfa', ...
    'preslope', 'earlyslope', 'lateslope', ...
    'prerawpac', 'earlyrawpac', 'laterawpac', ...
    'prenormpac', 'earlynormpac', 'latenormpac'};

% Build CSV.
csv = [];

for isubj = 1:length(info.subj)
    disp(isubj)
    nchan = length(chans{isubj});
    ntrial = length(encoding{isubj});
    
    % Pre-allocate per subject for speed.
    subjcurr = cell(nchan * ntrial, length(header));
    linenum = 1; % next line to fill in for the current subject.
    
    for ichan = 1:nchan
        for itrial = 1:ntrial
            % Build current line.
            linecurr = {info.subj{isubj}, info.age(isubj), chans{isubj}{ichan}, chanlobes{isubj}{ichan}, chanregions{isubj}{ichan}, itrial, encoding{isubj}(itrial), ...
                thetaamp{1}{isubj}(ichan, itrial), thetaamp{2}{isubj}(ichan, itrial), thetaamp{3}{isubj}(ichan, itrial), ...
                hfa{1}{isubj}(ichan, itrial), hfa{2}{isubj}(ichan, itrial), hfa{3}{isubj}(ichan, itrial), ...
                -slopes{1}{isubj}(ichan, itrial), -slopes{2}{isubj}(ichan, itrial), -slopes{3}{isubj}(ichan, itrial), ...
                pacwithin_raw{1}{isubj}(ichan, itrial), pacwithin_raw{2}{isubj}(ichan, itrial), pacwithin_raw{3}{isubj}(ichan, itrial), ...
                pacwithin_norm{1}{isubj}(ichan, itrial), pacwithin_norm{2}{isubj}(ichan, itrial), pacwithin_norm{3}{isubj}(ichan, itrial)};
            
            % Save current line.
            subjcurr(linenum, :) = linecurr;
            linenum = linenum + 1;
        end
    end
    
    % Append subject.
    csv = [csv; subjcurr];
    clear subjcurr
end

% Save.
util_cell2csv([info.path.csv 'kah_singletrial_singlechannel.csv'], csv, header)

%% SINGLE-CHANNEL
clearvars('-except', 'info')

% Load theta center frequencies.
load([info.path.processed.hd 'FR1_thetabands_-800_1600_chans.mat'])

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'chans', 'chanlobes', 'chanregions')

% Set names of metrics.
header = {'subject', 'age', 'channel', 'lobe', 'region', 'thetabump'};

% Build CSV.
csv = [];

for isubj = 1:length(info.subj)
    disp(isubj)
    nchan = length(chans{isubj});
    
    % Pre-allocate per subject for speed.
    subjcurr = cell(nchan, length(header));
    
    for ichan = 1:nchan
        % Build current line.
        thetabumpcurr = ~isnan(bands{isubj}(ichan, 1));
        if thetabumpcurr
            thetabumpcurr = 1;
        else
            thetabumpcurr = 0;
        end
        linecurr = {info.subj{isubj}, info.age(isubj), chans{isubj}{ichan}, chanlobes{isubj}{ichan}, chanregions{isubj}{ichan}, ...
            thetabumpcurr};
        
        % Save current line.
        subjcurr(ipair, :) = linecurr;
    end
    
    % Append subject.
    csv = [csv; subjcurr];
    clear subjcurr
end

% Save.
util_cell2csv([info.path.csv 'kah_singlechannel.csv'], csv, header)

%% MULTI-CHANNEL
clearvars('-except', 'info')

% Load phase-encoding for individualized theta bands.
load([info.path.processed.hd 'FR1_phase_corrcl_0_1600_cf.mat'], 'phaseencoding');

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'pairs', 'pairlobes', 'pairregions')

% Set names of metrics.
header = {'subject', 'age', 'pair', 'channelA', 'channelB', 'lobeA', 'lobeB', 'regionA', 'regionB', ...
    'encodingonset', 'encodinglength', 'encodingstrength', 'encodingepisodes'};

% Build CSV.
csv = [];

for isubj = 1:length(info.subj)
    disp(isubj)
    npair = size(pairs{isubj}, 1);
    
    % Pre-allocate per subject for speed.
    subjcurr = cell(npair, length(header));
    
    for ipair = 1:npair
        % Build current line.
        linecurr = {info.subj{isubj}, info.age(isubj), ipair, pairs{isubj}{ipair, 1}, pairs{isubj}{ipair, 2}, ...
            pairlobes{isubj}{ipair, 1}, pairlobes{isubj}{ipair, 2}, ...
            pairregions{isubj}{ipair, 1}, pairregions{isubj}{ipair, 2}, ...
            phaseencoding{isubj}.onset(ipair), phaseencoding{isubj}.time(ipair), phaseencoding{isubj}.strength(ipair), phaseencoding{isubj}.nepisode(ipair)};
        
        % Save current line.
        subjcurr(ipair, :) = linecurr;
    end
    
    % Append subject.
    csv = [csv; subjcurr];
    clear subjcurr
end

% Save.
util_cell2csv([info.path.csv 'kah_multichannel.csv'], csv, header)
disp('Done.')

%% SINGLE-TRIAL, MULTI-CHANNEL
clearvars('-except', 'info')

% Load tsPAC using individualized bands.
timewins = {[-800, 0], [0, 800], [800, 1600]};
pacbetween = kah_loadstmc(info, timewins);

% Load channel and trial information.
load([info.path.processed.hd 'FR1_chantrialinfo.mat'], 'pairs', 'pairlobes', 'pairregions', 'encoding')

% Set names of metrics.
header = {'subject', 'age', 'pair', 'channelA', 'channelB', 'lobeA', 'lobeB', 'regionA', 'regionB', 'trial', 'encoding', ...
    'prerawpacAB', 'earlyrawpacAB', 'laterawpacAB', ...
    'prerawpacBA', 'earlyrawpacBA', 'laterawpacBA', ...
    'prenormpacAB', 'earlynormpacAB', 'latenormpacAB', ...
    'prenormpacBA', 'earlynormpacBA', 'latenormpacBA'};

for isubj = 1:length(info.subj)
    % Skip this subject if their data has already been saved.
    filecurr = [info.path.csv 'kah_singletrial_multichannel_' info.subj{isubj} '.csv'];
    if exist(filecurr, 'file')
        disp(['Skipping subject ' num2str(isubj)])
        continue
    end
    
    npair = size(pairs{isubj}, 1);
    ntrial = length(encoding{isubj});
    
    % Pre-allocate per subject for speed.
    subjcurr = cell(npair * ntrial, length(header));
    linenum = 1; % next line to fill in for the current subject.
    
    for ipair = 1:npair
        disp([num2str(isubj) ' ' num2str(ipair) '/' num2str(npair)])
        for itrial = 1:ntrial
            % Build current line.
            linecurr = {info.subj{isubj}, info.age(isubj), ipair, pairs{isubj}{ipair, 1}, pairs{isubj}{ipair, 2}, ...
                pairlobes{isubj}{ipair, 1}, pairlobes{isubj}{ipair, 2}, ...
                pairregions{isubj}{ipair, 1}, pairregions{isubj}{ipair, 2}, ...
                itrial, encoding{isubj}(itrial), ...
                pacbetween{1, 1, 1}{isubj}(ipair, itrial), ...
                pacbetween{2, 1, 1}{isubj}(ipair, itrial), ...
                pacbetween{3, 1, 1}{isubj}(ipair, itrial), ...   
                pacbetween{1, 1, 2}{isubj}(ipair, itrial), ...
                pacbetween{2, 1, 2}{isubj}(ipair, itrial), ...
                pacbetween{3, 1, 2}{isubj}(ipair, itrial), ...             
                pacbetween{1, 2, 1}{isubj}(ipair, itrial), ...
                pacbetween{2, 2, 1}{isubj}(ipair, itrial), ...
                pacbetween{3, 2, 1}{isubj}(ipair, itrial), ...               
                pacbetween{1, 2, 2}{isubj}(ipair, itrial), ...
                pacbetween{2, 2, 2}{isubj}(ipair, itrial), ...
                pacbetween{3, 2, 2}{isubj}(ipair, itrial)};
            
            % Save current line.
            subjcurr(linenum, :) = linecurr;
            linenum = linenum + 1;
        end
    end
    
    % Save current line right to disk.
    disp('Saving.')
    util_cell2csv(filecurr, subjcurr, header, [])
end
disp('Done.')