## IsoSpike -- double-spike data reduction
    Copyright (C) 2020  John Creech

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

### What is IsoSpike
IsoSpike is free open-source software for double-spike data reduction. It was built as an addon for Iolite, and has been re-written in Python for Iolite4. The new Python code also includes some standalone code that can do DS correction from the command line, with a single analysis or a set of data files, which could be incorporated into a homebrew data reduction setup.

### Credit
If you use this software in your research, please cite the following paper in your publications:
Creech and Paul, 2013, Geostandards and Geoanalytical Research *39*, 7-15. doi:10.1111/j.1751-908X.2014.00276.x

### Installation and requirements
To use IsoSpike in Iolite4, *IsoSpike_iolite4.py* must be copied to a folder in the Iolite app folder called Addons —— for now, you will have to create it, but in future versions of Iolite the folder will exist by default. You will also need to add the addons folder to the Python Site Packages in the Paths section of Iolite's preferences. 

On a Mac, you can copy and paste the following into *Python Site Packages*: 
`;/Applications/iolite4.app/Contents/Resources/Addons;`

Note: there must be a semicolon between entries.

For convenience, in the IsoSpike_Iolite4 folder, there are two easy options for placing the files on a Mac.
  1. open terminal to the folder with the downloaded files and run `./IsoSpike_install_mac.sh
  2. open the IsoSpike.dmg, and simply drag and drop the files to the respective folders
  
When I get a chance to test on a Windows machine, I will provide more detailed instructions, but so long as you have the *IsoSpike_iolite4.py* file in a suitable folder, and reference that folder in Iolite's paths, it will work.

### Files in this repo
The only file required for IsoSpike to run in Iolite4 is *IsoSpike_iolite4.py* (to be copied to the Addons folder as described above). The repo also contains an example DRS from Pt isotopes called *Pt_DS.py*. That file gives an example of how you might prepare your data for IsoSpike, including setting up the double-spike parameters. You can use Iolite4's built in python editor, or any other editor you choose.

There are also a separate set of files that could be incorporated into an external data processing regime (without the benefits of Iolite's visualisation, etc.). Those are `dsPy_cmd.py` which would simply take three ratios as arguments from the command line and output the DS corrected results, and `dsPy_fin2.py`, which can take any number of FIN2 files as arguments, and will output a CSV file of the same name that includes columns with the DS results (i.e., alpha, beta, lambda, double-spike corrected ratios and deltas). Note: *both of these include DS parameters in the code, and you will need to update these to suit you purpose*.

### Using IsoSpike
An easy way to get started is to look at the *Pt_DS* example. IsoSpike itself is called in a single line of code in the DRS. 
  `IsoSpike_results=IsoSpike(DSsettings,Raw195_194,Raw196_194,Raw198_194)`
It takes four inputs, described below, and returns an array of results (here called IsoSpike_results).

The inputs for IsoSpike are the three raw ratios (calculated in DRS from Iolite data), and DSsettings, which is a numpy array containing the double-spike parameters. From the Pd_DS example DRS, the parameters are declared as follows:

```
rationames=['Pt195/Pt194','Pt196/Pt194','Pt198/Pt194']  ## This is used to generate channel names later in the DRS  
unmixedRatios=[1.0303605,0.7717145,0.2232910]
spikeRatios=[1.838948,19.31747,38.37810]
logMassRatios=[0.005153188,0.010270037,0.020439027]
DSsettings=np.array([unmixedRatios,spikeRatios,logMassRatios])
```

The `IsoSpike_results` array can then be referenced in the DRS and used in Iolite in the same way as any channel, and viewed in the Time Series or Results windows.

### Problems?
You could try emailing me at john@isospike.org

It would also possible to control these from the DRS settings widget (which I may set up in the future). 
