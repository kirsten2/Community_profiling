Community profiling of the honey bee gut microbiota, using metagenomic data
=======

This repository contains a pipeline for quantifying the relative abundance of bacterial species  of the honey bee gut microbiota, using metagenomic data.

If you are using the pipeline, please cite:

> Kirsten Maren Ellegaard & Philipp Engel. **Genomic diversity landscape of the honey bee gut microbiota**; _Nature Communications_ **10**, Article number: 446 (2019).
> PMID: 30683856;
> doi:[10.1038/s41467-019-08303-0](https://www.nature.com/articles/s41467-019-08303-0)

> Kirsten Maren Ellegaard, Shota Suenami, Ryo Miyasaki, Philipp Engel. **Vast differences in strain-level diversity in the gut microbiota of two closely related honey bee species**; _Current Biology_ **10**, Epub 2020 Jun 11.
> PMID: 32531278;
> doi: [10.1016/j.cub.2020.04.070](https://www.cell.com/current-biology/fulltext/S0960-9822(20)30586-8)
 
About community profiling on the honey bee gut microbiota: what and why
----------

The honey bee gut microbiota is an emerging insect model for studying the evolution and function of the gut microbiota (see fx. [10.1038/nrmicro.2016.43](https://pubmed.ncbi.nlm.nih.gov/27140688/)). Indeed, a large number of studies have been published, investigating the composition of the honey bee gut microbiota, both under natural conditions and in the lab. However, it has by now been firmly established that the microbiota is composed of highly diverse bacterial strains, which cannot be distinguished or functionally characterised with 16S rRNA data alone. Indeed, most  of the16S rRNA phylotypes (> 97% 16S rRNA) colonising the honey bee gut are composed of multiple highly divergent species (see fx. doi:[10.1038/s41467-019-08303-0](https://www.nature.com/articles/s41467-019-08303-0)). Using metagenomic data, these species can be accurately quantified, thereby giving a more detailed overview of the community composition.

The pipeline employs a comprehensive genomic database, tailored specifically towards the honey bee gut microbiota [zenodo_link](https://zenodo.org/record/4661061#.YGmkRy0RoRA). Previous studies on honey bees (*Apis mellifera*, *Apis cerana*) have shown that this database recruits about 90% of all metagenomic reads  in most metagenomic samples (excluding host-derived reads). The database also contains genomes derived from other bee species, such as bumble bees, but it has not been tested with metagenomic data for these bee species yet. 

Similarly to several other published metagenomic pipelines, species abundance is estimated based on mapped read coverage to core genes. However, there are a few added quirks that make this pipeline unique :

- Species boundaries have been determined with phylogenomic analysis and validated with metagenomic data. This is of importance, since some of the community members display evidence of ongoing speciation
- Most species in the database are represented by multiple genomes (max 98.5% gANI between genomes). This helps to ensure that reads a recruited with similar efficiency in metagenomic samples harboring distinct strains.
- The pipeline employs core genes inferred at the phylotype-level. By using a large number of core genes (> 700), more accurate abundance estimates can be obtained.
- The pipeline will estimate coverage at the terminus in case of ongoing replication, and thereby also estimate the replication activity ("PTR": peak-to-through ratio)


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