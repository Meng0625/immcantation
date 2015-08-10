#!/bin/bash
# Wrapper script to run the Change-O clonal assignment pipeline script on multiple inputs
# 
# Author:  Jason Anthony Vander Heiden
# Date:    2015.07.07
#
# Required Arguments:
#   $1 = A folder containing db files to process
#   $2 = Output directory


IN_DIR=$1
OUT_DIR=$2
SCRIPT="/scratch2/kleinstein/oconnor_mg_memory/scripts/ChangeoPipelineV2.2_DefineClones.sh"
GERM_DIR="/scratch2/kleinstein/oconnor_mg_memory/germlines/IMGT_Human_2015-07-07"
LOG_FILE="RunLog_${IN_DIR}.out"
NPROC=20

FILES=$(ls $IN_DIR/*.tab)
for F in $FILES
do
    echo "FILE: $F" | tee -a $LOG_FILE
    echo `date` | tee -a $LOG_FILE
    F=$(readlink -f $F)
    B=$(basename $F)
    N=${B/_functional*/}
    $SCRIPT $F $GERM_DIR "${OUT_DIR}/${N}" $N $NPROC | tee -a $LOG_FILE
done
