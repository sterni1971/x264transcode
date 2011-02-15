#!/bin/bash

###############################################################################
#   DVD Transcoding set of scripts (x264transcode)                            #
#   Copyright (C) 2008 - 2011 by Jaroslaw Zachwieja <grok@zyxxyz.eu>          #
#   Copyright (C) 2011 by Georg Sauthoff <gsauthof@techfak.uni-bielefeld.de>  #
#   Copyright (C) 2009 - 2010 by SevenOf29                                    #
#                                                                             #
#   macport maintainer:                                                       #
#   Stefan van der Eijk <stefan.van.der.eijk@gmail.com>                       #
#                                                                             #
#   This program is free software; you can redistribute it and/or modify      #
#   it under the terms of the GNU General Public License as published by      #
#   the Free Software Foundation; either version 3 of the License, or         #
#   (at your option) any later version.                                       #
#                                                                             #
#   This program is distributed in the hope that it will be useful,           #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of            #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             #
#   GNU General Public License for more details.                              #
#                                                                             #
#   You should have received a copy of the GNU General Public License         #
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.     #
###############################################################################

# Dependencies:
# 1) mplayer/mencoder that supports x264 encoding
# 2) mkvtoolnix (provides mkvmerge)
# 3) lsdvd
# 4) dvdxchap (part of ogmtools)
# 5) perl
# 6) crswallow (optional)

VERSION="0.2.9"

# These are defaults, edit autoripper.conf instead!
DEFAULT_TITLES="LONGEST"
DEFAULT_SHORTEST_FIRST="0"
DEFAULT_OUTPUT="/tmp/ISO"
DEFAULT_FINAL_DESTINATION="/done"
DEFAULT_UPSAMPLE="false" # 576p -> 720p
DEFAULT_DOWNSAMPLE="false" # 1080p -> 720p
DEFAULT_DEINT=""
DEFAULT_SAMPLE_POINTS="20"
DEFAULT_QUALITY="HIGH"
DEFAULT_FORCE_PULLUP="2"
DEFAULT_SOURCE_BASED_CRF="0"
DEFAULT_NOPROGRESS="0"
DEFAULT_CRSWALLOW_ARGS="5 -out-to-stderr"
DEFAULT_NO_B_PYRAMID="b_pyramid=strict"
DEFAULT_THREADS="auto"
DEFAULT_CRF="18"
DEFAULT_SPECIFY_PROFILE="1"
DEFAULT_MENCODER_SUBTITLE_QUIRK="-sid 4096"

# Load configuration
if (test -s /etc/autoripper.conf)
then
	. /etc/autoripper.conf && echo "Loaded /etc/autoripper.conf"
elif (test -s ~/.autoripper.conf)
then
	. ~/.autoripper.conf && echo "Loaded ~/.autoripper.conf"
else
	echo "No config file found, creating ~/.autoripper.conf"

# See, told you not to edit that stuff above, it'll get messy.

cat >~/.autoripper.conf <<EOF
DEFAULT_TITLES="LONGEST"
DEFAULT_SHORTEST_FIRST="0"
DEFAULT_OUTPUT="/tmp/ISO"
DEFAULT_FINAL_DESTINATION="/done"
DEFAULT_UPSAMPLE="false" # 576p -> 720p
DEFAULT_DOWNSAMPLE="false" # 1080p -> 720p
DEFAULT_DEINT=""
DEFAULT_SAMPLE_POINTS="20"
DEFAULT_QUALITY="HIGH"
DEFAULT_FORCE_PULLUP="2"
DEFAULT_SOURCE_BASED_CRF="0"
DEFAULT_NOPROGRESS="0"
DEFAULT_CRSWALLOW_ARGS="5 -out-to-stderr"
DEFAULT_NO_B_PYRAMID="b_pyramid=strict"
DEFAULT_THREADS="auto"
DEFAULT_CRF="18"
DEFAULT_SPECIFY_PROFILE="1"
DEFAULT_MENCODER_SUBTITLE_QUIRK="-sid 4096"
EOF
	. ~/.autoripper.conf && echo "Loaded ~/.autoripper.conf"
fi

if (test -z "$THREADS")
then
    THREADS="$DEFAULT_THREADS"
fi

if (test -z "$TITLES")
then
    TITLES="$DEFAULT_TITLES"
fi

if (test -z "$SHORTEST_FIRST")
then
    SHORTEST_FIRST=$DEFAULT_SHORTEST_FIRST
fi

if (test -z "$NO_B_PYRAMID")
then
    NO_B_PYRAMID=$DEFAULT_NO_B_PYRAMID
fi

if (test -z "$OUTPUT")
then
    OUTPUT="$DEFAULT_OUTPUT"
fi

if (test -z "$FINAL_DESTINATION")
then
    FINAL_DESTINATION="$DEFAULT_FINAL_DESTINATION"
fi

if (test -z "$NOPROGRESS")
then
    NOPROGRESS="$DEFAULT_NOPROGRESS"
fi

if (test -z "$CRSWALLOW_ARGS")
then
    CRSWALLOW_ARGS="$DEFAULT_CRSWALLOW_ARGS"
fi

if (test -z "$UPSAMPLE")
then
    UPSAMPLE="$DEFAULT_UPSAMPLE"
fi

if (test -z "$DOWNSAMPLE")
then
    DOWNSAMPLE="$DEFAULT_DOWNSAMPLE"
fi

if (test -z "$SAMPLE_POINTS")
then
    SAMPLE_POINTS="$DEFAULT_SAMPLE_POINTS"
fi

if (test -z "$FORCE_PULLUP")
then
    FORCE_PULLUP="$DEFAULT_FORCE_PULLUP"
fi

if (test -z "$QUALITY")
then
    QUALITY="$DEFAULT_QUALITY"
