""" Script for FOOOFing Kahana PSDs per trial per channel per subject. """

from fooof import FOOOF
import scipy.io as sio
import numpy as np

SUBJECTS = ['R1020J', 'R1032D', 'R1033D', 'R1034D', 'R1045E', 'R1059J', 'R1075J', 'R1080E', 'R1120E', 'R1135E', 'R1142N', 'R1147P', 'R1149N', 'R1151E', 'R1154D', 'R1162N', 'R1166D', 'R1167M', 'R1175N']

def run_fooof_trials(timewin, padlabel):
    """ Use FOOOF to get individual trial slope and HFA (offset) measurements. """
    for subject in SUBJECTS:
        print(subject)
        
        # Load data.
        mat_contents = sio.loadmat('/Volumes/DATAHD/Active/KAH/' + subject + '/psd/' + subject + '_FR1_psd_' + str(timewin[0]) + '_' + str(timewin[1]) + padlabel + '.mat')
        
        # Extract frequency axis and power spectra. PSDs are 'channels x frequencies x trials'. 
        freq = np.squeeze(mat_contents['freq'])
        psds = mat_contents['psds']
        
        # Initialize FOOOF model.
        foof_model = FOOOF(background_mode='fixed', peak_width_limits=[2.5, 12], peak_threshold=np.inf)
            
        # Initialize output (list of FOOOF oscillation parameters), one for each channel and trial.
        slopes = [[[] for _ in range(psds.shape[-1])] for _ in range(psds.shape[0])]
        hfa = [[[] for _ in range(psds.shape[-1])] for _ in range(psds.shape[0])]
        
        # Fit model per channel per trial.
        for ichan in range(psds.shape[0]):
            for itrial in range(psds.shape[-1]):
                # Fit for slope and HFA.
                try:
                    foof_model.fit(freq, psds[ichan, :, itrial], [2, 150])
                except Exception:
                    print('Skipping channel {}, trial {} because of slope'.format(ichan, itrial))
                    continue
                hfa[ichan][itrial] = foof_model.background_params_[0]
                slopes[ichan][itrial] = foof_model.background_params_[1]

                # # Fit for HFA.
                # try:
                #     foof_model.fit(freq, psds[ichan, :, itrial], [2, 150])
                # except Exception:
                #     print('Skipping channel {}, trial {} because of hfa'.format(ichan, itrial))
                #     continue
                # hfa[ichan][itrial] = foof_model.background_params_[0]
        
        # Save to .mat file.
        sio.savemat('/Volumes/DATAHD/Active/KAH/' + subject + '/fooof/' + subject + '_FR1_fooof_' + str(timewin[0]) + '_' + str(timewin[1]) + padlabel + '_slopes_hfa.mat', {'slopes':slopes, 'hfa':hfa})

    print('Done.')

if __name__ == "__main__":
    padlabel =  ''
 
    timewin = [-800, 0]
    run_fooof_trials(timewin, padlabel)

    timewin = [0, 800]
    run_fooof_trials(timewin, padlabel)

    timewin = [800, 1600]
    run_fooof_trials(timewin, padlabel)

