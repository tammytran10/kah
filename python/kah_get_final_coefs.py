""" Script for getting final model coefficients for classifiers for Kahana data. """

import numpy as np
import pickle
from kah_save_subject_data import SUBJECT_FILES
from kah_classifier import KahClassifier
from kah_data import SUBJECTS
from scipy import stats

def get_final_coefs(subj_type, predictors, filename):  
    """ Classify data using given subject data and desired predictors and get model coefficients with same C across subjects. """

    # Load data.
    with open(SUBJECT_FILES[subj_type[0]], 'rb') as file:
        subjects = pickle.load(file) 
        if subj_type[1]:
            subjects = [subj for subj in subjects if subj.subject in subj_type[1]]
    
    # Per subject, fit Logistic Regression models using various values of C. 
    # Save the C value associated with highest CV performance.
    C_best = np.empty(len(subjects))

    for isubj in range(len(subjects)):    
        print(subjects[isubj].subject)
    
        clf = KahClassifier(predictors=predictors)
        clf.classify(subjects[isubj], 'logistic', hyperparameters=None)
        C_best[isubj] = clf.final_estimator_.C_

    # Get the most common C value across subjects.
    C_mode = stats.mode(C_best).mode

    # Refit models using the common C and save the coefficients.
    coefs = np.empty([len(subjects), len(predictors) + 1])

    for isubj in range(len(subjects)):
        clf.classify(subjects[isubj], 'logistic', hyperparameters={'C':[C_mode]})
        coefs[isubj, :] = clf.final_estimator_.coef_

    # Save to disk.
    kah = {'C_best':C_best, 'C_mode':C_mode, 'coefs':coefs}
    with open(filename, 'wb') as file:
        pickle.dump(kah, file) 

if __name__ == "__main__":
    # Pick subject data based on exclusion criteria.

    no_theta = ['R1033D', 'R1080E', 'R1120E']
    bad_auc = ['R1059J', 'R1149N', 'R1162N', 'R1167M', 'R1175N']
    good_auc = [subj for subj in SUBJECTS if subj not in bad_auc and subj not in no_theta]

    # Tuple format is (data type, subjects to include)
    subj_type = ('theta', good_auc)
    predictors = 'all'
    filename = 'kah_theta_classifiableonly_predictors_all_coefs.pickle'

    get_final_coefs(subj_type, predictors, filename)