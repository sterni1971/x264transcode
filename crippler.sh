#!/bin/bash

############################################################################
#    DVD/CD Transcoding set of scripts (x264transcode)                     #
#    Copyright (C) 2008-2009 by Jaroslaw Zachwieja <grok@zyxxyz.eu>        #
#                                                                          #
#    This program is free software; you can redistribute it and/or modify  #
#    it under the terms of the GNU General Public License as published by  #
#    the Free Software Foundation; either version 3 of the License, or     #
#    (at your option) any later version.                                   #
#                                                                          #
#    This program is distributed in the hope that it will be useful,       #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#    GNU General Public License for more details.                          #
#                                                                          #
#    You should have received a copy of the GNU General Public License     #
#    along with this program.  If not, see <http://www.gnu.org/licenses/>. #
############################################################################

DEFAULT_CD_RIPPING_DEVICE="/dev/sr1"
DEFAULT_MUSIC_FINAL_DESTINATION="/music"

if (test -s ./autoripper.conf)
then
	. ./autoripper.conf
	echo "Found config file './autoripper.conf', loading."
elif (test -s ~/.autoripper.conf)
then
	. ~/.autoripper.conf
	echo "Found config file '~/.autoripper.conf', loading."
elif (test -s /etc/autoripper.conf)
then
	. /etc/autoripper.conf
	echo "Found config file '/etc/autoripper.conf', loading."
else
	echo "No config file found, using defaults."
fi

if (test -z "$CD_RIPPING_DEVICE")
then
	CD_RIPPING_DEVICE="$DEFAULT_CD_RIPPING_DEVICE"
fi

if (test -z $MUSIC_FINAL_DESTINATION)
then
	MUSIC_FINAL_DESTINATION=$DEFAULT_MUSIC_FINAL_DESTINATION
fi

ARTIST="`cripple --device ${CD_RIPPING_DEVICE} -q 2>&1|grep artist:|cut -d ':' -f 2-|sed -e 's/\ //g'`"
ALBUM="`cripple --device ${CD_RIPPING_DEVICE} -q 2>&1|grep album:|cut -d ':' -f 2-|sed -e 's/\ //g'`"

if [ -d "${TARGET}/${ARTIST}/${ALBUM}" ]
then
        echo "${ARTIST}/${ALBUM} already ripped. aborting."
        eject ${CD_DEVICE}
        sleep 10
else
        echo "Ripping ${ARTIST}/${ALBUM}."
        mkdir -p "${MUSIC_FINAL_DESTINATION}/${ARTIST}/${ALBUM}"
        nice -n 10 cripple --device ${CD_RIPPING_DEVICE} --eject --fat -c clever --encoder-opts '--preset extreme' -p "${MUSIC_FINAL_DESTINATION}/${ARTIST}/${ALBUM}" 2>&1 >/dev/tty9
        eject ${CD_DEVICE}
        sleep 10
fi
