#!/bin/bash
# Script to run MakeDb and ParseDb on multiple inputs
# 
# Author:  Jason Anthony Vander Heiden
# Date:    2015.07.03
#
# Required Arguments:
#   $1 = A two column tab delimited file mapping IMGT zip files (column 1) 
#        to submitted FASTA files (column 2)
#   $2 = Output directory

while read FILE_MAP
do
    FILE_ARRAY=($FILE_MAP)
    BASENAME=$(basename "${FILE_ARRAY[0]}" ".zip")
    MakeDb.py imgt -i "${FILE_ARRAY[0]}" -s "${FILE_ARRAY[1]}" --outdir $2
    ParseDb.py select -d "$2/${BASENAME}_db-pass.tab" -f FUNCTIONAL -u T \
        --outname "${BASENAME}_functional"
    ParseDb.py select -d "$2/${BASENAME}_functional_parse-select.tab" -f V_CALL J_CALL \
        -u "IGH" --logic all --regex --outname "${BASENAME}_functional-heavy"
    ParseDb.py select -d "$2/${BASENAME}_functional_parse-select.tab" -f V_CALL J_CALL \
        -u "IG[LK]" --logic all --regex --outname "${BASENAME}_functional-light"
done < $1

