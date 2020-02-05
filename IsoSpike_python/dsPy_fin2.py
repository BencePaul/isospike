#!/usr/bin/python2.4
### This version takes FIN2 files (any number) as arguments and outputs CSV files with the same names containing the all of the DS corrected data
# -*- coding: utf-8 -*-
from scipy.optimize import fsolve
import numpy as np
import pandas as pd
import sys
import os


def getSettings(settings_name): ## import DS settings from my old files
	DSsettings = np.loadtxt(settings_name, usecols=(1,3,4), skiprows=1)
	n = DSsettings[:,0]
	T = DSsettings[:,1]
	P = DSsettings[:,2]
	return n, T, P
	

def DSp_eqs(p,*params): ## define the set of double spike equations to solve
	x,y,z=p #//x is lamda, y is alpha and z is beta. Use guess initially
	m=params[0]
	n,T,P=params[1]

	# this is the set of three non-linear simultaneous equations we need to solve (one for each ratio)
	# T is the double spike composition; n is the unspiked or standard composition; P is the log of the mass ratios; m is the measured ratios
	f1 = (x*T[0] + (1-x)*n[0]*np.exp(-1*y*P[0]) - m[0]*np.exp(-1*z*P[0]))
	f2 = (x*T[1] + (1-x)*n[1]*np.exp(-1*y*P[1]) - m[1]*np.exp(-1*z*P[1]))
	f3 = (x*T[2] + (1-x)*n[2]*np.exp(-1*y*P[2]) - m[2]*np.exp(-1*z*P[2]))

	return (f1,f2,f3)

def readFIN2file(name): ### pull in data from a FIN2 file
	filename=name
	
	#Get column names, stored in row 8 of FIN2 file.
	headers=np.loadtxt(filename, skiprows=7, delimiter="," , max_rows=1, dtype=str)
	
	#Get all the following data
	iso_data = np.loadtxt(filename, skiprows=8, delimiter=",")

	# Convert to pandas dataframe
	df=pd.DataFrame(iso_data)
	df.columns=headers

	return (df)

def doPtDS(in_filename):
	print("running Pt DS with " + os.path.basename(in_filename) + " ", end="") ## progress feedback

	#read data file
	iso_data = readFIN2file(in_filename)

	#########################
	##### SETUP STUFF #######
	#########################
	## identify the four channels from fin2 file (three numerators and one denominator) to be used in the DS inversion
	num1="195Pt"
	num2="196Pt"
	num3="198Pt"
	den="194Pt"

	## Set up double-spike parameters, one of two ways —- hard coded here, or referencing DSsettings files (old format use with IsoSpike)
	## comment out one or the other

	# #### can do manual entry of DS settings here (examples from my Pt DS)
	# ## natural or measured unspiked composition (ratio1,ratio2,ratio3)
	# n=(1.0303605,0.7717145,0.2232910)
	# ## spike composition (ratio1,ratio2,ratio3)
	# T=(1.838948,19.31747,38.37810)
	# ## log of mass ratios (e.g., ln(massPt198/massPt194)). Atomic masses can be found in (e.g.) Audi et al. 2003, Nucl. Phys. A, 337–676
	# P=(0.005153188,0.010270037,0.020439027)

	### or point to files using the old IsoSpike DSsettings format
	DSsettings_path = "/Applications/Iolite v2.5/Add ons/IsoSpike/DS_settings/"
	settingsFileName = "DS_Settings_PtNewDS_Pb_20161104.txt"
	sname=DSsettings_path+settingsFileName
	n,T,P = getSettings(sname) # grab settings from file.

	#########
	### end of setup section
	#########

	ratio1=num1+"_"+den ### sets up ratio names
	ratio2=num2+"_"+den
	ratio3=num3+"_"+den

	iso_data['raw'+ratio1] = iso_data[num1]/iso_data[den] # # calculate raw ratios
	iso_data['raw'+ratio2] = iso_data[num2]/iso_data[den]
	iso_data['raw'+ratio3] = iso_data[num3]/iso_data[den]

	print(".", end="") ## progress feedback

	
	## setup array to temporarily store results
	numrows = iso_data.shape[0]	# store the number of rows in the input data for use elsewhere.
	result_array = np.empty((numrows,9)) # create empty array to hold results
	p=np.array([0.068,-0.03,1.2]) #first guesses of lambda, alpha, beta; required by fsolve, but shouldn't matter much

	print(".", end="") ## progress feedback
	
	#### DO DS STUFF
	for i in range(numrows):
		j = iso_data.loc[i,['raw'+ratio1,'raw'+ratio2,'raw'+ratio3]]
		params=(j,(n,T,P))
		x,y,z = fsolve(DSp_eqs,p,args=params)
			
		dscorr_ratio1 = (n[0]*np.exp(-1*y*P[0]))
		dscorr_ratio2 = (n[1]*np.exp(-1*y*P[1]))
		dscorr_ratio3 = (n[2]*np.exp(-1*y*P[2]))

		deltaratio1 = ((dscorr_ratio1/n[0])-1)*1000
		deltaratio2 = ((dscorr_ratio2/n[1])-1)*1000
		deltaratio3 = ((dscorr_ratio3/n[2])-1)*1000
		
		result = [x,y,z,dscorr_ratio1,dscorr_ratio2,dscorr_ratio3,deltaratio1,deltaratio2,deltaratio3] # x is lambda, y is alpha, and z is beta
		result_array[i] = result

	print(".", end="") ## progress feedback

	#copy results to pandas dataframe
	iso_data['lambda'] = result_array[:,0]
	iso_data['alpha'] = result_array[:,1]
	iso_data['beta'] = result_array[:,2]
	iso_data['dscorr'+ratio1] = result_array[:,3]
	iso_data['dscorr'+ratio2] = result_array[:,4]
	iso_data['dscorr'+ratio3] = result_array[:,5]
	iso_data['delta'+ratio1] = result_array[:,6]
	iso_data['delta'+ratio2] = result_array[:,7]
	iso_data['delta'+ratio3] = result_array[:,8]

	out_filename = in_filename[:-8]+"_DS.csv" ### saving data to csv file with same name and with the junk trimmed off the end
	iso_data.to_csv(out_filename)

	print(". done.") ## progress feedback


if(len(sys.argv)<2):
	print("missing argument(s).. point at FIN2 file(s)..")
	sys.exit (1)
else:
	files=sys.argv[1:]
	count=len(files)
	for file in files:
		doPtDS(file)
