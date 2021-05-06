#pragma rtGlobals=1		// Use modern global access method. - Leave this line as is, as 1st line!
#pragma ModuleName= Iolite_ActiveDRS  	//Leave this line as is, as 2nd line!
StrConstant DRS_Version_No= "1.0"  	//Leave this line as is, as 3rd line!
//****End of Header Lines - do not disturb anything above this line!****

//****The global strings (SVar) and variables (NVar) below must always be present. Do not alter their names, alter only text to the right of the "=" on each line.**** (It is important that this line is left unaltered)
	GlobalString				IndexChannel 						="m193p74_Ax"
	GlobalString				ReferenceStandard 					="IRMM010"
	GlobalString				DefaultIntensityUnits				="V"
	//**** Any global strings or variables you wish to use in addition to those above can be placed here. You may name these how you wish, and have as many or as few as you like**** (It is important that this line is left unaltered)
	GlobalVariable			MaskThreshold 						=0.1
	GlobalVariable			MaskEdgeDiscardSeconds 			=1
	//**** Any global strings or variables you wish to use in addition to those above can be placed here. You may name these how you wish, and have as many or as few as you like**** (It is important that this line is left unaltered)
	GlobalVariable			True195_194		 				=1.027997565  //my value
	GlobalString			PropagateSplineErrors				="Yes"
	GlobalString			DSsettingsFilename					="DS_Settings_29Oct2012_VUW-IRMM_196198DS.txt"  //DS_settings files must be in DS_settings folder within Iolite. If no file is specified, igor will ask user to find one. 
//	GlobalVariable			CalibratingFlag						=0 //change to 1 to see the contents of the DSsettings file each time
	GlobalString			Report_DefaultChannel				="Delta198_194"
	GlobalVariable			DS_noninteractiveflag							= 0 //0 = ask each crunch what to do about DS_settings. 1= Use specified one without asking. Default is 0. 


	//**** End of optional global strings and variables**** (It is important that this line is left unaltered)
	//certain optional globals are built in, and have pre-determined lists. these are currently: "StandardisationMethod", "OutputUnits"
	//Note that the above values will be the initial values every time the DRS is opened for the first time, but can then be overwritten for that experiment after that point via the button "Edit DRS Variables". This means that the settings for the above will effectively be stored within the experiment, and not this DRS (this is a good thing)
	//DO NOT EDIT THE ABOVE IF YOU WISH TO EDIT THESE VALUES WITHIN A PARTICULAR EXPERIMENT. THESE ARE THE STARTING VALUES ONLY. THEY WILL ONLY BE LOOKED AT ONCE WHEN THE DRS IS OPENED FOR THE FIRST TIME (FOR A GIVEN EXPERIMENT).

	//**** Initialisation routine for this DRS.  Will be called each time this DRS is selected in the "Select DRS" popup menu (i.e. usually only once).
Function InitialiseActiveDRS() //If init func is required, this line must be exactly as written.   If init function is not required it may be deleted completely and a default message will print instead at initialisation.
	SVAR nameofthisDRS=$ioliteDFpath("Output","S_currentDRS") //get name of this DRS (which should have been already stored by now)
	Print "DRS initialised:  Pt double spike analysis module for Nu Plasma and Neptune MC-ICP-MS data, \"" + nameofthisDRS + "\", Version " + DRS_Version_No + "\r"
End //**end of initialisation routine


