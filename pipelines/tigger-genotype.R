#!/usr/bin/env Rscript
# Super script to run TIgGER polymorphism detection and genotyping
#
# Author:  Jason Anthony Vander Heiden
# Date:    2018.09.15
#
# Arguments:
#   -d  Change-O formatted TSV (TAB) file.
#   -r  FASTA file containing IMGT-gapped V segment reference germlines.
#       Defaults to /usr/local/share/germlines/imgt/human/vdj/imgt_human_IGHV.fasta.
#   -v  Name of the output field containing genotyped V assignments.
#       Defaults to V_CALL_GENOTYPED.
#   -n  Sample name or run identifier which will be used as the output file prefix.
#       Defaults to a truncated version of the input filename.
#   -o  Output directory.
#       Defaults to current directory.
#   -p  Number of subprocesses for multiprocessing tools.
#       Defaults to the available processing units.
#   -h  Display help.

# Imports
suppressPackageStartupMessages(library("optparse"))
suppressPackageStartupMessages(library("dplyr"))
suppressPackageStartupMessages(library("ggplot2"))
suppressPackageStartupMessages(library("alakazam"))
suppressPackageStartupMessages(library("shazam"))
suppressPackageStartupMessages(library("tigger"))

# Set defaults
NPROC <- parallel::detectCores()

# Define commmandline arguments
opt_list <- list(make_option(c("-d", "--db"), dest="DB",
                             help="Change-O formatted TSV (TAB) file."),
                 make_option(c("-r", "--ref"), dest="REF",
                             default="/usr/local/share/germlines/imgt/human/vdj/imgt_human_IGHV.fasta",
                             help=paste("FASTA file containing IMGT-gapped V segment reference germlines.",
                                        "\n\t\tDefaults to /usr/local/share/germlines/imgt/human/vdj/imgt_human_IGHV.fasta.")),
                 make_option(c("-v", "--vfield"), dest="VFIELD",
                             default="V_CALL_GENOTYPED",
                             help=paste("Name of the output field containing genotyped V assignments.",
                                        "\n\t\tDefaults to V_CALL_GENOTYPED.")),
                 make_option(c("-n", "--name"), dest="NAME",
                             help=paste("Sample name or run identifier which will be used as the output file prefix.",
                                        "\n\t\tDefaults to a truncated version of the input filename.")),
                 make_option(c("-o", "--outdir"), dest="OUTDIR", default=".",
                             help=paste("Output directory.", "Defaults to current directory.")),
                 make_option(c("-p", "--nproc"), dest="NPROC", default=NPROC,
                             help=paste("Number of subprocesses for multiprocessing tools.",
                                        "\n\t\tDefaults to the available processing units.")))
# Parse arguments
opt <- parse_args(OptionParser(option_list=opt_list))

# Check input file
if (!("DB" %in% names(opt))) {
    stop("You must provide a Change-O database file with the -d option.")
}

# Check and fill sample name
if (!("NAME" %in% names(opt))) {
    n <- basename(opt$DB)
    opt$NAME <- tools::file_path_sans_ext(basename(opt$DB))
}

# Create output directory
if (!(dir.exists(opt$OUTDIR))) {
    dir.create(opt$OUTDIR)
}

# Load data
db <- as.data.frame(readChangeoDb(opt$DB))
igv <- readIgFasta(opt$REF)

# Identify polymorphisms and genotype
nv <- findNovelAlleles(db, germline_db=igv, nproc=opt$NPROC)
gt <- inferGenotype(db, germline_db=igv, novel_df=nv)

# Write genotype FASTA file
gt_seq <- genotypeFasta(gt, germline_db=igv, novel_df=nv)
writeFasta(gt_seq, file.path(opt$OUTDIR, paste0(opt$NAME, "_genotype.fasta")))

# Modify allele calls and write db
if (utils::packageVersion("tigger") <= "0.2.11") {
    db <- cbind(db, reassignAlleles(db, gt_seq))
} else {
    db <- reassignAlleles(db, gt_seq)
}

# Rename V call column if necessary
if (opt$VFIELD != "V_CALL_GENOTYPED") {
    db[[opt$VFIELD]] <- db$V_CALL_GENOTYPED
    db <- dplyr::select(db, -V_CALL_GENOTYPED)
}

# Write genotyped data
writeChangeoDb(db, file.path(opt$OUTDIR, paste0(opt$NAME, "_genotyped.tab")))

# Plot genotype
plot_file <- file.path(opt$OUTDIR, paste0(opt$NAME, "_genotype.pdf"))
pdf(plot_file, width=7, height=10, useDingbats=FALSE)
plotGenotype(gt, silent=FALSE)
dev.off()