""" Script for loading Kahana data per subject and aggregating into temporal and frontal measures per trial. """

from kah_data import SUBJECTS, KahData
import pickle

# All channels, only theta channels/pairs, only theta and phase encoding.
SUBJECT_TYPES = ['all', 'theta', 'theta_phase', 'notheta']

# Files to save to.
SUBJECT_FILES = {}
for subj_type in SUBJECT_TYPES:
    SUBJECT_FILES[subj_type] = 'data/kah_subjects_{}.pickle'.format(subj_type)

if __name__ == "__main__":
    # Load subject data.
    subject_data = {}
    for subj_type in SUBJECT_TYPES:
        subject_data[subj_type] = []

    for isubj in range(len(SUBJECTS)):
        print(SUBJECTS[isubj])
        
        # For no channel exclusions.
        subject_data['all'].append(KahData(subject=SUBJECTS[isubj], exclude_region='N'))

        # For excluding channels without theta.
        subject_data['theta'].append(KahData(subject=SUBJECTS[isubj], exclude_region='N', enforce_theta=True, theta_threshtype='bump'))

        # For excluding channels with theta.
        subject_data['notheta'].append(KahData(subject=SUBJECTS[isubj], exclude_region='N', exclude_theta=True, theta_threshtype='bump'))

        # For excluding channels without theta and channel pairs without phase encoding.
        subject_data['theta_phase'].append(KahData(subject=SUBJECTS[isubj], exclude_region='N', enforce_theta=True, enforce_phase=True, theta_threshtype='bump'))

    # Save to disk.
    for subj_type in SUBJECT_TYPES:
        with open(SUBJECT_FILES[subj_type], 'wb') as file:
            pickle.dump(subject_data[subj_type], file) 
