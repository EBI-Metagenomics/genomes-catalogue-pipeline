# coding=utf-8

"""
Library module imported by generate_readme_proks.py (prokaryotic catalogues) and
generate_readme_euks.py (eukaryotic catalogues). It is not meant to be run directly.

Holds the code both scripts share: argument parsing, the study list, the changelog for
catalogue updates and writing the README out. The README body itself is specific to each script.
"""

import sys
from pathlib import Path
import re

import pandas as pd

XLARGE_NOTE = """
* Due to the size of this catalogue, the clustering process was performed in two phases. First, the entire genome set \
was split up into random chunks of 25,000 genomes and each chunk was clustered independently. The species representative \
genomes from all chunks were then pulled together and clustered again. If two or more species representative genomes \
clustered together in the second round of clustering, their genome clusters from the first round of clustering were \
combined together. In some cases, this can produce clusters where some of the conspecific genomes share less than 95% ANI. 
"""


# ---------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------

def add_common_arguments(parser):
    """
    Add the arguments both README scripts take. generate_readme_euks.py also adds --datascout-link.
    """
    parser.add_argument(
        "-m",
        "--metadata-table",
        required=True,
        help="A path to the metadata table for the catalogue",
    )
    parser.add_argument("-o", "--outfile-name", required=True, help="A path to outfile")
    parser.add_argument(
        "-b",
        "--biome",
        required=True,
        help="The biome for the catalog. Do not specify if it is prokaryotic or eukaryotic here. "
             "Examples: human gut, cow rumen, human oral, marine",
    )
    parser.add_argument(
        "--pipeline-version",
        default="5.0.0",
        type=str,
        help="Genomes pipeline version",
    )
    parser.add_argument(
        "--git-link",
        type=str,
        required=True,
        help="Full link to the genomes pipeline github repo release. The link to the pipeline README is built from it, "
             "so it must end in /releases/tag/<version>. The pipeline version is extracted from here as well."
             "Example: https://github.com/EBI-Metagenomics/genomes-catalogue-pipeline/releases/tag/v5.0.0",
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
        "--previous-metadata-table", required=False,
        help="If this README is for an update, provide the path to the previous metadata table.",
    )
    parser.add_argument(
        "--additional-data-path", required=False,
        help="If this README is for an update, provide the path to the 'additional_data' folder "
             "(in the catalogue pipeline output).",
    )
    parser.add_argument(
        "--study-list-threshold",
        type=int,
        default=20,
        help="If the number of studies used to generate the catalogue exceeds this value, "
             "the full study list is written to a separate study_list.txt file (alongside "
             "the README) instead of being listed inline. Default: 20.",
    )
    parser.add_argument(
        "--remove-list", required=False,
        help="If this README is for an update, optionally provide the list of genomes that were removed, "
             "with the reason for each removal: one genome per line, accession then reason, separated by "
             "whitespace. Accessions can be MGYG or INSDC (INSDC accessions are looked up in the "
             "Genome_accession column of the previous metadata table). Removed genomes with no reason in this "
             "list are looked up in the QC reports in --additional-data-path "
             "(update_execution_reports/qs50_failed_previous_catalogue_version.csv, then "
             "combined_QC_failed_report.txt); the script stops if any removed genome has no reason.",
    )


def validate_update_args(previous_readme, previous_version, previous_metadata_table, additional_data_path,
                         remove_list=None):
    """If this README is for an updated catalogue, check that all the update arguments are provided."""
    if previous_readme or previous_version or previous_metadata_table or remove_list:
        if not all([previous_readme, previous_version, previous_metadata_table, additional_data_path]):
            raise ValueError(
                "For updates, you must provide --previous-readme, "
                "--previous-version, --additional-data-path, and --previous-metadata-table together "
                "(--remove-list is optional and only valid for updates)."
            )


# ---------------------------------------------------------------------------
# Parse out genomes pipeline version
# ---------------------------------------------------------------------------

def extract_release_version(link, arg_name):
    """
    Extract the version from a GitHub release link, without the leading "v":
        https://github.com/EBI-Metagenomics/genomes-catalogue-pipeline/releases/tag/v5.0.0 -> 5.0.0
    Raises ValueError if the link does not end in /releases/tag/<version>.
    """
    match = re.search(r"/releases/tag/v?(\d+(?:\.\d+)*)/?$", link.strip())
    if not match:
        raise ValueError(
            f"Could not extract a version from {arg_name} '{link}'. "
            f"Expected a link ending in /releases/tag/<version>, e.g. .../releases/tag/v5.0.0"
        )
    return match.group(1)


