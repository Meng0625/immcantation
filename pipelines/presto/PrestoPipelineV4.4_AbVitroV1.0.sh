#!/bin/bash
# Super script to run the pRESTO pipeline on AbVitro library v1.0 data 
# 
# Author:  Jason Anthony Vander Heiden, Gur Yaari, Namita Gupta
# Date:    2013.10.29
# 
# Required Arguments:
#   $1 = read 1 file (J start sequence)
#   $2 = read 2 file (V start sequence)
#   $3 = output directory (absolute path)
#   $4 = number of subprocesses for multiprocessing tools

# Define run parameters
ZIP_FILES=true
PRIMER_STEP=true
CALC_DIV=true
MAXDIV=0.1
PRCONS=0.6
MINQUAL=20
R1_MAXERR=0.2 
R2_MAXERR=0.2
AP_MAXERR=0.2 
ALPHA=0.1
FS_MISS=20
CS_MISS=0
NPROC=$4
        
# Define input files
R1_FILE=$1
R2_FILE=$2
OUTDIR=$3
R1_PRIMER_FILE='/scratch2/kleinstein/montgomery_wnv/primers/Primers_IGHJ_RT.fasta'
R2_PRIMER_FILE='/scratch2/kleinstein/montgomery_wnv/primers/Primers_VFR2.fasta'
R2_OFFSET_FILE='/scratch2/kleinstein/montgomery_wnv/primers/Primers_VFR2_offsets-reverse.tab'

# Define script execution command and log files
RUNLOG="${OUTDIR}/Pipeline.log"
TIMELOG="${OUTDIR}/Time.log"
RUN="nice -19 /usr/bin/time -o ${TIMELOG} -a -f %C\t%E\t%P\t%Mkb"
#RUN="nice -19"

# Start
mkdir -p $OUTDIR; cd $OUTDIR
echo '' > $RUNLOG; echo '' > $TIMELOG 
echo "DIRECTORY:" $OUTDIR

# Filter low quality reads
echo "   1: FilterSeq quality      $(date +'%H:%M %D')"
$RUN FilterSeq.py quality -s $R1_FILE -q $MINQUAL --nproc $NPROC --outname R1 \
    --outdir . --log QualityLogR1.log --clean >> $RUNLOG
$RUN FilterSeq.py quality -s $R2_FILE -q $MINQUAL --nproc $NPROC --outname R2 \
    --outdir . --log QualityLogR2.log --clean >> $RUNLOG

if $PRIMER_STEP; then
	# Identify primers and UID 
	echo "   2: MaskPrimers score      $(date +'%H:%M %D')"
	$RUN MaskPrimers.py score -s R1_quality-pass.fastq -p $R1_PRIMER_FILE --mode cut --start 12 --barcode \
	    --maxerror $R1_MAXERR --nproc $NPROC --log PrimerLogR1.log --clean >> $RUNLOG
	$RUN MaskPrimers.py score -s R2_quality-pass.fastq -p $R2_PRIMER_FILE --mode cut --start 0 \
	    --maxerror $R1_MAXERR --nproc $NPROC --log PrimerLogR2.log --clean >> $RUNLOG
	
	# Assign UIDs to read 1 sequences
	echo "   3: PairSeq                $(date +'%H:%M %D')"
	$RUN PairSeq.py -1 R1*primers-pass.fastq -2 R2*primers-pass.fastq -f BARCODE --coord illumina --clean >> $RUNLOG
else
	# Assign UIDs to read 1 sequences
	echo "   3: PairSeq                $(date +'%H:%M %D')"
	$RUN PairSeq.py -1 R1_quality-pass.fastq -2 R2_quality-pass.fastq -f BARCODE --coord illumina --clean >> $RUNLOG
fi

# Align sequence start positions by primer alignments
echo "   4: AlignSets              $(date +'%H:%M %D')" 
$RUN AlignSets.py offset -s R2*pair-pass.fastq -d $R2_OFFSET_FILE --bf BARCODE --pf PRIMER --nproc $NPROC >> $RUNLOG

