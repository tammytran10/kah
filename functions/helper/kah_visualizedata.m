function kah_visualizedata(data)
% Visualize data.
cfg = []; 
cfg.viewmode  = 'vertical';
cfg.ylim      = [-40 40];  
cfg.blocksize = length(data.times{1})/data.fsample;         
ft_databrowser(cfg, data);