# ---------------------------------------------------------------------------
# README sections and output
# ---------------------------------------------------------------------------

def build_catalogue_url(catalog_name, version):
    """Website URL of the catalogue, e.g. human-gut + v2.0 -> .../genome-catalogues/human-gut-v2-0"""
    return "https://www.ebi.ac.uk/metagenomics/genome-catalogues/{}-{}".format(
        catalog_name, version.replace(".", "-")
    )


def build_study_list_string(study_list, study_list_threshold, outfile_name):
    """
    Build the README line listing the studies used to generate the catalogue. If there are more
    than study_list_threshold studies, write them to study_list.txt alongside the README instead.
    """
    if len(study_list) > study_list_threshold:
        study_list_file = Path(outfile_name).parent / "study_list.txt"
        with open(study_list_file, "w") as f:
            for study in sorted(study_list):
                f.write(study + "\n")
        return (
            f"* Genomes from {len(study_list)} studies were used to generate the catalogue. "
            f"See the full list of studies in study_list.txt"
        )
    return (
        "* Genomes from the following studies were used to generate the catalogue: "
        + ", ".join(sorted(study_list))
    )


def get_xlarge_note(xlarge):
    """Note on two-phase clustering for catalogues generated with --xlarge."""
    return XLARGE_NOTE if xlarge else "\n"


def build_changelogs(version, previous_version, metadata_table, previous_metadata_table, additional_data_path,
                     outfile_name, previous_readme, remove_list=None):
    """
    If this is an update (previous_readme is set), generate a changelog from the previous version
    and pull the older changelogs out of the previous README. Returns empty strings otherwise.

    Returns
    -------
    changelog, previous_changelog : str, str
    """
    if not previous_readme:
        return "", ""
    changelog = create_changelog(version, previous_version, metadata_table, previous_metadata_table,
                                 additional_data_path, outfile_name, remove_list)
    previous_changelog = extract_previous_changelogs(previous_readme)
    return changelog, previous_changelog


def write_readme(outfile_name, readme_text, changelog, previous_changelog):
    """Append the changelogs (if any) to the README text and write it out."""
    if changelog:
        readme_text += "\n\n" + changelog
    if previous_changelog:
        readme_text += "\n\n" + previous_changelog

    with open(outfile_name, "w") as outfile:
        outfile.write(readme_text)


# ---------------------------------------------------------------------------
# Changelog for catalogue updates
# ---------------------------------------------------------------------------

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


def create_changelog(version, previous_version, metadata_table, previous_metadata_table,
                     additional_data_path, outfile_name, remove_list=None):
    new_df = count_new_genomes(metadata_table, previous_metadata_table)
    species_rep_replacements, removals = load_rep_changes(additional_data_path)
    removed_species, species_rep_replacements, previous_species_count, current_species_count = \
        resolve_species_changes(metadata_table, previous_metadata_table, species_rep_replacements, removals)
    removed_genomes_df = find_removed_genomes(metadata_table, previous_metadata_table, additional_data_path,
                                              remove_list)
    out_dir = Path(outfile_name).parent
    new_species_count, new_strains_count = count_new_species_and_strains(additional_data_path, metadata_table)

    # The changelog counts must explain the change in the species total
    expected_species_count = previous_species_count - len(removed_species) + new_species_count
    if expected_species_count != current_species_count:
        warn(f"Species counts do not add up: {previous_species_count} previous - {len(removed_species)} removed "
             f"+ {new_species_count} new = {expected_species_count}, but the catalogue has "
             f"{current_species_count} species. Check the changelog counts")
    changelog_header = f"## Changes in release {version} since {previous_version}\n"

    # Initialize lines
    lines = [changelog_header]

    new_genome_line = summarise_new_genomes(new_df, outfile_name)
    if new_genome_line:
        lines.append(new_genome_line)

        # New species/strain line
        if new_species_count > 0 or new_strains_count > 0:
            new_species_line = f"This resulted in {new_species_count} new species and {new_strains_count} new strains."
            lines.append(new_species_line)

    removed_genomes_line = summarise_removed_genomes(removed_genomes_df, out_dir)
    if removed_genomes_line:
        lines.append(removed_genomes_line)

    removed_species_line = summarise_removed_species(removed_species, previous_metadata_table, out_dir)
    if removed_species_line:
        lines.append(removed_species_line)

    replaced_reps_line = summarise_replaced_reps(species_rep_replacements, out_dir)
    if replaced_reps_line:
        lines.append(replaced_reps_line)

    lines.append("* Due to version changes and updates to the pipeline, all annotations were regenerated.")

    # Join all lines into a single block
    changelog_text = "\n".join(lines)
    return changelog_text


