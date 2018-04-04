import numpy as np
import pickle
from kah_save_subject_data import SUBJECT_FILES
from kah_classifier import KahClassifier, PREDICTORS_ALL
import os 
from kah_data import SUBJECTS

def classify_stepforward_subject(subj_type, nseed, predictors, foldername):  
    subj_type, subject_id = subj_type

    # Pick subject data based on exclusion criteria.
    with open(SUBJECT_FILES[subj_type], 'rb') as file:
        subjects = pickle.load(file) 
        if subj_type[1]:
            subjects = [subj for subj in subjects if subj.subject in subject_id]

    if predictors == 'all':
        predictors = PREDICTORS_ALL
    
    # Set file name to save output to.
    filename = foldername + '/kah_stepforward_{}_npred{}_ipred{}.pickle'

    # Stepforward individually for each subject.
    for isubj in range(len(subjects)):
        print(subject_id[isubj])
        
        # Start by considering all possible features.
        top_features = []

        # Build one-, then two-, then three- ... feature models, each time building on the most predictive previous models.
        for npred in range(len(predictors)):
            predictors_available = [pred for pred in predictors if pred not in top_features]
        
            # If all n-feature models have already been built, extract known top features.
            if os.path.isfile(filename.format(subject_id[isubj], npred, len(predictors_available) - 1)):
                top_features.append(_get_top_feature(filename, subject_id[isubj], npred, predictors_available))
                print('Adding feature {}'.format(top_features[-1]))
                continue
        
            print('Fitting models with {} features.'.format(npred + 1))
            for ipred, predictor in enumerate(predictors_available):
                # If current n-feature model has already been built, skip to the next.
                if os.path.isfile(filename.format(subject_id[isubj], npred, ipred)):
                    continue
                
                print('{}/{}'.format(ipred, len(predictors_available) - 1))
            
                auc_subset = np.empty([nseed])
                for seed in range(nseed):
                    # Classify using top features and each of the potential features left.
                    clf = KahClassifier(predictors=[*top_features, predictor], seed=seed)
                    clf.classify(subjects[isubj], 'logistic', hyperparameters=None)
                    auc_subset[seed] = clf.roc_auc_
                
                # Save each new feature combo to disk.
                kah_stepforward = {'auc_subset':auc_subset, 'predictors_available':predictors_available}
                with open(filename.format(subject_id[isubj], npred, ipred), 'wb') as file:
                    pickle.dump(kah_stepforward, file) 
        
            # Find and add new top feature to list.
            top_features.append(_get_top_feature(filename, subject_id[isubj], npred, predictors_available))
            print('Current list of top features: {}'.format(top_features))

def _get_top_feature(filename, subject, npred, predictors_available):
    # Return single feature if only one is provided.
    if len(predictors_available) == 1:
        return predictors_available[0]
    
    # Aggregate all models with npred number of features.
    auc_allsubsets = []
    for ipred in range(len(predictors_available)):
        with open(filename.format(subject, npred, ipred), 'rb') as file:
            auc_curr = pickle.load(file)['auc_subset'] 
            if ipred == 0:
                auc_allsubsets = auc_curr
            else:
                auc_allsubsets = np.vstack((auc_allsubsets, auc_curr))
    
    # Average across seeds, then find the feature corresponding to highest AUC.
    return predictors_available[np.argmax(np.median(auc_allsubsets, axis=1))]

if __name__ == "__main__":
    # Pick subject data based on exclusion criteria.
 
    no_theta = ['R1033D', 'R1080E', 'R1120E']
    with_theta = [subj for subj in SUBJECTS if subj not in no_theta]
    bad_auc = ['R1059J', 'R1149N', 'R1162N', 'R1167M', 'R1175N']
    good_auc = [subj for subj in SUBJECTS if subj not in bad_auc and subj not in no_theta]
    non_theta = ['R1020J', 'R1033D', 'R1034D', 'R1080E', 'R1154D', 'R1167M']

    # Tuple format is (data type, subjects to include)
    subj_type = ('theta', with_theta)
    nseed = 200
    predictors = 'all'
    foldername = 'stepforward_theta_all_nseed_200_subject'

    classify_stepforward_subject(subj_type, nseed, predictors, foldername)