//****Start of actual Data Reduction Scheme.  This is run every time raw data is added or the user presses the "crunch data" button.  Try to keep it to no more than a few seconds run-time!
Function RunActiveDRS() //The DRS function name must be exactly as written here.  Enter the function body code below.
	//the next 5 lines reference all of the global strings and variables in the header of this file for use in the main code of the DRS that follows.
	string currentdatafolder = GetDataFolder(1)
	setdatafolder $ioliteDFpath("DRSGlobals","")
	SVar IndexChannel, ReferenceStandard, DefaultIntensityUnits
	SVar PropagateSplineErrors
	NVar MaskThreshold, MaskEdgeDiscardSeconds
	//Add any Custom Variables names below
	NVar True195_194
	//Add any Custom Strings names below
	setdatafolder $currentdatafolder
	
	//Check which instrument the data is from - input waves are handled slightly differently due to naming of channels
	if(!WaveExists($IoliteDFPath("metadata","Channel_MetadataWave_3D")))
		Print Time() + ": No input data yet - DRS execution halted."
		Abort
	endif
	wave /T InputMetaData= $IoliteDFPath("metadata","Channel_MetadataWave_3D")	//Reference Iolite metadata
	Variable datatype
	string teststring = InputMetaData[%'Machine Type'][1]
	if(grepstring(teststring,"NuPlasma")==1)
		datatype = 1
		IndexChannel="m193p74_Ax"
	endif	
	if(grepstring(teststring,"TriNep")==1) 
		datatype = 2
		IndexChannel="Pt194"
	endif


//	//Do we have a wave to start with? if not, no point in continuing...
	DRSabortIfNotWave(ioliteDFpath("input", IndexChannel))	//Abort if [index]_Baseline_1 is not in the Splines folder, otherwise proceed with DRS code below..
	
	
	//Next, create a reference to the Global list of Output channel names, which must contain the names of all outputs produced by this routine, and to the inputs 
	SVAR ListOfOutputChannels=$ioliteDFpath("Output","ListOfOutputChannels") //"ListOfOutputChannels" is already in the Output folder, and will be empty ("") prior to this function being called.
	SVAR ListOfIntermediateChannels=$ioliteDFpath("Output","ListOfIntermediateChannels")
	SVAR ListOfInputChannels=$ioliteDFpath("input","GlobalListOfInputChannels") //Get reference to "GlobalListOfInputChannels", in the Input folder, and is a list of the form "ChannelName1;ChannelName2;..."
	//Now create the global time wave for intermediate and output waves, based on the index isotope  time wave  ***This MUST be called "index_time" as some or all export routines require it, and main window will look for it
	wave TotalBeam_Time = $ioliteDFpath("input","TotalBeam_Time")
	wave Index_Time = $MakeIndexTimeWave(OptionalInputTimeWave = TotalBeam_Time)	//create the index time wave using the external function - it tries to use the index channel, and failing that, uses total beam
	variable/G NoOfPoints=numpnts(Index_Time) //Use total beam to get total no of points - it will incorporate all input waves, so is better than the index, which will only incorporate the points where it exists
	wave IndexOut = $InterpInputOntoIndexTime(IndexChannel,name="Pt194_index")	//Make an output wave for Index isotope (as baseline-subtracted intensity)
	//Now check if there are any baselines. No point in continuing if there isn't
	DRSabortIfNotWave(ioliteDFpath("Splines",IndexChannel+"_Baseline_1"))	//Abort if [index]_Baseline_1 is not in the Splines folder, otherwise proceed with DRS code below..

