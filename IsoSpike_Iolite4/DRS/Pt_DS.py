#/ Type: DRS
#/ Name: Pt_DS
#/ Authors: John Creech
#/ Description: Python based Pt_DS DRS for Iolite 4
#/ References: None
#/ Version: 1.00
#/ Contact: john@isospike.org


from iolite import QtGui
import numpy as np
import pandas as pd
from IsoSpike_iolite4 import IsoSpike

def runDRS():
	drs.message("Starting Pt DRS...")
	drs.progress(0)

	# Get DRS settings
	settings = drs.settings()
	indexChannel = data.timeSeries(settings["IndexChannel"])
	rmName = settings["ReferenceMaterial"]

	# Get double-spike parameters
	## In this version, we will just include the DS settings in the DRS
	rationames=['Pt195/Pt194','Pt196/Pt194','Pt198/Pt194']
	unmixedRatios=[1.0303605,0.7717145,0.2232910]
	spikeRatios=[1.838948,19.31747,38.37810]
	logMassRatios=[0.005153188,0.010270037,0.020439027]
	DSsettings=np.array([unmixedRatios,spikeRatios,logMassRatios])
	
	# Create debug messages for the settings being used
	IoLog.debug("indexChannelName = %s" % indexChannel.name)

	# Setup index time
	drs.message("Setting up index time...")
	drs.progress(5)
	# drs.setIndexChannel(indexChannel)

	# Interp onto index time and baseline subtract
	drs.message("Interpolating onto index time and baseline subtracting...")
	drs.progress(25)

	# Reference the channels in the data
	Pt190 = data.timeSeries("Pt190").data()
	Pt192 = data.timeSeries("Pt192").data()
	Pt194 = data.timeSeries("Pt194").data()
	Pt195 = data.timeSeries("Pt195").data()
	Pt196 = data.timeSeries("Pt196").data()
	Pt198 = data.timeSeries("Pt198").data()
	Hg200 = data.timeSeries("Hg200").data()

	# Do baseline subtraction
	allInputChannels = data.timeSeriesList(data.Input)
	for counter, channel in enumerate(allInputChannels):
	 	drs.message("Baseline subtracting %s" % channel.name)
	 	drs.progress(25 + 10*counter/len(allInputChannels))
	 	
	 	drs.baselineSubtract(data.selectionGroup("OPZ"), [allInputChannels[counter]], None, 25, 50)

	drs.message("Calculating raw ratios")
	drs.progress(50)

	# Reference baseline subtracted data
	### For now, the baseline subtracted channels are labelled _CPS; should change in future releases of Iolite
	Pt190_BLSub = data.timeSeries("Pt190_CPS").data()
	Pt192_BLSub = data.timeSeries("Pt192_CPS").data()
	Pt194_BLSub = data.timeSeries("Pt194_CPS").data()
	Pt195_BLSub = data.timeSeries("Pt195_CPS").data()
	Pt196_BLSub = data.timeSeries("Pt196_CPS").data()
	Pt198_BLSub = data.timeSeries("Pt198_CPS").data()
	Hg200_BLSub = data.timeSeries("Hg200_CPS").data()

	#Calculate raw ratios    
	Raw190_194=Pt190_BLSub/Pt194_BLSub	
	Raw192_194=Pt192_BLSub/Pt194_BLSub
	Raw195_194=Pt195_BLSub/Pt194_BLSub
	Raw196_194=Pt196_BLSub/Pt194_BLSub				
	Raw198_194=Pt198_BLSub/Pt194_BLSub				
	
	# Add raw ratios to intermediate channels 
	data.createTimeSeries("Raw190_194",data.Intermediate, indexChannel.time(),Raw190_194)
	data.createTimeSeries("Raw192_194",data.Intermediate, indexChannel.time(),Raw192_194)	
	data.createTimeSeries("Raw195_194",data.Intermediate, indexChannel.time(),Raw195_194)	
	data.createTimeSeries("Raw196_194",data.Intermediate, indexChannel.time(),Raw196_194)	
	data.createTimeSeries("Raw198_194",data.Intermediate, indexChannel.time(),Raw198_194)

	# Calculate total Pt volts
	TotalPt_Volts = Pt190_BLSub + Pt192_BLSub + Pt194_BLSub + Pt195_BLSub + Pt196_BLSub + Pt198_BLSub	
	data.createTimeSeries("TotalPt_Volts",data.Output, indexChannel.time(),TotalPt_Volts)	
	
	####################################################################################################
	### Everything in the DRS that needs to be customised is above this line; below is all abstracted.
	####################################################################################################
		
	drs.message("Calling IsoSpike")
	drs.progress(70)
	#######
	#### Here is where we call IsoSpike, passing on the DS settings and the measured raw ratios.
	#######
	result_array=IsoSpike(DSsettings,Raw195_194,Raw196_194,Raw198_194)


	drs.message("Calculating internally normalised values")
	drs.progress(85)
	#### Below is some post-processing stuff. 
	### We need to reference the results of the DS calculations so we can see it in Iolite.

	ones=np.ones((len(indexChannel.time()))) ## initialise an array of ones; some data didn't work if I just copy into arrays, but fine when multiplying by array of ones

	#unpack results
	x=ones*result_array[:,0]
	y=ones*result_array[:,1]
	z=ones*result_array[:,2]
	DScorr_ratio1=ones*result_array[:,3]
	DScorr_ratio2=ones*result_array[:,4]
	DScorr_ratio3=ones*result_array[:,5]
	deltaratio1=ones*result_array[:,6]
	deltaratio2=ones*result_array[:,7]
	deltaratio3=ones*result_array[:,8]

	#create time series in Iolite
	data.createTimeSeries("lambda",data.Output, indexChannel.time(),x)
	data.createTimeSeries("alpha",data.Output, indexChannel.time(),y)
	data.createTimeSeries("beta",data.Output, indexChannel.time(),z)	
	data.createTimeSeries("DScorr"+rationames[0],data.Output, indexChannel.time(),DScorr_ratio1)
	data.createTimeSeries("DScorr"+rationames[1],data.Output, indexChannel.time(),DScorr_ratio2)
	data.createTimeSeries("DScorr"+rationames[2],data.Output, indexChannel.time(),DScorr_ratio3)	
	data.createTimeSeries("Delta"+rationames[0],data.Output, indexChannel.time(),deltaratio1)
	data.createTimeSeries("Delta"+rationames[1],data.Output, indexChannel.time(),deltaratio2)
	data.createTimeSeries("Delta"+rationames[2],data.Output, indexChannel.time(),deltaratio3)
	
	#create splines on the DS corrected ratios for the standard
	StdSpline1 = data.spline(rmName, 'DScorr'+rationames[0]).data()
	StdSpline2 = data.spline(rmName, 'DScorr'+rationames[1]).data()
	StdSpline3 = data.spline(rmName, 'DScorr'+rationames[2]).data()
	
	#calculate internally normalised delta values
	DeltaInt_ratio1 = ((DScorr_ratio1/StdSpline1)-1)*1000
	DeltaInt_ratio2 = ((DScorr_ratio2/StdSpline2)-1)*1000
	DeltaInt_ratio3 = ((DScorr_ratio3/StdSpline3)-1)*1000
	data.createTimeSeries("DeltaInt"+rationames[0],data.Output, indexChannel.time(),DeltaInt_ratio1)
	data.createTimeSeries("DeltaInt"+rationames[1],data.Output, indexChannel.time(),DeltaInt_ratio2)
	data.createTimeSeries("DeltaInt"+rationames[2],data.Output, indexChannel.time(),DeltaInt_ratio3)
	
	#finishing touches
	drs.message("Finished!")
	drs.progress(100)
	drs.finished()
	

def settingsWidget():
	widget = QtGui.QWidget()
	formLayout = QtGui.QFormLayout()
	widget.setLayout(formLayout)

	settings = drs.settings()

	defaultChannelName = "Pt194"
	drs.setSetting("IndexChannel", defaultChannelName)

	indexComboBox = QtGui.QComboBox(widget)
	indexComboBox.addItems(data.timeSeriesNames(data.Input))
	indexComboBox.setCurrentText(settings["IndexChannel"])
	indexComboBox.currentTextChanged.connect(lambda t: drs.setSetting("IndexChannel", t))
	formLayout.addRow("Index channel", indexComboBox)

	drs.setSetting("ReferenceMaterial", "IRMM010")
	rmNames = data.selectionGroupNames(data.ReferenceMaterial)
	rmComboBox = QtGui.QComboBox(widget)
	rmComboBox.addItems(rmNames)
	rmComboBox.setCurrentText(settings["ReferenceMaterial"])
	rmComboBox.currentTextChanged.connect(lambda t: drs.setSetting("ReferenceMaterial", t))
	formLayout.addRow("Reference material", rmComboBox)    

	drs.setSettingsWidget(widget)
