""" Class for applying classification techniques to Kahana data """

from kah_data import KahData
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import GridSearchCV
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import cross_val_score
from sklearn.model_selection import StratifiedKFold

class KahClassifier:
    """ Predict trial outcome (remembered vs. forgotten) using electrophysiological features before and during stimulus presentation 
    
    Parameters
    ----------
    predictors : string or list of strings, optional
        Electrophysiological features to use for classification. default: 'all'
        Possible features include ['preslope', 'postslope', 'pretheta', 'posttheta', 'prehfa', 'posthfa', 'normtspac', normtspacmax']

    Attributes
    ----------
    predvals : Pandas Dataframe
        Features aggregated per trial and brain region. Used ultimately for classification.
    labels : 1D array
        Labels of remembered (1) vs. forgotten (0) for each trial. Used ultimately for classification.

    """

    def __init__(self, predictors='all', scoring='roc_auc', cv=5, test_size=0.3, seed=42):
        """ Initialize KahClassifier object. """
        
        # Set input parameters. 
        self.predictors = predictors
        self.scoring = scoring
        self.cv = cv
        self.test_size = test_size
        self.seed = seed
    
    def classify(self, kahdata, method, hyperparameters=None):
        """ Predict trial outcome using classifier type of interest. """

        # Get predictor values and trial labels.
        self._set_predictors_labels(kahdata)

        # Split data into a training and test set.
        # The training set will be used for k-fold cross validation to pick optimal hyperparameters.
        # The test set will be used to evaluate performance of a full model fit over the training set using the best hyperparameter.
        self.Xtrain, self.Xtest, self.ytrain, self.ytest = train_test_split(self.predvals, self.labels, test_size=self.test_size, shuffle=True, stratify=self.labels, random_state=self.seed)

        # For logistic regression.
        if method == 'logistic':
            self._logistic_regression(hyperparameters)

    def _logistic_regression(self, hyperparameters):
        """ Classify using logistic regression. """

        # Defaults for C values to test.
        if not hyperparameters:
            hyperparameters = {'C':[0.01, 0.1, 1, 10]}
        
        # Select best C value if multiple are provided.
        if len(hyperparameters['C']) > 1:
            # Create GridSearchCV object that will loop over C values.
            clf = GridSearchCV(LogisticRegression(class_weight='balanced', random_state=self.seed), hyperparameters, scoring=self.scoring, cv=self.cv)
    
        # Otherwise, use the single value provided.
        else:
            clf = LogisticRegression(class_weight='balanced', random_state=self.seed, C=hyperparameters['C'][0])

        # Fit a model on all of the training data. In the case of multiple C, perform k-fold cross-validation on the training set.
        clf.fit(self.Xtrain, self.ytrain)

        if len(hyperparameters['C']) > 1:
            self.cv_results_ = clf.cv_results_
        
        # Get probability of class labels (forgotten in column 0, forgotten in column 1) for the test set.
        self.proba_ = clf.predict_proba(self.Xtest)

        # Calculate AUC of ROC curve for the test set.
        self.roc_auc_ = roc_auc_score(self.ytest, self.proba_[:, 1], average='weighted')

        # Fit a model on all data, both training and test.
        clf.fit(self.predvals, self.labels)

        # TODO: save model coefficients to self

    def _set_predictors_labels(self, kahdata):
        """ Extract predictors of interest from KahData() object, aggregating across channels and channel pairs. 
        
        Notes
        -----
        For each trial, there will be one value for each feature for each region.
        In the case of multichannel data, there will be one value for each feature for each region combination.

        """

        # Aggregate all measures per trial per region.
        stsc_ave = kahdata.stsc.pivot_table(index=['trial', 'region'], aggfunc = np.median)
        stmc_ave = kahdata.stmc.pivot_table(index=['trial', 'direction'], aggfunc = np.median)

        if self.predictors == 'all':
            self.predictors = set(list(stsc_ave.columns) + list(stmc_ave.columns))
        
        scfeatures = [predictor for predictor in self.predictors if predictor in list(stsc_ave.columns)]
        mcfeatures = [predictor for predictor in self.predictors if predictor in list(stmc_ave.columns)]
        mcfeatures = [predictor for predictor in mcfeatures if predictor not in scfeatures]

        self.predvals = pd.concat([stsc_ave[scfeatures].unstack(), stmc_ave[mcfeatures].unstack()], axis=1)

        self.labels = np.array(stsc_ave['encoding'])[::2]

    