def count_new_species_and_strains(additional_data_path, metadata_table):
    clusters_split_path = (
        Path(additional_data_path)
        / "update_execution_reports"
        / "clusters_split_new_species.txt"
    )

    mash_new_strains_path = (
        Path(additional_data_path)
        / "update_execution_reports"
        / "mash_parse_results"
        / "new_strains.tsv"
    )

    def strip_extension(acc):
        for ext in (".fa", ".fna", ".fasta"):
            if acc.endswith(ext):
                return acc[: -len(ext)]
        return acc

    new_species_count = 0
    new_strains_count = 0

    df = pd.read_csv(metadata_table, sep="\t")
    catalogue_genomes = set(df["Genome"])

    # it's ok if clusters split doesn't exist - it won't if there were no new species added
    if clusters_split_path.exists():
        with open(clusters_split_path, "r") as file_in:
            for line in file_in:
                line = line.strip()
                if not line:
                    continue

                # Take everything after the last colon
                # The lines look like this:
                # many_genomes: 14_1:MGYG000535625.fa, MGYG000535617.fa
                # one_genome: 15_0:MGYG000535607.fa
                accession_part = line.rsplit(":", 1)[-1]

                accessions = [
                    strip_extension(a.strip())
                    for a in accession_part.split(",")
                ]

                # First accession → species
                species_acc = accessions[0]
                if species_acc in catalogue_genomes:
                    new_species_count += 1

                # Remaining accessions → strains
                for acc in accessions[1:]:
                    if acc in catalogue_genomes:
                        new_strains_count += 1

    # New strains that were added to existing catalogue clusters are reported separately, and we need to count them.
    # We do not report the repeat strain count in the readme 
    if mash_new_strains_path.exists():
        mash_df = pd.read_csv(mash_new_strains_path, sep="\t")
        new_strains = set(mash_df["Accession"])
        for strain in new_strains:
            if strain in catalogue_genomes:
                new_strains_count += 1
    return new_species_count, new_strains_count


def summarise_new_genomes(new_genomes_df, outfile_name):
    """
    Build a one-line summary of newly added genomes and write the full
    per-genome list to added_genomes.tsv alongside the README.

    Parameters
    ----------
    new_genomes_df : pd.DataFrame
        Newly added genomes, with columns 'Genome', 'Genome_type', 'Study_accession'.
    outfile_name : str
        Path to the README output file; added_genomes.tsv is written into the
        same directory.

    Returns
    -------
    str
        Summary sentence for the changelog, or an empty string if there are
        no new genomes.
    """
    if new_genomes_df.empty:
        return ""

    mag_count = int((new_genomes_df["Genome_type"] == "MAG").sum())
    isolate_count = int((new_genomes_df["Genome_type"] == "Isolate").sum())

    parts = []
    if mag_count > 0:
        parts.append(f"{mag_count} MAGs")
    if isolate_count > 0:
        parts.append(f"{isolate_count} isolates")

    if not parts:
        return ""

    added_genomes_file = Path(outfile_name).parent / "added_genomes.tsv"
    new_genomes_df[["Genome", "Genome_type", "Study_accession"]].to_csv(
        added_genomes_file, sep="\t", index=False
    )

    summary = (
        "* "
        + " and ".join(parts)
        + " were added to the catalogue. See the full list and the source projects in added_genomes.tsv"
    )
    return summary


