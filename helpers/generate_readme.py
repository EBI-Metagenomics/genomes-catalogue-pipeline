#!/usr/bin/env python3
# coding=utf-8

import argparse
from pathlib import Path
import pandas as pd


def main(
    metadata_table,
    outfile_name,
    biome,
    ver_pipeline,
    git_link,
    xlarge,
    previous_readme,
    previous_version,
    previous_metadata_table,
    additional_data_path,
    new_species_count,
    new_strains_count
):
    # If this is a README for an updated catalogue, check that all arguments are provided
    if previous_readme or previous_version or previous_metadata_table:
        if not all([previous_readme, previous_version, previous_metadata_table, additional_data_path]):
            raise ValueError(
                "For updates, you must provide --previous-readme, "
                "--previous-version, --additional-data-path, and --previous-metadata-table together."
            )
        
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
   
    # If this is an update, generate a changelog from the previous version  
    if previous_readme:
        changelog = create_changelog(version, previous_version, metadata_table, previous_metadata_table, 
                                     additional_data_path, new_species_count, new_strains_count)
        previous_changelog = extract_previous_changelogs(previous_readme)
    else:
        changelog = ""
        previous_changelog = ""
        
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


def extract_previous_changelogs(previous_readme):
    """
    Extract the changelog section from a previous README file.

    Parameters
    ----------
    previous_readme : str
        Path to the previous README file.

    Returns
    -------
    str
        Changelog section starting from the first line that begins with
        "## Changes in release" until the end of the file.
        Returns an empty string if no such line is found.
    """

    changelog_lines = []
    found = False

    with open(previous_readme, "r") as fh:
        for line in fh:
            if not found and line.startswith("## Changes in release"):
                found = True
            if found:
                changelog_lines.append(line.rstrip("\n"))  # remove trailing newline

    return "\n".join(changelog_lines)
    
    
def get_tree_tool(count):
    if count > 1999:
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
                reps.add(fields[13])
                study_list.add(fields[16])
                if not version:
                    subfields = fields[19].strip().split("/")
                    catalog_name = subfields[7]
                    version = subfields[8]
                # count representatives that are archaea
                if "d__Archaea" in line and fields[13] == fields[0]:
                    archaea += 1
    total_genomes = "{:,}".format(total_genomes)
    num_reps = "{:,}".format(len(reps))
    return total_genomes, num_reps, study_list, version, catalog_name, archaea


def create_changelog(version, previous_version, metadata_table, previous_metadata_table, additional_data_path, 
                     new_species_count, new_strains_count):
    new_genome_dict = count_new_genomes(metadata_table, previous_metadata_table)
    species_rep_replacements, removals = load_rep_changes(additional_data_path)
    changelog_header = f"## Changes in release {version} since {previous_version}"
    
    # Initialize lines
    lines = [changelog_header]
    
    if new_genome_dict:

        new_genome_line = summarise_new_genomes(new_genome_dict)
        lines.append(new_genome_line)
        
        # New species/strain line
        # Todo: retrieve these numbers automatically
        if new_species_count > 0 or new_strains_count > 0:
            new_species_line = f"This resulted in {new_species_count} new species and {new_strains_count} new strains."
            lines.append(new_species_line)
    
    if species_rep_replacements:
        lines.append("The following species representatives were replaced:")
        lines.append("Old rep\tNew rep\tReason for replacement")
        for old_rep in species_rep_replacements:
            lines.append(f"{old_rep}\t{species_rep_replacements[old_rep]['new_rep']}\t"
                         f"{species_rep_replacements[old_rep]['reason']}")
        
    if removals:
        lines.append("The following genomes were removed from the catalogue:")
        for genome in removals:
            lines.append(genome)
            
    # Join all lines into a single block
    changelog_text = "\n".join(lines)
    return changelog_text


