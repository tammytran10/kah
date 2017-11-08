function lnspectra = rmr_findlinespectra(dat,fsample,searchrange,param)

% This function iteratively finds line spectra in electrophysiological
% recordings, with the purpose of filtering these line spectra afterwards
% in a different pipeline. Function outputs are peak frequencies of the line
% spectra combined with their filter half-bandwidths that suppress the line
% spectra successfully. Specification of the filters used for this purpose 
% are given in the output as well (and can given as input), as well as
% the appropriate length of the edges that should be cut off after
% filtering (in the case of IIR, an estimate based on 98% of the abs of the
% approximated impulse response). 
% 
% Filters are meant to applied to the entire recording regardless of on which 
% channel line spectra occur. Because of this, peaks and bandwidths are 
% determined using all channels. This is done by averaging their processed
% PSDs.
% 
% Spectral analysis performed to detect peaks is done using a Hanning 
% tapered Welch window. The resulting PSD (log10) is than filtered itself to
% remove any slow trends. The resulting processed PSD is then Z-valued
% (mean/std calculed for all channels simultaneously) and averaged over channels.
% The result processed PSD is then used to find peaks.
% 
% The peak finding algorithm consists of two iterative loops, having the following logic:
% 1) get PSD in normal/log space (do this temp.deriv. of data, helps flattening)
% 2) filter PSD to flatten it
% 3) z-value and average over channels
% 4) threshold and determine peaks as center of contiguous frequency bins above threshold
% 5) if peaks exist:
%   a) filter data
%   b) get PSD in normal/log space (do using temp.deriv. of data, helps flattening)
%   c) filter PSD to flatten it
%   d) z-value and average over channels (using z-value from 3)
%   e) if peaks are not fully suppressed, increase bandwidth and return to a
% 6) return to 1 for next pass using filtered data from last step 
% 
% 
% 
% 
%                Input:
%                         dat = Nchan X Nsample spatio-temporal matrix (can also be a filename with a single matrix, to save memory)
%                     fsample = scalar, sampling rate in Hz
%                 searchrange = 1x2 vector, frequency range in Hz to search in [freqmin freqmax]
%                       param = structure, containing additional inputs
%               param.zthresh = scalar, Z-value to use as threshold for catching peaks (default = 2)
%              param.welchwin = scalar, length in seconds of Welch window to use for PSD (default = 10)
%             param.bandwmin  = scalar, minimum filter half bandwidth in Hz (default = 0.5)
%             param.bandwstep = scalar, half bandwidth in Hz, stepsize for determining filter bandwidth (default = 0.25)
%                 param.taper = string, taper to use for spectral estimation (default = 'hanning')
%              param.filttype = string, type of bandstop filter  'but' (default),  'fir', etc (FieldTrip-style name)
%               param.filtord = scalar, order of bandstop filter (default = 2)
%               param.filtdir = string, direction of bandstop filter 'twopass' (default), 'onepass', etc (FieldTrip-style name)
%            param.maxouterit = scalar, maximum iterations of outer loop (default = 5)
%            param.maxinnerit = scalar, maximum iterations of inner loop (default = 5)
%
%
% 
%                Output:
%              lnspectra.peak = 1xN vector of peak frequencies in Hz
%         lnspectra.halfbandw = 1xN vector of half-bandwidths used for filtering (peak +/- halfbandw)
%          lnspectra.filttype = string, filter type of bandstop filter used
%           lnspectra.filtord = scalar, order of  bandstop filter used
%           lnspectra.filtdir = string, filter direction of bandstop filter used
%        lnspectra.edgeartlen = scalar, rough estimate of edge artifact length to be removed in seconds (only when filttype = 'but')
%              lnspectra.freq = 1xN vector, freq axis for PSDs below
%           lnspectra.origpsd = 1xN vector, PSD before filtering, for inspection purposes
%           lnspectra.filtpsd = 1xN vector, PSD after filtering, for inspection purposes
% 
%
%  (this function depends on FieldTrip, https://github.com/fieldtrip)
%  
%

%
% Copyright (C) 2015, Roemer van der Meij, roemervandermeij AT gmail DOT com
%

% set defaults 
if ~isfield(param,   'zthresh'),     param.zthresh     = 2;            end
if ~isfield(param,   'welchwin'),    param.welchwin    = 10;           end
if ~isfield(param,   'bandwmin'),    param.bandwmin    = 0.5;          end
if ~isfield(param,   'bandwstep'),   param.bandwstep   = 0.25;         end
if ~isfield(param,   'taper'),       param.taper       = 'hanning';    end
if ~isfield(param,   'filttype'),    param.filttype    = 'but';        end
if ~isfield(param,   'filtord'),     param.filtord     = 2;            end
if ~isfield(param,   'filtdir'),     param.filtdir     = 'twopass';    end
if ~isfield(param,   'maxouterit'),  param.maxouterit  = 5;            end
if ~isfield(param,   'maxinnerit'),  param.maxinnerit  = 5;            end

% load if filename
if ischar(dat)
  filevars = whos('-file', dat);
  if numel(filevars)>1 || ~any(strcmp(filevars.class,{'single','double'})) 
    error('filename contains either a single variable or not a array of singles or doubles')
  end
  datvarname = filevars.name;
  filecontent = load(dat);
  dat = filecontent.(datvarname);
  clear filecontent
end

% sanity checks
if size(dat,2)<size(dat,1)
  error('dat has more channels than samples')
end

% get pow of original data to be used in output
[origpow, freqorig]     = getpow(dat,fsample,searchrange,param.welchwin,param.taper,false);
[origpow50ms, freg50ms] = getpow(dat,fsample,searchrange,0.050,param.taper,false);


%%%%%%%%%%%%%%%%%%%%%
% iteratively find peaks, and iteratively adjust bandwidth of the peaks found
peaksremaining = true;
peaks     = [];
bandwidth = [];
pspecpeaks = [];
pspecbandw = [];
pspecprpow = [];
itouter = 0;
filtdat = dat; % this will from now on be filtered data
clear dat
while peaksremaining
  itouter = itouter + 1;
  
  % get pow
  [pow, freq] = getpow(filtdat,fsample,searchrange,param.welchwin,param.taper,true);
  % process pow
  [procpow,zparam] = processpow(pow,freq,[],peaks,bandwidth);
  
  % save round specific processed pow
  pspecprpow{itouter} = procpow;
  
  % find  peaks
  [peaks, bandwidth] = findpeaks(procpow,freq,param.zthresh,param.bandwmin);
  if ~isempty(peaks)
    disp(['found ' num2str(numel(peaks)) ' line spectra in pass ' num2str(itouter)])
    for ipeak = 1:numel(peaks)
      disp(['line spectra at ' num2str(peaks(ipeak)) 'Hz +/- ' num2str(bandwidth(ipeak)) 'Hz'])
    end
  else
    % no more peaks found, quit
    peaksremaining = false;
    disp(['no more peaks found in pass ' num2str(itouter)])
  end
  
  
  %%%%%%%%%%%%%%%%%%%%% 
  % iteratively increase bandwidth till all peaks are gone
  peakgone = false(size(peaks));
  itinner = 0;
  while ~all(peakgone)
    itinner = itinner + 1;
    
    % filter data, but do it per channel to save memory
    for ipeak = 1:numel(peaks)
      % apply a bandstop filter
      disp(['applying filter for peak at ' num2str(peaks(ipeak)) 'Hz +/- ' num2str(bandwidth(ipeak)) 'Hz'])
      for ichan = 1:size(filtdat,1)
        filtdat(ichan,:) = ft_preproc_bandstopfilter(filtdat(ichan,:), fsample, [peaks(ipeak)-bandwidth(ipeak) peaks(ipeak)+bandwidth(ipeak)], param.filtord, param.filttype, param.filtdir);
      end
    end
    
    % get pow and process it, using same zval-ling as used initially
    [pow, freq] = getpow(filtdat,fsample,searchrange,param.welchwin,param.taper,false);
    procpow     = processpow(pow,freq,zparam);
    
    % assess residual peak presence per peak, report in peaksgone, and increase bandwidth if necessary
    for ipeak = 1:numel(peaks)
      currpeak  = peaks(ipeak);
      currbandw = bandwidth(ipeak);
      currind   = find(freq>=(currpeak-currbandw) & freq<=(currpeak+currbandw));
      if any(procpow(currind)>param.zthresh)
        bandwidth(ipeak) = bandwidth(ipeak) + param.bandwstep;
        disp(['increased bandwidth for line spectra at ' num2str(peaks(ipeak)) 'Hz to +/-' num2str(bandwidth(ipeak)) 'Hz'])
      else
        peakgone(ipeak) = true;
      end
    end
    
    % stop if it goes on too long
    if itinner == param.maxinnerit
      warning('inner loop reached maxitt, likely param.zthresh is too low')
      break
    end
  end
  %%%%%%%%%%%%%%%%%%%%%
  
  % save pass-specific peaks and bandwidth, and new filtdat
  pspecpeaks{itouter} = peaks;
  pspecbandw{itouter} = bandwidth;
  
  % stop if it goes on too long
  if itouter == param.maxouterit
    warning('outer loop reached maxitt, likely param.zthresh is too low')
    break
  end
end
%%%%%%%%%%%%%%%%%%%%%
% gather peaks and bandwidths
peaks     = cat(2,pspecpeaks{:});
bandwidth = cat(2,pspecbandw{:});


% determine approximate length of impulse response at 98% of impulse response (determined by sum of abs)
if strcmp(param.filttype,'but') && (strcmp(param.filtdir,'twopass') || strcmp(param.filtdir,'onepass'))
  edgeartlen = NaN(1,numel(peaks));
  for ipeak = 1:numel(peaks)
    fakedat = zeros(1,round(10*fsample));
    fakedat(1) = 1;
    impresp  = ft_preproc_bandstopfilter(fakedat, fsample, [peaks(ipeak)-bandwidth(ipeak) peaks(ipeak)+bandwidth(ipeak)], param.filtord, param.filttype, 'onepass');
    impresp  = impresp ./ sum(abs(impresp));
    edgeartlen(ipeak) = (find(cumsum(abs(impresp))>0.98,1))./fsample; % 
  end
  if any(edgeartlen==10)
    error('fakedat too small')
  end
  if strcmp(param.filtdir,'twopass')
    edgeartlen = max(edgeartlen) * 2;
  else
    edgeartlen = max(edgeartlen);
  end
else
  edgeartlen = [];
end

% produce filtpow for output structure
[filtpow, freqorig]     = getpow(filtdat,fsample,searchrange,param.welchwin,param.taper,false);
[filtpow50ms, freg50ms] = getpow(filtdat,fsample,searchrange,0.050,param.taper,false);


% create output structure
lnspectra = [];
lnspectra.peak       = peaks;
lnspectra.halfbandw  = bandwidth;
lnspectra.filttype   = param.filttype;
lnspectra.filtord    = param.filtord;
lnspectra.filtdir    = param.filtdir;
lnspectra.edgeartlen = edgeartlen;
lnspectra.freq       = freqorig; 
lnspectra.origpsd    = origpow;
lnspectra.filtpsd    = filtpow; 




%%%%%%%%%%%%%%%%%
% % show some plots of results and process
% % 1) original PSD in log/norm space with found peaks highlighted and filtered spectrum on top of it
% figure('numbertitle','off','name','original and filtered mean PSD in log/normal space')
% hold on
% l1 = plot(freq,mean(log10(lnspectra.origpsd),1),'color',[0 1 0]);
% for ipeak = 1:numel(peaks)
%   begfreq = peaks(ipeak)-bandwidth(ipeak);
%   endfreq = peaks(ipeak)+bandwidth(ipeak);
%   ind = find(freq>=begfreq & freq<=endfreq);
%   l2 = plot(freq(ind),mean(log10(lnspectra.origpsd(:,ind)),1),'color',[1 0 0]);
% end
% l3 = plot(freq,mean(log10(lnspectra.filtpsd),1),'color',[0 0 1]);
% xlabel('frequency (Hz)')
% ylabel('log mean (over channels) power')
% if numel(peaks)>1
%   legend([l1 l2 l3],'orignal PSD','identified as line spectrum','filtered PSD');
% else
%   legend([l1 l3],'orignal PSD','filtered PSD');
% end
% title('result of bandstop filtering line spectra')

