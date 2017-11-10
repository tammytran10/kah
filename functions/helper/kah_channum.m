function channum = kah_channum(info, varargin)

% KAH_CHANNUM prints the number of total and clean temporal and frontal surface channels per subject.
% The first two columns are the total numbers of temporal and frontal channels.
% The next two columns are the numbers of clean temporal and frontal channels.
% The last column is the total number of clean surface channels.
% Input is the info struct returned by KAH_INFO.
%
% Usage: 
%   kah_channum(info) returns info for all subjects listed in info.subj
%
%   kah_channum(info, subjects) returns info just for the subjects specified

if nargin == 1
    subjoi = info.subj;
else
    subjoi = varargin{1};
    
    if ~iscell(subjoi)
        subjoi = {subjoi};
    end
end
    
channum = nan(length(subjoi), 5);

for isubj = 1:length(subjoi)
    subject = subjoi{isubj};
    
    surface = ~strcmpi('d', info.(subject).allchan.type);
    clean   = ~ismember(info.(subject).allchan.label, info.(subject).badchan.all);
    
    channum(isubj, 1) = sum(strcmpi('t', info.(subject).allchan.lobe(surface)));
    channum(isubj, 2) = sum(strcmpi('f', info.(subject).allchan.lobe(surface)));
    channum(isubj, 3) = sum(strcmpi('t', info.(subject).allchan.lobe(surface & clean)));
    channum(isubj, 4) = sum(strcmpi('f', info.(subject).allchan.lobe(surface & clean)));
    channum(isubj, 5) = sum(surface & clean);
end