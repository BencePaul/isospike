#pragma rtGlobals=1		// Use modern global access method.
//	Version 1.03 (2018-04-02)
//	This addon module was written by John Creech and Bence Paul. See www.isospike.org for full details and citation information.
//	These procedures uses the terminology of Rudge et al. (2009) "The double spike toolbox" Chem. Geol. v. 265, pp.420 - 431
//	This source code is released under a Creative Commons Attribution-ShareAlike 3.0 Unported license. For more information, see the LICENSE.txt file bundled with this procedure or the online documentation.

#include ":PeriodicTable" //include the periodic table function for use in IsoSpike

//	We need some input parameters to start off with. These are the Double Spike ratios (T), the unspiked ratios (N), the spiked-mixture ratios (M), 
//	and the natural log of the mass ratios (P). There are three of each of these. The user selects the unspiked and spiked ratios from the list of output channels. 
//	and the mass ratios and double spike values are entered as text. These values can be saved out, and imported again later.

Function IsoSpikeStart()	//This is the function that starts it all off. Copy and paste "IsoSpikeStart()" into the command window to launch it 
	DFREF saveDFR = GetDataFolderDFR()	// Save datafolder
	If(stringmatch(CheckAndCreateDFPath(ioliteDFpath("Addons","")),"OK")!=1)	//Create a new datafolder called "Addons" to hold all our data. 
		PrintAbort("Couldn't create a new datafolder called \"Addons\". Please check your permissions or report this bug.")	//The function "CheckandCreate..." returns "OK" if sucessfully completed datafolder creation. So this should only come up if it wasn't successful.
	Endif
	SetDataFolder(ioliteDFpath("Addons",""))		//And move to this new folder

	//This is where the options should be selected, and call the function below if necessary
	SVAR ListofOutputChannels = $IoliteDFPath("Output","ListOfOutputChannels")		//Reference the global list of output channels
	If(!SVar_Exists(ListofOutputChannels))	//If this string doesn't exist yet, it's most likely because the user hasn't finished processing their results yet
		SetDataFolder saveDFR			// and restore
		PrintAbort("Couldn't find the list of output channels. Please process your data first.")
	Endif

	PathInfo P_ionium		//symbolic links to the IsoSpike and DS_settings folders
	String of_path = S_path + "Add ons:IsoSpike:"
	PathInfo IsoSpike_path
	If(V_Flag==0 || cmpstr(S_path,of_path)!=0)
		NewPath/O IsoSpike_path, of_path
	Endif
	PathInfo DS_settings
	of_path+="DS_settings:"
	If(V_Flag==0 || cmpstr(S_path,of_path)!=0)
		NewPath/O DS_settings, of_path
	Endif

	//Optional flags
	setdatafolder $ioliteDFpath("DRSGlobals","")	
	NVar/Z DS_noninteractiveflag  // Option set in DRS. Option 0 will bring up a dialog to ask what to do about DS_settings. Option 1 will skip that unless no file is specified.
	if(!NVAR_Exists(DS_noninteractiveflag)) //If no option is specified, default to Option 0.
		DS_noninteractiveflag=0
	endif
	NVar/Z CalibratingFlag
	if(!NVAR_Exists(CalibratingFlag)) //If the calibrating flag variable hasn't been created in the DRS, make it now, but default to false.
		Variable/G CalibratingFlag = 0
	endif
	Variable/G gotSettingsFlag = 0  // allows us to test later whether DS settings have been acquired correctly

	NVar/Z doAnomaly
	if(!NVAR_Exists(doAnomaly))
		Variable/G doAnomaly = 0
	endif
	
	NVar/Z enterUnspiked
	if(!NVAR_Exists(enterUnspiked))
		Variable/G enterUnspiked = 0
	endif	
//	DS_noninteractiveflag = 0  //only for debug purposes.

	SVar/Z DSsettingsFilename  //global variable that stores the name of the currently used DS_settings file. If it doesn't exist make it.
	if(!SVAR_Exists(DSsettingsFilename))
		String/G DSsettingsFilename = "None" //Defaults to this name. Panel shows it greyed out and non-editable if this string is found.
	endif
	
	If(DS_noninteractiveflag==1) //we've chosen to crunch using DS_Settings specified in DRS with no dialogs
		//since we're not doing this interactively, if we want to review settings, CalibratingFlag must be pre-assigned in DRS
		DSp_LoadSettings(1)
		gotSettingsFlag = 1
	else
		//Draw a panel with buttons for all the options
		Variable pleft=200,ptop=150,pright=pleft+500,pbottom=ptop+150
		NewPanel /W=(pleft,ptop,pright,pbottom)/FLT/K=1/N=DSOptions as "Double Spike Options"
		SetDrawEnv fsize= 15, fname= "Times New Roman"
		DrawText 10,23,"Get DS_settings from:"
		SetDrawEnv fsize= 28, fname= "Times New Roman"
		DrawText 240,72,"}"
		Button DS_UseCurrentDSsettings,win=DSOptions,pos={10,30},size={220,20},proc=DoubleSpikeButtonHandler,title="Use current DS settings file"		
		Button DS_LoadDSsettings,win=DSOptions,pos={10,60},size={220,20},proc=DoubleSpikeButtonHandler,title="Load DS_settings file"		
		Button DS_EnterDSsettings,win=DSOptions,pos={10,90},size={220,20},proc=DoubleSpikeButtonHandler,title="Create DS_settings file"
		Button DS_Cancel,win=DSOptions,pos={10,120},size={220,20},proc=DoubleSpikeButtonHandler,title="Cancel"
		Checkbox DS_review, pos={260,52}, title="Review DS parameters before proceeding", value = CalibratingFlag, proc=DSreviewCheck, fsize=10
		Checkbox doAnomaly, pos={260,72}, title="Modify std values for anomalies", value = doAnomaly, proc=DSreviewCheck, fsize=10
		Checkbox enterUnspiked, pos={260,92}, title="Manually enter unspiked compositions", value = enterUnspiked, proc=DSreviewCheck, fsize=10
		SetDrawEnv fsize= 12, fname= "Times New Roman"
		DrawText 248,14,"Current DS settings file:"
		SetVariable setvar0 value=DSsettingsFilename,title=" ",limits={-inf,inf,0},pos={248,15},size={241,15},help={"Currently loaded DS settings file. Initially loads filename specified in DRS if present."};DelayUpdate
		if(cmpstr(DSsettingsFilename,"None")==0) 	//if no filename has been entered or found in DRS, defaults to "None".
			SetVariable setvar0 disable=2  				//if so, text box is greyed out and not editable
		else 
			SetVariable setvar0 disable=0				//otherwise it is active, and one can even paste the name of a file right in the box and it will work.
		endif
		PauseForUser DSOptions //Don't allow the user to do anything but click the buttons on the panel
	endif

	if(gotSettingsFlag==1)  //make sure the previous procedures ran ok
		if(CalibratingFlag==1)	//if we have selected to review DS settings before proceeding
			DSp_ShowSettings(opt=1) //this function will also run the DSp_Solve routine, so that's why it's not here as well
		else
			DSp_Solve()
		endif
	endif
	
	SetDataFolder saveDFR			// and restore data folder. To find the guts of the equations, go to DSp_Solve()
