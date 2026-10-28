#!/usr/bin/env python3
# coding=utf-8

import argparse

from readme_lib import (
    add_common_arguments,
    build_catalogue_url,
    build_changelogs,
    build_study_list_string,
    extract_release_version,
    get_xlarge_note,
    validate_update_args,
    write_readme,
)

TREE_TOOL_TRANSITION_COUNT = 1999  # we used fasttree to generate trees for large genome sets (2000+), otherwise iqtree


def main(
    metadata_table,
    outfile_name,
    biome,
    git_link,
    xlarge,
    previous_readme,
    previous_version,
    previous_metadata_table,
    additional_data_path,
    study_list_threshold,
    remove_list=None
):
    validate_update_args(previous_readme, previous_version, previous_metadata_table, additional_data_path,
                         remove_list)
    ver_pipeline = extract_release_version(git_link, "--git-link")

    (
        num_genomes,
        num_species,
        study_list,
        version,
        catalog_name,
        archaea
    ) = process_metadata_table(metadata_table)
    cat_url = build_catalogue_url(catalog_name, version)
    study_list_string = build_study_list_string(study_list, study_list_threshold, outfile_name)
    changelog, previous_changelog = build_changelogs(version, previous_version, metadata_table,
                                                     previous_metadata_table, additional_data_path,
                                                     outfile_name, previous_readme, remove_list)

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
        xlarge,
        changelog,
        previous_changelog
    )


def get_tree_tool(count):
    if count > TREE_TOOL_TRANSITION_COUNT:
        return "fasttree"
    else:
        return "iqtree"


