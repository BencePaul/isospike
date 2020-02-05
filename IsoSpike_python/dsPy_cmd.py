#!/usr/bin/python2.4
### This version takes three raw ratios as command line inputs, and outputs a table of results, including alpha, beta, lambda, DS corrected ratios, and delta values

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

def doPtDS(inputs):
	raw_ratios=np.asarray(inputs,dtype=float)
	
	#########################
	##### SETUP STUFF #######
	#########################
	## identify the channel names
	num1="195Pt"
	num2="196Pt"
	num3="198Pt"
	den="194Pt"

	#### can do manual entry of DS settings here (examples from my Pt DS)
	## natural or measured unspiked composition (ratio1,ratio2,ratio3)
	n=(1.0303605,0.7717145,0.2232910)
	## spike composition (ratio1,ratio2,ratio3)
	T=(1.838948,19.31747,38.37810)
	## log of mass ratios (e.g., ln(massPt198/massPt194)). Atomic masses can be found in (e.g.) Audi et al. 2003, Nucl. Phys. A, 337–676
	P=(0.005153188,0.010270037,0.020439027)

	### or point to files using the old IsoSpike DSsettings format
	DSsettings_path = "/Applications/Iolite v2.5/Add ons/IsoSpike/DS_settings/"
	settingsFileName = "DS_Settings_PtNewDS_Pb_20161104.txt"

	# # sname = chooseSettings(DSsettings_path,defaultname)
	# sname=DSsettings_path+settingsFileName
	# n,T,P = getSettings(sname) # grab settings from file.

	#########
	#########

	ratio1=num1+"_"+den ### set up ratio names
	ratio2=num2+"_"+den
	ratio3=num3+"_"+den

	#### DO DS STUFF
	params=(raw_ratios,(n,T,P))
	p=np.array([0.068,-0.03,1.2]) #set initial guess of lambda, alpha, beta; required by fsolve, but shouldn't matter much
	x,y,z = fsolve(DSp_eqs,p,args=params)
			
	dscorr_ratio1 = (n[0]*np.exp(-1*y*P[0]))
	dscorr_ratio2 = (n[1]*np.exp(-1*y*P[1]))
	dscorr_ratio3 = (n[2]*np.exp(-1*y*P[2]))

	deltaratio1 = ((dscorr_ratio1/n[0])-1)*1000
	deltaratio2 = ((dscorr_ratio2/n[1])-1)*1000
	deltaratio3 = ((dscorr_ratio3/n[2])-1)*1000
		
	result = [x,y,z,dscorr_ratio1,dscorr_ratio2,dscorr_ratio3,deltaratio1,deltaratio2,deltaratio3] # x is lambda, y is alpha, and z is beta
	iso_data=pd.DataFrame([result])
	headers=['lambda','alpha','beta','dscorr'+ratio1,'dscorr'+ratio2,'dscorr'+ratio3,'delta'+ratio1,'delta'+ratio2,'delta'+ratio3]
	iso_data.columns=headers

	print(iso_data)

if(len(sys.argv)<3):
	print("missing argument(s).. need 3 input ratios..")
	sys.exit (1)
else:
	inputs=sys.argv[1:]
	doPtDS(inputs)