End

Function DSp_PromptUser()			//Procedure to prompt user for parameters if choosing to input manually
	DFREF saveDFR = GetDataFolderDFR()	// Save datafolder
	SVAR ListofIntermediateChannels = $IoliteDFPath("Output","ListOfIntermediateChannels")		//reference the global list of INTERMEDIATE channels to use as inputs

	//Create the waves to hold the settings here
	Wave/T Ratio = $MakeIoliteWave("Addons","Ratio",N=3,Type="t")  //This is a text wave just saying ratio1, ratio2, ratio3; Simply for friendlyness of DS_Settings table and txt file
	Ratio[0] = "Ratio1"
	Ratio[1] = "Ratio2"
	Ratio[2] = "Ratio3"

	Wave/T MixedRatio = $MakeIoliteWave("Addons","MixedRatio",N=3,Type="t") //This holds the names of the MixedRatio waves
	Wave SpikeRatio = $MakeIoliteWave("Addons","SpikeRatio",N=3)
	Wave LogMassRatio = $MakeIoliteWave("Addons","LogMassRatio",N=3)
	
	//Now start prompting the user:
	//First, find out where to get unmixed ratios from. First 2 options happen immediately below
	String ListofUnmixedOptions = "Use measured value;Use reference standard value;"//;Use natural abundance ratios"
	String UnmixedOption 
	prompt UnmixedOption, "Unmixed options:", popup, ListofUnmixedOptions
	doprompt "How do you want to get unmixed (N) values?", UnmixedOption
	if(V_flag==1) // abort if user hits cancel
		abort
	endif
	
	//Sets up what to do for the first two options.
	if(cmpstr(UnmixedOption,"Use measured value")==0)
		//Select waves for the unmixed ratios
		String N_ratio1,N_ratio2,N_ratio3	//Strings to hold the names of the unmixed channels (this could be a standard spline interpolated into a channel)
		print "Using measured unspiked option"  //Note: It's still necessary for the user to make waves in their DRS that interpolate measured standard over time of integrations - not handled here.
		KillWaves/Z $IoliteDFpath("Addons","UnmixedRatio")
		Wave/T UnmixdRatio = $MakeIoliteWave("Addons","UnmixedRatio",N=3,Type="t")
		prompt N_ratio1, "Please select the first unmixed (N) channel:", popup, ListofIntermediateChannels
		prompt N_ratio2, "Please select the second unmixed (N) channel:", popup, ListofIntermediateChannels
		prompt N_ratio3, "Please select the third unmixed (N) channel:", popup, ListofIntermediateChannels
		doprompt "Select UNMIXED ratio channels", N_ratio1,N_ratio2,N_ratio3
		if(V_Flag==1) //if the user hits cancel this will stop the export from continuing
			abort
		endif
		
		UnmixdRatio[0] = N_ratio1
		UnmixdRatio[1] = N_ratio2
		UnmixdRatio[2] = N_ratio3
		
		Wave N_ratio1_wave =$IoliteDFPath("CurrentDRS",N_ratio1)	//Create wave references to the selected waves
		Wave N_ratio2_wave =$IoliteDFPath("CurrentDRS",N_ratio2)
		Wave N_ratio3_wave =$IoliteDFPath("CurrentDRS",N_ratio3)
		If(!WaveExists(N_ratio1_wave) || !WaveExists(N_ratio2_wave) || !WaveExists(N_ratio3_wave) )	//If any of these waves don't exist for some reason, we need to catch it here 
			PrintAbort("One of the selected unmixed channels doesn't exist. Please check that the selected channels exist.")
		Endif
	ElseIf(cmpstr(UnmixedOption,"Use reference standard value")==0)
		Variable N_ratio_1, N_ratio_2, N_ratio_3
		KillWaves/Z $IoliteDFpath("Addons","UnmixedRatio")
		Wave UnmixRatio  = $MakeIoliteWave("Addons","UnmixedRatio",N=3)
		print "Using reference standard option"
		prompt N_ratio_1, "Please input the first standard ratio (N) value:"
		prompt N_ratio_2, "Please input the second standard ratio (N) value:"
		prompt N_ratio_3, "Please input the third standard ratio (N) value:"
		doprompt "Input Standard Ratios", N_ratio_1,N_ratio_2,N_ratio_3  //!!NOTE!! this was wrong when I sent it to Bence.
		if(V_Flag==1) //if the user hits cancel this will stop the export from continuing
			abort
		endif
		UnmixRatio[0] = N_ratio_1
		UnmixRatio[1] = N_ratio_2
		UnmixRatio[2] = N_ratio_3
	Endif

	//Now, select the mixed ratio channels
	String M_ratio1,M_ratio2,M_ratio3	//Strings to hold the names of the mixed channels
	prompt M_ratio1, "Please select the first MIXED (M) channel:", popup, ListofIntermediateChannels
	prompt M_ratio2, "Please select the second MIXED (M) channel:", popup, ListofIntermediateChannels
	prompt M_ratio3, "Please select the third MIXED (M) channel:", popup, ListofIntermediateChannels
	doprompt "Select MIXTURE ratio channels", M_ratio1,M_ratio2,M_ratio3
	if(V_Flag==1) //if the user hits cancel this will stop the export from continuing
		abort
	endif
					
	Wave M_ratio1_wave =$IoliteDFPath("CurrentDRS",M_ratio1)	//Create wave references to the selected waves to check that they exist
	Wave M_ratio2_wave =$IoliteDFPath("CurrentDRS",M_ratio2)
	Wave M_ratio3_wave =$IoliteDFPath("CurrentDRS",M_ratio3)
	If(!WaveExists(M_ratio1_wave) || !WaveExists(M_ratio2_wave) || !WaveExists(M_ratio3_wave) )	//If any of these waves don't exist for some reason, we need to catch it here 
		PrintAbort("One of the selected mixed channels doesn't exist. Please check that the selected channels exist.")
	Endif
	
	MixedRatio[0] = M_ratio1 //Then store the mixed ratio channel names in our settings wave
	MixedRatio[1] = M_ratio2
	MixedRatio[2] = M_ratio3

 	//Now, input the spike values
	Variable T_ratio1,T_ratio2,T_ratio3	//Variables to hold the *values* of the spike ratios. NOTE: these don't change between analyses, but the above do
	prompt T_ratio1, "Please input the first double spike ratio (T) value:"
	prompt T_ratio2, "Please input the second double spike ratio (T) value:"
	prompt T_ratio3, "Please input the third double spike ratio (T) value:"
	doprompt "Input Double Spike Ratios", T_ratio1,T_ratio2,T_ratio3
	if(V_Flag==1) //if the user hits cancel this will stop the export from continuing
		abort
	endif
	
	SpikeRatio[0] = T_ratio1
	SpikeRatio[1] = T_ratio2
	SpikeRatio[2] = T_ratio3
	
	//Lastly, input the log mass ratio values
	if(PeriodicTable(DS=1)!=1)  //Launch isoPeriodicTable function to get log(mass ratios) ± abundance ratios.
		abort
	endif

	Wave massratios = root:Packages:iolite:AddOns:MassTable:IsotopeLogMassRatio  //reference the wave with the mass ratios that we made in the isoPeriodicTable function
	LogMassRatio[0] = massratios[0]
	LogMassRatio[1] = massratios[1]
	LogMassRatio[2] = massratios[2]

	Wave UnmixedRatio = $IoliteDFpath("Addons","UnmixedRatio")  //Reference the unmixed ratio wave. Seems to work even when it's text.	
