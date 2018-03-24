import numpy as np
import pickle
from kah_save_subject_data import SUBJECT_FILES
from kah_classifier import KahClassifier, PREDICTORS_ALL
import os 

def classify_stepforward(subj_type, nseed, predictors, foldername):  
    # Pick subject data based on exclusion criteria.
    with open(SUBJECT_FILES[subj_type[0]], 'rb') as file:
        subjects = pickle.load(file) 
        if subj_type[1]:
            subjects = [subj for subj in subjects if subj.subject not in subj_type[1]]

    filename = foldername + '/kah_stepforward_npred{}_ipred{}.pickle'

    # Start by considering all possible features.
    top_features = []

    if predictors == 'all':
        predictors = PREDICTORS_ALL
    
    # Build one-, then two-, then three- ... feature models, each time building on the most predictive previous models.
    for npred in range(len(predictors)):
        predictors_available = [pred for pred in predictors if pred not in top_features]
        
        # If all n-feature models have already been built, extract known top features.
        if os.path.isfile(filename.format(npred, len(predictors_available) - 1)):
            top_features.append(_get_top_feature(filename, npred, predictors_available))
            continue
        
        print('Fitting models with {} features.'.format(npred + 1))
        for ipred, predictor in enumerate(predictors_available):
            # If current n-feature model has already been built, skip to the next.
            if os.path.isfile(filename.format(npred, ipred)):
                continue
                
            print('{}/{}'.format(ipred, len(predictors_available) - 1))
            
            auc_subset = np.empty([len(subjects), nseed])
            for isubj in range(len(subjects)):    
                for seed in range(nseed):
                    # Classify using top features and each of the potential features left.
                    clf = KahClassifier(predictors=[*top_features, predictor], seed=seed)
                    clf.classify(subjects[isubj], 'logistic', hyperparameters=None)
                    auc_subset[isubj, seed] = clf.roc_auc_
                
            # Save each new feature combo to disk.
            kah_stepforward = {'auc_subset':auc_subset, 'predictors_available':predictors_available}
            with open(filename.format(npred, ipred), 'wb') as file:
                pickle.dump(kah_stepforward, file) 
        
        # Find and add new top feature to list.
        top_features.append(_get_top_feature(filename, npred, predictors_available))

def _get_top_feature(filename, npred, predictors_available):
    auc_allsubsets = []
    for ipred in range(len(predictors_available)):
        with open(filename.format(npred, ipred), 'rb') as file:
            auc_curr = pickle.load(file)['auc_subset'] 
            if ipred == 0:
                auc_allsubsets = auc_curr
            else:
                auc_allsubsets = np.dstack((auc_allsubsets, auc_curr))

    return predictors_available[np.argmax(np.median(np.median(auc_allsubsets, axis=1), axis=0))]

if __name__ == "__main__":
    # Pick subject data based on exclusion criteria.
    subj_type = ('theta', ['R1033D', 'R1080E', 'R1120E', # not enough theta channels
    'R1059J', 'R1149N', 'R1162N', 'R1167M', 'R1175N']) # classification poor
    nseed = 200
    predictors = 'all'
    foldername = 'stepforward_theta_classifiableonly_nseed_200'

    classify_stepforward(subj_type, nseed, predictors, foldername)