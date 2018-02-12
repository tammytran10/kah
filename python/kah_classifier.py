""" Class for applying classification techniques to Kahana data """

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import GridSearchCV
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score
from sklearn.preprocessing import StandardScaler

class KahClassifier:
    """ Predict trial outcome (remembered vs. forgotten) using electrophysiological features before and during stimulus presentation 
    
    Parameters
    ----------
    predictors : list of tuples, optional
        Electrophysiological features to use for classification. Each tuple should be ('measure', 'region'). default: 'all'
    scoring : string, optional
        The score to use for evaluating classifier performance. default: 'roc_auc'
    cv : int, optional
        The number of folds to use for cross-validation when testing multiple hyperparameters. default: 5
    test_size : float, optional
        The proportion of data to be held out to test final model performance. default: 0.3
    seed : int, optional
        Random state seed. default: 42

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
        """ Predict trial outcome using classifier type of interest. 
        
        Parameters
        ----------
        kahdata : KahData() object
            Data from subject(s) to classify
        method : string
            The type of classifier to use. Choices include 'logistic', 'SVM'
        hyperparameters : dict, optional
            Hyperparameters to try ({'C':[0.1, 1, 10, 100], 'kernel':['linear', 'rbf]}). 
            Defaults determined by individual classifier functions.

        """

        # Save hyperparameter values.
        self.hyperparameters = hyperparameters

        # Get predictor values and trial labels.
        self._set_predictors_labels(kahdata)

        # Split data into a training and test set.
        # The training set will be used for k-fold cross validation to pick optimal hyperparameters.
        # The test set will be used to evaluate performance of a full model fit over the training set using the best hyperparameter.
        self.Xtrain, self.Xtest, self.ytrain, self.ytest = train_test_split(self.predvals, self.labels, test_size=self.test_size, shuffle=True, stratify=self.labels, random_state=self.seed)

        # Scale features using the mean and variance of the training data.
        self._standardscale_features()

        # Create classifier object.
        if method == 'logistic': # for logistic regression.
            clf = self._logistic_regression()

        # Fit a model on all of the training data. In the case of multiple C, perform k-fold cross-validation on the training set.
        clf.fit(self.Xtrain, self.ytrain)

        # Save GridSearch results, if necessary.
        if self.grid:
            self.grid_results_ = clf.cv_results_
        
        # Get probability of class labels (forgotten in column 0, forgotten in column 1) for the test set.
        self.proba_ = clf.predict_proba(self.Xtest)

        # Calculate AUC of ROC curve for the test set.
        self.roc_auc_ = roc_auc_score(self.ytest, self.proba_[:, 1], average='weighted')

        # Fit a model on all data, both training and test, re-scaled using training data.
        clf.fit(self.scaler.transform(self.predvals), self.labels)

        # Save model coefficients.
        self.coef_ = clf.coef_
        self.intercept_ = clf.intercept_

    def _standardscale_features(self):
        """ Scale features to have zero mean and unit variance. """

        # Make scaler that stores mean and variance of the training data.
        self.scaler = StandardScaler().fit(self.Xtrain)

        # Scale training and test data using mean and variance of the training data.
        self.Xtrain = self.scaler.transform(self.Xtrain)
        self.Xtest = self.scaler.transform(self.Xtest)

    def _logistic_regression(self):
        """ Classify using logistic regression. """

        # Defaults for C values to test.
        if not self.hyperparameters:
            self.hyperparameters = {'C':[0.01, 0.1, 1, 10]}
        
        # Select best C value if multiple are provided.
        if len(self.hyperparameters['C']) > 1:
            # Create GridSearchCV object that will loop over C values.
            self.grid = True
            clf = GridSearchCV(LogisticRegression(class_weight='balanced', random_state=self.seed), self.hyperparameters, scoring=self.scoring, cv=self.cv)
    
        # Otherwise, use the single value provided.
        else:
            self.grid = False
            clf = LogisticRegression(class_weight='balanced', random_state=self.seed, C=self.hyperparameters['C'][0])
        
        return clf

    def _set_predictors_labels(self, kahdata):
        """ Extract predictors of interest from KahData() object, aggregating across channels and channel pairs. 
        
        Notes
        -----
        For each trial, there will be one value for each feature for each region.
        In the case of multichannel data, there will be one value for each feature for each region combination.

        """

        # Aggregate all measures per trial per region.
        stsc_ave = kahdata.stsc.pivot_table(index=['trial', 'region'], aggfunc = np.median).unstack()
        stmc_ave = kahdata.stmc.pivot_table(index=['trial', 'direction'], aggfunc = np.median).unstack()

        # If all predictors are being used, get tuples of all the column names.
        if self.predictors == 'all':
            self.predictors = set(list(stsc_ave.columns) + list(stmc_ave.columns))

        # Initialize data frame.
        self.predvals = pd.DataFrame()

        # Concatenate each desired predictor column to the predvals data frame.
        for pred in self.predictors:

            # Extract region and measure name.
            measure, region = pred

            if len(region) > 1: # between-channel measures
                self.predvals = pd.concat([self.predvals, stmc_ave[measure, region]], axis=1)
            else: # within-channel measures
                self.predvals = pd.concat([self.predvals, stsc_ave[measure, region]], axis=1)

        # Get labels for each trial (0 for forgotten, 1 for remembered).
        self.labels = np.array(stsc_ave['encoding', 'F'])