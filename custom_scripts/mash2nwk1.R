#!/usr/bin/env Rscript

# load libraries
library(reshape2)
library(fastcluster)
library(optparse)
library(data.table)
library(ape)

# prepare arguments
option_list = list(
  make_option(c("-m", "--mash"), type="character", default=NULL,
              help="mash distance file", metavar="mash"))
opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$mash)){
  print_help(opt_parser)
  stop("Provide mash distance file with -m")
}

# set working directory and load data
message("Reading MASH file...\n")
dset = fread(opt$mash)
path = dirname(file.path(opt$mash))

# carry hclust analysis
message("Converting to distance matrix...\n")
dist.dset = acast(dset, genome1~genome2, value.var="dist")
message("Clustering...\n")
hc = hclust(as.dist(dist.dset))
message(paste("Cutting clusters at 97% and 99% ANI\n"))
memb_99 = cutree(hc, h=0.01) 
memb_97 = cutree(hc, h=0.03)
clusters_99 = unique(memb_99)
clusters_97 = unique(memb_97)
ngroups_99 = length(clusters_99)
ngroups_97 = length(clusters_97)
cat(paste("97% clusters:", ngroups_97, "\t", "99% clusters:", ngroups_99, "\n"))

# save tree
species_tree = as.phylo(hc)
dir.create("trees")
write.tree(phy=species_tree, file="trees/mashtree.nwk")