% % 2) original PSD and filtered PSD in log/norm space, for input Welch window and for a 50ms window
% figure('numbertitle','off','name','original/filtered mean PSD in log/normal space with input Welch, and Welch = 50ms')
% hold on
% plot(freqorig,mean(log10(origpow),1),'color',[0.5 0.8 1])
% plot(freg50ms,mean(log10(origpow50ms),1),'color',[0 0 1])
% plot(freqorig,mean(log10(filtpow),1),'color',[.6 1 .5])
% plot(freg50ms,mean(log10(filtpow50ms),1),'color',[0 1 0])
% legend(['original PSD ' num2str(param.welchwin) 's Welch'],'original PSD 50ms Welch',['filtered PSD ' num2str(param.welchwin) 's Welch'],'filtered PSD 50ms Welch')
% title('bleeding of line spectra into neighboring frequencies')
% 
% 3) z-valued the original PSD in log/norm space with found peaks highlighted and filtered spectrum on top of it
figure('numbertitle','off','name','processed PSD of each pass in log/normal space')
npass = numel(pspecpeaks);
for ipass = 1:npass
  subplot(1,npass,ipass)
  hold on
  currpeaks = pspecpeaks{ipass};
  currbandw = pspecbandw{ipass};
  currprpow = pspecprpow{ipass};
  l1 = plot(freq,currprpow,'color',[0 0 1]);
  for ipeak = 1:numel(currpeaks)
    begfreq = currpeaks(ipeak)-currbandw(ipeak);
    endfreq = currpeaks(ipeak)+currbandw(ipeak);
    ind = find(freq>=begfreq & freq<=endfreq);
    l2 = plot(freq(ind),currprpow(ind),'color',[1 0 0]);
  end
  l3 = line([freq(1) freq(end)],[param.zthresh param.zthresh],'linestyle','--','color',[.6 .8 .5]);
  xlabel('frequency (Hz)')
  ylabel('log mean (over channels) power')
  if numel(currpeaks)>1
     legend([l1 l2 l3],'processed PSD','identified as line spectrum','threshold');
  else
    legend([l1 l3],'processed PSD','threshold');
  end
  title(['PSD and identified peaks of pass ' num2str(ipass)])
  ylim = get(gca,'ylim');
  set(gca,'ylim',[-3 max([ylim(2) 5])])
  set(gca,'xlim',[freq(1) freq(end)])