End	

Function DSp_LoadSettings(DSoption)
	variable DSoption
	DFREF saveDFR = GetDataFolderDFR()	// Save datafolder
	setdatafolder $ioliteDFpath("DRSGlobals","")	
	SVar/Z DSsettingsFilename
	SetDataFolder(ioliteDFpath("Addons","")) //Store settings waves in Addons folder
	KillWaves/Z UnmixedRatio
	If (DSoption==1) // If user chose to load default file
		LoadWave/O/Q/J/D/W/A/K=0/P=DS_settings DSsettingsFilename
//		LoadWave/O/Q/J/D/W/A/K=0/P=DS_settings/B="F=-2;F=0,T=4;F=-2;F=0,T=4;F=0,T=4;" DSsettingsFilename
		if(V_flag==0) // if no file was loaded (should never happen because user is selecting a file)
			printabort("Specified DS_Settings file not found")
		endif
	Else	
		LoadWave/O/Q/J/D/W/A/K=0/P=DS_settings
		if(V_flag==0) // since we used a dialog, V_flag == 0 if user hits cancel. If so, abort.
			printabort("DS procedure aborted")
		endif
	Endif
	Print "Double Spike settings loaded from " + S_path + S_fileName
	DSsettingsFilename=S_fileName
	if(getUnmixedRatioType()==1)
		print "Unmixed (N) ratio as wave"
	elseif(getUnmixedRatioType()==0)
		print "Unmixed (N) ratio as standard value"
	endif
	
	SetDataFolder saveDFR			// and restore datafolder
End

Function DSp_SaveSettings()		//This function saves settings for the double spike calculations, actioned when the user clicks Save Settings button on control panel
	Wave/T Ratio = $IoliteDFpath("Addons","Ratio")
	Wave/T MixedRatio = $IoliteDFpath("Addons","MixedRatio")
	Wave SpikeRatio = $IoliteDFpath("Addons","SpikeRatio")
	Wave LogMassRatio = $IoliteDFpath("Addons","LogMassRatio")
	Wave UnmixedRatio = $IoliteDFpath("Addons","UnmixedRatio") 
	
	Save/J/W/I/P=DS_settings Ratio,UnmixedRatio,MixedRatio,SpikeRatio,LogMassRatio as "DS_Settings.txt" //P=DS_settings

	DoWindow/F DSPanel	//check if DS settings panel exists (i.e. we're calling this from within the normal procedure)
	if(V_Flag==1)	
		Button DS_Save win=DSPanel,fColor=(48059,48059,48059)	//if so, grey out the save button
	endif 	
End

Function getUnmixedRatioType()
	If(strlen(WaveList("UnmixedRatio",";","TEXT:1"))>0)
		Return 1 //if wave is storing text (i.e. wave name) return 1
	Else
		Return 0 //if wave is storing a number, return 0
	endif
End

Function DSp_ShowSettings([opt])
	variable opt		
	//create references to parameter waves
	Wave/T Ratio = $IoliteDFpath("Addons","Ratio")
	Wave/T MixedRatio = $IoliteDFpath("Addons","MixedRatio")
	Wave SpikeRatio = $IoliteDFpath("Addons","SpikeRatio")
	Wave LogMassRatio = $IoliteDFpath("Addons","LogMassRatio")
	Wave UnmixedRatio = $IoliteDFpath("Addons","UnmixedRatio") 

	//Now we'll present these inputs in the form of a panel with the settings waves displayed in it.
	DoWindow/F DSPanel	//check if it exists
	if(V_Flag==1)	//if this window already exists for some reason
		killwindow DSPanel //then kill it
	endif //otherwise, just build it..	
	NewPanel /W=(150,50,878,636)/K=1/N=DSPanel as "Double Spike Parameters"
	Edit/W=(163,15,702,565)/HOST=DSPanel/K=1/N=DSPanel_Settings Ratio,UnmixedRatio,MixedRatio,SpikeRatio,LogMassRatio //DS_Settings.ld 	//Now show the new table
	ModifyTable/Z sigDigits[2]=8
//	ModifyTable/Z sigDigits[4]=8
//	ModifyTable/Z sigDigits[5]=8		
	SetActiveSubwindow ##		//Just for prettiness  
	if(opt==1)
		Button DS_Save,win=DSPanel,pos={34,107},size={100,20},proc=DoubleSpikeButtonHandler,title="Save Settings"		//The Save button
		Button DS_Close_Procede,win=DSPanel,pos={34,139},size={120,20},proc=DoubleSpikeButtonHandler,title="Close & Procede"		//The close button
		PauseForUser DSPanel //Don't allow the user to do anything but click the buttons on the panel
	endif
End

Function DSreviewCheck(name,value) //procedure to control "Review DS_settings" checkbox
   	String name
   	Variable value
	
	DFREF saveDFR = GetDataFolderDFR()	// Save datafolder
	setdatafolder(ioliteDFpath("DRSGlobals","")	)
	NVAR CalibratingFlag,doAnomaly, enterUnspiked
	
	strswitch (name) // only allow one option to be checked.

	case "DS_review":
		CalibratingFlag = value
		doAnomaly=0
		enterUnspiked=0
		Checkbox doAnomaly, value=doAnomaly
		Checkbox enterUnspiked, value=enterUnspiked
		break
	case "doAnomaly":
		CalibratingFlag = 0
		doAnomaly=value
		enterUnspiked=0
		Checkbox DS_review, value=CalibratingFlag
		Checkbox enterUnspiked, value=enterUnspiked
		break
	case "enterUnspiked":
		CalibratingFlag = 0
		doAnomaly=0
		enterUnspiked=value
		Checkbox DS_review, value=CalibratingFlag
		Checkbox doAnomaly, value=doAnomaly
		break
	endswitch
	setdatafolder saveDFR	

