#!/bin/bash

############################################################################
#    DVD Transcoding set of scripts (x264transcode)                        #
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

DEFAULT_ISO_STORAGE="/dvdrips"
DEFAULT_DVD_RIPPING_DEVICE="/dev/sr0"

if (test -s ~/.autoripper.conf)
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

if (test -z "$ISO_STORAGE")
then
	ISO_STORAGE="$DEFAULT_ISO_STORAGE"
fi

if (test -z "$DVD_RIPPING_DEVICE")
then
	DVD_RIPPING_DEVICE=$DEFAULT_DVD_RIPPING_DEVICE
fi

# Unlock the drive if we're ripping from a disk instead of an image
# ... and fetch the DISC_ID
DISC_ID="`mplayer dvd:// -dvd-device ${DVD_RIPPING_DEVICE} -ss 1 -endpos 1 -identify -really-quiet -vo null -ao null | grep ID_DVD_DISC_ID | sed 's#ID_DVD_DISC_ID=##' | sed 's# ##g'`"

TITLE="`lsdvd ${DVD_RIPPING_DEVICE} | grep 'Disc Title:' | cut -d ' ' -f 3`"
if [ "$TITLE" == "unknown" ] || [ "$TITLE" == "UNKNOWN" ] || [ "$TITLE" == "Unknown" ]
then
    echo "Disc title unknown, using DISC_${DISC_ID}"
    TITLE="DISC_${DISC_ID}"
fi

echo "$TITLE"

if [ -a "${ISO_STORAGE}/${TITLE}.iso" ]
then
        TITLE=""
fi
if [ "$TITLE" != "" ]
then
        echo "Found DVD: $TITLE. Ripping..."
        ionice -c 3 nice -n 10 dd if=$DVD_RIPPING_DEVICE of=${ISO_STORAGE}/${TITLE}.iso.partial bs=2k  || rm -f ${ISO_STORAGE}/${TITLE}.iso.partial
        mv -f ${ISO_STORAGE}/${TITLE}.iso.partial ${ISO_STORAGE}/${TITLE}.iso
        echo "Ripping of $TITLE finished."
fi

sleep 5

# let's hope MacOS X can do this substitution
`which drutil 2>/dev/null` eject `which drutil >/dev/null 2>/dev/null|| echo ${DEV}`
