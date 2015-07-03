#!/bin/bash
# Super script to run the pRESTO 0.4.7 pipeline on AbVitro AbSeq (V3) data
# 
# Author:  Jason Anthony Vander Heiden, Gur Yaari, Namita Gupta
# Date:    2015.05.31
# 
# Required Arguments:
#   $1 = read 1 file (C-region start sequence)
#   $2 = read 2 file (V-region start sequence)
#   $3 = read 1 primer file
#   $4 = read 2 primer file
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
ZIP_FILES=true
FILTER_LOWQUAL=true
ALIGN_UIDSETS=true
REFERENCE_ASSEMBLY=true
MASK_LOWQUAL=false
ALIGN_CREGION=true

# FilterSeq run parameters
FS_QUAL=20
FS_MASK=30

# MaskPrimers run parameters
MP_UIDLEN=17
MP_R1_MAXERR=0.2
MP_R2_MAXERR=0.5
MP_CREGION_MAXLEN=100
MP_CREGION_MAXERR=0.4
MP_CREGION_PRIMERS="/scratch2/kleinstein/oconnor_mg_memory/primers/AbSeqV3_Human_InternalCRegion.fasta"

# AlignSets run parameters
MUSCLE_EXEC=$HOME/bin/muscle

# BuildConsensus run parameters
BC_PRCONS_FLAG=true
BC_ERR_FLAG=true
BC_MAXERR=0.1
BC_PRCONS=0.6
BC_QUAL=0
BC_MAXGAP=0.5

# AssemblePairs-align run parameters
AP_ALN_SCANREV=true
AP_ALN_MAXERR=0.3
AP_ALN_MINLEN=8
AP_ALN_ALPHA=1e-5

# AssemblePairs-reference run parameters
AP_REF_MINIDENT=0.5
AP_REF_EVALUE=1e-5
AP_REF_MAXHITS=100
REF_FILE="/scratch2/kleinstein/germlines/IMGT_Human_IGV_ungapped_2014-08-23.fasta"
#REF_FILE="/scratch2/kleinstein/germlines/IMGT_Mouse_IGV_ungapped_2014-11-22.fasta"
USEARCH_EXEC=$HOME/bin/usearch

# CollapseSeq run parameters
CS_KEEP=true
CS_MISS=0

# Define log files
PIPELINE_LOG="Pipeline.log"
ERROR_LOG="Pipeline.err"

# Make output directory and empty log files
mkdir -p $OUTDIR; cd $OUTDIR
echo '' > $PIPELINE_LOG
echo '' > $ERROR_LOG

# Start
echo "DIRECTORY: ${OUTDIR}"
echo "VERSIONS:"
echo "  $(AlignSets.py -v 2>&1)"
echo "  $(AssemblePairs.py -v 2>&1)"
echo "  $(BuildConsensus.py -v 2>&1)"
echo "  $(ClusterSets.py -v 2>&1)"
echo "  $(CollapseSeq.py -v 2>&1)"
echo "  $(ConvertHeaders.py -v 2>&1)"
echo "  $(FilterSeq.py -v 2>&1)"
echo "  $(MaskPrimers.py -v 2>&1)"
echo "  $(PairSeq.py -v 2>&1)"
echo "  $(ParseHeaders.py -v 2>&1)"
echo "  $(ParseLog.py -v 2>&1)"
echo "  $(SplitSeq.py -v 2>&1)"
echo -e "\nSTART"
STEP=0

# Remove low quality reads
if $FILTER_LOWQUAL; then
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "FilterSeq quality"
    #OUTPREFIX="$(printf '%02d' $STEP)--${OUTNAME}"
    FilterSeq.py quality -s $R1_FILE -q $FS_QUAL --nproc $NPROC \
        --outname "${OUTNAME}-R1" --outdir . --log QualityLogR1.log \
        >> $PIPELINE_LOG  2> $ERROR_LOG
    FilterSeq.py quality -s $R2_FILE -q $FS_QUAL --nproc $NPROC \
        --outname "${OUTNAME}-R2" --outdir . --log QualityLogR2.log  \
        >> $PIPELINE_LOG  2> $ERROR_LOG
    MPR1_FILE="${OUTNAME}-R1_quality-pass.fastq"
    MPR2_FILE="${OUTNAME}-R2_quality-pass.fastq"
else
    MPR1_FILE=$R1_FILE
    MPR2_FILE=$R2_FILE
fi