End


///////////
///		This is where the double spike calculations actually happen
///////////
Function DSp_Solve([Q])		//This function begins the double spike calculations, actioned when the user clicks Close & Procede button on control panel
	Variable Q
	DFREF saveDFR = GetDataFolderDFR()	// Save datafolder
	SetDataFolder(ioliteDFpath("Addons",""))
	NVAR NoOfPoints = $IoliteDFpath("CurrentDRS","NoOfPoints")
	SVAR ListOfOutputChannels=$ioliteDFpath("Output","ListOfOutputChannels")

	DoWindow/F DSPanel	//kill the DS settings panel, if it exists
	if(V_Flag==1)	
		killwindow DSPanel 
	endif 
	DoWindow/F DSOptions	//kill the DS options panel, if it exists
	if(V_Flag==1)	
		killwindow DSOptions 
	endif 
	
	//Basically we need to solve 3 non-linear equations. Each equation has its own coefficients save in a wave callec coefs1, 2 or 3. We start by creating and filling these waves
	//with the double spike values entered by the user.
	
	//reference our DS_Settings waves
	Wave/T MixedRatio = $IoliteDFpath("Addons","MixedRatio")  // this one is always text. Unmixed one can be either, so it is defined within if statements below
	Wave LogMassRatio = $IoliteDFpath("Addons","LogMassRatio")
	Wave SpikeRatio = $IoliteDFpath("Addons","SpikeRatio")
		
	//We need to create three coefficient waves that will be put into the three non-linear equations. Note that the value for the double spike and the mass ratio won't change between samples, so we set them statically here
	//For the coefficient waves, row 0 is the double spike value for this ratio, row 1 is the unspiked or standard results (n), row 2 is the natural log of the mass ratio for this ratio (P), row 3 is the spiked ratio (m)

	//Get the values of the spike ratios and log mass ratios from our settings waves
	Make/O /n=4 coefs1
	Wave coefs1
	coefs1[0] = SpikeRatio[0]	//This is T of ratio 1, i.e. the value of the double spike
	coefs1[2] = LogMassRatio[0]		//This is P1, the natural log of the mass ratio for ratio 1
	Make/O /n=4 coefs2
	Wave coefs2
	coefs2[0] = SpikeRatio[1]		//This is T of ratio 2, i.e. the value of the double spike
	coefs2[2] = LogMassRatio[1]		//This is P2, the natural log of the mass ratio for ratio 2
	Make/O /n=4 coefs3
	Wave coefs3
	coefs3[0] = SpikeRatio[2]		//This is T of ratio 2, i.e. the value of the double spike
	coefs3[2] = LogMassRatio[2]		//This is P2, the natural log of the mass ratio for ratio 2
	
	//Reference data waves by names stored in MixedRatio wave
	Wave MixedRatio1 = $IoliteDFpath("CurrentDRS",MixedRatio[0])		
	Wave MixedRatio2 = $IoliteDFpath("CurrentDRS",MixedRatio[1])	
	Wave MixedRatio3 = $IoliteDFpath("CurrentDRS",MixedRatio[2])

	//Make some waves to hold the unmixed (N) ratios regardless of their source. //modified to make sure this has double precision
//	SetDataFolder(ioliteDFpath("CurrentDRS",""))
	SetDataFolder(ioliteDFpath("Addons",""))
	make /D/O/N=(NoOfPoints) N_wave1, N_wave2, N_wave3