fi

if (test -z "$SOURCE_BASED_CRF")
then
    SOURCE_BASED_CRF="$DEFAULT_SOURCE_BASED_CRF"
fi

if (test -z "$CRF")
then
    CRF="$DEFAULT_CRF"
fi

MQUIET=""
if [ "$NOPROGRESS" == "1" ]
then
    MQUIET="-quiet"
fi

if (test -z "$DEINT")
then
    DEINT="$DEFAULT_DEINT"
fi

if (test -z "$SPECIFY_PROFILE")
then
    SPECPROF="$DEFAULT_SPECIFY_PROFILE"
fi

if (test -z "$MENCODER_SUBTITLE_QUIRK")
then
    MENCODER_SUBTITLE_QUIRK="$DEFAULT_MENCODER_SUBTITLE_QUIRK"
fi

if !(test -d "${OUTPUT}")
then
	echo "OUTPUT $OUTPUT does not exist or is not a directory"
	exit 1
fi

if !(test -d "${FINAL_DESTINATION}")
then
	echo "FINAL_DESTINATION $FINAL_DESTINATION does not exist or is not a directory"
	exit 1
fi


INPUT="$1"

if [ "$INPUT" == "" ] || [ "$INPUT" == "-h" ] || [ "$INPUT" == "--help" ]
then
        echo "Usage: $0 <iso image|directory|dvd device|vob file|m2ts file> [output name prefix]"
        echo "image or directory rip is much faster than device rip."
        exit 0
fi

RESUME_FILE="$FINAL_DESTINATION/resume.log"

if [ -f "$RESUME_FILE" ]
then
  RESUME=1
  NOCLEANUP=1
fi

#only used if MODE dvd and we guess we're reading from a device
DUMPSTREAM=0
#(dumping a single title works more often than dumping the full disk)
#(used to speed up processing of audio and subtitle stream)
#(but always use device for information gathering,
# as result of dumpstream doesn't contain language information)

MODE="dvd"
IS_DIRECTORY=`file --brief --dereference $1 | grep -c "^directory"`
if [ "IS_DIRECTORY" == "1" ]
then
    echo "processing directory $1 as DVD"
else
    IS_MPEG=`file --brief --dereference $1 | grep -c "^MPEG sequence"`
    if [ "$IS_MPEG" == "1" ]
    then
       echo "input $1 has MPEG header, processing as VOB"
       MODE="dumpfile"
    else
       IS_TS=`mplayer -ao null -vo null -identify -ss 1 -endpos 1 -really-quiet $1 2>/dev/null |grep -c ID_DEMUXER=mpegts`
       if [ "$IS_TS" == "1" ]
       then
           echo "input $1 played using mpegts demuxer, processing as TS"
           MODE="dumpfile"
       else
           echo "processing $1 as DVD"
           DUMPSTREAM=1
       fi
    fi
fi

if !(mencoder -ovc help | grep -i x264)
then
    echo "This version of mencoder does not support x264."
    echo "Try installing restricted mplayer packages and libraries for your distribution."
    exit 1
else
    echo "mencoder seems to have x264 support."
fi

if [ "$MODE" == "dvd" ]
then
    # Unlock the drive if we're ripping from a disk instead of an image
    # ... and fetch the DISC_ID
    DISC_ID="`mplayer dvd:// -dvd-device ${INPUT} -ss 1 -endpos 1 -identify -really-quiet -vo null -ao null | grep ID_DVD_DISC_ID | sed 's#ID_DVD_DISC_ID=##' | sed 's# ##g'`"
fi

if [ -n "$2" ]
then
    TITLE_PREFIX="$2"
else
    if [ "$MODE" == "dvd" ]
    then
        TITLE_PREFIX="`lsdvd ${INPUT} | grep 'Disc Title:' | cut -d ' ' -f 3`"
        if [ "$TITLE_PREFIX" == "unknown" ] || [ "$TITLE_PREFIX" == "UNKNOWN" ] || [ "$TITLE_PREFIX" == "Unknown" ]
        then
            echo "Disc title unknown, using DISC_${DISC_ID}"
            TITLE_PREFIX="DISC_${DISC_ID}"
        fi
    else #dumpfile
        TITLE_PREFIX="`basename $1`"
    fi
fi

if [ "$NOCLEANUP" != "1" ]
then
    # Clean up any aborted transcodes in temporary directory.
    if [ "$MODE" == "dvd" ]
    then
        rm -f "${OUTPUT}/${TITLE_PREFIX}"_??.*
    else
        rm -f "${OUTPUT}/${TITLE_PREFIX}".*
    fi
fi

HAVE_CRSWALLOW="`which crswallow|wc -l`"

# MacOS X compatibility section starts here
HAVE_IONICE="`which ionice|wc -l`"
if [ "$HAVE_IONICE" == "1" ]
then
	IONICE_COMMAND="ionice -c 3"
else
	IONICE_COMMAND=""
fi

if [ "`which seq | wc -l`" -eq "1" ]
then
        echo "Have 'seq' in the path."
else
function seq()
{
	# This REALLY needs some input sanitisation! FIXME TODO
        a=$1
        while [ $a -lt $3 ]
        do
           echo "$a"
           a=$[ $a + $2 ]
        done
}
fi
# MacOS X compatibility section ends here

if [ "$MODE" == "dvd" ]
then
    if [ "$TITLES" == "LONGEST" ]
    then
        ALL_TITLES="`lsdvd ${INPUT} | grep 'Length:' | sort -rk 4 |head -1 |cut -d ' ' -f 2|cut -d ',' -f 1`"
    elif [ "$TITLES" == "ALL" ]
    then
        SORT_R="-r"
        if [ "$SHORTEST_FIRST" == "1" ]; then SORT_R=""; fi
        ALL_TITLES=`lsdvd ${INPUT} | grep 'Length:' | grep -v 'Length: 00:00:' | sort ${SORT_R} -k 4 |cut -d ' ' -f 2|cut -d ',' -f 1`
    else
        ALL_TITLES="$TITLES"
    fi
    echo "Encoding $TITLE_PREFIX, Titles: $ALL_TITLES"