//	//Make a mask for ratios, don't put it on baseline subtracted intermediates, as the full range is useful on these. "mask" is the name of your mask beam	
	Wave mask=$DRS_CreateMaskWave(IndexOut,MaskThreshold,MaskEdgeDiscardSeconds,"mask","StaticAbsolute")  //This mask currently removes all datapoints below 1000 CPS on U238, with a sideways effect of 1 second.

	
	PathInfo P_ionium
	String of_path = S_path + "Add ons:IsoSpike:DS_settings:"
	PathInfo DS_settings
	If(V_Flag==0 || cmpstr(S_path,of_path)!=0)
		NewPath/O DS_settings, of_path
	Endif
	
	Print "-----------" + date() + " " + time() +  ": started DRS ------------"


	if(datatype==1) //if using Nu Plasma data
		//The below code combines multiple measured masses of an isotope into a single intermediate wave. It assumes that (using Mg24 as an example) the measured masses are up to 0.1 amu lower than the number (e.g. 23.94)	
		//Outer loop, cycles through each mass in turn, then the inner loop sums all of the inputs found for that mass
		//start by initialising strings, variables, etc.
		string ListOfMatchingInputs = ""
		String ThisInputName
		variable NoOfMatchingInputs
		variable OuterLoopCounter = 0
		variable InnerLoopCounter
		String ListOfMasses = "Os188;Pt190;Pt192;Ir193;Pt194;Pt195;Pt196;Au197;Pt198;Hg200"
	//	String ListOfMasses = "Os188;Pt190;Pt192;Ir193;Pt194;Pt195;Pt196;Pt198;Hg200"
		string ThisWaveName
		Variable MassAsVariable
		variable NoOfMasses = itemsinlist(ListOfMasses, ";")
		do
			ThisInputName = StringFromList(OuterLoopCounter, ListOfMasses, ";")
			ThisWaveName = ThisInputName + "_BLSub"
			wave ThisWave = $MakeioliteWave("CurrentDRS",ThisWaveName,n=NoOfPoints)
			ThisWave = 0
			sscanf ThisInputName, "%*[A-Za-z]%f", MassAsVariable		//put the bits of the ThisInputName string that aren't letters into the variable MassAsVariable	(e.g. Mg24 will put 24 in the variable)
