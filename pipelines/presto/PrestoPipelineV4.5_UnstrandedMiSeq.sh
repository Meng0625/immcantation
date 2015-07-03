#!/bin/bash
# Super script to run the pRESTO 0.4.5 pipeline on unstranded MiSeq data without UIDs
# 
# Author:  Jason Anthony Vander Heiden
# Date:    2014.11.26
# 
# Required Arguments:
#   $1 = read 1 file
#   $2 = read 2 file
#   $3 = read 1 primer file (V-region)
#   $4 = read 2 primer file (C-region)
#   $5 = output directory
#   $6 = output file prefix
#   $7 = number of subprocesses for multiprocessing tools

# Capture command line parameters
R1_FILE=$(readlink -f $1)
R2_FILE=$(readlink -f $2)
R1_PRIMERS=$(readlink -f $3)
R2_PRIMERS=$(readlink -f $4)
OUTDIR=$5
OUTNAME=$6
NPROC=$7

# Define pipeline steps
LOG_RUNTIMES=true
ZIP_FILES=true
QUAL_STEP=true
MASK_STEP=false
MISS_STEP=false

# Define pRESTO run parameters
FS_QUAL=20
FS_MASK=20
FS_MISS=20
AP_SCANREV=true
AP_MAXERR=0.3
AP_ALPHA=0.01
MP1_MAXLEN=100
MP2_MAXLEN=100
MP1_MAXERR=0.2
MP2_MAXERR=0.2
CS_MISS=20
MUSCLE_EXEC=$HOME/bin/muscle


# Define script execution command and log files
mkdir -p $OUTDIR; cd $OUTDIR
RUNLOG="Pipeline.log"
echo '' > $RUNLOG 
if $LOG_RUNTIMES; then
	TIMELOG="Time.log"
	echo '' > $TIMELOG 
	RUN="nice -19 /usr/bin/time -o ${TIMELOG} -a -f %C\t%E\t%P\t%Mkb"
else
	RUN="nice -19"
fi


# Start
echo "DIRECTORY: ${OUTDIR}"
echo "VERSIONS:"
echo "  $(AlignSets.py -v 2>&1)"
echo "  $(AssemblePairs.py -v 2>&1)"
echo "  $(BuildConsensus.py -v 2>&1)"
echo "  $(CollapseSeq.py -v 2>&1)"
echo "  $(FilterSeq.py -v 2>&1)"
echo "  $(MaskPrimers.py -v 2>&1)"
echo "  $(PairSeq.py -v 2>&1)"
echo "  $(ParseHeaders.py -v 2>&1)"
echo "  $(ParseLog.py -v 2>&1)"
echo "  $(SplitSeq.py -v 2>&1)"

# Filter low quality reads
echo -e "\nSTART"
STEP=0

# Remove low quality reads
if $QUAL_STEP; then
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "FilterSeq quality"
    #OUTPREFIX="$(printf '%02d' $STEP)--${OUTNAME}"
    $RUN FilterSeq.py quality -s $R1_FILE -q $FS_QUAL --nproc $NPROC \
        --outname "${OUTNAME}-R1" --outdir . >> $RUNLOG
    $RUN FilterSeq.py quality -s $R2_FILE -q $FS_QUAL --nproc $NPROC \
        --outname "${OUTNAME}-R2" --outdir . >> $RUNLOG
    APR1_FILE="${OUTNAME}-R1_quality-pass.fastq"
    APR2_FILE="${OUTNAME}-R2_quality-pass.fastq"
else
    APR1_FILE=$R1_FILE
    APR2_FILE=$R2_FILE
fi

# Assemble paired ends
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "AssemblePairs align"
if $AP_SCANREV; then
    $RUN AssemblePairs.py align -1 $APR2_FILE -2 $APR1_FILE --coord illumina --rc tail \
        --maxerror $AP_MAXERR --alpha $AP_ALPHA --nproc $NPROC \
        --log AssembleLog.log --outname "${OUTNAME}" --outdir . --scanrev >> $RUNLOG
else
    $RUN AssemblePairs.py align -1 $APR2_FILE -2 $APR1_FILE --coord illumina --rc tail \
        --maxerror $AP_MAXERR --alpha $AP_ALPHA --nproc $NPROC \
        --log AssembleLog.log --outname "${OUTNAME}" --outdir . >> $RUNLOG