def load_remove_list(remove_list, previous_df):
    """
    Load the list of genomes removed on purpose, with the reason for each removal.

    Each line holds an accession and a reason, separated by a tab or other
    whitespace (the reason may itself contain spaces), e.g.:
        JDVW01          Genome suppressed
        MGYG000007070   Source sample not known
    Accessions that are not MGYG accessions are treated as INSDC accessions and
    converted to MGYG accessions via the Genome_accession column of the previous
    metadata table.

    Returns
    -------
    dict
        {MGYG accession: reason}
    """
    if not remove_list:
        return {}

    insdc_to_mgyg = dict(
        zip(previous_df["Genome_accession"].astype(str), previous_df["Genome"])
    ) if "Genome_accession" in previous_df.columns else {}

    reasons = {}
    unresolved = []
    with open(remove_list, "r") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            parts = line.split(None, 1)
            accession = parts[0]
            reason = parts[1].strip() if len(parts) > 1 else ""  # empty reason is reported later

            if accession.startswith("MGYG"):
                mgyg = accession
            else:
                mgyg = insdc_to_mgyg.get(accession)
                if mgyg is None:
                    unresolved.append(accession)
                    continue
            reasons[mgyg] = reason

    if unresolved:
        warn(f"{len(unresolved)} accession(s) in the remove list were not found in the "
             f"Genome_accession column of the previous metadata table and were ignored", unresolved)
    return reasons


def strip_accession_extension(accession):
    """Remove a FASTA file extension (optionally gzipped) from an MGYG accession."""
    accession = accession.strip()
    if accession.endswith(".gz"):
        accession = accession[:-3]
    for ext in (".fa", ".fna", ".fasta"):
        if accession.endswith(ext):
            return accession[: -len(ext)]
    return accession


def load_qc_failed_reasons(additional_data_path):
    """
    Load reasons for removal from the two QC reports in additional_data_path.
    Both files must exist.

    - update_execution_reports/qs50_failed_previous_catalogue_version.csv (comma-delimited):
      any line starting with an MGYG accession -> "Failed QC"
    - combined_QC_failed_report.txt (tab-delimited):
      lines starting with an MGYG accession -> reason from column 2

    Accessions may carry a file extension (e.g. .fa), which is removed.

    Returns
    -------
    qs50_reasons, combined_qc_reasons : dict, dict
        {MGYG accession: reason}
    """
    qs50_path = Path(additional_data_path) / "update_execution_reports" / "qs50_failed_previous_catalogue_version.csv"
    combined_qc_path = Path(additional_data_path) / "combined_QC_failed_report.txt"
    for path in (qs50_path, combined_qc_path):
        if not path.exists():
            raise FileNotFoundError(f"Missing QC report file: {path}")

    qs50_reasons = {}
    with open(qs50_path, "r") as fh:
        for line in fh:
            if line.startswith("MGYG"):
                accession = strip_accession_extension(line.split(",", 1)[0])
                qs50_reasons[accession] = "Failed QC"

    combined_qc_reasons = {}
    with open(combined_qc_path, "r") as fh:
        for line in fh:
            if line.startswith("MGYG"):
                fields = line.rstrip("\n").split("\t")
                accession = strip_accession_extension(fields[0])
                reason = fields[1].strip() if len(fields) > 1 else ""
                if reason:
                    combined_qc_reasons[accession] = reason

    return qs50_reasons, combined_qc_reasons