else #dumpfile
    ALL_TITLES="${TITLE_PREFIX}"
    echo "Encoding $1"
fi

if [ "$RESUME" = 1 ]
then
  echo "Resuming from previous run."
  . "$RESUME_FILE"
  rm -f ${FINAL_DESTINATION}/${TITLE}.mkv
fi

# Test for filename conflicts
for A_TITLE in $ALL_TITLES;
do
    if [ "$MODE" == "dvd" ]
    then
        TITLE=${TITLE_PREFIX}_${A_TITLE}
    else
        TITLE=${TITLE_PREFIX}
    fi

    if [ -a ${FINAL_DESTINATION}/${TITLE}.mkv ]
    then
        echo "destination file ${FINAL_DESTINATION}/${TITLE}.mkv already exists, exiting"
        exit 1
    fi
done

# Loop the desired titles
for A_TITLE in $ALL_TITLES;
do

    if [ "$RESUME" != 1 ]
    then

    if [ "$MODE" == "dvd" ]
    then
        TITLE=${TITLE_PREFIX}_${A_TITLE}

        # the _DECIMAL variables are required because bash interprets '0'-prefixed numbers as octal.
        # Sometimes we need that as string (grepping), sometimes as number (counting).
        A_TITLE_DECIMAL="`echo $A_TITLE | sed 's/0*\([0-9]\)/\1/'`"

        TITLE_LENGTH="`lsdvd -t ${A_TITLE_DECIMAL} ${INPUT} | cut -d ':' -f 3-4|cut -d ' ' -f 2`"
        HOURS="`echo $TITLE_LENGTH|cut -d ':' -f 1|sed 's/0*\([0-9]\)/\1/'`"
        MINUTES="`echo $TITLE_LENGTH|cut -d ':' -f 2|sed 's/0*\([0-9]\)/\1/'`"
        TITLE_LENGTH_SECONDS="$[${HOURS}*3600 + ${MINUTES}*60]"
    else #dumpfile
	#mplayer gives not for all ts files a correct result
	SECONDS_REAL=$((`mediainfo --Inform='Video;%Duration%' $INPUT`/1000))
        TITLE_LENGTH_SECONDS=`echo $SECONDS_REAL | sed 's#\..*##'`
    fi

    LENGTH_FOR_SAMPLING=$TITLE_LENGTH_SECONDS
    if (test -n "$SAMPLING_DIVIDER")
    then
        LENGTH_FOR_SAMPLING=$(( $TITLE_LENGTH_SECONDS / $SAMPLING_DIVIDER ))
    fi
    SAMPLE_STEP=$(( ($LENGTH_FOR_SAMPLING / ${SAMPLE_POINTS}) +1 ))

    AUDIO_STREAMS_NUMBER=
    AUDIO_STREAMS_NUMBER_DECIMAL=
    AUDIO_STREAMS_IDS=
    AUDIO_STREAMS=
    SUBTITLE_STREAMS_NUMBER=
    SUBTITLE_STREAMS_NUMBER_DECIMAL=
    SUBTITLE_STREAMS_IDS=
    SUBTITLE_STREAMS=

    if [ "$MODE" == "dvd" ]
    then
        MINPUT="-dvd-device $INPUT dvd://${A_TITLE_DECIMAL}"

        AUDIO_STREAMS_NUMBER="`lsdvd -t ${A_TITLE} ${INPUT}  | grep "^Title:" | cut -d " " -f 11|cut -d "," -f 1`"
        AUDIO_STREAMS_NUMBER_DECIMAL="`echo $AUDIO_STREAMS_NUMBER | sed 's/0*\([0-9]\)/\1/'`"
        AUDIO_STREAMS_IDS=`lsdvd -a -t ${A_TITLE} ${INPUT} | grep -C ${AUDIO_STREAMS_NUMBER_DECIMAL} "Title: ${A_TITLE}" | tail -n ${AUDIO_STREAMS_NUMBER_DECIMAL} | cut -d ':' -f 10|sed -e 's/\ //g'`

        SUBTITLE_STREAMS_NUMBER="`lsdvd -t ${A_TITLE} ${INPUT} | grep "^Title:" | cut -d " " -f 13|cut -d "," -f 1`"
        SUBTITLE_STREAMS_NUMBER_DECIMAL="`echo $SUBTITLE_STREAMS_NUMBER | sed 's/0*\([0-9]\)/\1/'`"
        SUBTITLE_STREAMS_IDS=`lsdvd -s -t ${A_TITLE} ${INPUT} | grep -C ${SUBTITLE_STREAMS_NUMBER_DECIMAL} "Title: ${A_TITLE}" | tail -n ${SUBTITLE_STREAMS_NUMBER_DECIMAL} | grep -v "xx - Unknown" | cut -d ':' -f 5 | cut -d "," -f 1 | sed -e 's/\ //g'`
    else #dumpfile
        MINPUT="$INPUT"

        echo "sampling input for audio and subtitle streams, $SAMPLE_POINTS steps"
        IDENT=""
        COUNTER=0
        for SAMPLE in `seq 1 ${SAMPLE_STEP} ${LENGTH_FOR_SAMPLING}`
        do
            COUNTER=$[${COUNTER}+1]
            echo -n "$COUNTER "
            TEMP_IDENT=`mplayer -ss $SAMPLE -frames 200 -fps 200 -really-quiet -nosound -vo null -identify $1 2>/dev/null`
            IDENT=`echo $IDENT $TEMP_IDENT | perl -pe 's# #\n#g' | egrep "ID_AUDIO_ID|ID_SUBTITLE_ID" | sort | uniq`
        done
        echo "sampling done"

        AUDIO_STREAMS_NUMBER_DECIMAL="`echo $IDENT | grep 'ID_AUDIO_ID' | wc -l`"
        AUDIO_STREAMS_IDS="`echo $IDENT | perl -pe 's# #\n#g' | grep 'ID_AUDIO_ID' | sed 's#ID_AUDIO_ID=##g' | sed 's# ##g'`"

        SUBTITLE_STREAMS_NUMBER_DECIMAL="`echo $IDENT | grep 'ID_SUBTITLE_ID' | wc -l`"
        SUBTITLE_STREAMS_IDS="`echo $IDENT | perl -pe 's# #\n#g' | grep 'ID_SUBTITLE_ID' | sed 's#ID_SUBTITLE_ID=##g' | sed 's# ##g'`"
    fi

    if [ -n "$ENDPOS" ]
    then
        ENDPOS="-endpos $ENDPOS"
    fi

    AUDIO_STREAMS="`for N in $AUDIO_STREAMS_IDS ; do AUDIO_STREAMS="$AUDIO_STREAMS $N" ; done ; echo $AUDIO_STREAMS`"
    SUBTITLE_STREAMS="`for N in $SUBTITLE_STREAMS_IDS ; do SUBTITLE_STREAMS="$SUBTITLE_STREAMS $N" ; done ; echo $SUBTITLE_STREAMS`"

    SOURCE_BR="`mplayer $MINPUT -identify -ao null -vo null -ss 1 -endpos 1 2>/dev/null |grep ID_VIDEO_BITRATE | sed 's#ID_VIDEO_BITRATE=##' | sed 's# ##g'`"
    BR_PRINT="?"
    CRF_ADJUST=0

    if [ "$SOURCE_BR" != "" ] && [ "$SOURCE_BR" != "0" ]
    then
        BR_PRINT=$(( $SOURCE_BR / 1000 ))
        BR_PRINT="$BR_PRINT kbps"

        if [ "$SOURCE_BASED_CRF" == "1" ]
        then
            # expected max about 9800000, increment CRF by one for each 1700000 lower than max
            if [[ $SOURCE_BR -le 8100000 ]]
            then
                CRF_ADJUST=1
            fi
            if [[ $SOURCE_BR -le 6400000 ]]
            then
                CRF_ADJUST=2
            fi
            if [[ $SOURCE_BR -le 4700000 ]]
            then
                CRF_ADJUST=3
            fi
            if [[ $SOURCE_BR -le 3000000 ]]
            then
                CRF_ADJUST=4
            fi
        fi
    fi

    AUDIO_PRINT="none"
    if [ -n "$AUDIO_STREAMS" ]
    then
        AUDIO_PRINT="$AUDIO_STREAMS"
    fi
    SUB_PRINT="none"
    if [ -n "$SUBTITLE_STREAMS" ]
    then
        SUB_PRINT="$SUBTITLE_STREAMS"
    fi

	if [ "$PREDEFINED_CROP" != "" ]
	then
		CROP="crop=${PREDEFINED_CROP}"
		echo "Have CROP defined as $CROP, skipping detection."
		Xc="`echo ${PREDEFINED_CROP}|cut -d ':' -f 1`"
		Yc="`echo ${PREDEFINED_CROP}|cut -d ':' -f 2`"
		Wc="`echo ${PREDEFINED_CROP}|cut -d ':' -f 3`"
		Hc="`echo ${PREDEFINED_CROP}|cut -d ':' -f 4`"
	else

    Xc=0
    Yc=0
    Wc=2000
    Hc=2000
    COUNTER=0
    for SAMPLE in `seq 1 ${SAMPLE_STEP} ${LENGTH_FOR_SAMPLING}`
    do
        COUNTER=$[${COUNTER}+1]
        echo -n "Crop detect pass $COUNTER, position $SAMPLE seconds, 200 frames: "
        CROP="`mplayer $MINPUT -vo null -nosound -vf cropdetect -ss $SAMPLE -frames 200 -fps 200 2>/dev/null | grep '\[CROP\]' | tail -n 1 |cut -d '(' -f 2 | cut -d ')' -f 1`"
        echo -n "\"$CROP\" "
        FOUNDCROP=`echo $CROP | grep -c 'crop='`
        if [ $FOUNDCROP == "1" ]
        then
          X="`echo $CROP | cut -d '=' -f 2 | cut -d ':' -f 1`"
          Y="`echo $CROP | cut -d '=' -f 2 | cut -d ':' -f 2`"
          W="`echo $CROP | cut -d '=' -f 2 | cut -d ':' -f 3`"
          H="`echo $CROP | cut -d '=' -f 2 | cut -d ':' -f 4`"

          if [ "$Xc" -lt "$X" ]
          then
              Xc=$X
              echo -n "X adjusted "
          fi

          if [ "$Yc" -lt "$Y" ]
          then
              Yc=$Y
              echo -n "Y adjusted "
          fi

          if [ "$Wc" -gt "$W" ]

          then
              Wc=$W
              echo -n "W adjusted "
          fi

          if [ "$Hc" -gt "$H" ]
          then
              Hc=$H
              echo -n "H adjusted "
          fi
      fi
      echo "Settled for $Xc $Yc $Wc $Hc."
    done

    CROP="crop=$Xc:$Yc:$Wc:$Hc"
	fi
    echo $CROP

    # 576p or 720p or 1080p ? decide based on Yc
    VIDEOCLASS="576p"
    if [ "$Yc" -gt 576 ]
    then
        VIDEOCLASS="720p"
        if [ "$Yc" -gt 720 ]
        then
            VIDEOCLASS="1080p"
        fi
        echo "processing as $VIDEOCLASS, disabling SOURCE_BASED_CRF"
        SOURCE_BASED_CRF="0"
    fi

    OPT_VF_PP=""
    OPT_VF_SCALE=""
    OPT_SWS=""
    X264_LEVEL="30" # safe default

    TARGET_VIDEOCLASS="$VIDEOCLASS"
    if [ "$VIDEOCLASS" == "720p" ]
    then
        echo "720p encode"
        OPT_VF_SCALE=",scale=1280:-10"
        OPT_SWS="-sws 9"
        X264_LEVEL="40"
        case $QUALITY in
            "HIGH") CRF="20"
                    ;;
            "MEDIUM") CRF="22"
                    ;;
            "LOW") CRF="24"
                    ;;
        esac
    elif [ "$VIDEOCLASS" == "1080p" ]
    then
        if [ "$DOWNSAMPLE" == "true" ]
        then
            echo "downsample encode, to 720p"
            TARGET_VIDEOCLASS="720p"
            OPT_VF_SCALE=",scale=1280:-10"
            OPT_SWS="-sws 9"
        else
            OPT_VF_SCALE=",scale=1920:-10"
            OPT_SWS="-sws 9"
        fi

    else # 576p
	#move the comma here at the end instead to the beginning of crop
        OPT_VF_PP="pp=${DEINT}ha/va/dr,"

        if [ "$UPSAMPLE" == "false" ]
        then
            echo "Standard encode"
            OPT_VF_SCALE=""
            OPT_SWS=""
        else
            echo "Upsampled encode, from 576p to 720p"
            TARGET_VIDEOCLASS="720p"
            OPT_VF_SCALE=",scale=1280:-10"
            OPT_SWS="-sws 9"
        fi
    fi

    case $TARGET_VIDEOCLASS in
        "576p") X264_LEVEL="31"
		X264_PROFILE="main"
                case $QUALITY in
                    "HIGH") CRF="18"
                            ;;
                    "MEDIUM") CRF="20"
                              ;;
                    "LOW") CRF="22"
                           ;;
                esac
                ;;
        "720p") X264_LEVEL="40"
		X264_PROFILE="high"
                case $QUALITY in
                    "HIGH") CRF="20"
                            ;;
                    "MEDIUM") CRF="22"
                              ;;
                    "LOW") CRF="24"
                           ;;
                esac
                ;;
        "1080p") X264_LEVEL="41"
		X264_PROFILE="high"
                 case $QUALITY in
                     "HIGH") CRF="21"
                             ;;
                     "MEDIUM") CRF="24"
                               ;;
                     "LOW") CRF="26"
                            ;;
                 esac
                 ;;
    esac


    TITLE_CRF=$(( $CRF + $CRF_ADJUST ))

    if [ "$MODE" == "dvd" ]
    then
        echo -n "Title: $A_TITLE_DECIMAL, "
    fi

    echo "audio streams: $AUDIO_PRINT, subtitle streams: $SUB_PRINT, source bitrate: $BR_PRINT, encoding quality crf=$TITLE_CRF ($CRF + $CRF_ADJUST)"
    echo "Title length: ${TITLE_LENGTH_SECONDS} seconds"

    if [ "$MODE" == "dvd" ]
    then
        dvdxchap -t ${A_TITLE_DECIMAL} ${INPUT}  | sed -e "s/Chapter\ //g" > ${OUTPUT}/${TITLE}.chapters
    fi

    echo "Calculating default frame duration."
    FPS="`mplayer $MINPUT -identify -ao null -vo null -ss 1 -endpos 1 2>/dev/null |grep ID_VIDEO_FPS |cut -d '=' -f 2`"

    echo "Calculating number of reframes."