def summarise_new_genomes(new_genomes):
    """
    Build a summary string of new genomes added per study.

    Parameters
    ----------
    new_genomes : dict
        Output from count_new_genomes(), e.g.
        {
            study_accession: {
                'isolates': count,
                'mags': count,
                'new_species': count,
                'new_strains': count
            }
        }

    Returns
    -------
    str
        Human-readable summary of new genomes added.
    """

    parts = []

    for study, counts in new_genomes.items():
        isolates = counts["isolates"]
        mags = counts["mags"]

        study_parts = []

        if isolates > 0:
            study_parts.append(f"{isolates} isolates")
        if mags > 0:
            study_parts.append(f"{mags} MAGs")

        if study_parts:
            parts.append(f"{' and '.join(study_parts)} from study {study}")

    summary = (
        "* The following genomes were added to the catalogue: "
        + ", ".join(parts)
    )

    return summary


def load_rep_changes(additional_data_path):
    """
    Load species representative changes from the update report.

    Parameters
    ----------
    additional_data_path : str
        Base directory containing update_execution_reports/

    Returns
    -------
    species_rep_replacements : dict
        {old_rep: {"new_rep": new_rep, "reason": reason}}
    removals : list
        [old_rep, ...]
    """

    report_path = (
        Path(additional_data_path)
        / "update_execution_reports"
        / "update_cluster_rep_changes_report.tsv"
    )

    # Fail if file does not exist
    if not report_path.exists():
        raise FileNotFoundError(f"Missing report file: {report_path}")

    # Read TSV
    df = pd.read_csv(report_path, sep="\t")

    species_rep_replacements = {}
    removals = []

    for _, row in df.iterrows():
        old_rep = row["old_rep"]
        new_rep = row["new_rep"]
        reason = row["reason"]

        # Treat NaN or empty new_rep as removal
        if pd.isna(new_rep) or new_rep == "":
            removals.append(old_rep)
        else:
            species_rep_replacements[old_rep] = {
                "new_rep": new_rep,
                "reason": reason,
            }

    return species_rep_replacements, removals

    
