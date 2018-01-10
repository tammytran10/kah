function data = kah_visualizedata(info, subject, datatype, timewin)
% Load data
data = kah_loadftdata(info, subject, datatype, timewin, 0);

% Visualize data.
cfg = []; 
cfg.viewmode  = 'vertical';
cfg.ylim      = [-40 40];  
cfg.blocksize = length(data.time{1})/data.fsample;         
ft_databrowser(cfg, data);