# Identify primers and UID 
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "MaskPrimers score"
MaskPrimers.py score -s $MPR1_FILE -p $R1_PRIMERS --mode cut \
    --start 0 --maxerror $MP_R1_MAXERR --nproc $NPROC --log PrimerLogR1.log \
    --outname "${OUTNAME}-R1" --outdir . >> $PIPELINE_LOG 2> $ERROR_LOG
MaskPrimers.py score -s $MPR2_FILE -p $R2_PRIMERS --mode cut \
    --start $MP_UIDLEN --barcode --maxerror $MP_R2_MAXERR --nproc $NPROC --log PrimerLogR2.log \
    --outname "${OUTNAME}-R2" --outdir . >> $PIPELINE_LOG 2> $ERROR_LOG

# Assign UIDs to read 1 sequences
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "PairSeq"
PairSeq.py -1 "${OUTNAME}-R2_primers-pass.fastq" -2 "${OUTNAME}-R1_primers-pass.fastq" \
    --1f BARCODE --coord illumina >> $PIPELINE_LOG 2> $ERROR_LOG

# Multiple align UID read groups
if $ALIGN_UIDSETS; then
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "AlignSets muscle"
	AlignSets.py muscle -s "${OUTNAME}-R1_primers-pass_pair-pass.fastq" --exec $MUSCLE_EXEC \
	    --nproc $NPROC --log AlignLogR1.log --outname "${OUTNAME}-R1" \
	    >> $PIPELINE_LOG 2> $ERROR_LOG
	AlignSets.py muscle -s "${OUTNAME}-R2_primers-pass_pair-pass.fastq" --exec $MUSCLE_EXEC \
	    --nproc $NPROC --log AlignLogR2.log --outname "${OUTNAME}-R2" \
	    >> $PIPELINE_LOG 2> $ERROR_LOG
	BCR1_FILE="${OUTNAME}-R1_align-pass.fastq"
	BCR2_FILE="${OUTNAME}-R2_align-pass.fastq"
else
	BCR1_FILE="${OUTNAME}-R1_primers-pass_pair-pass.fastq"
	BCR2_FILE="${OUTNAME}-R2_primers-pass_pair-pass.fastq"
fi

# Build UID consensus sequences
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "BuildConsensus"
if $BC_ERR_FLAG; then
    if $BC_PRCONS_FLAG; then
        BuildConsensus.py -s $BCR1_FILE --bf BARCODE --pf PRIMER --prcons $BC_PRCONS \
            -q $BC_QUAL --maxerror $BC_MAXERR --maxgap $BC_MAXGAP \
            --nproc $NPROC --log ConsensusLogR1.log \
            --outname "${OUTNAME}-R1" >> $PIPELINE_LOG 2> $ERROR_LOG
    else
        BuildConsensus.py -s $BCR1_FILE --bf BARCODE --pf PRIMER \
            -q $BC_QUAL --maxerror $BC_MAXERR --maxgap $BC_MAXGAP \
            --nproc $NPROC --log ConsensusLogR1.log \
            --outname "${OUTNAME}-R1" >> $PIPELINE_LOG 2> $ERROR_LOG
    fi

	BuildConsensus.py -s $BCR2_FILE --bf BARCODE --pf PRIMER \
	    -q $BC_QUAL --maxerror $BC_MAXERR --maxgap $BC_MAXGAP \
	    --nproc $NPROC --log ConsensusLogR2.log \
	    --outname "${OUTNAME}-R2" >> $PIPELINE_LOG 2> $ERROR_LOG
else
    if $BC_PRCONS_FLAG; then
        BuildConsensus.py -s $BCR1_FILE --bf BARCODE --pf PRIMER --prcons $BC_PRCONS \
            -q $BC_QUAL --maxgap $BC_MAXGAP \
            --nproc $NPROC --log ConsensusLogR1.log \
            --outname "${OUTNAME}-R1" >> $PIPELINE_LOG 2> $ERROR_LOG
    else
        BuildConsensus.py -s $BCR1_FILE --bf BARCODE --pf PRIMER \
            -q $BC_QUAL --maxgap $BC_MAXGAP \
            --nproc $NPROC --log ConsensusLogR1.log \
            --outname "${OUTNAME}-R1" >> $PIPELINE_LOG 2> $ERROR_LOG
    fi

	BuildConsensus.py -s $BCR2_FILE --bf BARCODE --pf PRIMER \
    	-q $BC_QUAL --maxgap $BC_MAXGAP \
    	--nproc $NPROC --log ConsensusLogR2.log \
    	--outname "${OUTNAME}-R2" >> $PIPELINE_LOG 2> $ERROR_LOG