def count_new_genomes(metadata_table, previous_metadata_table):
    """
    Count new genomes by study accession and genome type from tab-delimited files.

    Parameters
    ----------
    metadata_table : str
        Path to current metadata TSV file.
        Required columns: 'Genome', 'Genome_type', 'Study_accession'
    previous_metadata_table : str
        Path to previous metadata TSV file.
        Required column: 'Genome'

    Returns
    -------
    dict
        {
            study_accession: {
                'isolates': count,
                'mags': count
            }
        }
    """

    # Read tab-delimited metadata tables
    current_df = pd.read_csv(metadata_table, sep="\t")
    previous_df = pd.read_csv(previous_metadata_table, sep="\t")

    # Identify new genomes
    new_genomes_set = set(current_df["Genome"]) - set(previous_df["Genome"])

    # Filter current metadata to new genomes
    new_df = current_df[current_df["Genome"].isin(new_genomes_set)]

    # Summarise by study accession and genome type
    new_genomes = {}

    for _, row in new_df.iterrows():
        study = row["Study_accession"]
        genome_type = row["Genome_type"]
        genome = row["Genome"]
        species_rep = row["Species_rep"]

        if study not in new_genomes:
            new_genomes[study] = {
                "isolates": 0,
                "mags": 0,
            }

        if genome_type == "Isolate":
            new_genomes[study]["isolates"] += 1
        elif genome_type == "MAG":
            new_genomes[study]["mags"] += 1
    return new_genomes

    
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
    xlarge,
    changelog,
    previous_changelog
):
    bacteria = int(num_species.replace(",", "")) - archaea
    tree_tool_ar = get_tree_tool(archaea)
    tree_tool_bac = get_tree_tool(bacteria)
    if archaea > 2:
        phylo_text = """
    * ar53_{tree_tool_ar}.nwk : A phylogenetic tree for archaeal genomes in Newick format.
    * bac120_{tree_tool_bac}.nwk : A phylogenetic tree for bacterial genomes in Newick format.
    * ar53_alignment.faa.gz : A multiple sequence alignment for archaeal genomes.
    * bac120_alignment.faa.gz : A multiple sequence alignment for bacterial genomes.""".format(
            tree_tool_ar=tree_tool_ar,
            tree_tool_bac=tree_tool_bac
        )
    else:
        phylo_text = """
    * bac120_{tree_tool_bac}.nwk : A phylogenetic tree for bacterial genomes in Newick format.
    * bac120_alignment.faa.gz : A multiple sequence alignment for bacterial genomes. """.format(
            tree_tool_bac=tree_tool_bac
        )
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
    * [species_accession]_antismash.gff : AntiSMASH output file containing biosynthetic gene cluster information.
    * [species_accession]_cazy_summary.tsv : CAZy summary parsed from the eggNOG annotation file.
    * [species_accession]_cog_summary.tsv : COG summary parsed from the eggNOG annotation file.
    * [species_accession]_crisprcasfinder.gff : Unfiltered CRISPRCasFinder results file, including calls that have evidence level 1 and are less likely to be genuine.
    * [species_accession]_crisprcasfinder.tsv : Additional data for CRISPRCasFinder records reported in [species_accession]_crisprcasfinder.gff.
    * [species_accession]_dbcan.gff : dbCAN annotation file containing putative polysaccharide utilisation loci, predicted substrates and functions of member genes.
    * [species_accession]_defense_finder.gff : Anti-phage and anti-defense system annotations.
    * [species_accession]_eggNOG.tsv : eggNOG annotations of the protein coding sequences.
    * [species_accession].faa : Protein sequence FASTA file of the species representative.
    * [species_accession].fna : DNA sequence FASTA file of the genome assembly of the species representative.
    * [species_accession].fna.fai : A samtools-generated index of the genome assembly FASTA file.
    * [species_accession].gff : Genome GFF file with various sequence annotations, including InterPro, eggNOG, Pfam, KEGG, COG, ncRNAs, CRISPR (filtered results with evidence level >= 2), mobilome and viral annotations, biosynthetic gene clusters, antimicrobial resistance genes, putative polysaccharide utilisation loci, anti-phage and anti-defense systems.
    * [species_accession]_InterProScan.tsv : InterProScan annotation of the protein coding sequences.
    * [species_accession]_kegg_classes.tsv : KEGG classes and their counts.
    * [species_accession]_kegg_modules.tsv : KEGG modules and their counts.
    * [species_accession]_kegg_pathways.tsv : KEGG pathway completeness.
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

    # Append changelogs if they exist
    if changelog:
        readme_text += "\n\n" + changelog
    if previous_changelog:
        readme_text += "\n\n" + previous_changelog
        
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
    parser.add_argument(
        "--previous-readme", required=False,
        help="If this README is for an update, provide the path to the previous README version.",
    )
    parser.add_argument(
        "--previous-version", required=False,
        help="If this README is for an update, provide the previous catalogue version. For example, 'v1.0'.",
    )
    parser.add_argument(
        "--previous-metadata-table", required=False,
        help="If this README is for an update, provide the path to the previous metadata table.",
    )
    parser.add_argument(
        "--additional-data-path", required=False,
        help="If this README is for an update, provide the path to the 'additional_data' folder "
             "(in the catalogue pipeline output).",
    )
    parser.add_argument(
        "--new-species-count", required=False,
        help="If this README is for an update, provide the number of new species added.",
    )
    parser.add_argument(
        "--new-strains-count", required=False,
        help="If this README is for an update, provide the number of new strains added.",
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
        args.xlarge,
        args.previous_readme,
        args.previous_version,
        args.previous_metadata_table,
        args.additional_data_path,
        args.new_species_count,
        args.new_strains_count,
    )
