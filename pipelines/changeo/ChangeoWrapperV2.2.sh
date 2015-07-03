#!/bin/bash
# Wrapper script to run the Change-O pipeline script on multiple inputs
# 
# Author:  Jason Anthony Vander Heiden
# Date:    2015.04.07
#
# Required Arguments:
#   $1 = A two column tab delimited file mapping IMGT zip files (column 1) 
#        to submitted FASTA files (column 2)
#   $2 = Output directory

SCRIPT="/home/jason/apps/changeo/scripts/ChangeoPipelineV4.0_IMGT.sh"
GERM_DIR="/mnt/data/germlines/IMGT_Human_2014-08-23"
#GERM_DIR="/mnt/data/germlines/IMGT_Mouse_2014-11-22"
NPROC=2

while read FILE_MAP
do
    FILE_ARRAY=($FILE_MAP)
    FOLDER=$(basename "${FILE_ARRAY[0]}" ".zip")
    LOG_FILE="${FOLDER}_ChangeoLog.out"

    echo "FOLDER: $FOLDER" | tee -a $LOG_FILE
    echo `date` | tee -a $LOG_FILE
    $SCRIPT "${FILE_ARRAY[0]}" "${FILE_ARRAY[1]}" "$GERM_DIR" "$2/$FOLDER" "$FOLDER" $NPROC | tee -a $LOG_FILE
    #echo $SCRIPT "${FILE_ARRAY[0]}" "${FILE_ARRAY[1]}" $GERM_DIR "$2/$FOLDER" $FOLDER $NPROC "|" tee -a $LOG_FILE
done < $1