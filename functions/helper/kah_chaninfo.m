function chaninfo = kah_chaninfo(info, subject, varargin)

% KAH_CHANINFO displays complete channel information for a particular subject.
% kah_chaninfo(info, subject) displays all channels.
% kah_chaninfo(info, subject, chanoi) displays only the channels listed by label in the cell array chanoi.

if nargin < 3
    chanoi = info.(subject).allchan.label;
else
    chanoi = varargin{1};
end

chaninfo = cell(length(chanoi), 7);
for ichan = 1:length(chanoi)
    chancurr = ismember(info.(subject).allchan.label, upper(chanoi{ichan}));
    if sum(chancurr) == 0
        continue
    end
    chaninfo(ichan,:) = [info.(subject).allchan.label(chancurr), info.(subject).allchan.type(chancurr), info.(subject).allchan.lobe(chancurr), info.(subject).allchan.sublobe(chancurr), info.(subject).allchan.ind.region(chancurr), info.(subject).allchan.mni.region(chancurr), info.(subject).allchan.tal.region(chancurr)];
end
chaninfo = cat(1, {'Label', 'Type', 'Lobe', 'Sublobe', 'Ind', 'MNI', 'TAL'}, chaninfo);
end