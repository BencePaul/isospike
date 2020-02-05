#!/bin/bash
cd pwd
echo "---Installing IsoSpike for iolite4---"
FAIL=0;
cp -v Addons/IsoSpike_iolite4.py /Applications/iolite4.app/Contents/Resources/Addons/ || FAIL=1

if [[ $FAIL -eq 1 ]]; then
	echo "Install failed; couldn't find Iolite4"
	exit;
else
	while true; do
		read -p "-Also install demo DRS (Pt isotopes)? (y/n): " yn
		case $yn in
			[Yy]* ) cp -v DRS/Pt_DS.py /Applications/iolite4.app/Contents/Resources/DRS/; break;; #not doing error checking here; if IsoSpike worked, this should too
			[Nn]* ) break;;
			* ) echo "-Please answer y or n.";;
		esac
	done
fi

echo "---Success. Relaunch Iolite to get started.---"