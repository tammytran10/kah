""" Script for FOOOFing Kahana PSDs per trial per channel per subject. """

from fooof import FOOOF
import scipy.io as sio
import numpy as np
from kah_data import SUBJECTS

if __name__ == "__main__":
    # Change these to process different PSDs.
    timewin = [-800, 0]
    padlabel = ''

    # Find theta peaks and bandwidths for each channel per subject.
    for subject in SUBJECTS:
        print(subject)
        
        # Load data.
        mat_contents = sio.loadmat('/Volumes/DATAHD/Active/KAH/' + subject + '/psd/' + subject + '_FR1_psd_' + str(timewin[0]) + '_' + str(timewin[1]) + padlabel + '.mat')
        
        # Extract frequency axis and power spectra. PSDs are 'channels x frequencies x trials'. 
        freq = np.squeeze(mat_contents['freq'])
        psds = mat_contents['psds']
        
        # Initialize FOOOF model.
        # low limit 2.5 for [-800, 0] unpadded
        foof_model = FOOOF(background_mode='fixed', peak_width_limits=[2.5, 12], peak_threshold=np.inf)

        # Define frequency range over which to model PSD. Use a low frequency range to optimize theta fits.
        # A more broadband range ([2, 50]) includes massive beta that swaps all estimates.
        freq_range = [2, 55]
            
        # Initialize output (list of FOOOF oscillation parameters), one for each channel and trial.
        output = [[[] for _ in range(psds.shape[-1])] for _ in range(psds.shape[0])]
        
        # Fit model per channel per trial.
        for ichan in range(psds.shape[0]):
            for itrial in range(psds.shape[-1]):
                try:
                    foof_model.fit(freq, psds[ichan, :, itrial], freq_range)
                except Exception:
                    print('Skipping channel ' + str(ichan) + ', trial ' + str(itrial))
                    continue
                if foof_model.peak_params_.shape[0] != 0:
                    raise ValueError('Peak detected. Raise the peak_threshold parameter.')
                output[ichan][itrial] = foof_model.background_params_[1]
        
        # Save to .mat file.
        sio.savemat('/Volumes/DATAHD/Active/KAH/' + subject + '/fooof/' + subject + '_FR1_fooof_' + str(timewin[0]) + '_' + str(timewin[1]) + padlabel + '.mat', {'fooof':output})

    print('Done.')
