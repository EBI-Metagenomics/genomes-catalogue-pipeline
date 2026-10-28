#!/usr/bin/env python3
# coding=utf-8

import argparse
import re

import pandas as pd

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
    datascout_link,
    study_list_threshold,
    remove_list=None
):
    validate_update_args(previous_readme, previous_version, previous_metadata_table, additional_data_path,
                         remove_list)

    # Parse the pipeline and datascout versions and build the pipeline README link
    ver_pipeline = extract_release_version(git_link, "--git-link")
    ver_datascout = extract_release_version(datascout_link, "--datascout-link")
    readme_link = build_pipeline_readme_link(git_link)

    (
        num_genomes,
        num_species,
        study_list,
        version,
        catalog_name
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
        xlarge,
        changelog,
        previous_changelog,
        ver_datascout,
        datascout_link,
        readme_link
    )


def build_pipeline_readme_link(git_link):
    """
    Build a link to the pipeline README from the pipeline release link.

    Keeps the full release tag link and appends /README.md:
        https://github.com/EBI-Metagenomics/genomes-catalogue-pipeline/releases/tag/v5.0.0
        -> https://github.com/EBI-Metagenomics/genomes-catalogue-pipeline/releases/tag/v5.0.0/README.md

    Parameters
    ----------
    git_link : str
        Link to the pipeline GitHub release.

    Returns
    -------
    str
        Link to the pipeline README.

    Raises
    ------
    ValueError
        If the link does not end in /releases/tag/<version>.
    """
    match = re.match(r"^(.+?/releases/tag/[^/]+)/?$", git_link.strip())
    if not match:
        raise ValueError(
            f"Could not build the pipeline README link from --git-link '{git_link}'. "
            f"Expected a link like https://github.com/EBI-Metagenomics/genomes-catalogue-pipeline/releases/tag/v5.0.0"
        )
    return f"{match.group(1)}/README.md"


