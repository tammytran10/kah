function [event] = read_upennram_event(eventfile)

% READ_UPENNRAM_EVENT reads events from UPenn's RAM (Restoring Active Memory) publically
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
% [event] = read_upennram_event(eventfile)
%
%      Where,
%          eventfile = string, path+name of JSON file containing events from a RAM dataset (e.g. ../task_events.json, math_events.json, etc)
%      And,
%              event = 1Xnevent structure-array, where each structure contains an event, described by its fields.
%
%  For details on what each field in [event] reflects, see the Metadata documentation released together with the RAM datasets.
% 
%
% The read_upennram_event and read_upennram_header functions currently depends on JSONlab (by Qianqian Fang)
% from the MATLAB File Exchange, to parse the above JSON formatted files.
%
% See also READ_UPENNRAM_HEADER, READ_UPENNRAM_DATA

% Copyright (C) 2016-2017, Roemer van der Meij

% parse events in event file
event = loadjson(eventfile);
event = [event{:}];







