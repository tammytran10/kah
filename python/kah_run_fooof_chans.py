""" Script for FOOOFing Kahana PSDs (average PSD across trials) per channel per subject. """

from fooof import FOOOF
import scipy.io as sio
import numpy as np
from kah_data import SUBJECTS

if __name__ == "__main__":
    # Find theta peaks and bandwidths for each channel per subject.
    for subject in SUBJECTS:
        print(subject)
        
        # Load data.
        mat_contents = sio.loadmat('/Volumes/DATAHD/Active/KAH/' + subject + '/psds/' + subject + '_FR1_psd_-800_1600.mat')
        
        # Extract frequency axis and power spectra. PSDs are 'channels x frequencies x trials'. 
        freq = np.squeeze(mat_contents['freq'])
        psds = mat_contents['psds']
        
        # Initialize FOOOF model.
        # Bandlimits [0.5, 4] for [-800, 1600]
        foof_model = FOOOF(fit_knee = False, max_n_oscs = 3, bandwidth_limits=(0.5, 4))

        # Define frequency range over which to model PSD. Use a low frequency range to optimize theta fits.
        # A more broadband range ([2, 50]) includes massive beta that swaps all estimates.
        freq_range = [2, 12]
            
        # Initialize output (list of FOOOF oscillation parameters), one for each channel.
        output = [[] for ichan in range(psds.shape[0])]
        
        # Fit model per channel using the mean PSD across trials. 
        for ichan in range(psds.shape[0]):
            foof_model.fit(freq, np.mean(psds[ichan, :, :], axis=1), freq_range)
            output[ichan] = foof_model.oscillation_params_
        
        # Save to .mat file.
        sio.savemat('/Volumes/DATAHD/Active/KAH/' + subject + '/fooof/' + subject + '_FR1_fooof_-800_1600_chans.mat', {'fooof':output})

    print('Done.')