CeilMbsX=`perl -w -e "use POSIX; print ceil($Xc/16), qq{\n}"`
CeilMbsY=`perl -w -e "use POSIX; print ceil($Yc/16), qq{\n}"`

echo "Macroblocks X: $CeilMbsX Macroblocks Y: $CeilMbsY"

case $X264_LEVEL in
                        10)     MaxBpbMbs=396
                                ;;
                        1b)     MaxBpbMbs=396
                                ;;
                        11)     MaxBpbMbs=900
                                ;;
                        12)     MaxBpbMbs=2376
                                ;;
                        13)     MaxBpbMbs=2376
                                ;;
                        20)     MaxBpbMbs=2376
                                ;;
                        21)     MaxBpbMbs=4752
                                ;;
                        22)     MaxBpbMbs=8100
                                ;;
                        30)     MaxBpbMbs=8100
                                ;;
                        31)     MaxBpbMbs=18000
                                ;;
                        32)     MaxBpbMbs=20480
                                ;;
                        40)     MaxBpbMbs=32768
                                ;;
                        41)     MaxBpbMbs=32768
                                ;;
                        42)     MaxBpbMbs=34816
                                ;;
                        50)     MaxBpbMbs=110400
                                ;;
                        51)     MaxBpbMbs=184320
                                ;;
