function [statA, statB, statbetween, pvalA, pvalB, pvalbetween] = kah_calculatephaseencode(phaseA, phaseB, trialoutcome, testtype, outputfile)

% KAH_CALCULATEPHASEENCODE returns the statistics needed for determining if the phase of (or phase difference between) channels is predictive of trial outcome.
% 
% Inputs:
%   phaseA (vector or matrix; string) - an nsample x ntrial matrix (or single vector) of phase values for channel A
%                                     - if string, the name of a file with variable 'data' that is an nxample x ntrial matrix
%   phaseB (vector or matrix; string) - an nsample x ntrial matrix (or single vector) of phase values for channel B
%                                     - if string, the name of a file with variable 'data' that is an nxample x ntrial matrix
%   trialoutcome (vector)             - an ntrial x 1 vector of trial outcomes (remembered vs. forgotten).
%                                       can also be left empty if 'trialinfo' is available in the file 'phaseA'
%   testtype (string)                 - 'corrcl', 'wwtest', or 'cmtest'
%                                       depending on whether circular-linear correlation, ANOVA, or median test should be used to 
%   trialnums
%   outputfile (string)               - if not empty, where to save output
%
% Outputs:
%   Outputs are test statistic and p-value time series.
%   These time series are for phaseA and phaseB individually and also for the difference between them.
%   Test statistics are dependent on the type of test used (rho, F-statistic, P-statistic).
%
% Usage:
%   [statA, statB, statbetween, pvalA, pvalB, pvalbetween] = kah_calculatephaseencode(phaseA, phaseB, trialoutcome, 'corrcl', 'savehere.mat');

% If phaseA and phaseB are file names, load data. 
if ischar(phaseA)
    phaseA = load(phaseA);
    
    if isempty(trialoutcome)
        trialoutcome = logical(phaseA.trialinfo(:, 3));
    end
    
    phaseA = phaseA.data;

    phaseB = load(phaseB);
    phaseB = phaseB.data;
end

% Get number of samples (first dimension; second dimension is trial number). 
nsamp = size(phaseA, 1);

% Initialize output variables.
[statA, statB, statbetween, pvalA, pvalB, pvalbetween] = deal(nan(nsamp, 1));

% Test differences in phase (or phase differences) per sample between remembered/forgotten trials.
for isamp = 1:nsamp
    % Choose test type.
    switch testtype
        
        % Test type is circular-linear correlation (phase predicts encoding).
        % Test statitistic is rho. 
        case 'corrcl'
            [statA(isamp), pvalA(isamp)] = circ_corrcl(phaseA(isamp,:), trialoutcome);
            [statB(isamp), pvalB(isamp)] = circ_corrcl(phaseB(isamp,:), trialoutcome);
            [statbetween(isamp), pvalbetween(isamp)] = circ_corrcl(phaseA(isamp,:) - phaseB(isamp,:), trialoutcome);
        
        % Test type is a circular one-way ANOVA, the Watson-Williams test.
        % Test statistic is the F-statistic.
        case 'wwtest'
            [pvalA(isamp), table] = circ_wwtest(phaseA(isamp, trialoutcome), phaseA(isamp, ~trialoutcome));
            statA(isamp) = table{2, 5}; % F statistic
            
            [pvalB(isamp), table] = circ_wwtest(phaseB(isamp, trialoutcome), phaseB(isamp, ~trialoutcome));
            statB(isamp) = table{2, 5};
            
            [pvalbetween(isamp), table] = circ_wwtest(phaseA(isamp, trialoutcome) - phaseB(isamp, trialoutcome), ...
                phaseA(isamp, ~trialoutcome) - phaseB(isamp, ~trialoutcome));
            statbetween(isamp) = table{2, 5};
            
        % Test type is a nonparametric test for equal medians akin to the Kruskal-Wallis test.
        % Test statistic is the P-statistic.
        case 'cmtest'
            [pvalA(isamp), ~, statA(isamp)] = circ_cmtest(phaseA(isamp, trialoutcome), phaseA(isamp, ~trialoutcome));
            [pvalB(isamp), ~, statB(isamp)] = circ_cmtest(phaseB(isamp, trialoutcome), phaseB(isamp, ~trialoutcome));
            [pvalbetween(isamp), ~, statbetween(isamp)] = circ_cmtest(phaseA(isamp, trialoutcome) - phaseB(isamp, trialoutcome), ...
                phaseA(isamp, ~trialoutcome) - phaseB(isamp, ~trialoutcome));
            
        otherwise
            error('Test type is not recognized.')
    end
end

% Save output to file, if necessary.
if ~isempty(outputfile)
    save(outputfile, 'statA', 'statB', 'statbetween', 'pvalA', 'pvalB', 'pvalbetween')
end
    