# Build UID consensus sequences
echo "   5: BuildConsensus         $(date +'%H:%M %D')" 
if $CALC_DIV; then
	$RUN BuildConsensus.py -s R1*pair-pass.fastq --bf BARCODE --pf PRIMER --prcons $PRCONS \
	    -q $MINQUAL --maxdiv $MAXDIV --nproc $NPROC --log ConsensusLogR1.log --clean >> $RUNLOG
	$RUN BuildConsensus.py -s R2*align-pass.fastq --bf BARCODE --pf PRIMER \
	    -q $MINQUAL --maxdiv $MAXDIV --nproc $NPROC --log ConsensusLogR2.log --clean >> $RUNLOG
else
	$RUN BuildConsensus.py -s R1*pair-pass.fastq --bf BARCODE --pf PRIMER --prcons $PRCONS \
    	-q $MINQUAL --nproc $NPROC --log ConsensusLogR1.log --clean >> $RUNLOG
	$RUN BuildConsensus.py -s R2*align-pass.fastq --bf BARCODE --pf PRIMER \
    	-q $MINQUAL --nproc $NPROC --log ConsensusLogR2.log --clean >> $RUNLOG
fi

# Assemble paired ends
echo "   6: AssemblePairs          $(date +'%H:%M %D')" 
$RUN AssemblePairs.py align -1 R2*consensus-pass.fastq -2 R1*consensus-pass.fastq \
    --1f CONSCOUNT --2f PRCONS CONSCOUNT --coord presto --rc tail --maxerror $AP_MAXERR --alpha $ALPHA \
    --nproc $NPROC --log AssembleLog.log --outname Assembled --clean >> $RUNLOG

# Remove sequences with many Ns
echo "   7: FilterSeq missing      $(date +'%H:%M %D')" 
$RUN FilterSeq.py missing -s Assembled_assemble-pass.fastq -n $FS_MISS --inner \
    --nproc $NPROC --log MissingLog.log >> $RUNLOG

# Rewrite header with minimum of CONSCOUNT
echo "   8: ParseHeaders collapse  $(date +'%H:%M %D')"
$RUN ParseHeaders.py collapse -s Assembled*missing-pass.fastq -f CONSCOUNT --act min --fasta > /dev/null

# Remove duplicate sequences
echo "   9: CollapseSeq            $(date +'%H:%M %D')" 
$RUN CollapseSeq.py -s Assembled*reheader.fasta -n $CS_MISS --uf PRCONS \
    --cf CONSCOUNT --act sum --outname Assembled --inner >> $RUNLOG

# Filter to sequences with at least 2 supporting sources
echo "  10: SplitSeq group         $(date +'%H:%M %D')" 
$RUN SplitSeq.py group -s Assembled_collapse-unique.fasta -f CONSCOUNT --num 2 >> $RUNLOG

# Create table of final repertoire
echo "  11: ParseHeaders table     $(date +'%H:%M %D')"
$RUN ParseHeaders.py table -s Assembled_collapse-unique_atleast-2.fasta -f ID PRCONS CONSCOUNT DUPCOUNT > /dev/null

# Process log files
echo "  12: ParseLog               $(date +'%H:%M %D')"
$RUN ParseLog.py -l QualityLogR[1-2].log -f ID QUALITY > /dev/null &
if $PRIMER_STEP; then
	$RUN ParseLog.py -l PrimerLogR[1-2].log -f ID BARCODE PRIMER ERROR > /dev/null &
fi
$RUN ParseLog.py -l ConsensusLogR[1-2].log -f BARCODE SEQCOUNT CONSCOUNT PRIMER PRCOUNT PRFREQ DIVERSITY > /dev/null &
$RUN ParseLog.py -l AssembleLog.log -f ID OVERLAP LENGTH PVAL ERROR > /dev/null &
$RUN ParseLog.py -l MissingLog.log -f ID MISSING > /dev/null &
$RUN ParseLog.py -l Pipeline.log -f END SEQUENCES PAIRS SETS PASS FAIL UNIQUE DUPLICATE UNDETERMINED PARTS OUTPUT > /dev/null &
wait

# Zip intermediate and log files
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

