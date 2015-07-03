#!/bin/bash
# Super script to run the pRESTO pipeline on 454 data using the Jiang et al, 2013 protocol 
#
# Author:  Jason Anthony Vander Heiden, Gur Yaari, Namita Gupta
# Date:    2014.3.19
# 
# Required Arguments:
#   $1 = sequencing read file
#   $2 = MID file
#   $3 = output directory (absolute path)
#   $4 = number of subprocesses for multiprocessing tools

# Define run parameters
ZIP_FILES=true
LEN_STEP=true
MINLEN=250
MINQUAL=20
MAXPRERR=0.2
MAXPRLEN=50
CS_MISS=0
NPROC=$4
        
# Define input files
READ_FILE=$1
MID_FILE=$2
OUTDIR=$3
V_PRIMER_FILE="/scratch2/kleinstein/public_jiang2013_PRJNA176314/primers/SRX190717_VPrimers.fasta"
C_PRIMER_FILE="/scratch2/kleinstein/public_jiang2013_PRJNA176314/primers/SRX190717_CPrimers.fasta"

# Define script execution command and log files
RUNLOG="${OUTDIR}/Pipeline.log"
TIMELOG="${OUTDIR}/Time.log"
RUN="nice -19 /usr/bin/time -o ${TIMELOG} -a -f %C\t%E\t%P\t%Mkb"
#RUN="nice -19"

# Start
mkdir -p $OUTDIR; cd $OUTDIR
echo '' > $RUNLOG; echo '' > $TIMELOG
echo "DIRECTORY:" $FILEDIR
echo "VERSIONS:" >> $RUNLOG
CollapseSeq.py -v >> $RUNLOG
FilterSeq.py -v >> $RUNLOG
MaskPrimers.py -v >> $RUNLOG
ParseHeaders.py -v >> $RUNLOG
ParseLog.py -v >> $RUNLOG
SplitSeq.py -v >> $RUNLOG

# Filter short and low quality reads
if $LEN_STEP; then
	echo "   1: FilterSeq length     $(date +'%H:%M %D')"
	$RUN FilterSeq.py length -s $READ_FILE -n $MINLEN --nproc $NPROC \
    	--log FilterLen.log --clean --outname STEP1 --outdir . >> $RUNLOG

	echo "   2: FilterSeq quality    $(date +'%H:%M %D')"
	$RUN FilterSeq.py quality -s STEP1_length-pass.fastq -q $MINQUAL --nproc $NPROC \
    	--log FilterQual.log --clean >> $RUNLOG
else
	echo "   2: FilterSeq quality    $(date +'%H:%M %D')"
	$RUN FilterSeq.py quality -s $READ_FILE -q $MINQUAL --nproc $NPROC \
    	--log FilterQual.log --clean --outname STEP1 --outdir . >> $RUNLOG
fi

# Remove sample barcode and primers
echo "   3: MaskPrimers score    $(date +'%H:%M %D')"
$RUN MaskPrimers.py score -s STEP1*quality-pass.fastq -p $MID_FILE \
    --mode cut --start 0 --maxerror $MAXPRERR --nproc $NPROC --log PrimerMID.log --clean >> $RUNLOG

echo "   4: MaskPrimers align    $(date +'%H:%M %D')"
$RUN MaskPrimers.py align -s STEP1*quality-pass_primers-pass.fastq -p $V_PRIMER_FILE \
    --mode mask --maxerror $MAXPRERR --maxlen $MAXPRLEN --nproc $NPROC --log PrimerV.log --clean >> $RUNLOG

echo "   5: MaskPrimers align    $(date +'%H:%M %D')"
$RUN MaskPrimers.py align -s STEP1*primers-pass_primers-pass.fastq -p $C_PRIMER_FILE \
    --mode mask --maxerror $MAXPRERR --maxlen $MAXPRLEN --revpr --skiprc --nproc $NPROC \
    --outname STEP2 --log PrimerC.log --clean >> $RUNLOG

# Split by primers and group by barcode
echo "   6: ParseHeaders expand  $(date +'%H:%M %D')" 
$RUN ParseHeaders.py expand -s STEP2_primers-pass.fastq -f PRIMER > /dev/null

echo "   7: ParseHeaders rename  $(date +'%H:%M %D')"
$RUN ParseHeaders.py rename -s STEP2_primers-pass_reheader.fastq \
    -f PRIMER1 PRIMER2 PRIMER3 -k BARCODE VPRIMER CPRIMER --outname STEP3 > /dev/null

echo "   8: SplitSeq group       $(date +'%H:%M %D')"
$RUN SplitSeq.py group -s STEP3_reheader.fastq -f BARCODE --fasta >> $RUNLOG

# Filter duplicates and singletons
echo "   9: CollapseSeq          $(date +'%H:%M %D')"
$RUN CollapseSeq.py -s *reheader_MID*.fasta -n $CS_MISS --inner --uf CPRIMER \
    --cf BARCODE VPRIMER --act set set >> $RUNLOG

echo "  10: SplitSeq group       $(date +'%H:%M %D')"
$RUN SplitSeq.py group -s *unique.fasta -f DUPCOUNT --num 2 >> $RUNLOG

# Process log files
echo "  11: ParseLog             $(date +'%H:%M %D')"
$RUN ParseLog.py -l FilterLen.log -f ID LENGTH > /dev/null &
$RUN ParseLog.py -l FilterQual.log -f ID QUALITY > /dev/null &
$RUN ParseLog.py -l Primer*.log -f ID PRSTART PRIMER ERROR > /dev/null &
$RUN ParseLog.py -l Pipeline.log -f END SEQUENCES PAIRS SETS PASS FAIL UNIQUE DUPLICATE UNDETERMINED PARTS OUTPUT > /dev/null &
wait

# Zip intermediate and log files
if $ZIP_FILES; then
	tar -cf LogFiles.tar Filter*.log Primer*.log 
	gzip LogFiles.tar
	rm Filter*.log Primer*.log
	
	tar -cf TempFiles.tar *.fastq *under* *duplicate* *undetermined*
    gzip TempFiles.tar
    rm *.fastq *under* *duplicate* *undetermined*
fi

# End
echo -e "DONE\n" 
cd ../
