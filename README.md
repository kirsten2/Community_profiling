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

The honey bee is an emerging insect model for studying the evolution and function of the gut microbiota (see fx. [10.1038/nrmicro.2016.43](https://pubmed.ncbi.nlm.nih.gov/27140688/)). Indeed, a large number of studies have been published, investigating the composition of the honey bee gut microbiota, both under natural conditions and in the lab. However, it has by now been firmly established that the microbiota is composed of highly diverse bacterial strains, which cannot be distinguished or functionally characterised with 16S rRNA data alone. Indeed, most  of the16S rRNA phylotypes (> 97% 16S rRNA) colonising the honey bee gut are composed of multiple highly divergent species (see fx. doi:[10.1038/s41467-019-08303-0](https://www.nature.com/articles/s41467-019-08303-0)). Using metagenomic data, these species can be accurately quantified, thereby providing a more detailed profile of the community composition.

The pipeline employs a comprehensive genomic database, tailored specifically towards the honey bee gut microbiota ([zenodo](https://zenodo.org/record/4661061#.YGmkRy0RoRA)). Previous studies on honey bees (*Apis mellifera*, *Apis cerana*) have shown that this database recruits about 90% of all metagenomic reads  in most metagenomic samples (excluding host-derived reads). The database also contains genomes derived from other bee species, such as bumble bees, but it has not been tested with metagenomic data for these bee species yet. 

Similarly to several other published metagenomic pipelines, species abundance is estimated based on mapped read coverage to core genes. However, there are a few added quirks that make this pipeline unique :

- Species boundaries have been determined with phylogenomic analysis and validated with metagenomic data. This is of importance, since some of the community members display evidence of ongoing speciation.
- Most species in the database are represented by multiple genomes (max 98.5% gANI between genomes). This helps to ensure that reads a recruited with similar efficiency in metagenomic samples harboring distinct strains.
- The pipeline employs core genes inferred at the phylotype-level. By using a large number of core genes (+700), more accurate abundance estimates can be obtained.
- The pipeline will estimate coverage at the terminus in case of ongoing replication, and thereby also estimate the replication activity ("PTR": peak-to-through ratio)

Pre-requisites
--------

This pipeline requires:

* Python 3 (version 3.6 or higher)
* Bash
* R (including packages: "segmented", "plyr")
* [samtools](http://www.htslib.org) 
* [bwa](https://github.com/lh3/bwa) (if using the repository scripts for mapping)

Installation
--------

```bash
git clone https://github.com/kirsten2/Community_profiling.git
cd Community_profiling
export PATH=`pwd`/bin:$PATH
```
Note: in the following examples, it is assumed that the bin directory,```samtools``` and ```bwa mem``` are in the system path.

Quick-start: Running the pipeline with example data
--------

Download the genomic database and an example data-set of two metagenomic samples:

```bash
download_data.py --genome_db --metagenomic_reads
```
**Expected result**: four directories with genomic data for all genomes in the database (```faa_files```,```ffn_files```, ```bed_files```, ```gff_files```), the database file (```genome_db_210402```), the database metafile (```genome_db_metafile_210402.txt```), the Orthofinder directory (containing files of filtered single-copy core gene families) and four files with metagenomic reads (*fastq.tar.gz).

Map the reads to genomic database (using 6 threads), and filter the alignments (minimum read alignment length 50bp):

```bash
mapping.sh -d genome_db_210402 -l read_list.txt -t 6 -m 50
```
\*Note: This can take a while on a regular laptop, be patient..

**Expected result**: Two sorted and indexed bam-files, filtered to contain mapped reads (in this case, reads mapped with an alignment length of 50bp or more).

Calculate mapped read coverage on core gene families for the phylotype *Lactobacillus* "Firm5"\:

```bash
for i in $(ls *bam); do echo $i >> bamfile_list.txt; done
core_cov.py -d genome_db_metafile_210402.txt -l bamfile_list.txt  -g Orthofinder/4_firm5_single_ortho_filt.txt -b bed_files
```
**Expected result**: A text-file (```4_firm5_single_ortho_filt_corecov.txt```) in "long-format", with the summed-up mean coverage of each core gene family, for each metagenomic sample.

Estimate species coverage for the 6 species contained within the phylotype *Lactobacillus* "Firm5"\*, for the two metagenomic samples:

```bash
core_cov.R 4_firm5_single_ortho_filt_corecov.txt
```
**Expected result**: A smaller text-file (```4_firm5_single_ortho_filt_corecov_coord.txt```), with the estimated abundance of each species in each sample, and the "PTR" ratio (if determined). Furthermore, a pdf-file (```4_firm5_single_ortho_filt_corecov.pdf```) with plots depicting the coverage on the core gene families, and the fitted regression line used for the quantification.

Running the pipeline with other data
--------

**Data preparation, mapping and filtering**

Before mapping any reads, make sure to check the quality of the raw data (fx. with [fastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)). If needed, trim the reads and remove adapters (fx. with [Trimmomatic](https://github.com/usadellab/Trimmomatic)).

Reads can be mapped according to Software preference (just ensure that the resulting bam-files are sorted and indexed). For most mapping software, it is prudent to add an additional layer of filtering on the bam-file. For example, ```bwa mem```, will map reads even if only a short fragment of the read is aligned. The bash-script included with this repository (```mapping.sh```) will remove the vast majority of such mappings when setting the alignment length threshold to 50bp or more. It is also possible to filter by "edit-distance" (score related to the number of mis-matches in the mapped alignment). The filtering can be done without using the bash-script, directly on a bam-file, by piping the data with samtools, like so:

```bash
samtools view -h file.bam | filter_bam.py 
```