def process_metadata_table(metadata_table):
    """
    Summarise the current metadata table.

    Columns are looked up by name: 'Genome', 'Species_rep', 'Study_accession' and 'FTP_download'.
    The catalogue name and version are taken from the FTP link of the first genome, e.g.
    ftp://ftp.ebi.ac.uk/pub/databases/metagenomics/mgnify_genomes/<catalogue>/<version>/...

    Returns
    -------
    total_genomes : str
        Number of genomes, comma-formatted.
    num_reps : str
        Number of species representatives, comma-formatted.
    study_list : set
        Study accessions.
    version, catalog_name : str
    """
    df = pd.read_csv(metadata_table, sep="\t", dtype=str)

    required = ["Genome", "Species_rep", "Study_accession", "FTP_download"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"Metadata table {metadata_table} is missing required column(s): {', '.join(missing)}")
    if df.empty:
        raise ValueError(f"Metadata table {metadata_table} has no genomes")

    reps = set(df["Species_rep"].dropna())
    study_list = set(df["Study_accession"].dropna())

    subfields = df["FTP_download"].iloc[0].strip().split("/")
    catalog_name = subfields[7]
    version = subfields[8]

    total_genomes = "{:,}".format(len(df))
    num_reps = "{:,}".format(len(reps))
    return total_genomes, num_reps, study_list, version, catalog_name


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
    xlarge,
    changelog,
    previous_changelog,
    ver_datascout,
    datascout_link,
    readme_link
):
    xlarge_note = get_xlarge_note(xlarge)

    readme_text = """
{version} release
------------

Website URL: {url}

* A total of {num_genomes} eukaryotic genomes from the {biome} microbiome were clustered into {num_species} species-level clusters.
{study_list_string}
* The catalogue was generated using MGnify genomes pipeline v{ver_pipeline}: {git_link}. 
* Proteomic evidence for gene calling was obtained using datascout v{ver_datascout}: {datascout_link}
* A protein catalogue was produced with all protein coding sequences clustered at 100%, 95%, 90% and 50% amino acid identity.
* A gene catalogue is the collection of nucleotide sequences corresponding to the protein cluster representatives of the 100% identity clustering. {xlarge_note}

## The following files are available for download for the species representative in each species directory within the species_catalogue/ folder:

- genome/
    * [species_accession]_annotation_coverage.tsv.gz : Number and percentage of proteins annotated with InterProScan, eggNOG, COG and KEGG, and of proteins with no annotation.
    * [species_accession]_braker.gff.gz : Structural annotation generated with BRAKER3, using protein evidence where available and ab initio prediction otherwise.
    * [species_accession]_cazy_summary.tsv.gz : CAZy summary parsed from the eggNOG annotation file.
    * [species_accession]_cog_summary.tsv.gz : COG summary parsed from the eggNOG annotation file.
    * [species_accession]_dbcan.gff.gz : Result of carbohydrate-utilising enzyme annotation at the protein level by run_dbcan.
    * [species_accession]_eggNOG.tsv.gz : EggNOG annotations of the protein sequences.
    * [species_accession].faa.gz : Protein sequence FASTA file of the species representative.
    * [species_accession].fna.gz : DNA sequence FASTA file of the genome assembly of the species representative, with repeats soft-masked (where possible).
    * [species_accession].fna.gz.fai : A samtools-generated index of the genome assembly FASTA file.
    * [species_accession].gff.gz : Genome GFF file with various sequence annotations, including InterPro, eggNOG, Pfam, KEGG, COG, ncRNAs. The structural annotation is the merged result of BRAKER3 and MetaEuk, as described in the pipeline README: {readme_link} 
    * [species_accession]_InterProScan.tsv.gz : InterProScan annotation of the protein sequences.
    * [species_accession]_kegg_classes.tsv.gz : KEGG classes and their counts.
    * [species_accession]_kegg_modules.tsv.gz : KEGG modules and their counts.
    * [species_accession]_kegg_pathways.tsv.gz : KEGG pathway completeness.
    * [species_accession]_metaeuk.gff.gz : Structural annotation generated with MetaEuk (only available when there is suitable proteomic evidence).
    * [species_accession]_rRNAs.fasta.gz : rRNA sequence FASTA file.

## Additional files available in the parent directory:

- all_genomes.msh : A Mash sketch of all {num_genomes} genomes.

- all_genomes/ : Contains a combined GFF/FASTA file for each of the {num_genomes} genomes. For genomes with proteomic evidence, the combined files contain merged outputs from BRAKER3 and MetaEuk. For genomes without proteomic evidence, they contain processed BRAKER3 ab initio predictions. GFF files for species representative genomes include additional annotations, as described above. The original BRAKER3 and MetaEuk outputs for each genome are also included in this directory. 

- gene_catalogue/: 
    * gene_catalogue-100.ffn.gz : Nucleotide sequences corresponding to the protein cluster representatives in the protein catalogue clustered at 100% amino acid identity.
    * clusters.tsv.gz : A list of gene accession pairs where the first accession is that of a gene included in the gene catalogue as the representative and the second is a gene that is not included in the gene catalogue but belongs in the same cluster based on amino acid identity.

- genomes-all_metadata.tsv : Assembly statistics and metadata of all {num_genomes} genomes. 

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
        ver_datascout=ver_datascout,
        datascout_link=datascout_link,
        readme_link=readme_link,
        xlarge_note=xlarge_note,
        study_list_string=study_list_string,
        biome=biome,
        catalog_name=catalog_name,
    )

    write_readme(outfile_name, readme_text, changelog, previous_changelog)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Creates a README file for a eukaryotic genome catalogue"
    )
    add_common_arguments(parser)
    parser.add_argument(
        "--datascout-link", required=True,
        help="Link to the datascout release that was used to get evidence for gene calling for the catalogue. "
             "The datascout version is extracted from the link, so it must end in /releases/tag/<version>, "
             "for example, https://github.com/EBI-Metagenomics/datascout/releases/tag/v1.4.0",
    )
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
        args.datascout_link,
        args.study_list_threshold,
        args.remove_list
    )