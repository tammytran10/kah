import numpy as np
import pickle
from kah_classifier import KahClassifier, PREDICTORS_ALL
import os 

def get_top_feature(nsubject, nseed, npred, predictors_available):
    filename = 'stepforward_seed' + str(nseed) + '/kah_stepforward_npred{}_ipred{}.pickle'
    auc_allsubsets = np.empty([nsubject, nseed, len(predictors_available)])
    for ipred in range(len(predictors_available)):
        with open(filename.format(npred, ipred), 'rb') as file:
            auc_allsubsets[:,:,ipred] = pickle.load(file)['auc_subset'] 

    return predictors_available[np.argmax(np.median(np.median(auc_allsubsets, axis=1), axis=0))] #, auc_allsubsets

# Pick subject data based on exclusion criteria.
with open('kah_subjects_theta.pickle', 'rb') as file:
    subjects = pickle.load(file) 

# Find informative subsets of features using forward selection.
nseed = 200

filename = 'stepforward_seed' + str(nseed) + '/kah_stepforward_npred{}_ipred{}.pickle'

# Start by considering all possible features.
top_features = []

# Build one-, then two-, then three- ... feature models, each time building on the most predictive previous models.
for npred in range(len(PREDICTORS_ALL)):
    predictors_available = [pred for pred in PREDICTORS_ALL if pred not in top_features]
    
    # If all n-feature models have already been built, extract known top features.
    if os.path.isfile(filename.format(npred, len(predictors_available) - 1)):
        top_features.append(get_top_feature(len(subjects), nseed, npred, predictors_available))
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
    top_features.append(get_top_feature(len(subjects), nseed, npred, predictors_available))