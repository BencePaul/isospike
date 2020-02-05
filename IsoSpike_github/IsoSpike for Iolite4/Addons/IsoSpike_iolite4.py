# A python-based implementation of IsoSpike
#/ Name: IsoSpike
#/ Authors: John Creech
#/ Description: Double-spike data reduction tool for Iolite
#/ References: Creech and Paul 2013
#/ Version: 0.01
#/ Contact: john@isospike.org

from scipy.optimize import fsolve
import numpy as np
import pandas as pd


## first, define the set of double spike equations to solve
def DSp_eqs(p,*params):
	x,y,z=p #//x is lamda, y is alpha and z is beta. Use guess initially
	m=params[0]
	n,T,P=params[1]

	# this is the set of three non-linear simultaneous equations we need to solve (one for each ratio)
	# T is the double spike composition; n is the unspiked or standard composition; P is the log of the mass ratios; m is the measured ratios
	f1 = (x*T[0] + (1-x)*n[0]*np.exp(-1*y*P[0]) - m[0]*np.exp(-1*z*P[0]))
	f2 = (x*T[1] + (1-x)*n[1]*np.exp(-1*y*P[1]) - m[1]*np.exp(-1*z*P[1]))
	f3 = (x*T[2] + (1-x)*n[2]*np.exp(-1*y*P[2]) - m[2]*np.exp(-1*z*P[2]))

	return (f1,f2,f3)

## then, define the IsoSpike function to take all the data inputs and do the calculations
def IsoSpike(DSsettings,ratio1,ratio2,ratio3):	## takes the DS parameters and the three mixed ratios as inputs
	print("{}: starting DS deconvolution in IsoSpike\n".format(pd.Timestamp.now('Australia/Sydney')))
	#set up to catch an error is DS params aren't right?
	
	# prepare array to hold results
	result_array = np.empty((ratio1.size,9)) # create empty array to hold results
	result_array[:][:]=None #set all points to NaN

	# set initial conditions
	p=np.array([0.068,-0.03,1.2]) #first guesses of lambda, alpha, beta; required by fsolve, but shouldn't matter much

	result_array = np.empty((ratio1.size,9)) # create empty array to hold results; 9 columns for the 9 results we return
	result_array[:][:]=None    
	
	#unpacking DSsettings to n,T,P for the sake of tidyness with the additional results calcs
	n=DSsettings[0]
	T=DSsettings[1] #not used, but leaving here for clarity
	P=DSsettings[2]

	for a in range(len(ratio1)): # run through every measured ratio
		m=np.array([ratio1[a],ratio2[a],ratio3[a]]) #set up array of mixture measurements for this iteration to send to fsolve
		
		# set up parameters for fsolve
		params=(m,DSsettings) # m is mixed ratios, DSsettings contains the DS parameters; send as tuple of arguments for fsolve
		x,y,z = fsolve(DSp_eqs,p,args=params)	#inputs are function to solve, inital estimate, and tuple of additional arguments; outputs are x,y,z which are lambda, alpha and beta

		#calculate some other results
		trueratio1 = (n[0]*np.exp(-1*y*P[0]))	#This is the equation N=n*exp(-1*alpha*P)
		trueratio2 = (n[1]*np.exp(-1*y*P[1]))
		trueratio3 = (n[2]*np.exp(-1*y*P[2]))
		deltaratio1 = ((trueratio1/n[0])-1)*1000	#This is the delta equation, delta = (R_sample/R_std - 1) * 1000
		deltaratio2 = ((trueratio2/n[1])-1)*1000
		deltaratio3 = ((trueratio3/n[2])-1)*1000

		#put the results into an array
		result = [x,y,z,trueratio1,trueratio2,trueratio3,deltaratio1,deltaratio2,deltaratio3]
		#store them in the overall results array
		result_array[a]=result

	print("{}: IsoSpike finished; returning to DRS\n".format(pd.Timestamp.now('Australia/Sydney')))
	return(result_array)