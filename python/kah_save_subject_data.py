# Script for loading Kahana data per subject and aggregating into temporal and frontal measures per trial.

from kah_data import SUBJECTS, KahData
import pickle

if __name__ == "__main__":
    subjects_all = []
    subjects_theta = []
    subjects_theta_phase = []

    # Load subject data.
    for isubj in range(len(SUBJECTS)):
        print(SUBJECTS[isubj])
        
        # For no channel exclusions.
        subjects_all.append(KahData(subject=SUBJECTS[isubj], exclude_region='N', enforce_theta=False, enforce_phase=False, 
                                theta_threshtype='bump'))

        # For excluding channels without theta.
        subjects_theta.append(KahData(subject=SUBJECTS[isubj], exclude_region='N', enforce_theta=True, enforce_phase=False, 
                                theta_threshtype='bump'))

        # For excluding channels without theta and channel pairs without phase encoding.
        subjects_theta_phase.append(KahData(subject=SUBJECTS[isubj], exclude_region='N', enforce_theta=True, enforce_phase=True, 
                                theta_threshtype='bump'))

    # For theta enforcement, drop subjects with low channel number per region.
    subjects_theta_drop = ['R1033D', 'R1080E', 'R1120E']
    subjects_theta = [subj for subj in subjects_theta if subj.subject not in subjects_theta_drop]

    # Save to disk.
    with open('kah_subjects_all.pickle', 'wb') as file:
        pickle.dump(subjects_all, file) 

    with open('kah_subjects_theta.pickle', 'wb') as file:
        pickle.dump(subjects_theta, file) 

    with open('kah_subjects_theta_phase.pickle', 'wb') as file:
        pickle.dump(subjects_theta_phase, file) 
