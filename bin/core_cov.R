#!/usr/bin/env Rscript
options(warn=1)
rm(list=ls())


#Usage: Rscript core_cov.R api_corecov.txt --no_plots

#This R-script will estimate the coverage at the terminus, using the summed core gene family coverages. If the cov-ter cannot be properly estimated (fx. due to draft genome status or lack of replication), an estimate will be generated using the median coverage across core gene families, and the PTR is set to NA. If more than 20% of the core gene families have no coverage, the abundance will be set to zero. As output, a tabular file is generated (including the cov-ter/median cov, and PTR), and a pdf-file with plots for visual validation.

#Script help-usage
script_usage <- function() {
    cat("\nUsage: Rscript core_cov.R 4_firm5_single_ortho_filt_corecov.txt   [--no_plots]\n", fill=TRUE)
    cat("Input-file should correspond to the output-file generated by 'core_cov.py'", fill=TRUE)
    cat("If the --no_plots flag is provided, all plots will be skipped", fill=TRUE)
}

#Parse script arguments
Args <- commandArgs(trailingOnly=TRUE)
if (length(Args) == 0 || Args[1] == "--help") {
     script_usage()
     quit()
}
do_plots <-  1
if (length(Args) == 2 && Args[2] == "--no_plots") {
    do_plots <- 0
}

#Check if the R-package "segmented" is installed
if (! require("segmented")) {
    print("The R-package 'segmented' is not installed! Exiting script")
    quit()
} else {
    require("segmented")
}
if (! require("plyr")) {
    print("The R-package 'plyr' is not installed! Exiting script")
    quit()
} else {
    require("plyr")
}

##Functions for script

#Calculate the fraction of core-genes with coverage of at least 1

filter_corecov_fraction <- function(x) {
    nb_genes <- length(x)
    genes_cov <- length(which(x > 1))
    fraction_cov <- genes_cov/nb_genes  
    return(fraction_cov)
}

#Get indices for outliers, from a vector of gene coverages. Returns indices for values that are deviating no more than 2 times the median 

cov_outlier_indices <- function(x) {
    median_cov <- median(x)
    diff_from_median <- abs(x -median_cov)
    filt_gene_indices <- which(diff_from_median < 2*median_cov)
    return(filt_gene_indices)
}

#Fit segmented regression lines. Done with the package "segmented". The estimated break-point is calculated as half the max gene pos (which should be close to the actual genome length). A model containing the two fitted regression lines is generated when possible. If not, a vector is created, with the value "NA".

fit_line <- function(data_filt) {
	 x <- data_filt$Ref_pos
	 y <- data_filt$Coverage
	 psi_est <- max(x)/2
	 lin.mod <- lm(y~x)
	 seg.mod <-tryCatch(segmented(lin.mod, seg.Z=~x, psi=psi_est), error=function(e) "NA")
	 return (seg.mod)
}

#Get coordinates from the regression lines. I have added two check-points here: First; If the break-point is too far from the expected place (+/-50% of break-point estimate), ptr is set to 1. Second; If the coverage at ori (either beginning or endof dataframe) is lower than the estimated coverage at ter, ptr is also set to 1. 

get_coord <- function(seg.mod,x) {
    outlist <- c(NA,NA)
    if(is.list(seg.mod)) {
        psi <- (summary.segmented(seg.mod)[[12]])[2]
        psi_est <- max(x)/2
        psi_est <- max(x)/2
        psi_min <- psi_est-(0.5*psi_est)
        psi_max <- psi_est+(0.5*psi_est)
        intercept1 <- (intercept(seg.mod)[[1]])[1]
        intercept2 <- (intercept(seg.mod)[[1]])[2]
        slope1 <- (slope(seg.mod)[[1]])[1]
        slope2 <- (slope(seg.mod)[[1]])[2]
        cov_ter <- round(slope1*psi + intercept1, digits=1)
        cov_ori2  <- slope2*(tail(x, n=1)) + intercept2
        max_ori_cov <- max(intercept1, cov_ori2)
        min_ori_cov <- min(intercept1, cov_ori2)
        if ((psi<psi_min) || (psi>psi_max) || (min_ori_cov<cov_ter)){
            ptr <- NA
        }  else {
            ptr <- round(max_ori_cov/cov_ter, digits=2)
        }
        outlist <- c(cov_ter,ptr)
    }
	return(outlist)
}

