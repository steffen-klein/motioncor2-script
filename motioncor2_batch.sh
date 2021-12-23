################################################################################
#                                   License                                    #
################################################################################



################################################################################
#                                     Infos                                    #
################################################################################

# Script to automatically process tilt series frames acquired with serialEM using the dose symmetric script from Wim Hagen
#
# Frames need to be saved as .tif files with the following naming scheme: TS_aa_bbb_cc.c.tif
# with aa=tilt series, bbb=serialEM object and cc.c=titl angle.
#
# Raw data needs to be organized in a specific way in order for the script to be functional:
# ./01_raw_data <-- in this folder all realigned and ordered .st/mrc and .st/mrc.mdoc files are stored
# ./01_raw_data/frames <-- in this folder all .tif files are stored
# ./motioncor_batch.script <-- this is the correct location for this script
#
# This script will generate a hidden temporary folder called .motioncor2_temp where all intermediate files are stored.
# The final aligend files will be saved in the folder:
# ./02_motioncor2

################################################################################
#                            Setup MotionCor2                                  #
################################################################################

# Set path to motioncorr installation and set all MotionCor2 specific parameters
motioncor="/opt/MotionCor2/MotionCor2_1.4.7_Cuda115_12-09-2021 -Patch 7 5 -Iter 10 -Tol 0.5 -SplitSum 1 -Ftbin 2 -Serial 1 -Gpu 0 1 -Gain ./01_raw_data/frames/GainRef.mrc"

################################################################################
#                               Setup folder                                   #
################################################################################

# Setup file extensions used
TS_EXTENSION="mrc"

# Create temporary folder
mkdir -p .motioncor2_temp
mkdir -p .motioncor2_temp/01_aligned_tilts
mkdir -p .motioncor2_temp/02_tilt_files
mkdir -p .motioncor2_temp/03_aligned_unordered-stacks

# Create final output folder
mkdir -p  02_motioncor2
mkdir -p  02_motioncor2_EVN_ODD

################################################################################
#                                Run MotionCOo2                                #
################################################################################

# Convert GainRef file to .mrc
cd ./01_raw_data/frames/
	eval dm2mrc *.dm4 GainRef.mrc
cd ../../	# move back to working directory

# batch process all tif files with MotionCor2
eval $motioncor -InTiff ./01_raw_data/frames/TS_ -OutMrc ./.motioncor2_temp/01_aligned_tilts/TS_

################################################################################
#                              create tilt file                                #
################################################################################
	
cd ./.motioncor2_temp/01_aligned_tilts

# Go through all files in the frames folder and extract tilt
for FILE in TS_*.$TS_EXTENSION; do
	TS_FILE_NAME=$(basename -s .$TS_EXTENSION "$FILE")	# Get filename without extension
	TS_NUMBER=$(echo $TS_FILE_NAME | cut -d "_" -f 2)	# Extract TS number from file name
	TS_TILT=$(echo $TS_FILE_NAME | cut -d "_" -f 4)		# Get tilt
	TS_EVNODD=$(echo $TS_FILE_NAME | cut -d "_" -f 5)	# Get info on EVN or ODD
	TS_OUTPUT_TILT="TS_"$TS_NUMBER".tlt"
	
	touch ../02_tilt_files/$TS_OUTPUT_TILT			# Create file with tilt information stored

	# save tilt angle information for each tilt into tilt file.
	if [ "$TS_EVNODD" == "EVN" ]; then
		echo $TS_TILT >> ../02_tilt_files/$TS_OUTPUT_TILT	
	fi
done

cd ../../	# move back to working directory

################################################################################
#                         Sort files in subfolder                              #
################################################################################

cd ./.motioncor2_temp/01_aligned_tilts

# Go through all files in the frames folder and sort in even and odd
for FILE in TS_*.$TS_EXTENSION; do
	TS_FILE_NAME=$(basename -s .$TS_EXTENSION "$FILE")		# Get filename without extension
	TS_NUMBER=$(echo $TS_FILE_NAME | cut -d "_" -f 2)		# Extract TS number from file name´
	TS_EVNODD=$(echo $TS_FILE_NAME | cut -d "_" -f 5)		# Get info on EVN or ODD
	TS_FOLDER="TS_"$TS_NUMBER
	TS_FOLDER_EVN="TS_"$TS_NUMBER"_EVN"
	TS_FOLDER_ODD="TS_"$TS_NUMBER"_ODD"

	mkdir -p $TS_FOLDER						# Create folder with the name TS_xx
	mkdir -p $TS_FOLDER_EVN						# Create folder with the name TS_xx_EVN
	mkdir -p $TS_FOLDER_ODD						# Create folder with the name TS_xx_ODD

	# move file in subfolder for each tilt series: TS_xx, TS_xx_EVN and TS_xx_ODD
	if [ "$TS_EVNODD" == "EVN" ]; then
		mv "$FILE" "$TS_FOLDER_EVN/$FILE"
	   elif [ "$TS_EVNODD" = "ODD" ]; then
		mv "$FILE" "$TS_FOLDER_ODD/$FILE"
	   else
		mv "$FILE" "$TS_FOLDER/$FILE"
	fi
