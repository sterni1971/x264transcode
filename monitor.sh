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

MONITOR_DIRECTORY="$ISO_STORAGE"

for ISO in ${MONITOR_DIRECTORY}/*.iso
do
        if [ "$ISO" != "" ]
        then
                echo "Invoking $TRANSCODE_COMMAND $ISO"
                ${TRANSCODE_COMMAND} ${ISO}
        else
                echo "Nothing to transcode in $MONITOR_DIRECTORY"
        fi
done
sleep 180