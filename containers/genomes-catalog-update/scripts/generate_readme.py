#!/usr/bin/env python3
# coding=utf-8

import argparse


def main(
    metadata_table,
    outfile_name,
    biome,
    ver_pipeline,
    git_link,
    xlarge
):
    (
        num_genomes,
        num_species,
        study_list,
        version,
        catalog_name,
        archaea
    ) = process_metadata_table(metadata_table)
    cat_url = "https://www.ebi.ac.uk/metagenomics/genome-catalogues/{}-{}".format(
        catalog_name, version.replace(".", "-")
    )
    study_list_string = ", ".join(sorted(study_list))
    print_file(
        outfile_name,
        version,
        catalog_name,
        cat_url,
        num_genomes,
        num_species,
        ver_pipeline,
        study_list_string,
        biome,
        git_link,
        archaea,
        xlarge
    )


def process_metadata_table(metadata_table):
    total_genomes = 0
    reps = set()
    study_list = set()
    version = ""
    catalog_name = ""
    archaea = False
    with open(metadata_table, "r") as meta_in:
        for line in meta_in:
            if not line.startswith("Genome"):
                total_genomes += 1
                fields = line.strip().split("\t")
                reps.add(fields[13])
                study_list.add(fields[16])
                if not version:
                    subfields = fields[19].strip().split("/")
                    catalog_name = subfields[7]
                    version = subfields[8]
                if not archaea:
                    if "d__Archaea" in line:
                        archaea = True
    total_genomes = "{:,}".format(total_genomes)
    num_reps = "{:,}".format(len(reps))
    return total_genomes, num_reps, study_list, version, catalog_name, archaea


