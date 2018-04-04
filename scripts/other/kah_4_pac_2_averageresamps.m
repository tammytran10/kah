clear; clc

info = kah_info;

experiment = 'FR1';

nperm = 100;
pactype = 'ts';

for isubj = 1:length(info.subj)
    subject = info.subj{isubj};

    disp([num2str(isubj) ' ' subject])
    
    % Load all permutations of between-channel PAC and calculate average using running sum.
    pacbetween = [];
    for iperm = 1:nperm
        if mod(iperm, 10) == 0, disp(['Loading permutation ' num2str(iperm)]); end
        input = load([info.path.processed.hd subject '_' experiment '_pac_between_' pactype '_-800_1600_resamp_' num2str(iperm) '.mat'], 'pacbetween');
        if isempty(pacbetween)
            pacbetween = zeros(size(input.pacbetween));
        end
        pacbetween = pacbetween + input.pacbetween;
    end
    pacbetween = pacbetween ./ nperm;
    save([info.path.processed.hd subject '_' experiment '_pac_between_' pactype '_-800_1600_resamp_mean.mat'], 'pacbetween')
end
disp('Done')