//			ListOfMatchingInputs = GrepList(ListOfInputChannels, "(?i)_m"+num2str(MassAsVariable-1)+"p", 0, ";")  //changed for Iolite 2.4
			ListOfMatchingInputs = GrepList(ListOfInputChannels, "m"+num2str(MassAsVariable-1)+"p", 0, ";")
			NoOfMatchingInputs = itemsinlist(ListOfMatchingInputs, ";")
			if(NoOfMatchingInputs == 0)	//if no matches were found then printabort
				printabort("Sorry, unable to identify any inputs for the " + ThisInputName + " input mass. DRS aborted")
			endif
			ListOfIntermediateChannels+=ThisWaveName + ";"
			InnerLoopCounter = 0
			do		//loop through each of the inputs for this mass and add them to the wave
				ThisInputName = StringFromList(InnerLoopCounter, ListOfMatchingInputs, ";")
				//Now check if the baseline required for this input exists. Abort if it doesn't
				DRSabortIfNotWave(ioliteDFpath("Splines",ThisInputName+"_Baseline_1"))	//Abort if [index]_Baseline_1 is not in the Splines folder, otherwise proceed with DRS code below..
				//The below includes baseline subtraction
				wave ThisTempInput = $InterpOntoIndexTimeAndBLSub(ThisInputName, Name = "ThisTempInput")		//use this external function to interpolate the input onto index_time then subtract it's baseline
				//this interpolate will interpolate the first and last values out sideways in the new wave
				//so need to follow it by setting any points outside the range of the input wave to NaN
				wave ThisInputTimeWave = $ioliteDFpath("input",ThisInputName+"_Time")	//Need this for the below logic test
				ThisTempInput = Index_Time[p] < ThisInputTimeWave[0] ? inf : ThisTempInput		//if this point is before the time range of the input time wave then set point to inf (using inf so that it can be discriminated from a normal NaN)
				ThisTempInput = Index_Time[p] > ThisInputTimeWave[numpnts(ThisInputTimeWave)-1] ? inf : ThisTempInput		//if this point is before the time range of the input time wave then set point to  inf (using inf so that it can be discriminated from a normal NaN)
				//Then add this wave to ThisWave -- Note that this middle step of setting NaNs is required so that points falling both prior to and after the input wave can be ignored.
				ThisWave = numtype(ThisTempInput)==1 ? ThisWave : ThisWave + ThisTempInput
				InnerLoopCounter += 1
			while(InnerLoopCounter < NoOfMatchingInputs)
		OuterLoopCounter += 1
		while(OuterLoopCounter < NoOfMasses)	//3 is the number of Mg masses to run the loop for
		//Should now have a single wave for each of the measured isotopes, which contains a combination of all data for that isotope, regardless of the exact mass used during measurement
	
		wave Os188_BLSub = $ioliteDFpath("CurrentDRS","Os188_BLSub")		//BLSub means baseline subtracted. Best to keep wave names short, so used an abbreviation
		wave Pt190_BLSub = $ioliteDFpath("CurrentDRS","Pt190_BLSub")	
		wave Pt192_BLSub = $ioliteDFpath("CurrentDRS","Pt192_BLSub")	
		wave Ir193_BLSub = $ioliteDFpath("CurrentDRS","Pt193_BLSub")	
		wave Pt194_BLSub = $ioliteDFpath("CurrentDRS","Pt194_BLSub")	
		wave Pt195_BLSub = $ioliteDFpath("CurrentDRS","Pt195_BLSub")	
		wave Pt196_BLSub = $ioliteDFpath("CurrentDRS","Pt196_BLSub")	
		wave Au197_BLSub = $ioliteDFpath("CurrentDRS","Au197_BLSub")
		wave Pt198_BLSub = $ioliteDFpath("CurrentDRS","Pt198_BLSub")	
		wave Hg200_BLSub = $ioliteDFpath("CurrentDRS","Hg200_BLSub")
	
		//This is hopefully temporary - I currently have a minor issue with the index time wave being 1 point out of phase with the BLSub waves. This is quick fix.
		Os188_BLSub*=mask
		Pt190_BLSub*=mask
		Pt192_BLSub*=mask
		Pt194_BLSub*=mask
		Pt195_BLSub*=mask
		Pt196_BLSub*=mask
		Au197_BLSub*=mask
		Pt198_BLSub*=mask
		Hg200_BLSub*=mask
	endif
	
	if(datatype==2)//if Neptune data
		wave Os188_BLSub = $InterpOntoIndexTimeAndBLSub("Os188",name="Os188_BLSub")	
		wave Pt190_BLSub = $InterpOntoIndexTimeAndBLSub("Pt190",name="Pt190_BLSub")
		wave Pt192_BLSub = $InterpOntoIndexTimeAndBLSub("Pt192",name="Pt192_BLSub")	
		wave Pt194_BLSub = $InterpOntoIndexTimeAndBLSub("Pt194",name="Pt194_BLSub")	
		wave Pt195_BLSub = $InterpOntoIndexTimeAndBLSub("Pt195",name="Pt195_BLSub")	
		wave Pt196_BLSub = $InterpOntoIndexTimeAndBLSub("Pt196",name="Pt196_BLSub")	
		wave Pt198_BLSub = $InterpOntoIndexTimeAndBLSub("Pt198",name="Pt198_BLSub")	
		wave Hg200_BLSub = $InterpOntoIndexTimeAndBLSub("Hg200",name="Hg200_BLSub")		
		ListOfIntermediateChannels+="Os188_BLSub;Pt190_BLSub;Pt192_BLSub;Pt194_BLSub;Pt195_BLSub;Pt196_BLSub;Pt198_BLSub;Hg200_BLSub;"	
	endif