coord_and_plot <- function(x, do_plots) {
    coord <- c(0,"NA")
    nb_rows_data <- length(rownames(x))
    if (nb_rows_data != 0) {
        x <- droplevels(x)
        seg.mod <- fit_line(x)
        coord <- get_coord(seg.mod,x$Ref_pos)
        if (do_plots == 1) {
            sdp <- levels(x$SDP)
            sample <- levels(x$Sample)
            nb_genes_filt <- length(x$Coverage)
            y_max <- max(x$Coverage)
            y_max_round <- ceiling(y_max/50)*50
	        x_max <- max(x$Ref_pos)
	        x_max_round <- ceiling(x_max/50)*50
            main_title <-  paste0(sdp,": ", sample)
            plot(x$Ref_pos, x$Coverage, ylim=c(0,y_max_round),xlab="",ylab="",main=main_title,cex.main=0.9,pch=20,cex=0.4,cex.axis=0.8, font.main=1)
            grid(col="gray 40")
	        mtext("Coverage (reads/bp)",outer=TRUE,side=2,line=1,font=1)
	        mtext("Genome position (bp)", outer=TRUE, side=1,line=2,font=1)		   
            if (is.na(coord[2])) {
	            median_cov <- median(x$Coverage)
                abline(h=median_cov,col="red",lwd=2)
            } else {
                plot(seg.mod,add=T,col="red",lwd=2)  
            }
        }
    }
    return(coord)
}


##data acquisition. The script assumes the output as generated by the script core_cov.py

data <- read.table(Args[1],h=T)
data$SDP <- as.factor(data$SDP)
data$Sample <- as.factor(data$Sample)
data$OG <- as.factor(data$OG)
sdps <- levels(data$SDP)
samples <- levels(data$Sample)

##prep for output. Output files will be named according to the input-file

split_filename <- strsplit(Args[1],"\\.")[[1]]
outfile_prefix <- split_filename[1]
outfile_plot <- paste0(outfile_prefix,".pdf")
outfile_table <- paste0(outfile_prefix,"_coord.txt")
coord_table_header <- c("SDP", "Sample", "Cov","PTR")
coord_table <- data.frame(SDP=character(),Sample=character(),Cov_ter=numeric(),Ptr=numeric(),stringsAsFactors=FALSE)
if (do_plots == 1) {
    cairo_pdf(outfile_plot, onefile=TRUE)
    par(mfrow=c(4,3),pty="s", oma=c(3,3,0,0),mar=c(2,1.5,2,1.5))
}

##process data and generate output. If more than 20% of the core-genes have zero coverage, coverage is set to zero, and no plot is created. If the PTR was set to 1, the median will be plotted and used for quantification. Else, the segmented regression line is plotted, and the terminus coverage is used for quantification.

for (sdp in sdps) {
    #Subset for SDP-data
    sdp_data <- droplevels(subset(data, data$SDP==sdp))
    #Filter for samples with coverage on > 80% of the core genes
    sample_corecov_fraction <- tapply(sdp_data$Coverage, sdp_data$Sample, filter_corecov_fraction)
    samples_detected <- samples[which(sample_corecov_fraction > 0.8)]
    sdp_data_filt_sample <- sdp_data[sdp_data$Sample %in% samples_detected,]
    #split data by sample
    df_list <- split(sdp_data_filt_sample, sdp_data_filt_sample$Sample)
    #Filter off outlier coverage genes
    filt_df_list <- lapply(df_list, function(x) x[cov_outlier_indices(x$Coverage),])
    #Get fitted coordinates and append values to coord-table. Plot if data allows (and if user want..)
    sdp_coord <- lapply(filt_df_list, coord_and_plot, do_plots) 
    sdp_cov <- sapply(sdp_coord, function(x) x[1])
    sdp_ptr <- sapply(sdp_coord, function(x) x[2])
    sdp_coord_df <- data.frame(rep(sdp, length(samples)), samples, sdp_cov, sdp_ptr)
    names(sdp_coord_df) <- coord_table_header
    coord_table <- rbind(coord_table, sdp_coord_df)
}
if (do_plots == 1) {
    dev.off()
}
coord_table$Sample <- as.factor(coord_table$Sample)
coord_table_sorted <- coord_table[order(coord_table$Sample),]
rownames(coord_table_sorted) <- NULL
write.table(coord_table,file=outfile_table,row.names=FALSE,quote=FALSE,sep="\t")