fi

# Identify and mask V-region primers
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "MaskPrimers align (PR1)"
$RUN MaskPrimers.py align -s "${OUTNAME}_assemble-pass.fastq" -p $R1_PRIMERS --mode mask \
    --maxerror $MP1_MAXERR --maxlen $MP1_MAXLEN --nproc $NPROC \
    --log PrimerPR1Log.log --outname "${OUTNAME}-PR1" >> $RUNLOG

# Rename V-region primer field
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseHeaders rename (PR1)"
$RUN ParseHeaders.py rename -s "${OUTNAME}-PR1_primers-pass.fastq" \
    -f PRIMER -k VPRIMER --outname "${OUTNAME}-PR1" > /dev/null

# Identify and mask C-region primers
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "MaskPrimers align (PR2)"
$RUN MaskPrimers.py align -s "${OUTNAME}-PR1_reheader.fastq" -p $R2_PRIMERS --mode mask \
    --maxerror $MP2_MAXERR --maxlen $MP2_MAXLEN --nproc $NPROC --revpr --skiprc \
    --log PrimerPR2Log.log --outname "${OUTNAME}-PR2" >> $RUNLOG

# Rename C-region primer field
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseHeaders rename (PR2)"
$RUN ParseHeaders.py rename -s "${OUTNAME}-PR2_primers-pass.fastq" \
    -f PRIMER -k CPRIMER --outname "${OUTNAME}-PR2" > /dev/null

# Remove duplicate sequences
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "CollapseSeq"
$RUN CollapseSeq.py -s "${OUTNAME}-PR2_reheader.fastq" -n $CS_MISS --uf CPRIMER \
    --cf VPRIMER --act set --outname "${OUTNAME}" --inner >> $RUNLOG

# Mask low quality positions
if $MASK_STEP; then
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "FilterSeq maskqual"
    $RUN FilterSeq.py maskqual -s "${OUTNAME}-collapse-unique.fastq" -q $FS_MASK \
        --nproc $NPROC --outname "${OUTNAME}-unique" >> $RUNLOG
    FSMISS_FILE="${OUTNAME}-unique_maskqual-pass.fastq"
else
    FSMISS_FILE="${OUTNAME}_collapse-unique.fastq"
fi

# Remove sequences with many Ns
if $MISS_STEP; then
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "FilterSeq missing"
    $RUN FilterSeq.py missing -s $FSMISS_FILE -n $FS_MISS --inner --nproc $NPROC \
        --log MissingLog.log --outname "${OUTNAME}" --fasta >> $RUNLOG
    FINAL_FILE="${OUTNAME}_missing-pass.fastq"
else
    FINAL_FILE=$FSMISS_FILE
fi

# Rename final file
mv $FINAL_FILE "${OUTNAME}_final.fastq"

# Create table of final repertoire
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseHeaders table"
$RUN ParseHeaders.py table -s "${OUTNAME}_final.fastq" \
    -f ID CPRIMER VPRIMER DUPCOUNT >> $RUNLOG

# Split final file into sets of singletons and sequences with at least 2 reads
#printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "SplitSeq group"
#$RUN SplitSeq.py group -s "${OUTNAME}_final.fastq" -f DUPCOUNT --num 2 >> $RUNLOG

# Process log files
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseLog"
$RUN ParseLog.py -l AssembleLog.log -f ID REFID OVERLAP LENGTH GAP PVALUE ERROR HEADFIELDS TAILFIELDS > /dev/null &
$RUN ParseLog.py -l PrimerPR[1-2]Log.log -f ID SEQORIENT PRORIENT PRSTART PRIMER ERROR > /dev/null &
if $MISS_STEP; then
    $RUN ParseLog.py -l MissingLog.log -f ID MISSING > /dev/null &
fi
wait

if $ZIP_FILES; then
    tar -cf LogFiles.tar *Log.log
    gzip LogFiles.tar
    rm *Log.log
    
    tar -cf TempFiles.tar *quality* *duplicate* *undetermined* *reheader* *fail*
    gzip TempFiles.tar
    rm *quality* *duplicate* *undetermined* *reheader* *fail*
fi

# End
printf "DONE\n"
cd ../

