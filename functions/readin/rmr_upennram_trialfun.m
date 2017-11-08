function trl = rmr_upennram_trialfun(cfg)

% RMR_UPENNRAM_TRIALFUN FieldTrip-style trial function to obtain segmentation details of
% UPenn's RAM (Restoring Active Memory) publically available datasets, for the FR1/2 tasks.
%
% For the task specifications, see the Metadata documentation released together with the RAM datasets.
%
% The output of this function is a trl matrix, which describes the times of each trial in samples,
% and contains additional information for classifying trials (condition, hit/miss, rt, etc).
% The trl should be used as input for ft_preprocessing(cfg) by passing it as cfg.trl.
%
% The inputs to this function are given as a cfg (see below). This cfg contains the events as
% a structure-array, as provided by READ_UPENNRAM_EVENT, and a header as a header structure,
% as provided by READ_UPENNRAM_HEADER. Both functions can be either be called on their own, or
% via FT_READ_EVENT and FT_READ_HEADER.
%
% T=0 is defined as the start of the word presentation (encoding; presentation time 1600ms, ISI 750-1000ms)
% or start of the verbal report (recall) onset. Trial duration, and pre/poststimulus periods before
% and after this can be adjusted below using the cfg. A warning is issued if trials overlap with a 
% neighboring event. Selection of trials after creating the trl matrix can be done using the additional
% trialinfo columns below.
%
%              Input:
%         cfg.event = structure-array containing events
%        cfg.header = structure containing header
%   cfg.encduration = during encoding, time period in seconds after/before pre/poststim periods (default = 1.6s)
%   cfg.recduration = during recall, time period in seconds after/before pre/poststim periods (default = 1.0s)
%    cfg.encprestim = during encoding, length of prestimulus period (default = 0s)
%   cfg.encpoststim = during encoding, length of poststimulus period (default = 0s)
%    cfg.recprestim = during recall, length of prestimulus period (default = 0s)
%   cfg.recpoststim = during recall, length of poststimulus period (default = 0s)
%
%
% trl matrix columns: (4 and up will form the data.trialinfo field after reading in the data)
%  (1) begsample     - beginning of trial
%  (2) endsample     - end of trial
%  (3) offset        - offset to t=0 in samples (used for creating time axis)
%  (4) taskphase     - phase of the experiment, encoding = 1, recall = 2
%  (5) stim          - indicating whether stimulation was present during encoding (1 = yes, 0 = no) (in case of recall, during encoding of the recalled word)
%  (6) subseqmem     - subsequent memory effect, for encoding: later remembered = 1, later forgotten =  0; for recall: 1 = succesfully remembered, 0 = new word
%  (7) list          - list number (i.e. task phase)
%  (8) serialpos     - serial position of word in list during encoding (for recall, NaN in case of new word)
%  (9) wordno        - numeric identifier of word presented/recalled (for recall, NaN in case of new word)
% (10) timefromprev  - time in seconds from begsample till previous event (positive indicates overlap)
% (11) timetonext    - time in seconds from endsample till next event     (negative indicates overlap)


% parse cfg
cfg.event               = ft_getopt(cfg, 'event',                  []);
cfg.header              = ft_getopt(cfg, 'header',                 []);
cfg.encduration         = ft_getopt(cfg, 'encduration',            1.6);
cfg.recduration         = ft_getopt(cfg, 'recduration',            1);
cfg.encprestim          = ft_getopt(cfg, 'encprestim',             0);
cfg.encpoststim         = ft_getopt(cfg, 'encpoststim',            0);
cfg.recprestim          = ft_getopt(cfg, 'recprestim',             0);
cfg.recpoststim         = ft_getopt(cfg, 'recpoststim',            0);
if isempty(cfg.event) || isempty(cfg.header)
  error('event and header structure are necessary')
end


%%%%%%%%%%%%%%%%%%%%%%% TRIAL FUNCTION START %%%%%%%%%%%%%%%%%%%%
event   = cfg.event;
fsample = cfg.header.Fs;
trl = [];
for ievent = 1:numel(event) % looping over events
  
  
  % Finding CUE as trial anchor
  if any(strcmp(event(ievent).type,{'WORD','REC_WORD'}))
    startevent = event(ievent).type;
    
    %
    switch startevent
      case 'WORD' % encoding
        % begsampe, endsample and offset
        begsample = event(ievent).eegoffset - round(cfg.encprestim*fsample);
        endsample = event(ievent).eegoffset + round(cfg.encduration*fsample) + round(cfg.encpoststim*fsample);
        offset    = -round(cfg.encprestim*fsample);
    
        % additional trial info
        taskphase   = 1;
       
      case 'REC_WORD' % recall
        % begsampe, endsample and offset
        begsample = event(ievent).eegoffset - round(cfg.recprestim*fsample);
        endsample = event(ievent).eegoffset + round(cfg.recduration*fsample) + round(cfg.recpoststim*fsample);
        offset    = -round(cfg.recprestim*fsample);

        % additional trial info
        taskphase = 2;
    end
    
    % additional trial info
    stim      = event(ievent).is_stim;
    subseqmem = event(ievent).recalled;
    list      = event(ievent).list;
    serialpos = event(ievent).serialpos;
    wordno    = event(ievent).item_num;
    
    %         
    timefromprev = (event(ievent-1).eegoffset-begsample) ./ fsample; % (positive indicates overlap)
    timetonext   = (event(ievent+1).eegoffset-endsample) ./ fsample; % (negative indicates overlap)
    if timefromprev>0
      warning(['beginning of current trial overlaps by ' num2str(timefromprev) 's with event: ' event(ievent-1).type])
    end
    if timetonext<0
      warning(['end of current trial overlaps by ' num2str(timetonext) 's with event: ' event(ievent+1).type])
    end
    
    % add to trl
    trl(end+1,:) = [begsample endsample offset taskphase stim subseqmem list serialpos wordno timefromprev timetonext];
    
    
  end % strcmp(event(ievent).type)
end % for ievent
trl(trl(:,8)==-999,8) = NaN;
trl(trl(:,9)==-1,9)   = NaN;
disp(['found ' num2str(size(trl,1)) ' trials'])
%%%%%%%%%%%%%%%%%%%%%%% TRIAL FUNCTION END %%%%%%%%%%%%%%%%%%%%%%