esac

PicMbs=$[ $CeilMbsX * $CeilMbsY ]

nREF=$[ $MaxBpbMbs / $PicMbs ]

echo "Max ReFrames=$nREF"


    OPT_DTC=""
    case $FPS in

        23.976) IFPS="24000/1001"
		OFPS="24000/1001"
		DEFD="41.708ms"
		;;
        24.000) IFPS="24"
		OFPS="24"
		DEFD="41.666ms"
		;;
        25.000) IFPS="25"
		OFPS="25"
		DEFD="40.000ms"
		;;
        29.970) if [ "$FORCE_PULLUP" == "1" ]
		then
			IFPS="30000/1001"
			OFPS="24000/1001"
			DEFD="41.708ms"
			OPT_DTC="pullup,softskip,"
		elif [ "$FORCE_PULLUP" == "2" ]
		then
			IFPS="30000/1001"
			OFPS="24000/1001"
			DEFD="41.708ms"
			OPT_DTC="softpulldown,ivtc=2,"
		else
			IFPS="30000/1001"
			OFPS="30000/1001"
			DEFD="33.367ms"
		fi
		;;
        30.000) if [ "$FORCE_PULLUP" == "1" ]
		then
			IFPS="30"
			OFPS="24"
			DEFD="41.667ms"
			OPT_DTC="pullup,softskip,"
		elif [ "$FORCE_PULLUP" == "2" ]
		then
			IFPS="30"
			OFPS="24"
			DEFD="41.667ms"
			OPT_DTC="softpulldown,ivtc=2,"
		else
			IFPS="30"
			OFPS="30"
			DEFD="33.333ms"
		fi
		;;
    esac