def print_file(
    outfile_name,
    version,
    catalog_name,
    cat_url,
    num_genomes,
    num_species,
    ver_pipeline,
    study_list,
    biome,
    git_link,
    archaea,
    xlarge
):
    if archaea:
        phylo_text = """
    * ar53_iqtree.nwk : A phylogenetic tree for archaeal genomes in Newick format.
    * bac120_iqtree.nwk : A phylogenetic tree for bacterial genomes in Newick format.
    * ar53_alignment.faa.gz : A multiple sequence alignment for archaeal genomes.
    * bac120_alignment.faa.gz : A multiple sequence alignment for bacterial genomes."""
    else:
        phylo_text = """
    * bac120_iqtree.nwk : A phylogenetic tree for bacterial genomes in Newick format.
    * bac120_alignment.faa.gz : A multiple sequence alignment for bacterial genomes. """
    if xlarge:
        xlarge_note = """
* Due to the size of this catalogue, the clustering process was performed in two phases. First, the entire genome set \
was split up into random chunks of 25,000 genomes and each chunk was clustered independently. The species representative \
genomes from all chunks were then pulled together and clustered again. If two or more species representative genomes \
clustered together in the second round of clustering, their genome clusters from the first round of clustering were \
combined together. In some cases, this can produce clusters where some of the conspecific genomes share less than 95% ANI. 
"""
    else:
        xlarge_note = "\n"
    
    readme_text = """
{version} release
------------

Website URL: {url}

* A total of {num_genomes} prokaryotic genomes from the {biome} microbiome were clustered into {num_species} species representatives.
* Genomes from the following studies were used to generate the catalogue: {study_list}
* The catalogue was generated using MGnify genomes pipeline v{ver_pipeline}: {git_link}. 
* A protein catalogue was produced with all protein coding sequences clustered at 100%, 95%, 90% and 50% amino acid identity.
* A gene catalogue is the collection of nucleotide sequences corresponding to the protein cluster representatives of the 100% identity clustering. {xlarge_note}

## The following files are available for download for the species representative in each species directory within the species_catalogue/ folder:

- genome/
    * [species_accession]_amrfinderplus.tsv : AMR annotations produced by AMRFinderPlus.
    * [species_accession]_annotation_coverage.tsv : A summary of annotation coverage.
    * [species_accession]_cazy_summary.tsv : CAZy summary parsed from the eggNOG annotation file.
    * [species_accession]_cog_summary.tsv : COG summary parsed from the eggNOG annotation file.
    * [species_accession]_crisprcasfinder.gff : Unfiltered CRISPRCasFinder results file, including calls that have evidence level 1 and are less likely to be genuine.
    * [species_accession]_crisprcasfinder.tsv : Additional data for CRISPRCasFinder records reported in [species_accession]_crisprcasfinder.gff.
    * [species_accession]_eggNOG.tsv : eggNOG annotations of the protein coding sequences.
    * [species_accession].faa : Protein sequence FASTA file of the species representative.
    * [species_accession].fna : DNA sequence FASTA file of the genome assembly of the species representative.
    * [species_accession].fna.fai : A samtools-generated index of the genome assembly FASTA file.
    * [species_accession].gff : Genome GFF file with various sequence annotations, including InterPro, eggNOG, Pfam, KEGG, COG, ncRNAs, CRISPR (filtered results with evidence level >= 2), mobilome and viral annotations, biosynthetic gene clusters, antimicrobial resistance genes.
    * [species_accession]_InterProScan.tsv : InterProScan annotation of the protein coding sequences.
    * [species_accession]_kegg_classes.tsv : KEGG classes and their counts.
    * [species_accession]_kegg_modules.tsv : KEGG modules and their counts.
    * [species_accession]_mobilome.gff : Annotated viral sequence and mobile elements.
    * [species_accession]_rRNAs.fasta : rRNA sequence FASTA file.
    * [species_accession]_sanntis.gff : SanntiS output file containing biosynthetic gene cluster information.


## For species where there is more than one conspecific genome, pan-genomes can be found in:
       
- pan-genome/
    * core_genes.txt : List of core genes for the pan-genome (genes found in >=90% of the genomes).
    * pan-genome.fna : Nucleotide sequence FASTA file of the pan-genome.
    * gene_presence_absence.csv: A list of genes in the pan-genome with their annotation and MGYG accessions.
    * gene_presence_absence.Rtab : Presence/absence binary matrix of the pan-genome across all conspecific genomes.
    * mashtree.nwk : Tree generated from the pairwise Mash distances of conspecific genomes.


## Additional files available in the parent directory:

- all_genomes.msh : A Mash sketch of all {num_genomes} genomes.

- all_genomes/ : Combined GFF/FASTA file (Prokka output) for each of the {num_genomes} genomes. For species representative genomes, the GFF contains additional annotations as described above.  
       
- gene_catalogue/: 
    * gene_catalogue-100.ffn.gz : Nucleotide sequences corresponding to the protein cluster representatives in the protein catalogue clustered at 100% amino acid identity.
    * clusters.tsv : A list of gene accession pairs where the first accession is that of a gene included in the gene catalogue as the representative and the second is a gene that is not included in the gene catalogue but belongs in the same cluster based on amino acid identity.

- genomes-all_metadata.tsv : Assembly statistics and metadata of all {num_genomes} genomes. 

- kraken2_db_{catalog_name}_{version}/ : A folder containing the Kraken 2 and Bracken databases. 

- phylogenies/: {phylo_text}

- protein_catalogue/
    * protein_catalogue-XX.tar.gz
        - protein_catalogue-XX.faa : Protein FASTA file of the clustered, representative sequences.
        - protein_catalogue-XX.tsv : Cluster membership of all the protein sequences.
    For 90% identity catalogue only:
        - protein_catalogue-90_eggNOG.tsv : eggNOG annotation results of the protein catalogue.
        - protein_catalogue-90_InterProScan.tsv : InterProScan annotation results of the protein catalogue.
    """.format(
        version=version,
        url=cat_url,
        num_genomes=num_genomes,
        num_species=num_species,
        ver_pipeline=ver_pipeline,
        git_link=git_link,
        xlarge_note=xlarge_note,
        study_list=study_list,
        biome=biome,
        catalog_name=catalog_name,
        phylo_text=phylo_text
    )
    with open(outfile_name, "w") as outfile:
        outfile.write(readme_text)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Creates a README file for a genome catalog"
    )
    parser.add_argument(
        "-m",
        "--metadata-table",
        required=True,
        help="A path to the metadata table for the catalog",
    )
    parser.add_argument("-o", "--outfile-name", required=True, help="A path to outfile")
    parser.add_argument(
        "-b",
        "--biome",
        required=True,
        help="The biome for the catalog. Examples: human gut, cow rumen, human oral",
    )
    parser.add_argument(
        "--pipeline-version",
        default="2.0.0",
        type=str,
        help="Genomes pipeline version",
    )
    parser.add_argument(
        "--git-link",
        type=str,
        help="Full link to the github repo release. "
             "Example: https://github.com/EBI-Metagenomics/genomes-pipeline/releases/tag/v1.2.1",
    )
    parser.add_argument(
        "--xlarge", action='store_true',
        help="Specify this flag if the catalogue was generated using the --xlarge flag and "
             "the number of genomes is over 25,000 (meaning chunked dRep was performed).",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.metadata_table,
        args.outfile_name,
        args.biome,
        args.pipeline_version,
        args.git_link,
        args.xlarge
    )