//	SetDataFolder(IoliteDFpath("Addons",""))

	//Now populate the unmixed ratio waves. If we used a static value, we make a wave with that value. Otherwise just reference a source wave.
	if(getUnmixedRatioType()==0)
		Wave UnmixedRatio = $IoliteDFpath("Addons","UnmixedRatio")	
			N_wave1 = MixedRatio1*0+UnmixedRatio[0]  //just a hack to get our std values into a wave. Take existing wave, multiply by zero, add our constant -> only values that existed in the original wave have the constant value, rest are NaN
			N_wave2 = MixedRatio1*0+UnmixedRatio[1]
			N_wave3 = MixedRatio1*0+UnmixedRatio[2]
	//	Print "Using Static N value"
	elseif(getUnmixedRatioType()==1)
		Wave/T UnmixdRatio = $IoliteDFpath("Addons","UnmixedRatio")	
		Wave UnmixRatio1 = $IoliteDFpath("CurrentDRS",UnmixdRatio[0])  //if we're using a wave, reference the source wave by wave names stored in DS_Settings
		Wave UnmixRatio2 = $IoliteDFpath("CurrentDRS",UnmixdRatio[1])
		Wave UnmixRatio3 = $IoliteDFpath("CurrentDRS",UnmixdRatio[2])
		N_wave1 = UnmixRatio1 	
		N_wave2 = UnmixRatio2 
		N_wave3 = UnmixRatio3
	//	Print "Using N value from wave"
	endif 
	
	//Get ratio names from MixedRatio wave names (Note: assumes the user is putting ratio name in the wave name)
	//I just made this to fit with my format of naming waves. My DRS makes raw ratio waves named e.g. Raw192_194. This code parses the names and strips off the "Raw" to get the ratio, and later adds DScorr at the front. 
	//If user has a different format, may end up with odd names. Only major problem will be if their channel name includes no non-A-Z characters, then we'd end up with a null string.  Adding a fix for that at least.
	String/G ratnam1, ratnam2, ratnam3 //gets names of ratios to use in new channel names below
	sscanf MixedRatio[0], "%*[A-Za-z]%s", ratnam1
	sscanf MixedRatio[1], "%*[A-Za-z]%s", ratnam2
	sscanf MixedRatio[2], "%*[A-Za-z]%s", ratnam3	
	
	if(cmpstr(ratnam1,"")==0)	// if any ratios have an improper name, assume all will, and set names to defaults
		ratnam1 = "Ratio1"		// Thus, will end up with double spike corrected channels named DScorrRatio1 etc.
		ratnam2 = "Ratio2"
		ratnam3 = "Ratio3"
	endif

	//Make some waves to hold our results	//modified to make sure this has double precision
	SetDataFolder(ioliteDFpath("CurrentDRS",""))
	String r1 = "DScorr"+ratnam1, r2 = "DScorr"+ratnam2, r3 = "DScorr"+ratnam3
	Make /D/O/N=(NoOfPoints) $r1, $r2, $r3
	Wave TrueRatio1 = $IoliteDFpath("CurrentDRS","DScorr" + ratnam1) // Now we can refer to them using an objective name, but the results waves will be named for the ratios, e.g. DScorr196_194
	Wave TrueRatio2 = $IoliteDFpath("CurrentDRS","DScorr" + ratnam2) 
	Wave TrueRatio3 = $IoliteDFpath("CurrentDRS","DScorr" + ratnam3)	
	SetDataFolder(ioliteDFpath("Addons",""))
		
	Wave alphawave = $MakeIoliteWave("CurrentDRS","alphawave",n=NoOfPoints)	
	Wave betawave = $MakeIoliteWave("CurrentDRS","betawave",n=NoOfPoints)	
	Wave lambdawave = $MakeIoliteWave("CurrentDRS","lambdawave",n=NoOfPoints)	
	
	Wave DeltaRatio1 = $MakeIoliteWave("CurrentDRS","Delta" + ratnam1,n=NoOfPoints)	
	Wave DeltaRatio2 = $MakeIoliteWave("CurrentDRS","Delta" + ratnam2,n=NoOfPoints)	
	Wave DeltaRatio3 = $MakeIoliteWave("CurrentDRS","Delta" + ratnam3,n=NoOfPoints)	

	variable rootfinder_problem = 0	//flag to set if rootfinder reports any issues
	Wave rootfinder_debug = $MakeIoliteWave("Addons","rootfinder_debug",n=NoOfPoints) //debug wave so we can find where rootfinder issues happen if necessary

	//Now do the double spike inversion

	Variable i = 0, time1, time2, calcrate, invcounter = 0
	if(Q!=1) //dont print if quiet mode selected. Otherwise do.	
		Print time() + ": started DS inversion"
	endif
	

	///extra stuff for doing anomaly corrections
	setdatafolder $ioliteDFpath("DRSGlobals","")	
	NVar/Z doAnomaly
	SetDataFolder(ioliteDFpath("Addons",""))

	if(doAnomaly==1)	//check if we are doing an anomaly correction
		Make /D/O/N=(NoOfPoints) std_ratio1, std_ratio2, std_ratio3
	
		if(std_ratio1[0]==0||std_ratio1[1]==NaN)//if not already set, get values from DS settings (already fetched above); otherwise, leave them alone
			std_ratio1=UnmixedRatio[0]
			std_ratio2=UnmixedRatio[1]
			std_ratio3=UnmixedRatio[2]
		endif
		if(setStandardForAnomalies()==1)
			N_wave1=std_ratio1
			N_wave2=std_ratio2
			N_wave3=std_ratio3
		endif
	endif
	
	
	////extra stuff for manually entering unspiked ratios
	setdatafolder $ioliteDFpath("DRSGlobals","")	
	NVar/Z enterUnspiked
	SetDataFolder(ioliteDFpath("Addons",""))

	if(enterUnspiked==1)	//check if we are entering unspiked compositions
		Make /D/O/N=(NoOfPoints) unspikedWave1,unspikedWave2,unspikedWave3
	
		if(unspikedWave1[0]==0||unspikedWave1[1]==NaN)//if not already set, get values from DS settings (already fetched above); otherwise, leave them alone -- this will also mean that the standard value is used for any sample without input unspiked compositions
			unspikedWave1[]=UnmixedRatio[0]
			unspikedWave2[]=UnmixedRatio[1]
			unspikedWave3[]=UnmixedRatio[2]
		endif
		if(setUnspikedCompositions()==1)
			N_wave1=unspikedWave1
			N_wave2=unspikedWave2
			N_wave3=unspikedWave3
		endif
	endif
	
	
	time1 = datetime
	For(i=0;i<dimsize(MixedRatio1,0);i+=1) 
		if(cmpstr(num2str(MixedRatio1[i]),"NaN"))  //only bother where the wave has a value
			coefs1[3] = MixedRatio1[i]  //mixed (M) values (i.e. spiked result)
			coefs2[3] = MixedRatio2[i]
			coefs3[3] = MixedRatio3[i]

			coefs1[1] = N_wave1[i]	//unmixed (N) values (previously set equal to a measured wave (interpolated onto a spline) or to a constant value)
			coefs2[1] = N_wave2[i]
			coefs3[1] = N_wave3[i]

			//HERE is the part where it determines the roots of the non-linear equation
//			FindRoots /Q dsF1, coefs1,dsF1, coefs2,dsF1, coefs3		//original
			FindRoots /X={0.1, -0.04, 0.6} /Q dsF1, coefs1,dsF1, coefs2,dsF1, coefs3	//trying giving starting points for lambda, alpha and beta
			if(V_Flag!=0)
				rootfinder_problem=1
				rootfinder_debug[i]=1
			endif
			
			Wave W_Root		//This wave contains the results, where W_Root[0] is lambda, W_Root[1] is alpha, and W_Root[2] is beta. 
			
			TrueRatio1[i] = coefs1[1]*EXP(-1*W_Root[1]*coefs1[2])		//This is the equation N=n*exp(-1*alpha*P)
			TrueRatio2[i] = coefs2[1]*EXP(-1*W_Root[1]*coefs2[2])		//This is the equation N=n*exp(-1*alpha*P)
			TrueRatio3[i] = coefs3[1]*EXP(-1*W_Root[1]*coefs3[2])		//This is the equation N=n*exp(-1*alpha*P)	
				
			lambdawave[i] = W_Root[0] //store the solutions at each point. Can use to correct additional isotope ratios.
			alphawave[i] = W_Root[1]
			betawave[i] = W_Root[2]

			DeltaRatio1[i] = ((TrueRatio1[i]/coefs1[1])-1)*1000		//This is the delta equation, delta = (R_sample/R_std - 1) * 1000
			DeltaRatio2[i] = ((TrueRatio2[i]/coefs2[1])-1)*1000		//What value to use if using a measured value for the standard? Should be calculating deltas relative to fixed value (because measured value is fractionated)?
			DeltaRatio3[i] = ((TrueRatio3[i]/coefs3[1])-1)*1000		//Maybe should just not calculate any deltas here, leave it for the DRS? Need to decide on this.

			invcounter+=1
		EndIf
	endfor
	
	if(rootfinder_problem!=0)
		print "Warning: root finder reported some issues, which probably means it wasn't able to find a root at some point. Email john@isospike.org if you need help."
