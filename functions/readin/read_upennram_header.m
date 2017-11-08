function [hdr] = read_upennram_header(headerfile)

% READ_UPENNRAM_HEADER reads the header from UPenn's RAM (Restoring Active Memory) publically
% available datasets. It uses several of the possible header files as a hook, to obtain details
% necessary for making sure the data files match the intended recording, and checking for
% data integrity.
%
% UPenn's RAM project is a DARPA funded project, headed by Daniel Rizzuto and Michael Kahana.
% From the RAM website: (http://memory.psych.upenn.edu/RAM)
% "The goal of RAM is to develop a fully implantable device that can electrically stimulate
% the brain to improve memory function. The program?s immediate focus is to deliver new treatments
% for those who have experienced a traumatic brain injury, such as veterans returning from combat.
% In the long term, such therapies could help patients with a broad range of ailments, from Alzheimer's
% to dementia. RAM is part of a broader portfolio of programs within DARPA that support President Obama's
% BRAIN initiative."
% Intracranial human EEG has been recorded in various tasks and is publically available at the above
% website.
%
% From the press release (https://news.upenn.edu/news/penns-restoring-active-memory-project-releases-extensive-human-brain-dataset):
% "The recently released dataset includes information from 700 sessions, and for every patient,
% intracranial recording files from 100 to 200 electrode channels, neuro-anatomical information
% indicating the location of each electrode, precise records of patient behavior and the experimental
% design documents. To receive the raw dataset, interested researchers may request access through
% the RAM website."
%
%
% Use as
% [hdr] = read_upennram_header(headerfile)
%
%      Where,
%         headerfile = string, path+name of JSON file pointing to details of a RAM dataset
%                           IMPORTANT: this NEEDS to be the index.json file, in $PATIENTID/experiments/$TASKID/sessions/$#/behavioral/current_processed/
%                                      of the task and session of interest. This file allows to unamibigously identify the 'true' headers files:
%                                      (1) $PATIENTID/experiments/$TASKID/sessions/$#/ephys/current_processed/sources.json (binary format, nsample, etc)
%                                      (2) $PATIENTID/localizations/$#/montages/$#/neuroradiology/current_processed/contacts.json (channel names)
%                            (It is key that #2 reflects the montage used on the day of recording, incase the patients had a reimplantation,
%                             which is ensured by using index.json.)
%                            Note: the Ephys filename base is currently taken from $PATIENTID/experiments/$TASKID/sessions/$#/behavioral/current_processed/task_events.json,
%                                  due to the name field in index.json containing faulty information for some datasets
%      And,
%                hdr = matlab structure, containing details of the respective dataset, such as channel names, binary format, number of samples, etc
%
%
% The read_upennram_event and read_upennram_header functions currently depends on JSONlab (by Qianqian Fang)
% from the MATLAB File Exchange, to parse the above JSON formatted files.
%
% See also READ_UPENNRAM_EVENT, READ_UPENNRAM_DATA

% Copyright (C) 2016-2017, Roemer van der Meij

% parse contents of 'hook' headerfile
hookhdr = loadjson(headerfile);

% obtain patient path, patient name, experiment, sessionnumber,ephysbase
if isunix
    slashind = strfind(headerfile,'/');
else
    slashind = strfind(headerfile,'\');
end
nslash     = numel(slashind);
patpath    = headerfile(1:slashind(nslash-6));
%patname    = headerfile(slashind(nslash-7)+1:slashind(nslash-6)-1);
%experiment = headerfile(slashind(nslash-5)+1:slashind(nslash-4)-1);
%sessionnum = headerfile(slashind(nslash-3)+1:slashind(nslash-2)-1);
ephyspath  = [headerfile(1:slashind(nslash-2)) 'ephys' headerfile(slashind(nslash-1):slashind(nslash))];

% find and parse sources.json
sourcesfn = [ephyspath 'sources.json'];
hdr1      = loadjson(fixjsonnan(sourcesfn));
fieldname = fieldnames(hdr1);
if numel(fieldname)>1
    warning('multiple datasets detects in 1 session? Error following')
    error('multiple datasets detects in 1 session?')
end
hdr1      = hdr1.(fieldname{:});

% find and parse all_events.json, containing the eeg file name (unambigously, hopefully)
takeventsfn  = [headerfile(1:slashind(end)) hookhdr.files.task_events];
taskevents   = loadjson(takeventsfn);
taskevents   = [taskevents{:}];
taskeventsef = unique({taskevents.eegfile});
taskeventsef = taskeventsef(~cellfun(@isempty,taskeventsef)); % remove empty eegfile fields
if numel(taskeventsef)==1
    filebase    = taskeventsef{1};
    if isempty(filebase) % sigh
        warning('Ephys files cannot be identified unambigously, error following')
        error('Ephys files cannot be identified unambigously')
        % possible unsafe fallback: filebase = [patname '_' experiment '_' sessionnum '_' hdr1.start_time_str];
    end
else
    warning('multiple datasets detects in 1 session? Error following')
    error('multiple datasets detects in 1 session?')
end

% obtain contacts.json info
contactsfn = hookhdr.info.contacts;
ind        = strfind(contactsfn,'localizations');
contactsfn = [patpath contactsfn(ind:end)];
hdr2       = loadjson(contactsfn);
fieldname  = fieldnames(hdr2);
hdr2       = hdr2.(fieldname{:}); % failsafe in case of event that two main fields are present

% obtain list of possible channels and their data-file file extensions, combine into filenames
label     = fieldnames(hdr2.contacts);
chanfn    = cell(size(label));
datadir   = [ephyspath 'noreref/'];
for ichan = 1:numel(label)
    currind = hdr2.contacts.(label{ichan}).channel;
    currfn  = [filebase '.' num2str(currind,'%03.0f')];
    if exist([datadir currfn],'file')
        chanfn{ichan} = currfn;
    end
end
notexist = cellfun(@isempty,chanfn);
if all(notexist)
    warning('insufficient information to identify ephys files that match task events, error following')
    error('insufficient information to identify ephys files that match task events')
elseif sum(notexist)~=0
    warning([num2str(sum(notexist)) ' out of ' num2str(numel(label)) ' electrodes in contacts.json not found on disk, removed from header'])
    label(notexist)  = [];
    chanfn(notexist) = [];
end

% get number of bytes per sample of dataformat (lame..., there should be matlab function for this)
tmp = cast(1,hdr1.data_format);
tmp = whos('tmp');
nbytespersample = tmp.bytes;

% sources.json has issues, check here if nsamples matches the data. An accidental match is extremely unlikely (also correct nsamples if it's NaN)
nsample = hdr1.n_samples;
nbytes  = zeros(1,numel(chanfn));
for ichan = 1:numel(chanfn)
    fn = [datadir chanfn{ichan}];
    fid = fopen(fn);
    fseek(fid,0,'eof');
    nbytes(ichan) = ftell(fid);
    fclose(fid);
end
if all(nbytes==nbytes(1))
    foundnsample = nbytes(1) ./ nbytespersample;
    if isnan(nsample)
        nsample = foundnsample;
    else
        if isequal(nsample,foundnsample)
            % nice
        else
            if (nsample-foundnsample) == 1
                warning('sources.json nsample deviates from ephys files by 1 sample, this is presambly caused by sources.json, ephys files can be used safely')
                nsample = foundnsample;
            else
                warning(['nsample found (' num2str(foundnsample) ') deviations from nsample specified (' num2str(nsample) '), sources.json possible does not match ephys file size, recording cannot be identified or matched unambiguously to task_events, error following'])
                error('sources.json likely does not match ephys file size, recording cannot be identified or matched unambiguously to task_events')
            end
        end
    end
else
    warning('electrode ephys files are of different size, error following')
    error('electrode ephys files are of different size')
end

% construct header
hdr = [];
hdr.nChans       = numel(label);
hdr.nSamples     = nsample;
hdr.Fs           = hdr1.sample_rate;
hdr.label        = label;
hdr.channelfile  = chanfn;
hdr.nSamplesPre  = 0;
hdr.nTrials      = 1;
hdr.dataformat   = hdr1.data_format;
hdr.nBytes       = nbytespersample;
hdr.chantype     = repmat({'unknown'},[numel(label) 1]);
hdr.chanunit     = repmat({'unknown'},[numel(label) 1]);
hdr.orig1        = hdr1;
hdr.orig2        = hdr2;




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% SUBFUNCTION
function jsonstring = fixjsonnan(jsonstring)

% check whether already read
if exist(jsonstring,'file')
    jsonstring = fileread(jsonstring);
end

% find NaN, Inf, -Inf
target = {'NaN','Inf','-Inf'};
for itarg = 1:numel(target)
    ind = findstr(jsonstring,target{itarg}); % case sensitive
    for iind = 1:numel(ind)
        begind = ind(iind);
        endind = ind(iind)+numel(target{itarg})-1;
        tmpstring1 = jsonstring(1:begind-1);
        tmpstring2 = jsonstring(endind+1:end);
        jsonstring = [tmpstring1 '"_' jsonstring(begind:endind) '_"' tmpstring2];
    end
end