fi

# Assign UIDs to read 1 sequences
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "PairSeq"
PairSeq.py -1 "${OUTNAME}-R2_consensus-pass.fastq" -2 "${OUTNAME}-R1_consensus-pass.fastq" \
    --coord presto >> $PIPELINE_LOG 2> $ERROR_LOG

# Assemble paired ends via mate-pair alignment
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "AssemblePairs align"

if $BC_PRCONS_FLAG; then
    PRFIELD="PRCONS"
else
    PRFIELD="PRIMER"
fi

if $AP_ALN_SCANREV; then
    AssemblePairs.py align -1 "${OUTNAME}-R2_consensus-pass_pair-pass.fastq" \
        -2 "${OUTNAME}-R1_consensus-pass_pair-pass.fastq" --1f CONSCOUNT --2f $PRFIELD CONSCOUNT \
        --coord presto --rc tail --minlen $AP_ALN_MINLEN --maxerror $AP_ALN_MAXERR \
        --alpha $AP_ALN_ALPHA --nproc $NPROC --log AssembleAlignLog.log \
        --outname "${OUTNAME}-ALN" --scanrev --failed >> $PIPELINE_LOG 2> $ERROR_LOG
else
    AssemblePairs.py align -1 "${OUTNAME}-R2_consensus-pass_pair-pass.fastq" \
        -2 "${OUTNAME}-R1_consensus-pass_pair-pass.fastq" --1f CONSCOUNT --2f $PRFIELD CONSCOUNT \
        --coord presto --rc tail --minlen $AP_ALN_MINLEN --maxerror $AP_ALN_MAXERR \
        --alpha $AP_ALN_ALPHA --nproc $NPROC --log AssembleAlignLog.log \
        --outname "${OUTNAME}-ALN" --failed >> $PIPELINE_LOG 2> $ERROR_LOG
fi

# Assemble paired ends via alignment against V-region reference database
if $REFERENCE_ASSEMBLY; then
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "AssemblePairs reference"
    AssemblePairs.py reference -1 "${OUTNAME}-ALN-1_assemble-fail.fastq" \
        -2 "${OUTNAME}-ALN-2_assemble-fail.fastq" -r $REF_FILE \
        --1f CONSCOUNT --2f $PRFIELD CONSCOUNT --coord presto \
        --minident $AP_REF_MINIDENT --evalue $AP_REF_EVALUE --maxhits $AP_REF_MAXHITS \
        --nproc $NPROC --log AssembleReferenceLog.log --outname "${OUTNAME}-REF" \
        --exec $USEARCH_EXEC --failed >> $PIPELINE_LOG 2> $ERROR_LOG
    cat "${OUTNAME}-ALN_assemble-pass.fastq" "${OUTNAME}-REF_assemble-pass.fastq" > \
        "${OUTNAME}-CAT_assemble-pass.fastq"
    PH_FILE="${OUTNAME}-CAT_assemble-pass.fastq"
else
    PH_FILE="${OUTNAME}-ALN_assemble-pass.fastq"
fi

# Mask low quality positions
if $MASK_LOWQUAL; then
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "FilterSeq maskqual"
    FilterSeq.py maskqual -s $PH_FILE -q $FS_MASK --nproc $NPROC \
        --outname "${OUTNAME}-MQ" --log MaskqualLog.log \
        >> $PIPELINE_LOG 2> $ERROR_LOG
    PH_FILE="${OUTNAME}-MQ_maskqual-pass.fastq"
fi

if $ALIGN_CREGION; then
    # Annotate with internal C-region
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "MaskPrimers align"
    MaskPrimers.py align -s $PH_FILE -p $MP_CREGION_PRIMERS \
    --maxlen $MP_CREGION_MAXLEN --maxerror $MP_CREGION_MAXERR --mode tag --revpr --skiprc \
    --failed --log CRegionLog.log --outname "${OUTNAME}-CR" --nproc $NPROC \
    >> $PIPELINE_LOG 2> $ERROR_LOG

    # Renamer primer field
    printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseHeaders rename"
    ParseHeaders.py rename -s "${OUTNAME}-CR_primers-pass.fastq" -f PRIMER -k CREGION \
        --outname "${OUTNAME}-CR" > /dev/null 2> $ERROR_LOG

    PH_FILE="${OUTNAME}-CR_reheader.fastq"
    CREGION_FIELD="CREGION"