//		Abort  "Warning: root finder reported some issues, which probably means it wasn't able to find a root and your DS correction failed. \nEmail john@isospike.org for help."
	endif
	
	time2 = datetime
	calcrate = invcounter/(time2-time1)
	if(Q!=1) //dont print if quiet mode selected. Otherwise do.
		Print time() + ": completed DS inversion  (" + num2str(calcrate) + " inversions/second)" 
	endif

//	//This relies on the user having a mask in their DRS, but is a much more elegant way of doing this than I was doing before.
	Wave/Z mask = $ioliteDFpath("CurrentDRS","mask")
	If(WaveExists(mask))
		TrueRatio1*=mask
		TrueRatio2*=mask
		TrueRatio3*=mask
		lambdawave*=mask
		alphawave*=mask
		betawave*=mask
	endif	
	
	ListOfOutputChannels+="DScorr" + ratnam1 +";DScorr" + ratnam2 +";DScorr" + ratnam3 + ";"
	ListOfOutputChannels+="Delta" + ratnam1 +";Delta" + ratnam2 +";Delta" + ratnam3+ ";"
	ListOfOutputChannels+="alphawave;betawave;lambdawave;"
	
	RecalculateIntegrations("*","*")
	SetDataFolder saveDFR
	if(Q!=1) //dont print if quiet mode selected. Otherwise do.
		Print "Created alpha, beta and lambda waves in current DRS folder - can use to correct other ratios" 
	endif
End

Function dsF1(w,x,y,z)	//The function that describes the non-linear equations. The same function is used for all ratios
	Wave w	//This is the coefficient wave. See DSp_Solve() for what each value represents
	Variable x, y, z	//x is lamda, y is alpha and z is beta
	
	Return x*w[0] + (1-x)*w[1]*exp(-1*y*w[2]) - w[3]*exp(-1*z*w[2])
End

Function DoubleSpikeButtonHandler(ButtonStructure) : ButtonControl //generic button control, rather than writing one for each button.  Is called each time a button is pressed...
	STRUCT WMButtonAction&ButtonStructure // WMButtonAction is an externally-defined structure type, and ButtonStructure is not a string or a variable (etc) but a structure of  WMButtonAction type(and could be called anything)
	if( ButtonStructure.eventCode != 2 ) // ".eventcode" is one part of the WMButtonAction structure, in this case tells what caused this function to be called, ==2 would mean mouse was clicked, so if not ==2 then
		return 0  // we only want to handle mouse up (i.e. a released click - for now that is), so exit if this wasn't what caused it
	endif  //otherwise, respond to the button click
	
	setdatafolder $ioliteDFpath("DRSGlobals","")	
	NVar/Z CalibratingFlag 	// a global variable set in the DRS about whether we're calibrating or not. If not, don't bother showing this panel
	NVar gotSettingsFlag
	
	String ButtonHostWindow=ButtonStructure.win, NameOfButton=ButtonStructure.ctrlName //get the button Host window and button names from the structure
	variable EventCode = ButtonStructure.EventCode
	strswitch(ButtonHostWindow)	// string switch on host window name
		case "DSPanel" :	// Double Spike addon settings panel
			strswitch(NameOfButton)	
				case "DS_Save" :	// User is trying to save settings
					DSp_SaveSettings()		//Function for saving settings
					return 0 
				case "DS_Close_Procede" :	// User wants to continue and solve double spike equations
					DSp_Solve()
					return 0 
			endswitch // etc
		case "DSOptions" :	// Double Spike addon settings panel
			strswitch(NameOfButton)	
				case "DS_Cancel" :	// Use clicks cancel
					killwindow DSOptions
					abort
				case "DS_UseCurrentDSsettings" :
						DSp_LoadSettings(1)
						gotSettingsFlag = 1
						killwindow DSOptions
						return 0
				case "DS_LoadDSsettings" :
						DSp_LoadSettings(2) 
						gotSettingsFlag = 1
						killwindow DSOptions
						return 0
				case "DS_EnterDSsettings" :
						killwindow DSOptions	// have to do this first in this case to make sure it doesn't get in the way
						DSp_PromptUser()
						CalibratingFlag = 1
						gotSettingsFlag = 1
						return 0		
			endswitch // etc
	endswitch //end of host window string switch.  Will only have got this far if a there is a window with buttons which isn't listed here
	return 0 //return 0 if we got that far, as that is what Igor expects
End

Function setUnspikedCompositions() // procedure for taking manually input unspiked compositions and applying them over the time of an analysis
	Wave TotalBeam_Time = $IoliteDFpath("input","TotalBeam_Time") //reference the time wave
	Wave /T/Z MetadataWave_3D=$IoliteDFpath("metadata","MetadataWave_3D")	//reference the iolite metadata wave, which is where we get start and end times for each analysis
	if(!WaveExists(MetadataWave_3D)) 	//abort if we don't find it because we can't proceed without it
		printabort("no metadata wave")
	endif

	SVAR ListOfIntermediateChannels=$ioliteDFpath("Output","ListOfIntermediateChannels") //reference list of output channels so we can add some things later

	//reference WAVES TO HOLD VALUES TO USE FOR DS
	Wave unspikedWave1 = $IoliteDFpath("Addons","unspikedWave1")
	Wave unspikedWave2 = $IoliteDFpath("Addons","unspikedWave2")
	Wave unspikedWave3 = $IoliteDFpath("Addons","unspikedWave3")
	
	//make WAVES TO HOLD INPUT UNSPIKED COMPOSITIONS
	Wave ratio1unspiked = $MakeIoliteWave("Addons","ratio1unspiked")
	Wave ratio2unspiked = $MakeIoliteWave("Addons","ratio2unspiked")
	Wave ratio3unspiked = $MakeIoliteWave("Addons","ratio3unspiked")

	if(ratio1unspiked[0]==0||ratio1unspiked[1]==NaN)	//if we've just created them, populate with default standard composition from DS settings
		Wave UnmixedRatio = $IoliteDFpath("Addons","UnmixedRatio")	
		ratio1unspiked[]=UnmixedRatio[0]
		ratio2unspiked[]=UnmixedRatio[1]
		ratio3unspiked[]=UnmixedRatio[2]
	endif

	// get the list of integrations (analyses)
	SVAR ListOfIntegrations = $IoliteDFpath("integration","ListOfIntegrations"), ReferenceStandard = $ioliteDFpath("DRSGlobals","ReferenceStandard")
	variable x = WhichListItem(" ",ListOfIntegrations,";"), y = WhichListItem(" ",ListOfIntegrations,";",x+1) //find the positions of the spaces in this list to get the list of outputs we've made
	Wave/t int_names = $MakeIoliteWave("Addons","int_names", Type="t")
	Wave/t int_types = $MakeIoliteWave("Addons","int_types", Type="t")
	Wave startTime = $MakeIoliteWave("Addons","startTime")
	Wave endTime = $MakeIoliteWave("Addons","endTime")

	string temp = "", temp_t = "", temp_m = ""
	variable j

	variable ID_out_Index = 0
	for(j=x+1;j<y+1;j+=1)	//going to y+1, but using the extra cycle to grab the values for the reference standard
		temp = stringfromlist(j,ListOfIntegrations,";")
		if(cmpstr(temp,"")!=0)
			if(j==y)						//if we're in the last cycle
				temp = ReferenceStandard	//get reference standard integrations
			endif
			temp_t = "t_" + temp
			temp_m = "m_" + temp
			
			Wave OutputMatrix=$IoliteDFpath("integration",temp_m)//int_m)	//Now we'll reference the results matrix for Output_1
			Wave/T Output_tMatrix=$IoliteDFpath("integration",temp_t)//int_t)	//Now we'll reference the text matrix for Output_1 so we can get integration names

			Variable ThisInteg = 1		//This is a counter that goes through the integrations in the Output_1 matrix
			
			for(ThisInteg=1;ThisInteg<dimsize(OutputMatrix,0);ThisInteg+=1)	//Go through all integrations in the output matrix and pull out integration names and groups
				int_names[ID_out_Index] = Output_tMatrix[ThisInteg][0][1]
				int_types[ID_out_Index] = temp_m
				If(ThisInteg!=1)		//If this is the first integration, we've already got a blank line to put the results into, otherwise
					InsertPoints dimsize(int_names,0), 1, int_names	
					InsertPoints dimsize(int_types,0), 1, int_types	
				Endif
				ID_out_Index += 1
			Endfor		//This will move to the next set of results i.e. the next sample	
		endif
	endfor
	Redimension/N=(ID_out_Index,0) int_names, int_types, startTime, endtime,ratio1unspiked,ratio2unspiked,ratio3unspiked
	
	variable p,q
	for(q=0;q<dimsize(int_names,0);q+=1)
		for(p=0;p<dimsize(MetadataWave_3D,0);p+=1)
			if(cmpstr(int_names[q],MetadataWave_3D[p][6][1])==0)
				startTime[q]=str2num(MetadataWave_3D[p][0][1])
				endTime[q]=str2num(MetadataWave_3D[p][3][1])
