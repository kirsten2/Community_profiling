#!/usr/bin/env bash

usage="
bash $(basename "$0") [-h] [-d GENOME_DB] [-l READ_LIST] [-t NUM_THREADS] [-m MATCH_LENGTH] [-e EDIT_DIST]

Map reads to the honey bee gut microbiota database, and generate sorted and indexed bam-files of mapped reads, according to the mapping thresholds specified specified by the user.

The script requires both bwa mem and samtools to be installed, and accessible in path. The following options should be provided:

-d: GENOME_DB. Name of the honey bee gut microbiota genomic database file (required)
-l READ_LIST. Text-file with sample-id and names of paired fastq-files, one line per sample, comma-separated (required)
-t NUM_THREADS. Number of threads to be used with bwa mem and samtools (optional)
-m MATCH_LENGTH. Minimum read alignment length for mapped reads (optional, but see below)
-e EDIT_DIST. Maximum edit distance for mapped reads (optional, but see below)

The genomic database file is a fasta-file containing concatenate sequences of assembly contigs (one sequence per genome). The file will be indexed with bwa mem if needed. 

The read-list should be a plain text-file, containing a chosen sample-id and the names of the paired fastq-files (which may be compressed files), fx.:

Ig13619,Ig13619_paired_R1.fastq.gz,Ig13619_paired_R2.fastq.gz
Ig13641,Ig13641_paired_R1.fastq.gz,Ig13641_paired_R2.fastq.gz

Number of threads is an optional parameter, but beware that it can take a very long time to process the reads without multi-threading.

Filtering thresholds (MATCH_LENGTH, EDIT_DIST) are optional, but at least one of the two must be provided. 

The script will output one sorted and indexed bam-file per sample, containing only mapped reads (as defined by the user).
"

IFS_DEF="$IFS"

#Parse script options
options=':hd:l:t:m:e:'
while getopts $options option; do
    case "${option}" in
        h) echo "$usage"; exit;;
        d) GENOME_DB=${OPTARG};;
         l) READ_LIST=${OPTARG};;
        t) NUM_THREADS=${OPTARG};;
        m) MATCH_LENGTH=${OPTARG};;
        e) EDIT_DIST=${OPTARG};;
       \?) printf "illegal option: -%s\n" "$OPTARG" >&2; echo "$usage" >&2; exit 1;;
    esac
done

#Check that the required arguments have been provided
if [ ! "$GENOME_DB" ] ; then
    echo "ERROR: Please provide the name of the genomic database that will be used for mapping (-d)"
    echo "$usage" >&2; exit 1
fi
if [ ! "$READ_LIST" ]; then
    echo "ERROR: Please provide the name of a text-file containing sample_ids and fastq-files (-l)"
    echo "$usage" >&2; exit 1
fi
if [ ! "$MATCH_LENGTH" ]; then
    MATCH_LENGTH="NA"
fi
if [ ! "$EDIT_DIST" ]; then
    EDIT_DIST="NA"
fi
if [ "$MATCH_LENGTH" == "NA" ] && [ "$EDIT_DIST" == "NA" ]; then
    echo "ERROR: at least one filtering threshold must be provided (-m or -e)"
    echo "$usage" >&2; exit 1
fi  

#Check that the required software is installed, and in path
if ! [ -x "$(command -v bwa mem)" ]; then
    echo 'Error: bwa mem is not installed/not in path. Exiting script!' >&2
    exit 1
fi
if ! [ -x "$(command -v samtools)" ]; then
    echo 'Error: samtools is not installed/not in path. Exiting script' >&2
    exit 1
fi

#Check for existence of mandatory input files
if [ ! -f "$GENOME_DB" ]; then
    echo "The specified genome database file doesnt exist in the run-dir: $GENOME_DB"
    echo "Exiting script!"
    exit 1
fi
if [ ! -f "$READ_LIST" ]; then
    echo "The specified read-list file doesnt exist in the run-dir: $READ_LIST"
    echo "Exiting script!"
    exit 1
fi
while IFS= read -r line; do
    if  [ "$line" ]; then
        IFS=','; read -ra split_line <<< "$line"
        if [ ! -f "${split_line[1]}" ] || [ ! -f "${split_line[2]}" ]; then
                echo "One or both of the provided read-files dont exist in the run-dir:"
                echo "${split_line[1]}, ${split_line[2]}"
                echo "Exiting script!"
                exit 1
            fi
    fi
done < "$READ_LIST"

#Index the genome database file for mapping (if not done already)
INDEX_FILE1="$GENOME_DB.amb"
if [ ! -f  "$INDEX_FILE1" ]; then
    echo "Indexing the genome database"
    bwa index "$GENOME_DB"
fi

#Run the mapping pipeline
while IFS= read -r line; do
    if  [ "$line" ]; then
        IFS=','; read -ra split_line <<< "$line"
        sample_id="${split_line[0]}"
        R1="${split_line[1]}"
        R2="${split_line[2]}"
        IFS="$IFS_DEF"
        outfile=""$sample_id"_filt.bam"
        bwa mem -t "$NUM_THREADS" "$GENOME_DB" "$R1" "$R2" | samtools view -h -F4 --threads 20 - | python3 bin/filter_bam.py -m "$MATCH_LENGTH" -e "$EDIT_DIST"  | samtools sort - --threads 20 -o "$outfile"
        samtools index "$outfile"
    fi
done < "$READ_LIST"