end
%%%%%%%%%%%%%%%%%




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%% SUB FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Calculate power
function [pow, freq] = getpow(dat,fsample,searchrange,welchwin,taper,diffflag)

% set basics
nsample = size(dat,2);
nchan   = size(dat,1);

%%%% get PSD using a welch approach
% determine the welch windows to loop over, 25% overlap
nsampwelch   = round(welchwin .* fsample); % samples in a welch window
welchwinstep = round(nsampwelch .* (3/4)); % steps in between windows
welchindbeg  = 1:welchwinstep:nsample;
welchindend  = nsampwelch:welchwinstep:nsample;
welchindbeg  = welchindbeg(1:numel(welchindend));
welchind  = [welchindbeg; welchindend].';
nwelchwin = size(welchind,1);
% determine freq axis and freq bins to use for searching
freqboilim = round([searchrange(1) searchrange(2)] ./ (fsample ./ nsampwelch)) + 1;
freqboi    = freqboilim(1):1:freqboilim(2);
freq       = (freqboi-1) ./ (welchwin);
% get PSD
pow = zeros(nchan,numel(freqboi));
for iwelch = 1:nwelchwin
  
  % cut out and taper
  tap = feval(taper,nsampwelch);
  tap = tap ./ sqrt(sum(tap.^2));
  tap = tap(:); % ensure tap is column vector, some window functions return a row instead of column
  currind = welchind(iwelch,:);
  currdat = dat(:,currind(1):currind(2));
  if diffflag
    currdat    = diff(currdat,[],2);
    currdattap = bsxfun(@times,currdat,tap(1:end-1).');
  else
    currdattap = bsxfun(@times,currdat,tap.');
  end
  
  
  % get power
  fftdat = fft(currdattap,[], 2);
  currpow = abs(fftdat(:,freqboi)).^2; % select bins
  
  % calc running mean
  pow = pow + (currpow ./ nwelchwin);
end
% the above is equivalent to pwelch(dat.',nsampwelch,welchwinstep*3,freq,fsample).', but pwelch used in this way is horribly slow
% the former also allows for more control (tapering)
%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Log power, fit slope, remove it from non log space, z-value them all together, and mean
function [procpow, zparam] = processpow(pow,freq,varargin)

% get variable input arg
if nargin == 2
  zparam    = [];
  peaks     = [];
  bandwidth = [];
elseif nargin == 3
  zparam    = varargin{1};
  peaks     = [];
  bandwidth = [];  
elseif nargin == 5
  zparam    = varargin{1};
  peaks     = varargin{2};
  bandwidth = varargin{3};
else
  error('internal error: nargin should 2, 3, or 5')
end

% log pow and freq axis
logpow  = log10(pow);
logfreq = log10(freq);

% set basics
nchan = size(logpow,1);

% filter it with a very low highpass. The annoying trick I applied here, 'funny padding', is because I couldn't 
% get a decent filter response at low (approximate) order without inducing edge artifacts. I use a filter, instead of slope
% fitting, to straigthen it out, because I want this to also work for data closer to the oscillatory range of 
% frequencies, e.g. starting to search from 40Hz onwards. 
% create a fake time using the frequency resolution
fakefsample = 1./(mean(diff(freq))); % to make things easy, consider 1Hz as 1s
% make high pass filter to suppress slow wiggles. 
% there's an cumbersome trade-off here: the smaller the high pass, the more slow wiggles stay in there, and fitting capability is reduced.
% but the higher the high pass, the more the 'slower' edges of broad line spectra get pushed to lower freqs, which also affects 
% fitting capability
hpfreq  = 1/250; % X is now a frequency whose "cycle length" is 500Hz
% filter settings are hardcoded and not meant to be changed
filttype = 'but';
filtord  = 2;
filtdir  = 'twopass';
% apply filtering with 'slope padding': pad out the edges according to the slope
padlen  = 100*fakefsample; % 100Hz 
prepad  = NaN(nchan,padlen);
postpad = NaN(nchan,padlen);
% extrapolate freq to both sides
prefreq  = freq(1:padlen)-(freq(padlen+1)-freq(1));
postfreq = freq(end-padlen+1:end) + (freq(end)-freq(end-padlen));
if exist('rmr_robustfit.m','file')
  hfun = @rmr_robustfit;
else
  hfun = @robustfit;
end
for ichan = 1:size(logpow,1)
  % prepad
  offschi   = feval(hfun,freq(1:padlen),logpow(ichan,1:padlen));
  prepad(ichan,:) = (offschi(1) + (offschi(2).*prefreq));
  % postpad
  offschi   = feval(hfun,freq(end-padlen+1:end),logpow(ichan,end-padlen+1:end));
  postpad(ichan,:) = (offschi(1) + (offschi(2).*postfreq));
end
filtpow = [prepad logpow postpad];
filtpow = ft_preproc_highpassfilter(filtpow, fakefsample, hpfreq, filtord, filttype, filtdir);
filtpow = filtpow(:,(padlen+1):end-(padlen)); % remove padding

% zval it, and output mean/std as zparam
if isempty(zparam)
  % calculate zparams on parts of the spectrum that are not peaks (which shoot up/down before/after bandstop filtering)
  tmpfiltpow = filtpow;
  if ~isempty(peaks)
    for ipeak = 1:numel(peaks)
      currpeak  = peaks(ipeak);
      currbandw = bandwidth(ipeak);
      currind   = find(freq>=(currpeak-currbandw) & freq<=(currpeak+currbandw)); % robust to boundaries
      tmpfiltpow(:,currind) = NaN;
    end
  end
  meanlpow = nanmean(filtpow(:));
  stdlpow  = nanstd(filtpow(:));
  zparam   = [meanlpow stdlpow];
end
procpow  = (filtpow - zparam(1)) ./ zparam(2);
procpow  = mean(procpow,1);
%%%%%%%%%%%%%%%%%%%%%%%%%




%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Find peaks and determine bandwidth
function [peaks, bandwidth] = findpeaks(procpow,freq,zthresh,minbandw)

% find threshold crossings
passthresh = procpow>zthresh;
% find contigious points and select center of these
if any(passthresh)
  passind = [];
  passind(:,1) = find(diff([0,passthresh,0]) == 1);
  passind(:,2) = find(diff([0,passthresh,0]) == -1) - 1;
  peaks = freq(round(mean(passind,2)));
  % get bandwidth start values
  bandwidth = freq(passind(:,2))-freq(passind(:,1));
  bandwidth(bandwidth<minbandw) = minbandw;
  % ensure maximal accuracy of .1Hz
  peaks     = round(peaks*100)/100;
  bandwidth = round(bandwidth*100)/100;
else
  peaks     = [];
  bandwidth = [];
end
%%%%%%%%%%%%%%%%%%%%%%%%%









function playground



[poworg, freqorg] = getpow(orgdat,fsample,searchrange,10,param.taper);
[poworg075, freq075] = getpow(orgdat,fsample,searchrange,0.075,param.taper);
[filtpow, freqorg] = getpow(dat,fsample,searchrange,10,param.taper);
[filtpow075, freq075] = getpow(dat,fsample,searchrange,.075,param.taper);

figure
hold on
plot(freqorg,mean(log10(poworg)),'color',[0.5 0.8 1])
plot(freq075,mean(log10(poworg075)),'color',[0 0 1])
plot(freqorg,mean(log10(filtpow)),'color',[.6 1 .5])
plot(freq075,mean(log10(filtpow075)),'color',[0 1 0])
legend('original PSD 10s Welch','original PSD 0.075s Welch','filtered PSD 10s Welch','filtered PSD 0.075s Welch')