//	//Now have baseline subtracted each mass
//	//To make ratios, create a wave to hold the results, then calculate the results
	Wave Raw190_194=$MakeioliteWave("CurrentDRS","Raw190_194",n=NoOfPoints)
	Wave Raw192_194=$MakeioliteWave("CurrentDRS","Raw192_194",n=NoOfPoints)
	Wave Raw195_194=$MakeioliteWave("CurrentDRS","Raw195_194",n=NoOfPoints)
	Wave Raw196_194=$MakeioliteWave("CurrentDRS","Raw196_194",n=NoOfPoints)
	Wave Raw198_194=$MakeioliteWave("CurrentDRS","Raw198_194",n=NoOfPoints)
	ListOfIntermediateChannels+="Raw190_194;Raw192_194;Raw195_194;Raw196_194;Raw198_194;"

	Raw190_194=Pt190_BLSub/Pt194_BLSub		*mask       	//commented due to correction applied below
	Raw192_194=Pt192_BLSub/Pt194_BLSub		*mask		//commented due to correction applied below
	Raw195_194=Pt195_BLSub/Pt194_BLSub		*mask
	Raw196_194=Pt196_BLSub/Pt194_BLSub		*mask		//commented due to correction applied below
	Raw198_194=Pt198_BLSub/Pt194_BLSub		*mask		//commented due to correction applied below


	/// Monitoring for presence of Os or Hg
	variable OsHitCount = 0, i, HgHitCount = 0, j
	
	For(i=0;i<NoOfPoints;i+=1)
		if(Os188_BLSub[i]>0.0001)	// set a threshold of 0.1mV for Os monitoring
			OsHitCount+=1
		endif
	EndFor
	if(OsHitCount>=1)
		print "Os interference threshold crossed for " + num2str(HgHitCount) + " of " + num2str(NoOfPoints) + " points"
	endif
	For(j=0;j<NoOfPoints;j+=1)
		if(Hg200_BLSub[j]>0.0001)	// set a threshold of 0.1mV for Hg monitoring
			HgHitCount+=1
		endif
	EndFor
	if(HgHitCount>=1)
		print "Hg interference threshold crossed for " + num2str(HgHitCount) + " of " + num2str(NoOfPoints) + " points"
	endif


	Wave TotalPt_Volts=$MakeioliteWave("CurrentDRS","TotalPt_Volts",n=NoOfPoints)
	TotalPt_Volts = Pt190_BLSub + Pt192_BLSub + Pt194_BLSub + Pt195_BLSub + Pt196_BLSub + Pt198_BLSub
	
	Variable MassPt190 = 189.959930, MassPt192 = 191.961035, MassPt194 = 193.962664, MassPt195 = 194.96479, MassPt196 = 195.964935, MassPt198 = 197.967876

	//Internally normalised Pt isotope ratios
	Wave Fract=$MakeioliteWave("CurrentDRS","Fract",n=NoOfPoints)
	Fract = Ln(True195_194/(Pt195_BLSub/Pt194_BLSub))/Ln(MassPt195/MassPt194)	*mask		// calculate fractionation coefficient
//	Wave Corr190_194=$MakeioliteWave("CurrentDRS","Corr190_194",n=NoOfPoints)			//waves to hold internally corrected ratios
//	Wave Corr192_194=$MakeioliteWave("CurrentDRS","Corr192_194",n=NoOfPoints)
//	Wave Corr195_194=$MakeioliteWave("CurrentDRS","Corr195_194",n=NoOfPoints)
//	Wave Corr198_194=$MakeioliteWave("CurrentDRS","Corr198_194",n=NoOfPoints)	
//	Corr190_194=Raw190_194 * (MassPt190 / MassPt194) ^ Fract	*mask
//	Corr192_194=Raw192_194 * (MassPt192 / MassPt194) ^ Fract	*mask
//	Corr195_194=Raw195_194 * (MassPt195 / MassPt194) ^ Fract	*mask	
//	Corr198_194=Raw198_194 * (MassPt198 / MassPt194) ^ Fract	*mask	
//	ListOfOutputChannels+="TotalPt_Volts;Fract;Corr190_194;Corr192_194;Corr196_194;Corr198_194;"

	Wave Corr196_194=$MakeioliteWave("CurrentDRS","Corr196_194",n=NoOfPoints)
	Corr196_194=Raw196_194 * (MassPt196 / MassPt194) ^ Fract	*mask		
	
	Wave TotalPt_Volts=$MakeioliteWave("CurrentDRS","TotalPt_Volts",n=NoOfPoints)
	TotalPt_Volts = Pt190_BLSub + Pt192_BLSub + Pt194_BLSub + Pt195_BLSub + Pt196_BLSub + Pt198_BLSub
	
	ListOfOutputChannels+="TotalPt_Volts;Fract;Corr196_194;" 

