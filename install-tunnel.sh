#!/bin/sh

cd "`dirname \"$0\"`"

if [ "x${MATHEMATICA_BASE}x" = "xx" ]
then
	if [ -d /Library/Mathematica ]
	then
		# OS X
		MATHEMATICA_BASE=/Library/Mathematica
	else
		# Linux
		MATHEMATICA_BASE=/usr/share/Mathematica
	fi
fi

if [ "x${MATHEMATICA_USERBASE}x" = "xx" ]
then
	if [ -d "$HOME/Library/Mathematica" ]
	then
		# OS X
		MATHEMATICA_USERBASE="$HOME/Library/Mathematica"
	else
		# Linux
		MATHEMATICA_USERBASE="$HOME/.Mathematica"
	fi
fi

# install kernel init file
mkdir -v -p "${MATHEMATICA_BASE}/Kernel"
cp -f -v scripts/tunnel.m "${MATHEMATICA_BASE}/Kernel"

# install shell script helpers
mkdir -v -p "${MATHEMATICA_USERBASE}/FrontEnd"
cp -f -v scripts/tunnel.sh "${MATHEMATICA_USERBASE}/FrontEnd"
chmod +x "${MATHEMATICA_USERBASE}/FrontEnd/tunnel.sh"
cp -f -v scripts/tunnel_sub.sh "${MATHEMATICA_USERBASE}/FrontEnd"
chmod +x "${MATHEMATICA_USERBASE}/FrontEnd/tunnel_sub.sh"
