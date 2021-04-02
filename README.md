# Community_profiling

#Download the honey bee gut microbiota genomic database and some example metagenomic reads

python3 bin/download_data.py --genome_db
python3 bin/downépad_data.py --metagenomic_reads

#Map reads to genomic database and filter alignments (setting minimum read alignment length to 50bp)

#NOTE: add check for python-script? 
bash bin/mapping.sh -d genome_db_210402 -l read_list.txt -t 6 -m 50

#Calculate mapped read coverage on filtered single-copy core gene families 

for i in $(ls *bam); do echo $i >> bamfile_list.txt; done
python3 bin/core_cov.py -d genome_db_metafile_210402.txt -l bamfile_list.txt  -g Orthofinder/4_firm5_single_ortho_filt.txt -b bed_files


#Estimate terminus coverage (or median coverage)

Rscript bin/core_cov.R 4_firm5_single_ortho_filt_corecov.txt --no_plots
Rscript bin/core_cov.R 4_firm5_single_ortho_filt_corecov.txt 