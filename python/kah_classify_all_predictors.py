import numpy as np
import pickle
from kah_classifier import KahClassifier

if __name__ == "__main__":
    # Pick subject data based on exclusion criteria.
    with open('kah_subjects_theta.pickle', 'rb') as file:
        subjects = pickle.load(file) 

    # Set number of iterations per subject to run.
    nseed = 1000

    # Set number of permutations per iteration to run.
    nresample = 1000

    auc_allfeatures = np.empty([len(subjects), nseed])
    auc_resample_allfeatures = np.empty([len(subjects), nseed, nresample])

    # Per subject, fit Logistic Regression models using various values of C. 
    for isubj in range(len(subjects)):    
        print(subjects[isubj].subject)

        # hyp = {'C':[1e-15, 1e-14, 1e-13, 1e-12, 1e-11, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1, 1, 10, 100, 1000, 10000, 100000, 1000000]}
    
        for seed in range(nseed):
            if np.mod(seed, 500) == 0:
                print(seed)
            clf = KahClassifier(predictors='all', seed=seed)
            clf.classify(subjects[isubj], 'logistic', hyperparameters=None, resample='permute', nresample=nresample)
            auc_allfeatures[isubj, seed]= clf.roc_auc_
            auc_resample_allfeatures[isubj, seed, :] = clf.roc_auc_resample_

    # Save to disk.
    kah_allfeatures_resample = {'auc_allfeatures':auc_allfeatures, 'auc_resample_allfeatures':auc_resample_allfeatures}
    with open('kah_allfeatures_resample.pickle', 'wb') as file:
        pickle.dump(kah_allfeatures_resample, file) 