//				startTime_T[q]=secs2date(startTime[q],-2,"/") + " " + secs2time(startTime[q],3)		//obsolete: get startTime and endTime as a date and time (text) instead of decimal
//				endTime_T[q]=secs2date(endTime[q],-2,"/") + " " + secs2time(endTime[q],3)			//leaving it here just in case I want it again
			endif
		endfor
	endfor
	
//modify wave of standard composition to unspiked values
	Wave UnmixedRatio = $IoliteDFpath("Addons","UnmixedRatio")	//reference wave that holds DS_settings data. We assume that this exists already since that part of the execution happens first

	DoWindow/F unspikedPanel	//kill the panel if it already exists
	if(V_Flag==1)	
		killwindow unspikedPanel 
	endif 
	
	NewPanel /W=(150,50,720,650)/K=1/N=unspikedPanel as "Unspiked compositions"	//Make the panel to input anomalies
	Edit /W=(10,15,550,565)/HOST=unspikedPanel int_types,int_names, ratio1unspiked,ratio2unspiked,ratio3unspiked//, startTime_T, endTime_T //stdratio1,stdratio2,stdratio3,
	ModifyTable/Z width[2]=110, sigDigits[3]=8,sigDigits[4]=8,sigDigits[5]=8
	Button unsp_Go,win=unspikedPanel,pos={470,570},size={80,20},title="Continue",proc=anomButtons, help={"Continue IsoSpike execution"}		
	Button unsp_reset,win=unspikedPanel,pos={380,570},size={80,20},title="Reset",proc=anomButtons, help={"Reset all to zero"}		
	DrawText 11,590,"Input unspiked ratios"
	PauseForUser unspikedPanel
	
	variable r,s,buffer=100
	for(s=0;s<dimsize(startTime,0);s+=1)
		for(r=0;r<numpnts(TotalBeam_Time);r+=1)
			if(TotalBeam_Time[r]>=startTime[s]-buffer&&TotalBeam_Time[r]<=endTime[s]+buffer)		//buffer is a hack because it was missing some integrations each end (?). None of the analyses are very close together so it's not a problem. 
				// s it outer loop, r is inner. for every row in N_wave, we should end up with the unspiked ratio for the current analysis
				unspikedWave1[r]=ratio1unspiked[s]
				unspikedWave2[r]=ratio2unspiked[s]
				unspikedWave3[r]=ratio3unspiked[s]
			endif
		endfor
	endfor

	print "Used manually input unspiked compositions"
	return(1)	//returns 1 if succesfully completed, which throws us back to DSp_Solve()
end


