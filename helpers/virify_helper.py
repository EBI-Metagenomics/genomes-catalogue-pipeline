#!/usr/bin/env python3

import argparse
import os
import shutil
from pathlib import Path
from subprocess import check_output


def launch_virify(workdir, genome_id, fasta):
    """Launch a virify job for a given fasta"""
    current_env = os.environ.copy()
    # a few envs required
    current_env["NXF_TEMP"] = "/hps/scratch/rdf/metagenomics/nf-scratch"
    current_env["TMPDIR"] = "/hps/scratch/rdf/metagenomics/nf-scratch"
    current_env["NXF_ANSI_LOG"] = "false"

    workdir = os.path.abspath(workdir)
    os.makedirs(workdir, exist_ok=True)

    cmd = [
        "bsub",
        "-J",
        f"virify_{genome_id}",
        "-cwd",
        workdir,
        "/hps/software/users/rdf/metagenomics/service-team/software/nextflow/nextflow-21.10.0/nextflow",
        "run",
        "/nfs/production/rdf/metagenomics/pipelines/prod/emg-viral-pipeline/virify.nf",
        "--fasta",
        fasta,
        "--output",
        workdir,
        "-profile",
        "ebi",
    ]
    print("----- Virify launch ----")
    print(" ".join(cmd))
    print("-------------------------")
    return check_output(list(map(str, cmd)), universal_newlines=True, env=current_env)


def main():
    # Default #
    MAX_VIRIFY_JOBS = 15

    parser = argparse.ArgumentParser("Genomes Catalogue VIrify launcher")
    parser.add_argument(
        "--catalogue-results-folder",
        required=True,
    )
    parser.add_argument(
        "--virify-outdir",
        help="Base virify outdir base, each genome will have a folder in this path",
        required=True,
    )
    parser.add_argument(
        "--max-virify-jobs",
        default=MAX_VIRIFY_JOBS,
    )
    args = parser.parse_args()

    MAX_VIRIFY_JOBS = args.max_virify_jobs
    results_folder = args.catalogue_results_folder
    virify_outdir = args.virify_outdir

    genome_fasta_files = Path(results_folder).glob("species_catalogue/*/*/genome/*.fna")

    launched_jobs = 0

    for genome_fasta in genome_fasta_files:
        genome_id = genome_fasta.stem
        # Check if final gff is present #
        virify_gff = f"{virify_outdir}/{genome_id}/{genome_id}/08-final/gff/{genome_id}_virify.gff"
        virify_tsv = f"{virify_outdir}/{genome_id}/{genome_id}/08-final/gff/{genome_id}_virify_contig_viewer_metadata.tsv"
        if Path(virify_gff).exists():
            print(f"Virify completed for {genome_id}, copying the file now")
            folder_prefix = genome_id[:11]
            shutil.copyfile(
                virify_gff,
                f"{results_folder}/species_catalogue/{folder_prefix}/{genome_id}/genome/{genome_id}_virify.gff",
            )
            if Path(virify_tsv).exists():
                shutil.copyfile(
                    virify_tsv,
                    f"{results_folder}/species_catalogue/{folder_prefix}/{genome_id}/genome/{genome_id}_virify_metadata.tsv",
                )
            else:
                print("WARNING: genome {} has a gff output but no associated metadata tsv file. Check Virify logs for"
                      "errors".format(genome_id))
        else:
            if launched_jobs <= MAX_VIRIFY_JOBS:
                print(
                    launch_virify(
                        f"{virify_outdir}/{genome_id}",
                        genome_id,
                        str(genome_fasta.resolve()),
                    )
                )
                launched_jobs += 1
            else:
                print(
                    "The max number of virify jobs were launched."
                    " Please wait until more of them are completed and re-run this script"
                )
                break


if __name__ == "__main__":
    main()
