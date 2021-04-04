#!/usr/bin/env python3
import sys
import os
import argparse
import subprocess

def get_bedcov_genome(bedfile, bamfile):
    bedcov_run = subprocess.run(['samtools', 'bedcov', bedfile, bamfile], universal_newlines=True,stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    bedcov = bedcov_run.stdout
    bedcov = bedcov.strip()
    bedcov_list = bedcov.split("\n")
    genome_gene_cov = dict()
    for line in bedcov_list:
        line = line.strip()
        split_line = line.split("\t")
        gene_id = split_line[3]
        if gene_id not in gene_OG: continue
        OG_id = gene_OG[gene_id]
        gene_start = int(split_line[1])
        gene_end = int(split_line[2])
        gene_length = gene_end - gene_start
        mapped_reads = int(split_line[4])
        gene_cov = mapped_reads/gene_length
        genome_gene_cov[gene_id] = gene_cov
    return(genome_gene_cov)
    
def check_file_exists(file):
    try:
        fh = open(file)
    except:
        print("Cant find/open this file: ", file)
        print("Exiting script!")
        exit()

def print_to_file(outfile, sdp,sdp_bam_genefam_cov):
    fh_outfile = open(outfile, 'a')
    sdp_ref_pos = OG_ref_pos[sdp]
    sorted_pos = sorted(sdp_ref_pos.items(), key=lambda x: x[1]) #Tuple (OG-pos pairs)
    for bamfile in bamfiles:
        for ele in sorted_pos:
            OG_id = ele[0][0:-1] #Trim off colon from id
            start_pos = str(ele[1])
            if bamfile.find('/') != -1: #Check if a directory was provided for the bam-file. If so, remove the path (so the sample-id in the outfile wont contain the path)
                split_filename = bamfile.split('/')
                sample = split_filename[-1][0:-4]
            else:
                sample = bamfile[0:-4]
            line_out = [sdp, sample, OG_id, start_pos, str(sdp_bam_genefam_cov[sdp][bamfile][ele[0]])]
            line_out_str = "\t".join(line_out)
           
            fh_outfile.write(line_out_str + "\n")
    fh_outfile.close()

#Check software requirements
python_version_major = sys.version_info.major
if python_version_major != 3:
    print("This script required python3! You are running:")
    print("You are using Python {}.{}.".format(sys.version_info.major, sys.version_info.minor))
    print("Exiting script!")
    sys.exit(1)
python_version_minor = sys.version_info.minor
if python_version_minor < 6:
    print("You are running and old version of python (< 3.6). This may cause trouble with the subprocess module")
    print("Exiting script!")
    sys.exit(1)
try:
    samtools_check = subprocess.run(['samtools', 'bedcov'], universal_newlines=True,stdout=subprocess.PIPE, stderr=subprocess.PIPE)
except:
    print("ERROR: subprocess module calling 'samtools bedcov' returned a bad exit code")
    print("Check the samtools installation from the command-line:")
    print("samtools bedcov")
    print("Exiting script!")
    sys.exit(1)

#Parse input options
parser = argparse.ArgumentParser()
requiredNamed = parser.add_argument_group('required arguments')
requiredNamed.add_argument('-d',metavar="db_metafile",required=True, help="File detailing genome-id and SDP affiliation")
requiredNamed.add_argument('-l', metavar="bamfile_list",required=True, help="List of bam-files, one line per file")
requiredNamed.add_argument('-g', metavar='orthofinder_file', required=True, help="Filtered single-copy ortholog gene file (orthofinder format)")
requiredNamed.add_argument('-b', metavar="bedfile_dir", required=True, help="Directory conaining bed-files for genomes in db")
args = vars(parser.parse_args())
if (args['d']):
    database_metafile = args['d']
if (args['b']):
    bamfile_list = args['l']
if (args['g']):
    ortho_file = args['g']
if (args['b']):
    bedfile_dir = args['b']
if os.path.isdir(bedfile_dir) == False:
   print("The specified bed-file directory does not exist:", bedfile_dir)
   print("Exiting script")
   exit()

#Read the database metafile, store sdp-affiliation and sdp-ref ids in dictionaries
db_dict = dict() #genome - sdp
sdp_ref = dict()
check_file_exists(database_metafile)
fh_metafile = open(database_metafile)
for line in fh_metafile:
    line = line.strip()
    split_line = line.split("\t")
    genome_id = split_line[0]
    sdp = split_line[2]
    ref_stat = split_line[3]
    db_dict[genome_id] = sdp
    if ref_stat == "Ref":
        sdp_ref[sdp] = genome_id
fh_metafile.close()

#Read the bam-file list, save filenames in list
bamfiles = list()
check_file_exists(bamfile_list)
fh_bamlist = open(bamfile_list)
for line in fh_bamlist:
    line = line.strip()
    if len(line) == 0: continue #Check for empty lines
    check_file_exists(line)
    bamfiles.append(line)
fh_bamlist.close()

#Read the orthofinder-file, get genome-ids per SDP and gene-family members per SDP. Store OG-family affiliation for all gene-ids.
check_file_exists(ortho_file)
fh_orthofile = open(ortho_file)
sdp_genomes = dict() #Genome-ids contained within each SDP in orthofinder file (SDP - genome_id - 1)
gene_OG = dict() #Family affiliation of all genes in orthofinder file
sdp_OG_genes = dict() #Gene-members for each OG, for each SDP (SDP - OG_id -gene_list)
for line in fh_orthofile:
    line = line.strip()
    split_line = line.split()
    OG_id = split_line.pop(0)
    for gene in split_line:
        gene_OG[gene] = OG_id
        split_gene = gene.split('_')
        genome_id = split_gene[0]
        sdp = db_dict[genome_id]
        if sdp not in sdp_genomes:
            sdp_genomes[sdp] = dict()
        sdp_genomes[sdp][genome_id] = 1
        if sdp not in sdp_OG_genes:
            sdp_OG_genes[sdp] = dict()
        if OG_id not in sdp_OG_genes[sdp]:
            sdp_OG_genes[sdp][OG_id] = list()
        sdp_OG_genes[sdp][OG_id].append(gene)
fh_orthofile.close()

#Read the bed-files for the SDP reference genomes, get the start-position for each gene-family
cwd = os.getcwd()
os.chdir(bedfile_dir)
OG_ref_pos = dict()
for sdp in sdp_genomes.keys():
    ref_genome = sdp_ref[sdp]
    bedfile = ref_genome + ".bed"
    check_file_exists(bedfile)
    fh_bedfile = open(bedfile)
    if sdp not in OG_ref_pos:
        OG_ref_pos[sdp] = dict()
    for line in fh_bedfile:
        line = line.strip()
        split_line = line.split("\t")
        gene_id = split_line[3]
        start_pos = split_line[1]
        if gene_id not in gene_OG: continue
        OG_id = gene_OG[gene_id]
        OG_ref_pos[sdp][OG_id] = int(start_pos)
    fh_bedfile.close()
os.chdir(cwd)

#Prepare for outfile, print the header
if ortho_file.find('/') != -1: #Check if a directory was provided for the orthofinder-file. If so, remove the path (so outfile will be printed in the run-dir)
    split_filename = ortho_file.split('/')
    ortho_file = split_filename[-1]
split_filename = ortho_file.split('.')
outfile = split_filename[0] + "_corecov.txt"
fh_outfile = open(outfile, 'w')
header = ["SDP","Sample","OG", "Ref_pos", "Coverage"]
header_str = "\t".join(header)
fh_outfile.write(header_str + "\n")
fh_outfile.close()

#Get the SDP-coverage of all gene-families in orthofile, for all listed bam-files
sdp_bam_genefam_cov = dict()  #sdp - bamfile - OG - summed_cov
gene_cov = dict()
sdp_list = list(sdp_genomes.keys())
sdp_list.sort()
for sdp in sdp_list:
    print("Working on SDP:", sdp)
    sdp_bam_genefam_cov[sdp] = dict()
    genomes = sdp_genomes[sdp]
    for bamfile in bamfiles:
        print("\tProcessing bamfile:",bamfile)
        sdp_bam_genefam_cov[sdp][bamfile] = dict()
        #For each genome, get coverage on OG genes, store in gene-cov dict
        for genome in genomes.keys():
            bedfile = bedfile_dir + '/' + genome + '.bed'
            check_file_exists(bedfile)
            fh_bedfile = open(bedfile)
            print("\t\tGenome:", genome)
            gene_cov_genome = get_bedcov_genome(bedfile, bamfile)
            gene_cov.update(gene_cov_genome)
        print("\tSumming up SDP-coverage for each gene-family..") 
        OG_fams = sdp_OG_genes[sdp]   
        for OG_id in OG_fams.keys():
            OG_genes = OG_fams[OG_id]
            genefam_cov = 0
            for gene in OG_genes:
                genefam_cov += gene_cov[gene]
                sdp_bam_genefam_cov[sdp][bamfile][OG_id]= round(genefam_cov,2)
    print_to_file(outfile, sdp, sdp_bam_genefam_cov)































