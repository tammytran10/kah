function [dat] = read_upennram_data(datadir, hdr, begsample, endsample, chanindx)

% READ_UPENNRAM_DATA reads samples from UPenn's RAM (Restoring Active Memory) publically
% available datasets.
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
% [dat] = read_upennram_data(datadir, hdr, begsample, endsample, chanindx)
%
%      Where,
%            datadir = string, path+directory containing channel-specific data files (PATIENTID_DATAID.001, 002, etc)
%                hdr = structure as obtained from READ_UPENNRAM_HEADER containing info on datafiles
%          begsample = scalar, indicating first sample to read, counted from start of recording to end of recording
%          endsample = scalar, indicating last sample to read, counted from start of recording to end of recording
%           chanindx = 1Xnchan vector, index of channels to read, indexing into hdr.label (containing names of all channels)
%      And,
%                dat = NChanXNSample matrix, spatiotemporal matrix containing the requested data
% 
%
%
% See also READ_UPENNRAM_HEADER, READ_UPENNRAM_EVENT

% Copyright (C) 2016-2017, Roemer van der Meij

nchan   = numel(chanindx);
nsample = endsample-begsample+1;

% safety checks
if nsample > hdr.nSamples
  error('requested data exceeds available data')
end

% allocate memory
dat = zeros(nchan,nsample);

% loop over channels, read in data
for ichan = 1:nchan
  fn = [datadir hdr.channelfile{chanindx(ichan)}]; % this ensures there is no mismatch between data and header (as it will unavoidably lead to an error)
  
  % open file read-only
  fid = fopen(fn,'r');
  
  % move seeker in position
  fseek(fid,(hdr.nBytes*(begsample-1)),'bof');
  
  % fetch data
  dat(ichan,:) = fread(fid,nsample,hdr.dataformat);
  
  % close file
  fclose(fid);
end


  
  
  
  
  
  
  
  
  
  
  
  
  
  
  