else
    CREGION_FIELD=""
fi

# Rewrite header with minimum of CONSCOUNT
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseHeaders collapse"
ParseHeaders.py collapse -s $PH_FILE -f CONSCOUNT --act min \
    --outname "${OUTNAME}-FIN" > /dev/null 2> $ERROR_LOG

# Remove duplicate sequences
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "CollapseSeq"
if $CS_KEEP; then
    CollapseSeq.py -s "${OUTNAME}-FIN_reheader.fastq" -n $CS_MISS \
    --uf PRCONS $CREGION_FIELD --cf CONSCOUNT --act sum --inner \
    --keepmiss --outname "${OUTNAME}-FIN" >> $PIPELINE_LOG 2> $ERROR_LOG
else
    CollapseSeq.py -s "${OUTNAME}-FIN_reheader.fastq" -n $CS_MISS \
    --uf PRCONS $CREGION_FIELD --cf CONSCOUNT --act sum --inner \
    --outname "${OUTNAME}-FIN" >> $PIPELINE_LOG 2> $ERROR_LOG
fi

# Filter to sequences with at least 2 supporting sources
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "SplitSeq group"
SplitSeq.py group -s "${OUTNAME}-FIN_collapse-unique.fastq" -f CONSCOUNT --num 2 \
    >> $PIPELINE_LOG 2> $ERROR_LOG

# Create table of final repertoire
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseHeaders table"
ParseHeaders.py table -s "${OUTNAME}-FIN_reheader.fastq" \
    -f ID PRCONS $CREGION_FIELD CONSCOUNT --outname "Final" \
    >> $PIPELINE_LOG 2> $ERROR_LOG
ParseHeaders.py table -s "${OUTNAME}-FIN_collapse-unique.fastq" \
    -f ID PRCONS $CREGION_FIELD CONSCOUNT DUPCOUNT --outname "Final-Unique" \
    >> $PIPELINE_LOG 2> $ERROR_LOG
ParseHeaders.py table -s "${OUTNAME}-FIN_collapse-unique_atleast-2.fastq" \
    -f ID PRCONS $CREGION_FIELD CONSCOUNT DUPCOUNT --outname "Final-Unique-Atleast2" \
    >> $PIPELINE_LOG 2> $ERROR_LOG

# Process log files
printf "  %2d: %-*s $(date +'%H:%M %D')\n" $((++STEP)) 24 "ParseLog"
if $FILTER_LOWQUAL; then
    ParseLog.py -l QualityLogR[1-2].log -f ID QUALITY > /dev/null &
fi
ParseLog.py -l PrimerLogR[1-2].log -f ID BARCODE PRIMER ERROR \
    > /dev/null  2> $ERROR_LOG &
ParseLog.py -l ConsensusLogR[1-2].log -f BARCODE SEQCOUNT CONSCOUNT PRIMER PRCONS PRCOUNT PRFREQ ERROR \
    > /dev/null  2> $ERROR_LOG &
ParseLog.py -l AssembleAlignLog.log -f ID LENGTH OVERLAP ERROR PVALUE FIELDS1 FIELDS2 \
    > /dev/null  2> $ERROR_LOG &
if $REFERENCE_ASSEMBLY; then
    ParseLog.py -l AssembleReferenceLog.log -f ID REFID LENGTH OVERLAP GAP EVALUE1 EVALUE2 IDENTITY FIELDS1 FIELDS2 \
    > /dev/null  2> $ERROR_LOG &
fi
if $MASK_LOWQUAL; then
    ParseLog.py -l MaskqualLog.log -f ID MASKED > /dev/null  2> $ERROR_LOG &
fi
if $ALIGN_CREGION; then
    ParseLog.py -l CRegionLog.log -f ID PRIMER ERROR \
        > /dev/null  2> $ERROR_LOG &
fi
wait

# Zip intermediate and log files
if $ZIP_FILES; then
    LOG_FILES_ZIP=$(ls *LogR[1-2].log *Log.log)
    tar -zcf LogFiles.tar $LOG_FILES_ZIP
    rm $LOG_FILES_ZIP

    TEMP_FILES_ZIP=$(ls *.fastq | grep -v "FIN_reheader.fastq\|FIN_collapse-unique.fastq\|FIN_collapse-unique_atleast-2.fastq")
    tar -zcf TempFiles.tar $TEMP_FILES_ZIP
    rm $TEMP_FILES_ZIP
fi

# End
printf "DONE\n\n"
cd ../

