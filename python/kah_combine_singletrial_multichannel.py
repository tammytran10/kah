""" Script for combining Kahana singletrial_multichannel CSVs across subjects. """

import glob, os
import pandas as pd 

if __name__ == "__main__":
    # Concatenate DFs across subjects.
    df = pd.concat(map(pd.read_csv, glob.glob(os.path.join('', '/Users/Rogue/Documents/Research/Projects/KAH/csv/*singletrial_multichannel*'))))

    # Save full CSV.
    df.to_csv('/Users/Rogue/Documents/Research/Projects/KAH/csv/kah_singletrial_multichannel.csv', sep=',')
