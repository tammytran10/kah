""" Tests for the KahData class. """

from kah_data import KahData, DATASETS, CHANNELS
import os
import numpy as np 

# Global variables for loading and indexing subject.
TESTSUBJ = 'R1033D'
TESTREG  = 'N'

# Subject data for all testing.
DATA = KahData(subject=TESTSUBJ, exclude_region=TESTREG, enforce_theta=True, enforce_phase=True)

def test_csvdir():
    """ Test that the path to the CSV directory is available. """
    
    assert os.path.isdir(KahData.csvpath)

def test_csvfiles():
    """ Test that each CSV is available. """
    
    for path in KahData.paths:
        assert os.path.isfile(KahData.paths[path])

def test_kah_DATA():
    """ Test that each CSV is loaded and that there is data in each. """
    
    for path in KahData.paths:
        assert eval('KahData.' + path + '.shape[0]')

def test_kah_DATA_object():
    """ Test that the KahData() object is being returned and that subjects are excluded in all data. """
    
    # Test that the object is returned.
    assert DATA

    # Test that only one subject remains.
    for dataset in DATASETS:
        assert np.all(getattr(DATA, dataset)['subject'] == TESTSUBJ)

def test_exclude_region():
    """ Test that regions are appropriately excluded in all data sets. """
    
    for idata, dataset in enumerate(DATASETS):
        for channel in CHANNELS[idata]:
            assert TESTREG not in getattr(DATA, dataset)[channel].unique()

def test_enforce_theta():
    """ Test that channels remaining all have theta. """
    
    # Check that all channels in the sc DATA set have theta.
    assert np.all(DATA.sc['pvalposttheta'] < 0.05)

    # Check that channels in all other DATA sets are in the sc DATA set.
    for idata, dataset in enumerate(DATASETS):
        for channel in CHANNELS[idata]:
            assert np.all([1 if chan in list(DATA.sc['channel']) else 0 for chan in getattr(DATA, dataset)[channel]])

def test_enforce_phase():
    """ Test that remaining channel pairs are phase-encoding pairs. """

    # Check that all remaining pairs in the mc DATA set are phase encoding.
    assert np.all(DATA.mc['encodingepisodes'] > 0)

    # Check that all remaining pairs in the stmc DATA set are in the mc DATA set.
    phasepair = DATA.mc[DATA.mc['encodingepisodes'] > 0]['pair']
    assert np.all([1 if pair in list(phasepair) else 0 for pair in DATA.stmc['pair']])

def test_set_betweenpac():
    """ Test that direction labels are correct for between-channel PAC. """

    for _, trial in DATA.stmc.iterrows():
        if trial['normtspacmax'] == trial['normtspacAB']: # PAC was stronger in the AB direction
            assert trial['direction'][0] == trial['regionA'] and trial['direction'][-1] == trial['regionB']
        else: # PAC was stronger in the BA direction
            assert trial['direction'][0] == trial['regionB'] and trial['direction'][-1] == trial['regionA']