Function setStandardForAnomalies()
	Wave TotalBeam_Time = $IoliteDFpath("input","TotalBeam_Time") //reference the time wave
	Wave /T/Z MetadataWave_3D=$IoliteDFpath("metadata","MetadataWave_3D")	//reference the iolite metadata wave, which is where we get start and end times for each analysis
	if(!WaveExists(MetadataWave_3D)) 	//abort if we don't find it because we can't proceed without it
		printabort("no metadata wave")
	endif

	SVAR ListOfIntermediateChannels=$ioliteDFpath("Output","ListOfIntermediateChannels") //reference list of output channels so we can add some things later

	//reference WAVES TO HOLD VALUES TO USE FOR DS
	Wave std_ratio1 = $IoliteDFpath("Addons","std_ratio1")
	Wave std_ratio2 = $IoliteDFpath("Addons","std_ratio2")
	Wave std_ratio3 = $IoliteDFpath("Addons","std_ratio3")
	
	//MAKE WAVES TO HOLD INPUT ANOMALIES
	Wave ratio1anomaly = $MakeIoliteWave("Addons","ratio1anomaly")
	Wave ratio2anomaly = $MakeIoliteWave("Addons","ratio2anomaly")
	Wave ratio3anomaly = $MakeIoliteWave("Addons","ratio3anomaly")

	// this goes through each integration type and gets the mixed198/194 ratios
	SVAR ListOfIntegrations = $IoliteDFpath("integration","ListOfIntegrations"), ReferenceStandard = $ioliteDFpath("DRSGlobals","ReferenceStandard")
	variable x = WhichListItem(" ",ListOfIntegrations,";"), y = WhichListItem(" ",ListOfIntegrations,";",x+1) //find the positions of the spaces in this list to get the list of outputs we've made

	Wave/t int_names = $MakeIoliteWave("Addons","int_names", Type="t")
	Wave/t int_types = $MakeIoliteWave("Addons","int_types", Type="t")
	Wave startTime = $MakeIoliteWave("Addons","startTime")
	Wave endTime = $MakeIoliteWave("Addons","endTime")

	string temp = "", temp_t = "", temp_m = ""
	variable j

	variable ID_out_Index = 0
	for(j=x+1;j<y+1;j+=1)	//going to y+1, but using the extra cycle to grab the values for the reference standard
		temp = stringfromlist(j,ListOfIntegrations,";")
		if(cmpstr(temp,"")!=0)
			if(j==y)						//if we're in the last cycle
				temp = ReferenceStandard	//get reference standard integrations
			endif
			temp_t = "t_" + temp
			temp_m = "m_" + temp
			
			Wave OutputMatrix=$IoliteDFpath("integration",temp_m)//int_m)	//Now we'll reference the results matrix for Output_1
			Wave/T Output_tMatrix=$IoliteDFpath("integration",temp_t)//int_t)	//Now we'll reference the text matrix for Output_1 so we can get integration names

			Variable ThisInteg = 1		//This is a counter that goes through the integrations in the Output_1 matrix, extracting the values for the unmixed ratios and mixed ratios 
			
			for(ThisInteg=1;ThisInteg<dimsize(OutputMatrix,0);ThisInteg+=1)	//Go through all integrations in the output matrix and pull out integration names and groups
				int_names[ID_out_Index] = Output_tMatrix[ThisInteg][0][1]
				int_types[ID_out_Index] = temp_m
				If(ThisInteg!=1)		//If this is the first integration, we've already got a blank line to put the results into, otherwise
					InsertPoints dimsize(int_names,0), 1, int_names	
					InsertPoints dimsize(int_types,0), 1, int_types	
				Endif
				ID_out_Index += 1
			Endfor		//This will move to the next set of results i.e. the next sample	
		endif
	endfor
	Redimension/N=(ID_out_Index,0) int_names, int_types, startTime, endtime,ratio1anomaly,ratio2anomaly,ratio3anomaly
	
	variable p,q
	for(q=0;q<dimsize(int_names,0);q+=1)
		for(p=0;p<dimsize(MetadataWave_3D,0);p+=1)
			if(cmpstr(int_names[q],MetadataWave_3D[p][6][1])==0)
				startTime[q]=str2num(MetadataWave_3D[p][0][1])
				endTime[q]=str2num(MetadataWave_3D[p][3][1])
			endif
		endfor
	endfor
	
	//get standard values from DS_settings as the starting point to modify for anomaly correction. note: this assumes that we are modifying a standard composition, not a measured composition
	Wave UnmixedRatio = $IoliteDFpath("Addons","UnmixedRatio")	//reference wave that holds DS_settings data. We assume that this exists already since that part of the execution happens first
	variable srat1 = UnmixedRatio[0], srat2 = UnmixedRatio[1], srat3 = UnmixedRatio[2]

	DoWindow/F anomalyPanel	//kill the panel if it already exists
	if(V_Flag==1)	
		killwindow anomalyPanel 
	endif 
	
	NewPanel /W=(150,50,720,650)/K=1/N=anomalyPanel as "Input anomalies"	//Make the panel to input anomalies
	Edit /W=(10,15,550,565)/HOST=anomalyPanel int_types,int_names, ratio1anomaly,ratio2anomaly,ratio3anomaly//, startTime_T, endTime_T //stdratio1,stdratio2,stdratio3,
	ModifyTable/Z width[2]=110
	Button anom_Go,win=anomalyPanel,pos={470,570},size={80,20},title="Continue",proc=anomButtons, help={"Continue IsoSpike execution"}		
	Button anom_reset,win=anomalyPanel,pos={380,570},size={80,20},title="Reset",proc=anomButtons, help={"Reset all anomalies to zero"}		
	DrawText 11,590,"Input anomalies in epsilon units"
	PauseForUser anomalyPanel
	
	variable r,s,buffer=100
	for(s=0;s<dimsize(startTime,0);s+=1)
		for(r=0;r<numpnts(TotalBeam_Time);r+=1)
			if(TotalBeam_Time[r]>=startTime[s]-buffer&&TotalBeam_Time[r]<=endTime[s]+buffer)		//buffer is a hack because it was missing some integrations each end (?). None of the analyses are very close together so it's not a problem. 
				std_ratio1[r]=((ratio1anomaly[s]/10000)+1)*srat1
				std_ratio2[r]=((ratio2anomaly[s]/10000)+1)*srat2
				std_ratio3[r]=((ratio3anomaly[s]/10000)+1)*srat3
			endif
		endfor
	endfor

	print "Corrected for anomalies"
	return(1)	//returns 1 if succesfully completed, which throws us back to DSp_Solve()
end

function anomButtons(ctrlName) : ButtonControl // now using for unspiked panel as well as anomalies
	String ctrlName
	if(cmpstr(ctrlname,"anom_Go")==0)	// user clicks 'go', close the window (which is paused for user)
		DoWindow/F anomalyPanel	//kill the ID panel, if it exists
		if(V_Flag==1)	
			killwindow anomalyPanel
		endif 
	endif
	if(cmpstr(ctrlname,"unsp_Go")==0)	// user clicks 'go', close the window (which is paused for user)
		DoWindow/F unspikedPanel	//kill the ID panel, if it exists
		if(V_Flag==1)	
			killwindow unspikedPanel
		endif 
	endif

	if(cmpstr(ctrlname,"anom_reset")==0)	//reset all anomalies to zero
		Wave ratio1anomaly = $IoliteDFpath("Addons","ratio1anomaly")
		Wave ratio2anomaly = $IoliteDFpath("Addons","ratio2anomaly")
		Wave ratio3anomaly = $IoliteDFpath("Addons","ratio3anomaly")
		ratio1anomaly[]=0
		ratio2anomaly[]=0
		ratio3anomaly[]=0
	endif
	
	if(cmpstr(ctrlname,"unsp_reset")==0)	//reset all anomalies to zero
		Wave ratio1unspiked = $IoliteDFpath("Addons","ratio1unspiked")
		Wave ratio2unspiked = $IoliteDFpath("Addons","ratio2unspiked")
		Wave ratio3unspiked = $IoliteDFpath("Addons","ratio3unspiked")
		Wave UnmixedRatio = $IoliteDFpath("Addons","UnmixedRatio")	
		ratio1unspiked[]=UnmixedRatio[0]
		ratio2unspiked[]=UnmixedRatio[1]
		ratio3unspiked[]=UnmixedRatio[2]
	endif
end