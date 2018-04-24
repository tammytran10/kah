""" Class for loading Kahana features from CSV. """

import pandas as pd
import numpy as np

# Global variables for accessing data sets.
SINGLECHAN = ['sc', 'stsc'] # single-channel data sets
MULTICHAN  = ['mc', 'stmc'] # multi-channel data sets
DATASETS = [single for single in SINGLECHAN] + [multi for multi in MULTICHAN] # ['sc', 'stsc', 'stmc', 'mc']

CHANNELS = [['channel'], ['channel'], ['channelA', 'channelB'], ['channelA', 'channelB']]
REGIONS = [['region'], ['region'], ['regionA', 'regionB'], ['regionA', 'regionB']]
LOBES = [['lobe'], ['lobe'], ['lobeA', 'lobeB'], ['lobeA', 'lobeB']]
THETAS = [['thetachan'], ['thetachan'], ['thetachanA', 'thetachanB'], ['thetachanA', 'thetachanB']]

SUBJECTS = ['R1020J', 'R1032D', 'R1033D', 'R1034D', 'R1045E', 'R1059J', 'R1075J', 'R1080E', 'R1135E', 'R1142N', 'R1147P', 'R1149N', 'R1154D', 'R1162N', 'R1166D', 'R1167M', 'R1175N']

class KahData:
    """ Load Kahana data from CSV files. 

    Parameters
    ----------
    subject : string or 'all', optional
        Subject(s) for which to classify trial outcome. default: 'all'
    include_region : string or list of strings, optional
        Regions or lobes to include during feature calculation. default: None (include all)
    enforce_theta : boolean, optional
        Keep only channels and channel pairs in which theta was present. default: False
    enforce_phase : boolean, optional
        Keep only channel pairs in which there was significant theta phase encoding. default: False
    theta_threshtype : string, optional
        Detect theta channels based on 'pval' (binomial test, # of trials > 0.5), 'percent' (% of trials with theta), or 'bump' (FOOOF bump
        in average across trials). default: 'bump'
    theta_threshlevel : float, optional
        Threshold for detecting theta. For 'pval', this is the p-value threshold. For 'percent', this is the % trials threshold. Ignored
        for 'bump'. default: None
    theta_bandtype : string, optional
        To use individualized ('cf') or canonical ('canon') theta bands.
    
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

    def __init__(self, subject='all', include_regions=None, enforce_theta=False, enforce_phase=False, theta_threshtype='bump', theta_threshlevel=None, exclude_theta=False, theta_bandtype='cf'):
        """ Create a KahData() object. """

        # Set input parameters. 
        self.subject = subject
        self.include_regions = include_regions
        self.enforce_theta = enforce_theta
        self.enforce_phase = enforce_phase
        self.theta_threshtype = theta_threshtype
        self.theta_threshlevel = theta_threshlevel
        self.exclude_theta = exclude_theta
        self.theta_bandtype = theta_bandtype

        if self.enforce_theta and self.exclude_theta:
            raise ValueError('Theta power should not be enforced and simultaneous used to exclude channels.')

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
        self._drop_columns()

    def _set_subject(self):
        """ Remove subjects, if necessary. """

        if self.subject != 'all':
            for dataset in DATASETS:
                datacurr = getattr(self, dataset)
                setattr(self, dataset, datacurr[datacurr['subject'] == self.subject])

    def _set_region(self):
        """ Keep only some regions, if necessary. """

        if self.include_regions:
            for idata, dataset in enumerate(DATASETS):
                for region in REGIONS[idata]:
                    datacurr = getattr(self, dataset)
                    rows_keep = np.array([True if region_ in self.include_regions else False for region_ in datacurr[region]])
                    setattr(self, dataset, datacurr.iloc[rows_keep, :])

    def _set_theta(self):
        """ Determine theta channels and remove non-theta channels, if necessary. """

        # Mark channels that have theta.
        if self.theta_threshtype == 'pval':
            thetachan = self.sc[self.sc['pvalposttheta'] < self.theta_threshlevel]['channel']
        elif self.theta_threshtype == 'percent':
            thetachan = []
            for chan in self.sc['channel']:
                ntheta_trial = np.sum(self.stsc[self.stsc['channel'] == chan]['posttheta'] > 0)
                thetachan.append((ntheta_trial / len(self.stsc['trial'].unique())) > self.theta_threshlevel)
            thetachan = self.sc[thetachan]['channel']
        elif self.theta_threshtype == 'bump':
            thetachan = self.sc[self.sc['thetabump'] == 1]['channel']
        else:
            raise ValueError('Threshold type not recognized for detecting theta channels.')

        for idata, dataset in enumerate(DATASETS):
            for theta, channel in zip(THETAS[idata], CHANNELS[idata]):
                getattr(self, dataset)[theta] = [1 if chan in list(thetachan) else 0 for chan in getattr(self, dataset)[channel]]

        # Exclude channels with or without prominent theta, if necessary.
        if self.enforce_theta or self.exclude_theta:
            if self.exclude_theta:
                targets = [0, 0]
            elif self.enforce_theta:
                targets = [1, 2]

            # Single channels.
            for single in SINGLECHAN:
                datacurr = getattr(self, single)
                setattr(self, single, datacurr[datacurr['thetachan'] == targets[0]])

            # Channel pairs.
            for multi in MULTICHAN:
                datacurr = getattr(self, multi)
                setattr(self, multi, datacurr[datacurr['thetachanA'] + datacurr['thetachanB'] == targets[1]])

    def _set_phasepair(self):
        """ Mark phase-encoding pairs and remove non-encoding pairs, if necessary. """

        # Use encoding episodes from individualized or canonical theta bands.
        episodes_to_use = 'encodingepisodes_' + self.theta_bandtype

        # Mark channel pairs showing significant phase encoding.
        phasepair = self.mc[self.mc[episodes_to_use] > 0]['pair']
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
        ab = self.stmc['normtspacAB_' + self.theta_bandtype] > self.stmc['normtspacBA_'  + self.theta_bandtype]

        # Set PAC as that in the maximal direction.
        # NOTE: Because PAC direction is set for individual trials, a pair could be TF in one trial and FT in another.
        self.stmc['normtspacmax'] = np.maximum(self.stmc['normtspacAB_' + self.theta_bandtype], self.stmc['normtspacBA_'  + self.theta_bandtype])

        # Construct lobe pair label using individual channel regions. This label corresponds to the AB direction.
        lobepair = ['{}{}'.format(lobeA, lobeB) for lobeA, lobeB in zip(self.stmc['lobeA'], self.stmc['lobeB'])]

        # Make a direction label using the region pair label. Flip the region pair label if PAC was stronger in the BA direction.
        self.stmc['direction'] = [pair if ab_ else pair[::-1] for pair, ab_ in zip(lobepair, ab)]

    def _drop_columns(self):
        """ Drop columns based on whether indivualized or canonical theta bands were specified. """

        if self.theta_bandtype == 'canon':
            band_exclude = 'cf'
        else:
            band_exclude = 'canon'
        
        # In each dataset, drop columns with 'cf' or 'canon' in the column name.
        for dataset in DATASETS:
            datacurr = getattr(self, dataset)
            col_exclude = [True if band_exclude in col_name else False for col_name in datacurr.columns]
            setattr(self, dataset, datacurr.iloc[:, np.logical_not(col_exclude)])