done

cd ../../	# move back to working directory

################################################################################
#                     Combine all tilts to one stack                           #
################################################################################

cd ./.motioncor2_temp/01_aligned_tilts

for FOLDER in */; do						# go through each folder
	cd $FOLDER
	TS_FILE_NAME=$(basename $FOLDER)			# Get folder name
	TS_NUMBER=$(echo $TS_FILE_NAME | cut -d "_" -f 2)	# Extract TS number from folder name
	TS_INPUT="TS_"$TS_NUMBER"."$TS_EXTENSION
	TS_INPUT_MDOC="TS_"$TS_NUMBER"."$TS_EXTENSION".mdoc"
	TS_OUTPUT=$TS_FILE_NAME"."$TS_EXTENSION
	TS_OUTPUT_MDOC=$TS_FILE_NAME"."$TS_EXTENSION".mdoc"

	newstack TS_*.$TS_EXTENSION ../../03_aligned_unordered-stacks/$TS_OUTPUT			# Combine all tilts to a single stack				
	cp ../../../01_raw_data/$TS_INPUT_MDOC ../../03_aligned_unordered-stacks/$TS_OUTPUT_MDOC	# Copy mdoc file from raw_data
	cd ../
done

cd ../../	# move back to working directory

################################################################################
#                               Reorder stacks                                 #
################################################################################

cd ./.motioncor2_temp/03_aligned_unordered-stacks/ 			# go to folder with combined but unordered stacks

# Go through each tilt series in this folder
for FILE in *.$TS_EXTENSION; do						# go through each TS_xx.st/mrc file in this folder
	TS_FILE_NAME=$(basename -s .$TS_EXTENSION $FILE)		# get basename of file without .st/mrc
	TS_NUMBER=$(echo $TS_FILE_NAME | cut -d "_" -f 2)		# Extract TS number from folder name
	newstack -reorder 1 -mdoc -angle ../02_tilt_files/"TS_"$TS_NUMBER".tlt" $TS_FILE_NAME"."$TS_EXTENSION ../../02_motioncor2/$TS_FILE_NAME"_mc2."$TS_EXTENSION	# sort TS acquired by their tilt angle
done

cd ../../	# move back to working directory

################################################################################
#                                  Cleanup                                     #
################################################################################

cd ./02_motioncor2/	# go to output folder

# Set correct pixel size for all tilt series in output folder
for FILE in TS_*.$TS_EXTENSION; do
	TS_NUMBER=$(echo $FILE | cut -d "_" -f 2)	# Extract TS number from file name
	INPUT_FILE="../01_raw_data/TS_"$TS_NUMBER"."$TS_EXTENSION
	PIXEL=$(header -PixelSize $INPUT_FILE | awk '{print $1 "," $2 "," $3}')
	eval alterheader -PixelSize $PIXEL $FILE
done

# Move .st/mrc and .st/mrc.mdoc to subfolder if they are EVN or ODD
for FILE in TS_*; do
	TS_NUMBER=$(echo $FILE | cut -d "_" -f 2)	# Extract TS number from file name
	TS_EVNODD=$(echo $FILE | cut -d "_" -f 3)	# Get info on EVN or ODD
	mkdir -p ../02_motioncor2_EVN_ODD/TS_$TS_NUMBER
	if [ "$TS_EVNODD" == "EVN" ]; then
		mv "$FILE" "../02_motioncor2_EVN_ODD/TS_$TS_NUMBER/$FILE"
	 elif [ "$TS_EVNODD" = "ODD" ]; then
		mv "$FILE" "../02_motioncor2_EVN_ODD/TS_$TS_NUMBER/$FILE"
	fi
done

cd ../			# move back to working directory

# Remove temporary folder
#rm -rf ./.motioncor2_temp	# delete temporary folder

################################################################################
#                            END OF SCRIPT                                     #
################################################################################