#
#	IFPS = input stream frames per second
#	OFPS = output (encoded) stream frames per second
#	DEFD = output stream frame duration in miliseconds (1000/$OFPS)
#	OPT_DTC = inverse telecine algorithm, two available:
#		1) pullup,softskip, (for correctly pulled down material)
#		2) softpulldown,ivtc=2, (for messed up, re-edited material)
#	Note the extra comma after the OPT_DTC value.
#
	if [ ! -z "${IFPS}" ]
	then
		echo -n "Input frame rate: ${IFPS}, output frame rate: ${OFPS}, frame duration: ${DEFD}"
		if [ -z "${OPT_DTC}" ]
		then
			echo ""
		else
			echo ", pullup setting: $OPT_DTC"
		fi
	else
		echo "This source has a strange frame rate (${FPS}) and"
		echo "correct frame timing cannot be established. You have two options:"
		echo "1) Give up"
		echo "2) Manually specify \$IFPS, \$OFPS, \$DEFD and possibly \$OPT_DTC (if required)"
		echo "   You can do so by prepending the command line with correct values, i.e.:"
		echo "   IFPS=\"30\" OFPS=\"24\" DEFD=\"41.667ms\" OPT_DTC=\"pullup,softskip,\" x264transcode.sh file.iso"
		echo "I'd suggest you use a tool like 'mediainfo' to find the correct values and"
		echo "make a test encode to check for any judder. If you look at the source code"
		echo "of this script, you'll see example values of *FPS right above this error"
		echo "message. If you see a lot of \"Skipping frame\" messages during encode,"
		echo "then the values you're using are probably wrong."
		echo ""
		echo "Right now I'm going to abort -- whatever I'm going to encode here will most"
		echo "likely suffer from audio drift and you will end up cursing at me."
		echo "$0 Terminating."
		exit 1
	fi

    DUMPFROM="$MINPUT"
    if [ "$MODE" == "dvd" ] && [ "$DUMPSTREAM" == "1" ]
    then
        DUMPFROM=$OUTPUT/${TITLE}.dumpstream
        RUNARGS="-dumpstream -dumpfile ${DUMPFROM} $MINPUT"
        echo "mplayer $RUNARGS"
        mplayer $RUNARGS 1>&2 || SKIP=1
    fi

    if [ -s "${OUTPUT}/${TITLE}.idx" ] && [ -s "${OUTPUT}/${TITLE}.sub" ] && [ -s $OUTPUT/${TITLE}.smap ]
    then
        echo "using existing subtitles"
        SUBTITLE_SUCCESS_COUNT=`wc -l $OUTPUT/${TITLE}.smap`
    else
        COUNTER=0
        rm -f "$OUTPUT/${TITLE}".smap
        rm -f "$OUTPUT/${TITLE}".subpartial.smap
        if [ "$SUBTITLE_STREAMS_NUMBER_DECIMAL" != "0" ]
        then
            for SID in $SUBTITLE_STREAMS
            do
                echo "Extracting subtitle $SID"
                SKIP=0
                if [ "$MODE" == "dvd" ]
                then
                    SUBTITLE_LANGUAGE_CODE="`lsdvd -t ${A_TITLE_DECIMAL} -s $INPUT | grep $SID | cut -d ':' -f 3 | cut -d ' ' -f 2`"
                    SUBTITLE_LANGUAGE_NAME="`lsdvd -t ${A_TITLE_DECIMAL} -s $INPUT | grep $SID | cut -d ':' -f 3 | cut -d ' ' -f 4 | cut -d ',' -f 1`"
                else #dumpfile
                    SUBTITLE_LANGUAGE_CODE="xx"
                    SUBTITLE_LANGUAGE_NAME="Unknown"
                fi

                RUNARGS="-nosound -ovc frameno -fps ${IFPS} -vf ${OPT_DTC}harddup -ofps ${OFPS} -vobsubout ${OUTPUT}/${TITLE}.subpartial -o /dev/null -sid $SID -vobsuboutid $SUBTITLE_LANGUAGE_CODE -vobsuboutindex $COUNTER $DUMPFROM"
                echo "mencoder $RUNARGS"
                 if [ "$HAVE_CRSWALLOW" == "1" ]
                then
                    mencoder $MQUIET $RUNARGS 2>&1 | eval crswallow $CRSWALLOW_ARGS || SKIP=1
                else
                    mencoder $MQUIET $RUNARGS 1>&2 || SKIP=1
                fi

                if [ "$SKIP" == "0" ]
                then
                    echo "Writing entry for subtitle $SID into subtitle map ${OUTPUT}/${TITLE}.smap"
                    echo "$SID $SUBTITLE_LANGUAGE_CODE $SUBTITLE_LANGUAGE_NAME index=$COUNTER" >> $OUTPUT/${TITLE}.subpartial.smap
                    COUNTER=$[${COUNTER}+1]
                else
                    echo "Ripping subtitle $SID failed, skipping it."
                fi
            done
            cat $OUTPUT/${TITLE}.subpartial.smap
        fi
        SUBTITLE_SUCCESS_COUNT=$COUNTER
        if [ -s "${OUTPUT}/${TITLE}.subpartial.idx" ] && [ -s "${OUTPUT}/${TITLE}.subpartial.sub" ] && [ "$SUBTITLE_SUCCESS_COUNT" != "0" ]
        then
            mv "${OUTPUT}/${TITLE}.subpartial.idx" "${OUTPUT}/${TITLE}.idx"
            mv "${OUTPUT}/${TITLE}.subpartial.sub" "${OUTPUT}/${TITLE}.sub"
            mv "${OUTPUT}/${TITLE}.subpartial.smap" "${OUTPUT}/${TITLE}.smap"
        fi
    fi

    COUNTER=0
    rm -f "$OUTPUT/${TITLE}".amap
    for AID in $AUDIO_STREAMS
    do
        echo "Extracting audio track $AID"
        SKIP=1
        if [ "$MODE" == "dvd" ]
        then
            AUDIO_LANGUAGE_CODE="`lsdvd -t ${A_TITLE_DECIMAL} -a $INPUT | grep $AID | cut -d ':' -f 3 | cut -d ' ' -f 2`"
            AUDIO_LANGUAGE_NAME="`lsdvd -t ${A_TITLE_DECIMAL} -a $INPUT | grep $AID | cut -d ':' -f 3 | cut -d ' ' -f 4 | cut -d ',' -f 1`"
        else #dumpfile
            AUDIO_LANGUAGE_CODE="xx"
            AUDIO_LANGUAGE_NAME="Unknown"
        fi

        if [ -s "${OUTPUT}/${TITLE}.$AID" ]
        then
            echo "keeping existing file ${OUTPUT}/${TITLE}.$AID"
            SKIP=0
        else
            RUNARGS="-aid $AID -vo null -vc dummy -dumpaudio -dumpfile ${OUTPUT}/${TITLE}.$AID.partial $DUMPFROM"
            echo "mplayer $RUNARGS"
            if [ "$HAVE_CRSWALLOW" == "1" ]
            then
                mplayer $MQUIET $RUNARGS 2>&1 | eval crswallow $CRSWALLOW_ARGS || SKIP=1
            else
                mplayer $MQUIET $RUNARGS 1>&2 || SKIP=1
            fi

            if [ -s "${OUTPUT}/${TITLE}.$AID.partial" ]
            then
                SKIP=0
                mv "${OUTPUT}/${TITLE}.$AID.partial" "${OUTPUT}/${TITLE}.$AID"
            fi
        fi

        if [ "$SKIP" == "0" ]
        then
            echo "Writing entry for audio $AID into audio map ${OUTPUT}/${TITLE}.amap"
            echo "$AID $AUDIO_LANGUAGE_CODE $AUDIO_LANGUAGE_NAME index=$COUNTER" >>$OUTPUT/${TITLE}.amap
            COUNTER=$[${COUNTER}+1]
        else
            echo "Ripping audio $AID failed, skipping it."
        fi
    done

    if [ "$COUNTER" == "0" ]
    then
        echo "Incorrectly mastered DVD, claims 0 audio tracks, extracting default audio track."

        if [ -s "${OUTPUT}/${TITLE}.adef" ]
        then
            echo "keeping existing file ${OUTPUT}/${TITLE}.adef"
            SKIP=0
        else
            RUNARGS="-vo null -vc dummy -dumpaudio -dumpfile ${OUTPUT}/${TITLE}.adef.partial $DUMPFROM"
            echo "mplayer $RUNARGS"
            if [ "$HAVE_CRSWALLOW" == "1" ]
            then
                mplayer $MQIET $RUNARGS 2>&1 | eval crswallow $CRSWALLOW_ARGS || SKIP=1
            else
                mplayer $MQIET $RUNARGS 1>&2 || SKIP=1
            fi

            if [ -s "${OUTPUT}/${TITLE}.adef.partial" ]
            then
                SKIP=0
                mv "${OUTPUT}/${TITLE}.adef.partial" "${OUTPUT}/${TITLE}.adef"
            fi
        fi

        if [ "$SKIP" == "0" ]
        then
            echo "Writing entry for audio into audio map ${OUTPUT}/${TITLE}.amap"
            echo "adef xx Unknown index=0" >>$OUTPUT/${TITLE}.amap
        fi
    fi

    cat $OUTPUT/${TITLE}.amap

    echo "Ripping main video stream."

    # WARNING: some versions of mplayer seem to ignore the "-noautosub" option and insist
    # on burning the subtitles into the stream anyway. If this happens, use "-sid 4096" instead,
    # it asks mplayer to use a subtitle stream ID that is well outside the usual range.

    if [ "$SPECPROF" != "1" ]
    then
        MENC_PROFILE=""
    else
	MENC_PROFILE="profile=${X264_PROFILE}:"
    fi

    if [ -s "${OUTPUT}/${TITLE}.x264" ]
    then
        echo "keeping existing file ${OUTPUT}/${TITLE}.x264"
    else
        RUNARGS="-nosound -noautosub $MENCODER_SUBTITLE_QUIRK $ENDPOS $DUMPFROM -fps ${IFPS} -vf ${OPT_DTC}${OPT_VF_PP}${CROP}${OPT_VF_SCALE},harddup ${OPT_SWS} -ovc x264 -x264encopts threads=${THREADS}:crf=${TITLE_CRF}:level_idc=${X264_LEVEL}:frameref=$nREF:bframes=3:${MENC_PROFILE}nodct_decimate:trellis=2:${NO_B_PYRAMID}:me=umh:mixed_refs:weight_b -ofps ${OFPS} -of rawvideo -o ${OUTPUT}/${TITLE}.x264.partial"
        echo "mencoder $RUNARGS"
        if [ "$HAVE_CRSWALLOW" == "1" ]
        then
            $IONICE_COMMAND nice -n 19 mencoder $MQUIET $RUNARGS 2>&1 | crswallow $SWALLOW_SECONDS -out-to-stderr
        else
            $IONICE_COMMAND nice -n 19 mencoder $MQUIET $RUNARGS 1>&2
        fi
        if [ -s "${OUTPUT}/${TITLE}.x264.partial" ]
        then
            mv "${OUTPUT}/${TITLE}.x264.partial" "${OUTPUT}/${TITLE}.x264"
        fi
    fi

    ALLAUDIO="--default-track 0"
    AVAILABLE_AUDIO="`cat ${OUTPUT}/${TITLE}.amap | cut -d ' ' -f 1`"

    for ATRACK in $AVAILABLE_AUDIO
    do
        AINDEX="`grep $ATRACK ${OUTPUT}/${TITLE}.amap | cut -d ' ' -f 4 | cut -d '=' -f 2`"
        ALANGUAGE_CODE="`grep $ATRACK ${OUTPUT}/${TITLE}.amap | cut -d ' ' -f 2`"
        ALANGUAGE_NAME1="`grep $ATRACK ${OUTPUT}/${TITLE}.amap | cut -d ' ' -f 3`"
        ALANGUAGE_NAME2="`mkvmerge --list-languages | grep -v code | cut -d '|' -f 2,3 | sed -e 's/\ //g' -e 's/|/,/g' | grep ,${ALANGUAGE_CODE} | tail -n 1 | cut -d ',' -f 1`"
        if [ "${ALANGUAGE_NAME2}" == "" ]
        then
            ALANGUAGE_NAME2="und"
        fi

        ALLAUDIO="$ALLAUDIO --compression 0:none --language 0:${ALANGUAGE_NAME2} ${OUTPUT}/${TITLE}.${ATRACK}"
        echo $ATRACK $AINDEX $ALANGUAGE_CODE $ALANGUAGE_NAME1 $ALANGUAGE_NAME2
    done

    echo $ALLAUDIO

    if [ "$SUBTITLE_STREAMS_NUMBER_DECIMAL" != "0" ] && [ "$SUBTITLE_SUCCESS_COUNT" != "0" ] && [ -s "${OUTPUT}/${TITLE}.idx" ] && [ -s "${OUTPUT}/${TITLE}.sub" ]
    then
	SUBTITLES="${OUTPUT}/${TITLE}.idx"
    else
        SUBTITLES=""
    fi

    fi # RESUME

    echo "Merging it all..."
    RUNARGS="-o ${OUTPUT}/${TITLE}.x264.mkv --compression 0:none --default-duration 0:${DEFD} ${OUTPUT}/${TITLE}.x264 ${ALLAUDIO} ${SUBTITLES}"
    if [ "$MODE" == "dvd" ]
    then
        RUNARGS="$RUNARGS --chapters ${OUTPUT}/${TITLE}.chapters"
    fi

    MKVQUIET=""
    if [ "$NOPROGRESS" == "1" ]
    then
        MKVQUIET="--quiet"
    fi

    echo "mkvmerge $RUNARGS"
    $IONICE_COMMAND nice -n 19 mkvmerge $MKVQUIET $RUNARGS 1>&2

    if [ $? != 0 ]
    then
      cat << EOF