def find_removed_genomes(metadata_table, previous_metadata_table, additional_data_path, remove_list=None):
    """
    Identify all genomes present in the previous metadata table but not the current one,
    and attach the reason for each removal. Reasons are taken from the first source
    that has one, in this order:
        1. the remove list (--remove-list), if provided
        2. update_execution_reports/qs50_failed_previous_catalogue_version.csv
        3. combined_QC_failed_report.txt
    Raises ValueError if any removed genome has no reason in any of them.

    Returns
    -------
    pd.DataFrame
        Columns: 'Genome', 'Genome_accession', 'Species_rep' (in the previous release),
        'Was_species_rep', 'Reason'.
    """
    current_df = pd.read_csv(metadata_table, sep="\t")
    previous_df = pd.read_csv(previous_metadata_table, sep="\t")

    remove_list_reasons = load_remove_list(remove_list, previous_df)
    qs50_reasons, combined_qc_reasons = load_qc_failed_reasons(additional_data_path)
    reasons = remove_list_reasons  # checks below apply to the remove list only
    current_genomes = set(current_df["Genome"])

    still_present = sorted(g for g in reasons if g in current_genomes)
    if still_present:
        warn(f"{len(still_present)} genome(s) in the remove list are still in the current metadata table",
             still_present)
    not_in_previous = sorted(set(reasons) - set(previous_df["Genome"]) - current_genomes)
    if not_in_previous:
        warn(f"{len(not_in_previous)} MGYG accession(s) in the remove list are not in the previous "
             f"metadata table", not_in_previous)

    cols = [c for c in ("Genome", "Genome_accession", "Species_rep") if c in previous_df.columns]
    removed_df = previous_df[~previous_df["Genome"].isin(current_genomes)][cols].copy()
    removed_df["Was_species_rep"] = removed_df["Genome"] == removed_df["Species_rep"]

    def resolve_reason(genome):
        # An empty reason in the remove list falls through to the QC reports
        for source in (remove_list_reasons, qs50_reasons, combined_qc_reasons):
            if source.get(genome):
                return source[genome]
        return None

    removed_df["Reason"] = removed_df["Genome"].map(resolve_reason)

    # Every removed genome must have a reason; stop rather than write an incomplete changelog
    missing = list(removed_df.loc[removed_df["Reason"].isna(), "Genome"])
    if missing:
        sources = ["qs50_failed_previous_catalogue_version.csv", "combined_QC_failed_report.txt"]
        sources.insert(0, "the remove list" if remove_list else "a remove list (--remove-list was not provided)")
        listed_without_reason = [g for g in missing if g in remove_list_reasons]
        message = format_accessions(
            f"{len(missing)} genome(s) were removed from the catalogue but have no reason for removal in "
            f"{', '.join(sources[:-1])} or {sources[-1]}", missing)
        if listed_without_reason:
            message += "\n" + format_accessions(
                f"Of these, {len(listed_without_reason)} are in the remove list without a reason",
                listed_without_reason)
        raise ValueError(message)

    return removed_df


def format_accessions(message, accessions, limit=10):
    """Append up to `limit` accessions to a message."""
    if not accessions:
        return message
    shown = ", ".join(accessions[:limit])
    more = f" ... (+{len(accessions) - limit} more)" if len(accessions) > limit else ""
    return f"{message}: {shown}{more}"


def warn(message, accessions=None, limit=10):
    """Print a warning to stderr, listing up to `limit` accessions."""
    print(f"WARNING: {format_accessions(message, accessions, limit)}", file=sys.stderr)


def summarise_removed_genomes(removed_genomes_df, out_dir):
    """
    Write all removed genomes to removed_genomes.tsv and return a changelog summary
    with a per-reason breakdown. Returns an empty string if nothing was removed.
    """
    if removed_genomes_df.empty:
        return ""

    removed_genomes_df[["Genome", "Was_species_rep", "Reason"]].rename(
        columns={"Reason": "Reason_for_removal"}
    ).to_csv(Path(out_dir) / "removed_genomes.tsv", sep="\t", index=False)

    lines = [f"* {len(removed_genomes_df)} genomes were removed from the catalogue. "
             f"See the full list and the reason for each removal in removed_genomes.tsv"]
    summary_reasons = removed_genomes_df["Reason"].map(summarise_removal_reason)
    for reason, count in summary_reasons.value_counts().items():
        lines.append(f"    - {reason}: {count}")
    return "\n".join(lines)


def summarise_removal_reason(reason):
    """
    Collapse a detailed removal reason into a category for the README summary.
    The full reason is still written to removed_genomes.tsv.
    """
    if reason.startswith("Duplicate of "):
        return "Exact duplicate"
    if reason.startswith("Assembly from this sample already exists"):
        return "Removed during curation of redundant genomes derived from the same source sample"
    if ":" in reason:
        return reason.split(":", 1)[0].strip()
    return reason


def summarise_removed_species(removals, previous_metadata_table, out_dir):
    """
    Write species that are no longer in the catalogue (identified by their previous
    species representative) to removed_species.tsv and return a changelog summary.
    Returns an empty string if no species were removed.
    """
    if not removals:
        return ""

    previous_df = pd.read_csv(previous_metadata_table, sep="\t")
    lineage = dict(zip(previous_df["Genome"], previous_df["Lineage"])) if "Lineage" in previous_df.columns else {}

    removed_species_df = pd.DataFrame({
        "Previous_species_rep": removals,
        "Lineage": [lineage.get(rep, "") for rep in removals],
    })
    removed_species_df.to_csv(Path(out_dir) / "removed_species.tsv", sep="\t", index=False)

    return (f"* {len(removals)} species are no longer in the catalogue. "
            f"See their previous species representatives in removed_species.tsv")