def process_metadata_table(metadata_table):
    total_genomes = 0
    reps = set()
    study_list = set()
    version = ""
    catalog_name = ""
    archaea = 0
    with open(metadata_table, "r") as meta_in:
        for line in meta_in:
            if not line.startswith("Genome"):
                total_genomes += 1
                fields = line.strip().split("\t")
                species_rep = fields[13]
                genome_acc = fields[0]
                study = fields[16]
                ftp_link = fields[19]
                reps.add(species_rep)
                study_list.add(study)
                if not version:
                    subfields = ftp_link.strip().split("/")
                    catalog_name = subfields[7]
                    version = subfields[8]
                # count representatives that are archaea
                if "d__Archaea" in line and species_rep == genome_acc:
                    archaea += 1
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
    study_list_string,
    biome,
    git_link,
    archaea,
    xlarge,
    changelog,
    previous_changelog
):
    bacteria = int(num_species.replace(",", "")) - archaea
    tree_tool_ar = get_tree_tool(archaea)
    tree_tool_bac = get_tree_tool(bacteria)
    has_archaea = archaea > 2

    phylo_lines = [
        f"    * bac120_{tree_tool_bac}.nwk : A phylogenetic tree for bacterial genomes in Newick format.",
        "    * bac120_alignment.faa.gz : A multiple sequence alignment for bacterial genomes.",
    ]
    if has_archaea:
        phylo_lines += [
            f"    * ar53_{tree_tool_ar}.nwk : A phylogenetic tree for archaeal genomes in Newick format.",
            "    * ar53_alignment.faa.gz : A multiple sequence alignment for archaeal genomes.",
        ]

    itol_intro = ("    * iTOL/ : Files for visualising phylogenetic trees in iTOL (https://itol.embl.de). "
                  f"Use bacterial annotation files with the corresponding bacterial tree (bac120_{tree_tool_bac}.nwk)")
    if has_archaea:
        itol_intro += f" and archaeal annotation files with the corresponding archaeal tree (ar53_{tree_tool_ar}.nwk)"
    phylo_lines.append(itol_intro + ".")

    domains = [("bac", "bacterial")] + ([("arc", "archaeal")] if has_archaea else [])
    itol_lines = []
    for domain, domain_name in domains:
        itol_lines += [
            f"        * itol_gtdb-layer_{domain}_phylum.txt : A colour-coded annotation layer showing the phylum-level "
            f"taxonomy of {domain_name} genomes in the phylogenetic tree.",
            f"        * itol_gtdb-legend_{domain}_phylum.txt : Range colouring of the {domain_name} tree by phylum, "
            f"using the same randomly assigned colours as the annotation layer.",
            f"        * novel_existing_{domain}_phylum-layer.txt : A colour layer distinguishing {domain_name} genomes "
            f"assigned to novel species (according to the GTDB release used) from those belonging to existing species. "
            f"Novel species are shown in light green, existing species in light blue.",
            f"        * novel_existing_{domain}_phylum-legend.txt : Range colouring of the {domain_name} tree by "
            f"novel/existing species status, using the same colours as the novelty layer.",
            f"        * cluster_size_{domain}.txt : A bar chart layer showing the number of genomes in each "
            f"{domain_name} species cluster.",
            f"        * cluster_size_log10_{domain}.txt : A bar chart layer showing log10(number of genomes + 1) "
            f"in each {domain_name} species cluster.",
        ]

    # List iTOL files alphabetically by file name
    phylo_lines += sorted(itol_lines, key=lambda line: line.strip().lstrip("* ").split(" ")[0].lower())

    phylo_text = "\n".join(phylo_lines)
    xlarge_note = get_xlarge_note(xlarge)

    readme_text = """
{version} release
------------

Website URL: {url}

* A total of {num_genomes} prokaryotic genomes from the {biome} microbiome were clustered into {num_species} species-level clusters.
{study_list_string}
* The catalogue was generated using MGnify genomes pipeline v{ver_pipeline}: {git_link}. 
* A protein catalogue was produced with all protein coding sequences clustered at 100%, 95%, 90% and 50% amino acid identity.
* A gene catalogue is the collection of nucleotide sequences corresponding to the protein cluster representatives of the 100% identity clustering. {xlarge_note}

## The following files are available for download for the species representative in each species directory within the species_catalogue/ folder:

- genome/
    * [species_accession]_amrfinderplus.tsv.gz : AMR annotations produced by AMRFinderPlus.
    * [species_accession]_annotation_coverage.tsv.gz : A summary of annotation coverage.
    * [species_accession]_antismash.gff.gz : AntiSMASH output file containing biosynthetic gene cluster information.
    * [species_accession]_cazy_summary.tsv.gz : CAZy summary parsed from the eggNOG annotation file.
    * [species_accession]_cog_summary.tsv.gz : COG summary parsed from the eggNOG annotation file.
    * [species_accession]_crisprcasfinder.gff.gz : Unfiltered CRISPRCasFinder results file, including calls that have evidence level 1 and are less likely to be genuine.
    * [species_accession]_crisprcasfinder.tsv.gz : Additional data for CRISPRCasFinder records reported in [species_accession]_crisprcasfinder.gff.
    * [species_accession]_dbcan.gff.gz : dbCAN annotation file containing putative polysaccharide utilisation loci, predicted substrates and functions of member genes.
    * [species_accession]_defense_finder.gff.gz : Anti-phage and anti-defense system annotations.
    * [species_accession]_eggNOG.tsv.gz : eggNOG annotations of the protein coding sequences.
    * [species_accession].faa.gz : Protein sequence FASTA file of the species representative.
    * [species_accession].fna.gz : DNA sequence FASTA file of the genome assembly of the species representative.
    * [species_accession].fna.gz.fai : A samtools-generated index of the genome assembly FASTA file.
    * [species_accession].gff.gz : Genome GFF file with various sequence annotations, including InterPro, eggNOG, Pfam, KEGG, COG, ncRNAs, CRISPR (filtered results with evidence level >= 2), mobilome and viral annotations, biosynthetic gene clusters, antimicrobial resistance genes, putative polysaccharide utilisation loci, anti-phage and anti-defense systems.
    * [species_accession]_InterProScan.tsv.gz : InterProScan annotation of the protein coding sequences.
    * [species_accession]_kegg_classes.tsv.gz : KEGG classes and their counts.
    * [species_accession]_kegg_modules.tsv.gz : KEGG modules and their counts.
    * [species_accession]_kegg_pathways.tsv.gz : KEGG pathway completeness.
    * [species_accession]_mobilome.gff.gz : Annotated viral sequence and mobile elements.
    * [species_accession]_pathofact2_combined_report.tsv.gz : Pathogenicity-related annotations at protein level in TSV format.
    * [species_accession]_rRNAs.fasta.gz : rRNA sequence FASTA file.
    * [species_accession]_sanntis.gff.gz : SanntiS output file containing biosynthetic gene cluster information.


## For species where there is more than one conspecific genome, pan-genomes can be found in:

- pan-genome/
    * pan-genome.fna.gz : Nucleotide sequence FASTA file of the pan-genome.
    * gene_presence_absence.csv.gz : A list of genes in the pan-genome with their annotation and MGYG accessions.
    * gene_presence_absence.Rtab.gz : Presence/absence binary matrix of the pan-genome across all conspecific genomes.
    * gene_prevalence_corrected.txt.gz : Summary file reporting the observed count of each gene in the pan-genome, along with core/middle/rare classifications based on completeness-adjusted frequency. Cut-offs of 95% (core) and 5% (rare) are provided to CELEBRIMBOR prior to adjustment. Note: these classifications may be unreliable for small genome clusters due to limited sample size.
    * mashtree.nwk.gz : Tree generated from the pairwise Mash distances of conspecific genomes.

## Additional files available in the parent directory:

- all_genomes.msh : A Mash sketch of all {num_genomes} genomes.

- all_genomes/ : Combined GFF/FASTA file (Prokka output) for each of the {num_genomes} genomes. For species representative genomes, the GFF contains additional annotations as described above.  

- gene_catalogue/: 
    * gene_catalogue-100.ffn.gz : Nucleotide sequences corresponding to the protein cluster representatives in the protein catalogue clustered at 100% amino acid identity.
    * clusters.tsv.gz : A list of gene accession pairs where the first accession is that of a gene included in the gene catalogue as the representative and the second is a gene that is not included in the gene catalogue but belongs in the same cluster based on amino acid identity.

- genomes-all_metadata.tsv : Assembly statistics and metadata of all {num_genomes} genomes. 

- kraken2_db_{catalog_name}_{version}/ : A folder containing the Kraken 2 and Bracken databases. 

- phylogenies/: 
    Note: Alignments and the trees generated from them are based on GTDB-Tk results. Genomes classified only to the domain level by GTDB-Tk (e.g. d__Bacteria;p__;c__;o__;f__;g__;s__) will not be included.
{phylo_text}

- protein_catalogue/
    * protein_catalogue-XX.tar.gz
        - protein_catalogue-XX.faa : Protein FASTA file of the clustered, representative sequences. Computed from all genomes in the catalogue (representative and non-representative).
        - protein_catalogue-XX.tsv : Cluster membership of all the protein sequences.
    For 90% identity catalogue only:
        - protein_catalogue-90_eggNOG.tsv : eggNOG annotation results of the protein catalogue.
        - protein_catalogue-90_InterProScan.tsv : InterProScan annotation results of the protein catalogue.
    * proteins.faa.gz : Protein FASTA containing all protein sequences from all genomes in the catalogue (representative and non-representative).
    """.format(
        version=version,
        url=cat_url,
        num_genomes=num_genomes,
        num_species=num_species,
        ver_pipeline=ver_pipeline,
        git_link=git_link,
        xlarge_note=xlarge_note,
        study_list_string=study_list_string,
        biome=biome,
        catalog_name=catalog_name,
        phylo_text=phylo_text
    )

    write_readme(outfile_name, readme_text, changelog, previous_changelog)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Creates a README file for a prokaryotic genome catalogue"
    )
    add_common_arguments(parser)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(
        args.metadata_table,
        args.outfile_name,
        args.biome,
        args.git_link,
        args.xlarge,
        args.previous_readme,
        args.previous_version,
        args.previous_metadata_table,
        args.additional_data_path,
        args.study_list_threshold,
        args.remove_list
    )