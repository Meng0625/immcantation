#!/bin/bash
# Wrapper script to run the pRESTO pipeline script on multiple inputs
# 
# Author:  Jason Anthony Vander Heiden
# Date:    2015.05.31
# Required arguments:
#   $1 = run identifier (string to match in folder names within $DATA_DIR/raw)

# Define run parameters
DATA_DIR=/scratch2/kleinstein/oconnor_mg_memory
SCRIPT=/scratch2/kleinstein/oconnor_mg_memory/scripts/PrestoPipelineV4.7_AbSeqV3.sh
PRIMERS1=/scratch2/kleinstein/oconnor_mg_memory/primers/AbSeqV3_Human_R1CPrimers.fasta
PRIMERS2=/scratch2/kleinstein/oconnor_mg_memory/primers/AbSeqV3_Human_R2TSPrimers.fasta
NPROC=12

# Determine folders
RUN_ID=$(ls -d ${DATA_DIR}/raw/* | grep ${1} | xargs -n1 basename)
LOG_FILE=${RUN_ID}_RunLog.out
FOLDERS=$(ls -d $DATA_DIR/raw/$RUN_ID/*| xargs -n1 basename)

echo "" > $LOG_FILE 
for F in $FOLDERS
do
    echo "FOLDER: $F" | tee -a $LOG_FILE 
    echo `date` | tee -a $LOG_FILE
    R1=$DATA_DIR/raw/$RUN_ID/$F/*L001_R1_001.fastq
    R2=$DATA_DIR/raw/$RUN_ID/$F/*L001_R2_001.fastq
    OUTDIR=$DATA_DIR/presto/$RUN_ID/$F
    OUTNAME=$F
    $SCRIPT $R1 $R2 $PRIMERS1 $PRIMERS2 $OUTDIR $OUTNAME $NPROC | tee -a $LOG_FILE
done