def summarise_replaced_reps(species_rep_replacements, out_dir):
    """
    Write species representative replacements to replaced_species_reps.tsv and return
    a changelog summary with a per-reason breakdown. Returns an empty string if none.
    """
    if not species_rep_replacements:
        return ""

    replaced_df = pd.DataFrame(
        [(old, change["new_rep"], change["reason"]) for old, change in species_rep_replacements.items()],
        columns=["Previous_species_rep", "New_species_rep", "Reason"],
    )
    replaced_df.to_csv(Path(out_dir) / "replaced_species_reps.tsv", sep="\t", index=False)

    lines = [f"* {len(replaced_df)} species representatives were replaced. "
             f"See the previous and new representatives and the reason for each replacement "
             f"in replaced_species_reps.tsv"]
    for reason, count in replaced_df["Reason"].value_counts().items():
        lines.append(f"    - {reason}: {count}")
    return "\n".join(lines)


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
        old_rep = strip_accession_extension(str(row["old_rep"]))
        new_rep = row["new_rep"]
        reason = row["reason"]

        # Treat NaN or empty new_rep as removal
        if pd.isna(new_rep) or str(new_rep).strip() == "":
            removals.append(old_rep)
        else:
            species_rep_replacements[old_rep] = {
                "new_rep": strip_accession_extension(str(new_rep)),
                "reason": reason,
            }

    return species_rep_replacements, removals


def resolve_species_changes(metadata_table, previous_metadata_table, species_rep_replacements, removals):
    """
    Work out which previous species are no longer in the catalogue, using the metadata tables.

    A previous species is removed if none of its genomes are in the current catalogue and it was not given a
    replacement representative that is.

    Returns
    -------
    removed_species : list
        Previous species representatives of the species no longer in the catalogue.
    valid_replacements : dict
        The replacements whose new representative is in the current catalogue,
        {old_rep: {"new_rep": new_rep, "reason": reason}}.
    previous_species_count, current_species_count : int
    """
    previous_df = pd.read_csv(previous_metadata_table, sep="\t", usecols=["Genome", "Species_rep"]).dropna()
    current_df = pd.read_csv(metadata_table, sep="\t", usecols=["Genome", "Species_rep"]).dropna()
    previous_reps = set(previous_df["Species_rep"])
    current_genomes = set(current_df["Genome"])

    # Previous species that still have at least one genome in the catalogue
    with_genomes_left = set(previous_df.loc[previous_df["Genome"].isin(current_genomes), "Species_rep"])

    valid_replacements = {}
    replaced_by_missing = []
    for old_rep, change in species_rep_replacements.items():
        if change["new_rep"] in current_genomes:
            valid_replacements[old_rep] = change
        else:
            replaced_by_missing.append(old_rep)
    if replaced_by_missing:
        warn(f"{len(replaced_by_missing)} species representative replacement(s) in "
             f"update_cluster_rep_changes_report.tsv point to a genome that is not in the current catalogue "
             f"and are not reported as replacements", sorted(replaced_by_missing))

    removed_species = sorted(previous_reps - with_genomes_left - set(valid_replacements))

    still_present = sorted(set(removals) - set(removed_species))
    if still_present:
        warn(f"{len(still_present)} species reported as removed in update_cluster_rep_changes_report.tsv "
             f"are still in the catalogue and are not counted as removed", still_present)

    return removed_species, valid_replacements, len(previous_reps), current_df["Species_rep"].nunique()


def count_new_genomes(metadata_table, previous_metadata_table):
    """
    Identify genomes present in the current metadata table but not the previous one.

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
    pd.DataFrame
        Subset of the current metadata table containing only the newly added
        genomes, with columns 'Genome', 'Genome_type', 'Study_accession'.
    """

    # Read tab-delimited metadata tables
    current_df = pd.read_csv(metadata_table, sep="\t")
    previous_df = pd.read_csv(previous_metadata_table, sep="\t")

    # Identify new genomes
    new_genomes_set = set(current_df["Genome"]) - set(previous_df["Genome"])

    # Filter current metadata to new genomes
    new_df = current_df[current_df["Genome"].isin(new_genomes_set)][
        ["Genome", "Genome_type", "Study_accession"]
    ]
    return new_df
