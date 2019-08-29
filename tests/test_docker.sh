#!/usr/bin/env bats

# Run parameters
VERSION="release"
IMAGE="kleinstein/immcantation:${VERSION}"
DATE=$(date +"%Y.%m.%d")
DATA_DIR=$(realpath data)
RUN_DIR="run/docker-${DATE}-${VERSION}"
NPROC=2
EXT="tab"

# Create output parent
mkdir -p ${RUN_DIR}
RUN_DIR=$(realpath ${RUN_DIR})

# PhiX
@test "preprocess-phix" {
	SAMPLE=HD13M
	READS=/data/sequences/HD13M_10K_R1.fastq
	OUT_DIR="/scratch/phix"

	run docker run -v $DATA_DIR:/data:z -v $RUN_DIR:/scratch:z $IMAGE \
		preprocess-phix -s $READS -o $OUT_DIR -p $NPROC

	[ "$status" -eq 0 ]
}

# AbSeq
@test "presto-abseq" {
	SAMPLE=HD13M
	READS_R1=/data/sequences/HD13M_10K_R1.fastq
	READS_R2=/data/sequences/HD13M_10K_R2.fastq
	YAML=/data/report.yaml
	OUT_DIR="/scratch/abseq"

	run docker run -v $DATA_DIR:/data:z -v $RUN_DIR:/scratch:z $IMAGE \
		presto-abseq -1 $READS_R1 -2 $READS_R2 -y $YAML \
		-n $SAMPLE -o $OUT_DIR -p $NPROC

	[ "$status" -eq 0 ]
}

# Clontech
@test "presto-clontech" {
	SAMPLE=HD13M
	READS_R1=/data/sequences/HD13M_10K_R1.fastq
	READS_R2=/data/sequences/HD13M_10K_R2.fastq
	CREGION=/usr/local/share/protocols/Universal/Human_IG_CRegion_RC.fasta
    VREF=/usr/local/share/igblast/fasta/imgt_human_ig_v.fasta
	OUT_DIR="/scratch/clontech"

    run docker run -v $DATA_DIR:/data:z -v $RUN_DIR:/scratch:z $IMAGE \
        presto-clontech -1 $READS_R1 -2 $READS_R2 -j $CREGION -r $VREF \
        -n $SAMPLE -o $OUT_DIR -p $NPROC

	[ "$status" -eq 0 ]
}

# 10X
@test "changeo-10x" {
	SAMPLE=PBMC2B
	READS=/data/sequences/PBMC2B.fasta
	ANNOTATIONS=/data/sequences/PBMC2B_annotations.csv
	DIST=auto
	OUT_DIR="/scratch/10x"

	run docker run -v $DATA_DIR:/data:z -v $RUN_DIR:/scratch:z $IMAGE \
        changeo-10x -s $READS -a $ANNOTATIONS -x $DIST \
        -n $SAMPLE -o $OUT_DIR -p $NPROC

	[ "$status" -eq 0 ]
}

# IgBLAST
@test "changeo-igblast" {
	SAMPLE=HD13M
	READS="/scratch/abseq/${SAMPLE}-final_collapse-unique_atleast-2.fastq"
	OUT_DIR="/scratch/changeo"

	run docker run -v $DATA_DIR:/data:z -v $RUN_DIR:/scratch:z $IMAGE \
		changeo-igblast -s $READS -n $SAMPLE -o $OUT_DIR -p $NPROC

	[ "$status" -eq 0 ]
}

# TIgGER
@test "tigger-genotype" {
	SAMPLE=HD13M
	DB="/scratch/changeo/${SAMPLE}_db-pass.${EXT}"
	V_FIELD="V_CALL_GENOTYPED"
	GERMLINE_MIN=20
	OUT_DIR="/scratch/changeo"

	run docker run -v $DATA_DIR:/data:z -v $RUN_DIR:/scratch:z $IMAGE \
		tigger-genotype -d $DB -v $V_FIELD -m $GERMLINE_MIN \
		-n $SAMPLE -o $OUT_DIR -p $NPROC

	[ "$status" -eq 0 ]
}

# SHazaM threshold
@test "shazam-threshold" {
	SAMPLE=HD13M
	DB="/scratch/changeo/${SAMPLE}_db-pass.${EXT}"
	OUT_DIR="/scratch/changeo"

	run docker run -v $DATA_DIR:/data:z -v $RUN_DIR:/scratch:z $IMAGE \
		shazam-threshold -d $DB --subsample 5000 --repeats 2 \
        -n $SAMPLE -o $OUT_DIR -p $NPROC

	[ "$status" -eq 0 ]
}

# Change-O cloning
@test "changeo-clone" {
	SAMPLE=HD13M
	DB="/scratch/changeo/${SAMPLE}_db-pass.${EXT}"
	OUT_DIR="/scratch/changeo"
	DIST=0.15

	run docker run -v $DATA_DIR:/data:z -v $RUN_DIR:/scratch:z $IMAGE \
		changeo-clone -d $DB -x $DIST -n $SAMPLE -o $OUT_DIR -p $NPROC

	[ "$status" -eq 0 ]
}
