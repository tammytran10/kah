""" Class for loading Kahana features from CSV. """

import pandas as pd
import numpy as np

# Global variables for accessing data sets.
SINGLECHAN = ['sc', 'stsc'] # single-channel data sets
MULTICHAN  = ['mc', 'stmc'] # multi-channel data sets
DATASETS = [single for single in SINGLECHAN] + [multi for multi in MULTICHAN] # ['sc', 'stsc', 'stmc', 'mc']

CHANNELS = [['channel'], ['channel'], ['channelA', 'channelB'], ['channelA', 'channelB']]
REGIONS = [['region'], ['region'], ['regionA', 'regionB'], ['regionA', 'regionB']]
THETAS = [['thetachan'], ['thetachan'], ['thetachanA', 'thetachanB'], ['thetachanA', 'thetachanB']]

class KahData:
    """ Load Kahana data from CSV files. 

    Parameters
    ----------
    subject : string or 'all', optional
        Subject(s) for which to classify trial outcome. default: 'all'
    exclude_region : string or list of strings, optional
        Regions ('T', 'F', 'N') to exclude from feature calculation. default: None
    enforce_theta : boolean, optional
        Keep only channels and channel pairs in which theta was present. default: False
    enforce_phase : boolean, optional
        Keep only channel pairs in which there was significant theta phase encoding. default: False

    Attributes
    ----------
    csvpath : string
        Path to directory containing CSVs.
    paths : dictionary
        Paths to each CSV. Each CSV contains features from different segments of data, described below.
    stsc : Pandas Dataframe
        Single-trial, single-channel features. Examples include theta power, slope, HFA, within-channel PAC.
    stmc : Pandas Dataframe
        Single-trial, multi-channel features. Examples include between-channel PAC.
    sc : Pandas Dataframe
        Single-channel features. Examples include p-values for theta power and HFA.
    mc : Pandas Dataframe
        Multi-channel features. Examples include p-values for between-channel PAC and phase encoding episode characteristics.

    """

    # Set path information.
    csvpath = '/Users/Rogue/Documents/Research/Projects/KAH/csv/'
    paths = {'stsc':csvpath + 'kah_singletrial_singlechannel.csv', 
             'stmc':csvpath + 'kah_singletrial_multichannel.csv',
             'mc':csvpath + 'kah_multichannel.csv', 
             'sc':csvpath + 'kah_singlechannel.csv'}
    
    # Load data from each CSV.
    for path in paths:
        exec(path + ' = pd.read_csv(paths[path])')

    def __init__(self, subject='all', exclude_region=None, enforce_theta=False, enforce_phase=False):
        """ Create a KahData() object. """

        # Set input parameters. 
        self.subject = subject
        self.exclude_region = exclude_region
        self.enforce_theta = enforce_theta
        self.enforce_phase = enforce_phase

        # Extract data of interest based on subject, channel exclusion, and features of interest.
        self._set_data()

    def _set_data(self):
        """ Extract data based on the inputs to init. """
        
        # Initial data is all trials across all channels and subjects from KahData.
        for dataset in DATASETS:
            setattr(self, dataset, getattr(KahData, dataset))

        self._set_subject()
        self._set_region()
        self._set_theta()
        self._set_phasepair()
        self._set_betweenpac()

    def _set_subject(self):
        """ Remove subjects, if necessary. """

        if self.subject != 'all':
            for dataset in DATASETS:
                datacurr = getattr(self, dataset)
                setattr(self, dataset, datacurr[datacurr['subject'] == self.subject])

    def _set_region(self):
        """ Exclude regions, if necessary. """

        if self.exclude_region:
            for region_exclude in self.exclude_region:
                for idata, dataset in enumerate(DATASETS):
                    for region in REGIONS[idata]:
                        datacurr = getattr(self, dataset)
                        setattr(self, dataset, datacurr[datacurr[region] != region_exclude])

    def _set_theta(self):
        """ Determine theta channels and remove non-theta channels, if necessary. """

        # Mark channels that have theta.
        thetachan = self.sc[self.sc['pvalposttheta'] < 0.05]['channel']

        for idata, dataset in enumerate(DATASETS):
            for theta, channel in zip(THETAS[idata], CHANNELS[idata]):
                getattr(self, dataset)[theta] = [1 if chan in list(thetachan) else 0 for chan in getattr(self, dataset)[channel]]

        # Exclude channels without prominent theta, if necessary.
        if self.enforce_theta:
            # Single channels must have theta.
            for single in SINGLECHAN:
                datacurr = getattr(self, single)
                setattr(self, single, datacurr[datacurr['thetachan'] == 1])

            # Channel pairs must have theta in both channels.
            for multi in MULTICHAN:
                datacurr = getattr(self, multi)
                setattr(self, multi, datacurr[datacurr['thetachanA'] + datacurr['thetachanB'] == 2])

    def _set_phasepair(self):
        """ Mark phase-encoding pairs and remove non-encoding pairs, if necessary. """

        # Mark channel pairs showing significant phase encoding.
        phasepair = self.mc[self.mc['encodingepisodes'] > 0]['pair']
        for multi in MULTICHAN:
            getattr(self, multi)['phasepair'] = [1 if pair in list(phasepair) else 0 for pair in getattr(self, multi)['pair']]

        # Remove non-encoding pairs, if necessary.
        if self.enforce_phase: 
            for multi in MULTICHAN:
                datacurr = getattr(self, multi)
                setattr(self, multi, datacurr[datacurr['phasepair'] == 1])

    def _set_betweenpac(self):
        """ Determine per-trial, between-channel PAC values based the direction (AB or BA) in which PAC is strongest for that trial. """

        # Determine if PAC is stronger in direction AB or direction BA.
        ab = self.stmc['normtspacAB'] > self.stmc['normtspacBA']

        # Set PAC as that in the maximal direction.
        # NOTE: Because PAC direction is set for individual trials, a pair could be TF in one trial and FT in another.
        self.stmc['normtspacmax'] = np.maximum(self.stmc['normtspacAB'], self.stmc['normtspacBA'])

        # Construct region pair label using individual channel regions. This label corresponds to the AB direction.
        regionpair = ['{}{}'.format(regionA, regionB) for regionA, regionB in zip(self.stmc['regionA'], self.stmc['regionB'])]

        # Make a direction label using the region pair label. Flip the region pair label if PAC was stronger in the BA direction.
        self.stmc['direction'] = [pair if ab_ else pair[::-1] for pair, ab_ in zip(regionpair, ab)]


