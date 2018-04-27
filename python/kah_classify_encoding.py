""" Script for performing classification of encoded vs. forgotten trials for Kahana data. """

import numpy as np
import pickle
from kah_save_subject_data import SUBJECT_FILES
from kah_classifier import KahClassifier
from kah_data import SUBJECTS

def classify_encoding(subj_type, nseed, nresample, predictors, filename):  
    """ Classify data using given subject data and desired predictors, with or without resampling, repeated nseed number of times. """

    with open(SUBJECT_FILES[subj_type[0]], 'rb') as file:
        subjects = pickle.load(file) 
        if subj_type[1]:
            subjects = [subj for subj in subjects if subj.subject in subj_type[1]]

    auc = np.empty([len(subjects), nseed])
    if nresample > 0:
        auc_resample = np.empty([len(subjects), nseed, nresample])

    # Initialize classifier object.
    clf = KahClassifier(predictors=predictors)

    # Per subject, fit Logistic Regression models using various values of C. 
    for isubj in range(len(subjects)):    
        print(subjects[isubj].subject)

        # Set predictors and labels for current subject.
        clf._set_predictors_labels(subjects[isubj])

        # hyp = {'C':[1e-15, 1e-14, 1e-13, 1e-12, 1e-11, 1e-10, 1e-9, 1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1, 1, 10, 100, 1000, 10000, 100000, 1000000]}
    
        for seed in range(nseed):
            if np.mod(seed, 500) == 0:
                print(seed)
            clf.seed = seed
            clf.classify(subjects[isubj], 'logistic', hyperparameters=None, resample='permute', nresample=nresample, need_aggregate=False)
            auc[isubj, seed]= clf.roc_auc_
            if nresample > 0:
                auc_resample[isubj, seed, :] = clf.roc_auc_resample_

    # Save to disk.
    if nresample > 0:
        kah = {'auc':auc, 'auc_resample':auc_resample, 'subject_id':[subj.subject for subj in subjects], 'predictors':predictors}
    else:
        kah = {'auc':auc, 'subject_id':[subj.subject for subj in subjects], 'predictors':predictors}
    with open(filename, 'wb') as file:
        pickle.dump(kah, file) 

if __name__ == "__main__":
    # Pick subject data.
    no_theta = ['R1033D', 'R1034D', 'R1080E', 'R1154D']
    with_theta = [subj for subj in SUBJECTS if subj not in no_theta]
    non_theta = ['R1020J', 'R1033D', 'R1034D', 'R1059J', 'R1142N', 'R1167M']
    good_auc_all = ['R1020J', 'R1032D', 'R1034D', 'R1045E', 'R1059J', 'R1075J', 'R1080E', 'R1142N', 'R1147P', 'R1154D', 'R1166D', 'R1167M', 'R1175N'] # 13/17

    # Tuple format is (data type, subjects to include)
    subj_type = ('all', None)
    nseed = 1000
    nresample = 0
    predictors = [
        ('earlyhfa', 'T'),
        ('latetheta_cf', 'F'),
        ('earlyhfa', 'F'),
        ]
    filename = 'kah_all_all_nseed_1000_nresample_0_predictors_top3.pickle'

    classify_encoding(subj_type, nseed, nresample, predictors, filename)