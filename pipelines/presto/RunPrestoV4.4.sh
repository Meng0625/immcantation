#!/bin/bash
# Wrapper script to run the pRESTO pipeline script on multiple inputs
# 
# Author:  Jason Anthony Vander Heiden
# Date:    2014.6.4

DATADIR=/scratch2/kleinstein/oconnor_im
SCRIPT=/scratch2/kleinstein/oconnor_im/scripts/RunPipelineV4_AbVitroV3.0.sh
RUNID=RQ2410
LOGFILE=${RUNID}_RunLog.out
FOLDERS=$(ls -d $DATADIR/data/$RUNID/Sample_*| xargs -n 1 basename)
NPROC=20

echo "" > $LOGFILE 
for F in $FOLDERS
do
    echo "FOLDER: $F" | tee -a $LOGFILE 
    echo `date` | tee -a $LOGFILE
    R1=$DATADIR/data/$RUNID/$F/*L001_R1_001.fastq
    R2=$DATADIR/data/$RUNID/$F/*L001_R2_001.fastq
    OUT=$DATADIR/results/$RUNID/$F
    $SCRIPT $R1 $R2 $OUT $NPROC | tee -a $LOGFILE
done
