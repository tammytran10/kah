import numpy as np
import pickle
from kah_save_subject_data import SUBJECT_FILES
from kah_classifier import KahClassifier

def classify_encoding(subjects, nseed, nresample, predictors, filename):  
    auc = np.empty([len(subjects), nseed])
    if nresample > 0:
        auc_resample = np.empty([len(subjects), nseed, nresample])

    # Per subject, fit Logistic Regression models using various values of C. 
    for isubj in range(len(subjects)):    
        print(subjects[isubj].subject)

        # hyp = {'C':[1e-15, 1e-14, 1e-13, 1e-12, 1e-11, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1, 1, 10, 100, 1000, 10000, 100000, 1000000]}
    
        for seed in range(nseed):
            if np.mod(seed, 500) == 0:
                print(seed)
            clf = KahClassifier(predictors=predictors, seed=seed)
            clf.classify(subjects[isubj], 'logistic', hyperparameters=None, resample='permute', nresample=nresample)
            auc[isubj, seed]= clf.roc_auc_
            if nresample > 0:
                auc_resample[isubj, seed, :] = clf.roc_auc_resample_

    # Save to disk.
    kah = {'auc':auc, 'auc_resample':auc_resample}
    with open(filename, 'wb') as file:
        pickle.dump(kah, file) 

if __name__ == "__main__":
    # Pick subject data based on exclusion criteria.
    subjects = 'theta'
    nseed = 1000
    nresample = 1000
    predictors = 'all'
    filename = 'kah_nseed_1000_nresample_1000_predictors_all.pickle'

    with open(SUBJECT_FILES[subjects], 'rb') as file:
        subjects = pickle.load(file) 

    classify_encoding(subjects, nseed, nresample, predictors, filename)