//	////////
//	// UNSPIKED OPTION
//	////////
//	//this is how you can interpolate some measured unspiked samples onto a wave that exists during output integrations. First need to add unspiked runs to the "unspiked" standard integration type
//	//make waves to hold the unspiked values
//	Wave Unspiked195_194 = $MakeIoliteWave("CurrentDRS","Unspiked195_194",n=NoOfPoints)  //then make a wave to hold the values (need one for each ratio)
//	Wave Unspiked196_194 = $MakeIoliteWave("CurrentDRS","Unspiked196_194",n=NoOfPoints)  //then make a wave to hold the values (need one for each ratio)
//	Wave Unspiked198_194 = $MakeIoliteWave("CurrentDRS","Unspiked198_194",n=NoOfPoints)  //then make a wave to hold the values (need one for each ratio)
//	//make splines for each channel
//	Wave stdspline_Unspiked195_194 = $InterpSplineOntoIndexTime("Raw195_194","unspiked")	//then interpolate the values on to the wave
//	Wave stdspline_Unspiked196_194 = $InterpSplineOntoIndexTime("Raw196_194","unspiked")	//then interpolate the values on to the wave
//	Wave stdspline_Unspiked198_194 = $InterpSplineOntoIndexTime("Raw198_194","unspiked")	//then interpolate the values on to the wave
//	//now set our unspiked waves equal to the spline.
//	Unspiked195_194 = stdspline_Unspiked195_194
//	Unspiked196_194 = stdspline_Unspiked196_194
//	Unspiked198_194 = stdspline_Unspiked198_194
//	//Add these to the list of intermediate channels, now ready to use in the DS code
//	ListOfIntermediateChannels+="Unspiked195_194;Unspiked196_194;Unspiked198_194;"

	//*********
	IsoSpikeStart() 	// call double spike procedure
	//*********

	//Calculate µ values for Pt isotope ratios
	//reference the DS corrected waves
	wave DScorr192_194=$ioliteDFpath("CurrentDRS","DSCorr192_194")	
	wave DScorr195_194=$ioliteDFpath("CurrentDRS","DSCorr195_194")
	wave DScorr196_194=$ioliteDFpath("CurrentDRS","DSCorr196_194")	
	wave DScorr198_194=$ioliteDFpath("CurrentDRS","DSCorr198_194")	
		
	//note: only proceeds if there is a spline for the standard
	DRSAbortIfNotSpline("DSCorr198_194", ReferenceStandard)
	
	if(WaveExists(DScorr192_194))
		wave StdSpline_DSCorr192_194 = $InterpSplineOntoIndexTime("DSCorr192_194", ReferenceStandard)
		Wave MuInt192_194=$MakeioliteWave("CurrentDRS","MuInt192_194",n=NoOfPoints)
		MuInt192_194 = (DSCorr192_194 / StdSpline_DSCorr192_194 - 1) * 1000000
		ListOfOutputChannels+="MuInt192_194;"
	endif
	
	if(WaveExists(DScorr195_194))
		wave StdSpline_DSCorr195_194 = $InterpSplineOntoIndexTime("DSCorr195_194", ReferenceStandard)
		Wave MuInt195_194=$MakeioliteWave("CurrentDRS","MuInt195_194",n=NoOfPoints)
		MuInt195_194 = (DSCorr195_194 / StdSpline_DSCorr195_194 - 1) * 1000000
		ListOfOutputChannels+="MuInt195_194;"
	endif
	
	wave StdSpline_DSCorr196_194 = $InterpSplineOntoIndexTime("DSCorr196_194", ReferenceStandard)
	Wave MuInt196_194=$MakeioliteWave("CurrentDRS","MuInt196_194",n=NoOfPoints)
	MuInt196_194 = (DSCorr196_194 / StdSpline_DSCorr196_194 - 1) * 1000000

	
	wave StdSpline_DSCorr198_194 = $InterpSplineOntoIndexTime("DSCorr198_194", ReferenceStandard)
	Wave MuInt198_194=$MakeioliteWave("CurrentDRS","MuInt198_194",n=NoOfPoints)
	MuInt198_194 = (DSCorr198_194 / StdSpline_DSCorr198_194 - 1) * 1000000
	
	ListOfOutputChannels+="MuInt196_194;MuInt198_194;"	
	
	RecalculateIntegrations("*","*")
	
	
