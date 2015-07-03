#!/bin/bash
# Super script to run the pRESTO pipeline on AbVitro library v2.0 data 
# 
# Author:  Jason Anthony Vander Heiden, Gur Yaari, Namita Gupta
# Date:    2014.6.2
# 
# Required Arguments:
#   $1 = read 1 file (C-region start sequence)
#   $2 = read 2 file (V-region start sequence)
#   $3 = output directory
#   $4 = number of subprocesses for multiprocessing tools

# Define run parameters
NPROC=$4
LOG_RUNTIMES=true
ZIP_FILES=true
CALC_DIV=true
FS_QUAL=20
FS_MISS=10
MP_UIDLEN=15
MP_MAXERR=0.2
BC_QUAL=0
BC_MAXDIV=0.1
BC_PRCONS=0.6
AP_MAXERR=0.2
AP_ALPHA=0.01
CS_MISS=10

# Define input files
R1_FILE=$(readlink -f $1)
R2_FILE=$(readlink -f $2)
OUTDIR=$3
R1_PRIMER_FILE='/scratch2/kleinstein/oconnor_ms_trafficking/primers/MS_JPrimers.fasta'
R2_PRIMER_FILE='/scratch2/kleinstein/oconnor_ms_trafficking/primers/MS_VPrimers.fasta'

# Define script execution command and log files
mkdir -p $OUTDIR; cd $OUTDIR
RUNLOG="${OUTDIR}/Pipeline.log"
echo '' > $RUNLOG 
if $LOG_RUNTIMES; then
	TIMELOG="${OUTDIR}/Time.log"
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
echo "   1: FilterSeq quality      $(date +'%H:%M %D')"
$RUN FilterSeq.py quality -s $R1_FILE -q $FS_QUAL --nproc $NPROC --outname R1 \
    --outdir . --log QualityLogR1.log --clean >> $RUNLOG
$RUN FilterSeq.py quality -s $R2_FILE -q $FS_QUAL --nproc $NPROC --outname R2 \
    --outdir . --log QualityLogR2.log --clean >> $RUNLOG

# Identify primers and UID 
echo "   2: MaskPrimers score      $(date +'%H:%M %D')"
$RUN MaskPrimers.py score -s R1_quality-pass.fastq -p $R1_PRIMER_FILE --mode cut --start $MP_UIDLEN \
	--barcode --maxerror $MP_MAXERR --nproc $NPROC --log PrimerLogR1.log --clean >> $RUNLOG
$RUN MaskPrimers.py score -s R2_quality-pass.fastq -p $R2_PRIMER_FILE --mode mask --start 0 \
    --maxerror $MP_MAXERR --nproc $NPROC --log PrimerLogR2.log --clean >> $RUNLOG

# Assign UIDs to read 1 sequences
echo "   3: PairSeq                $(date +'%H:%M %D')"
$RUN PairSeq.py -1 R1*primers-pass.fastq -2 R2*primers-pass.fastq -f BARCODE --coord illumina \
	--clean >> $RUNLOG

# Build UID consensus sequences
echo "   5: BuildConsensus         $(date +'%H:%M %D')" 
if $CALC_DIV; then
	$RUN BuildConsensus.py -s R1*pair-pass.fastq --bf BARCODE --pf PRIMER --prcons $BC_PRCONS \
	    -q $BC_QUAL --maxdiv $BC_MAXDIV --nproc $NPROC --log ConsensusLogR1.log --clean >> $RUNLOG
	$RUN BuildConsensus.py -s R2*pair-pass.fastq --bf BARCODE --pf PRIMER \
	    -q $BC_QUAL --maxdiv $BC_MAXDIV --nproc $NPROC --log ConsensusLogR2.log --clean >> $RUNLOG
else
	$RUN BuildConsensus.py -s R1*pair-pass.fastq --bf BARCODE --pf PRIMER --prcons $BC_PRCONS \
    	-q $BC_QUAL --nproc $NPROC --log ConsensusLogR1.log --clean >> $RUNLOG
	$RUN BuildConsensus.py -s R2*pair-pass.fastq --bf BARCODE --pf PRIMER \
    	-q $BC_QUAL --nproc $NPROC --log ConsensusLogR2.log --clean >> $RUNLOG
fi


# Assemble paired ends
echo "   6: AssemblePairs          $(date +'%H:%M %D')" 
$RUN AssemblePairs.py align -1 R2*consensus-pass.fastq -2 R1*consensus-pass.fastq \
    --1f CONSCOUNT --2f PRCONS CONSCOUNT --coord presto --rc tail --maxerror $AP_MAXERR \
    --alpha $AP_ALPHA --nproc $NPROC --log AssembleLog.log --clean >> $RUNLOG
    
# Remove sequences with many Ns
echo "   7: FilterSeq missing      $(date +'%H:%M %D')" 
$RUN FilterSeq.py missing -s *assemble-pass.fastq -n $FS_MISS --inner \
    --nproc $NPROC --log MissingLog.log >> $RUNLOG

# Rewrite header with minimum of CONSCOUNT
echo "   8: ParseHeaders collapse  $(date +'%H:%M %D')"
$RUN ParseHeaders.py collapse -s *missing-pass.fastq -f CONSCOUNT --act min \
    --outname Assembled --fasta > /dev/null

# Remove duplicate sequences
echo "   9: CollapseSeq            $(date +'%H:%M %D')" 
$RUN CollapseSeq.py -s Assembled_reheader.fasta -n $CS_MISS --uf PRCONS \
    --cf CONSCOUNT --act sum --outname Assembled --inner >> $RUNLOG

# Filter to sequences with at least 2 supporting sources
echo "  10: SplitSeq group         $(date +'%H:%M %D')" 
$RUN SplitSeq.py group -s Assembled_collapse-unique.fasta -f CONSCOUNT --num 2 >> $RUNLOG

# Create table of final repertoire
echo "  11: ParseHeaders table     $(date +'%H:%M %D')"
$RUN ParseHeaders.py table -s Assembled_collapse-unique_atleast-2.fasta -f ID PRCONS CONSCOUNT DUPCOUNT >> $RUNLOG

# Process log files
echo "  12: ParseLog               $(date +'%H:%M %D')"
$RUN ParseLog.py -l QualityLogR[1-2].log -f ID QUALITY > /dev/null &
$RUN ParseLog.py -l PrimerLogR[1-2].log -f ID BARCODE PRIMER ERROR > /dev/null &
$RUN ParseLog.py -l ConsensusLogR[1-2].log -f BARCODE SEQCOUNT CONSCOUNT PRIMER PRCOUNT PRFREQ DIVERSITY > /dev/null &
$RUN ParseLog.py -l AssembleLog.log -f ID OVERLAP LENGTH PVAL ERROR HEADFIELDS TAILFIELDS > /dev/null &
$RUN ParseLog.py -l MissingLog.log -f ID MISSING > /dev/null &
wait

if $ZIP_FILES; then
    tar -cf LogFiles.tar *LogR[1-2].log *Log.log
    gzip LogFiles.tar
    rm *LogR[1-2].log *Log.log
    
    tar -cf TempFiles.tar R[1-2]_*.fastq *under* *duplicate* *undetermined* *reheader*
    gzip TempFiles.tar
    rm R[1-2]_*.fastq *under* *duplicate* *undetermined* *reheader*
fi

# End
echo -e "DONE\n" 
cd ../

