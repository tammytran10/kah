%{
Kahana data set for free recall task
Subset of 68 subjects, published in Burke et al. 2013
%}

clear
close all

% input data
kahana = struct;
kahana.ages = [15,8,17,20,14,19,16,13,33,25,31,41,34,45,46,20,53,50,28,37,18,23,21,35,37,41,21,43,19,21,35,25,41,25,40,34,44,43,21,56,57,20,41,34,52,44,33,23,48,33,45,23,53,29,35,48,20,20,38,30,43,36,25,18,27,40,27,37];
kahana.percentRecall = [28.7,26.5,10.7,31.7,20.9,18.4,31.7,33.3,23.9,25.0,13.3,16.4,27.1,16.9,16.7,14.0,16.3,19.3,12.3,21.7,40.3,34.5,32.7,18.0,30.7,8.4,22.2,10.2,32.0,51.7,19.6,32.3,28.7,32.2,17.1,22.7,15.9,24.2,20.1,16.7,10.0,26.7,20.8,26.7,36.7,45.0,32.0,29.2,35.0,37.6,22.6,37.2,18.1,48.3,22.8,18.0,43.1,30.8,22.5,18.0,11.5,11.7,22.5,23.1,21.7,31.7,28.1,25.1];

% include only subjects 18 and over
adults = kahana.ages >= 18;
kahana.ages = kahana.ages(adults);
kahana.percentRecall = kahana.percentRecall(adults);

% median split by age
young = kahana.ages < median(kahana.ages);
old = ~young;

yAge = kahana.ages(young);
oAge = kahana.ages(old);
age = [yAge, oAge];

yNum = sum(young);
oNum = sum(old);
ageLabel = [zeros(1, yNum), ones(1, oNum)];

yRecall = kahana.percentRecall(young);
oRecall = kahana.percentRecall(old);
recall = [yRecall, oRecall];

[~, pTtest] = ttest2(yRecall, oRecall, 'vartype', 'unequal');
% d = cohens_d(yRecall, oRecall, false);

figure
boxplot(recall, ageLabel, 'labels', {'Young', 'Old'})
ylabel('Percent Recall (%)')

% correlate age with percent recall
coeffs = polyfit(kahana.ages, kahana.percentRecall, 1);
recallPredicted = coeffs(2) + (coeffs(1) * kahana.ages);
figure
hold on
scatter(kahana.ages, kahana.percentRecall, [], 'blue', 'filled')
plot(kahana.ages, recallPredicted, 'b')
[rho, pCorr] = corr(kahana.ages.', kahana.percentRecall.');

xlim([0, 60])
ylim([0, 55])
xlabel('Age (Years)')
ylabel('Percent Recall (%)')