//Now propagate errors (if required)
//	if(cmpstr(PropagateSplineErrors, "Yes") == 0)	//if the user wants to propagate spline errors
//		string ListOfOutputsToPropagate = "Delta_195_194"
//		Propagate_Errors("All", ListOfOutputsToPropagate, "StdCorrRaw_195_194", ReferenceStandard)
//		endif
end   //****End of DRS function.  Write any required external sub-routines below this point****


//****Start Export data function (optional).  If present in a DRS file, this function is called by the export Stats routine when it is about to save the export stats text matrix to disk.
Function ExportFromActiveDRS(Stats,NameOfPathToDestinationFolder) //this line must be as written here
	wave/T Stats //will be a wave reference to the stats text wave that is about to be saved
	String NameOfPathToDestinationFolder //will be the name of the path to the destination folder for this export.
	//This routine allows the segment/stats export routine to be intercepted if there are DRS-specific actions to be undertaken during data export.  For now, for U-Th there is just this warning:
end	//end of DRS intercept of data export - export routine will now save the (~altered) stats wave in the folder it supplied.

Function AutoIntermediates(buttonstructure) //Build the main display and integration window --- This is based off a button, so has button structure for the next few lines
	STRUCT WMButtonAction&buttonstructure
	if( buttonstructure.eventCode != 2 )
		return 0  // we only want to handle mouse up (i.e. a released click), so exit if this wasn't what caused it
	endif  //otherwise, respond to the popup click
	ClearAllTraces()
	AutoTrace(0, "Raw192_194", 0.41, 0.45, extraflag = "Primary")	//see the autotrace function for what these mean.
	AutoTrace(1, "Raw195_194", 0.9, 0.94)	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(2, "Raw196_194", 0.67, 0.695, extraflag = "Right")	//see the autotrace function for what these mean.
	AutoTrace(3, "Raw198_194", 0.95, 1.05)	//see the autotrace function for what these mean.
	//AutoTrace(6, "Raw42_44", 0, 0)	//see the autotrace function for what these mean.
end

Function AutoBaselines(buttonstructure) //Build the main display and integration window --- This is based off a button, so has button structure for the next few lines
	STRUCT WMButtonAction&buttonstructure
	if( buttonstructure.eventCode != 2 )
		return 0  // we only want to handle mouse up (i.e. a released click), so exit if this wasn't what caused it
	endif  //otherwise, respond to the popup click
	ClearAllTraces()
	AutoTrace(0, "m191p74_L2", -0.0015, 0.004,extraflag = "Hidden")	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(1, "m193p74_Ax",  -0.0015, 0.005,extraflag = "Primary")	//see the autotrace function for what these mean.
	AutoTrace(2, "m194p74_H1", -0.0015, 0.004,extraflag = "Right")	//see the autotrace function for what these mean.
	AutoTrace(3, "m195p74_H2", -0.001, 0.007,extraflag = "Hidden")	//see the autotrace function for what these mean.
	AutoTrace(4, "m197p74_H4", -0.001, 0.012,extraflag = "Hidden")	//see the autotrace function for what these mean.
	AutoTrace(5, "m187p74_L4", -0.001, 0.0001)	//see the autotrace function for what these mean.	
	AutoTrace(6, "m199p74_H5", -0.001, 0.0011,extraflag = "Hidden")	//see the autotrace function for what these mean.	
end