mkvmerge failed. Perhaps not enough space available.
Saving state to $RESUME_FILE. You have two alternatives:

    1) Make some space and rerun the x264transcode.sh with the same arguments.
    2) Delete $RESUME_FILE and start a new job.
EOF

      t=0
      x=""
      for i in $ALL_TITLES
      do
        if [ "$t" = 1 ]
        then
          x="$x $i"
        fi
        if [ "$i" = "$A_TITLE" ]
        then
          x="$i"
          t=1
        fi
      done
      cat << EOF > "$RESUME_FILE"
        ALL_TITLES="$x"
        TITLE="$TITLE"
        DEFD="$DEFD"
        ALLAUDIO="$ALLAUDIO"
        SUBTITLES="$SUBTITLES"
EOF
      exit 3
    fi

    if [ "$RESUME" = 1 ]
    then
      NOCLEANUP=""
      RESUME=""
      rm "$RESUME_FILE"
    fi

    ls -l "${OUTPUT}/${TITLE}".*

    mv "${OUTPUT}/${TITLE}".x264.mkv "${FINAL_DESTINATION}/${TITLE}".mkv

    if [ -a "${FINAL_DESTINATION}/${TITLE}".mkv ]
    then
	echo -n "${FINAL_DESTINATION}/${TITLE}.mkv successfully created."
        if [ "$NOCLEANUP" != "1" ]
        then
        	echo " Cleaning up."
		echo "Removing:"
		ls -l "${OUTPUT}/${TITLE}".*
        	rm -f "${OUTPUT}/${TITLE}".*
		echo "Done."
	else
		echo " NOCLEANUP=1, leaving temporary files as they are."
		ls -l "${OUTPUT}/${TITLE}".*
        fi
    else
	echo "Can't find ${FINAL_DESTINATION}/${TITLE}.mkv. Something went wrong."
	echo "Have a look in ${OUTPUT} for possible clues and check if"
	echo "${FINAL_DESTINATION} is writeable and you haven't ran out of disk space."
	echo "Temporary files in $OUTPUT will be removed when you restart the script."
	exit 1
    fi
done

echo "Done."

