#!/bin/bash

encoder=${ENCODER:-libx265}  # libx265 = HEVC, little support but much smaller filesize; libx264 = H.264, very wide support
quality=${QUALITY:-28}  # ok quality = 28 for HEVC, 23 for H264; great quality = 22 for HEVC, 20 for H264
scale=$SCALE  # decrease size of full HD streams: set to 1280:720; leave empty for no downscaling
audio_bitrate=${BITRATE:-80k}  # decrease audio quality to something acceptable for voice; set to 180k for precise music; leave empty to remove audio
frame_rate=$FRAMERATE  # set to 12 for video call archives
speed=${SPEED:-veryslow}  # more compute power against smaller size

if [[ $1 == '--dry-run' ]]
then
	dry_run=true
	shift
fi

if [[ $1 == '--in-place' ]]
then
	in_place=true
	shift
fi

if [[ $# == 0 ]]
then source_files="*.[mM][pPoO4][4gGvV]"
else source_files="$@"
fi

shared_options=""
shared_options="$shared_options -crf $quality"
shared_options="$shared_options -preset $speed"
shared_options="$shared_options -codec:v $encoder"
shared_options="$shared_options -filter:v format=yuv420p"  # ensure QuickTime can read resulting file
shared_options="$shared_options -map_metadata 0"  # copy all metadata


if [[ $encoder == 'libx265' ]]
then shared_options="$shared_options -tag:v hvc1"  # ensure QuickTime can read HEVC file, see https://stackoverflow.com/a/46540577/594053
fi
if [[ $scale ]]
then shared_options="$shared_options -filter:v scale=$scale"
fi
if [[ $frame_rate ]]
then shared_options="$shared_options -r $frame_rate"
fi
if [[ $audio_bitrate ]]
then shared_options="$shared_options -codec:a aac -b:a $audio_bitrate"
else shared_options="$shared_options -an"
fi
shared_options="$shared_options -movflags +faststart"  # ensure internet streaming is smooth

reencode_command() {  # $1 = source file, $2 = target file
	filename=`echo "$1" | rev | cut -d '.' -f 2- | rev`  # remove extension

	if [[ -e "$filename.jpg" ]]
	then local file_specific_options="-attach '$filename.jpg'"  # add cover artwork
	fi

	echo ffmpeg -i "'$1'" $shared_options $file_specific_options "'$2'"
}


for file in $source_files
do
	target_file="${file%.*}.$encoder-$quality.mp4"

	command=`reencode_command "$file" "$target_file"`

	if [[ $dry_run ]]
	then
		echo $command
		continue
	fi

	bash -c "$command"
	touch -r "$file" "$target_file"  # copy mtime and ctime

	if [[ $in_place ]]
	then
		mv "$file" "$HOME/.Trash/$file"
		mv "$target_file" "$file"
	fi
done
