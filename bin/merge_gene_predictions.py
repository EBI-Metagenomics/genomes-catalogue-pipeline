#!/usr/bin/env python3
# coding=utf-8

# This file is part of MGnify genome analysis pipeline.
#
# MGnify genome analysis pipeline is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# MGnify genome analysis pipeline is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with MGnify genome analysis pipeline. If not, see <https://www.gnu.org/licenses/>.

import argparse
import logging
import re
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, TextIO, Tuple
from Bio import SeqIO
from Bio.SeqRecord import SeqRecord

logger = logging.getLogger(__name__)


@dataclass
class Transcript:
    """CDS model of a single transcript: its contig, strand, sorted exons and per-exon GFF phases."""

    contig: str
    strand: str
    exons: List[Tuple[int, int]] = field(default_factory=list)
    phases: Dict[Tuple[int, int], str] = field(default_factory=dict)

    @property
    def start(self) -> int:
        """Leftmost exon start."""
        return min(exon[0] for exon in self.exons)

    @property
    def end(self) -> int:
        """Rightmost exon end."""
        return max(exon[1] for exon in self.exons)

    @property
    def length(self) -> int:
        """Total CDS length in bases (1-based)."""
        return sum(exon[1] - exon[0] + 1 for exon in self.exons)


@dataclass
class GffFeature:
    seqid: str
    source: str
    feature_type: str
    start: str
    end: str
    score: str
    strand: str
    phase: str
    attributes: str

    @classmethod
    def parse(cls, line: str) -> Optional["GffFeature"]:
        """Parse a GFF line into a GffFeature, or None if it is not a 9-column row."""
        cols = line.rstrip("\n").split("\t")
        if len(cols) != 9:
            return None
        return cls(*cols)

    def render(
        self, *, source: Optional[str] = None, attributes: Optional[str] = None
    ) -> str:
        """Serialise back to a GFF line, optionally overriding the source/attributes columns."""
        return "\t".join(
            [
                self.seqid,
                source if source is not None else self.source,
                self.feature_type,
                self.start,
                self.end,
                self.score,
                self.strand,
                self.phase,
                attributes if attributes is not None else self.attributes,
            ]
        )


@dataclass
class BrakerGene:
    """All GFF feature rows of a single BRAKER gene, with its leftmost start."""

    contig: str
    start: int
    lines: List[GffFeature] = field(default_factory=list)


def transcript_key(attr: str, is_metaeuk: bool) -> Optional[str]:
    """Return a unique transcript key from a CDS attribute column, by caller.

    BRAKER and MetaEuk encode transcript identity differently:
      * BRAKER  -- the CDS carries ``Parent=g<n>.t<m>``, already unique, so it is returned as-is.
      * MetaEuk -- the CDS carries ``TCS_ID=<acc>|<contig>|...``. MetaEuk repeats gene accessions
                   across contigs, so the accession alone is NOT unique; the key is
                   ``<acc>|<contig>`` (the first two fields) to be unique per gene/contig. MetaEuk
                   produces one transcript per gene, so this doubles as the gene and transcript key.

    Returns None when the expected attribute (TCS_ID= / Parent=) is absent or malformed.
    """
    if is_metaeuk:
        tcs = None
        for part in attr.split(";"):
            if part.startswith("TCS_ID="):
                tcs = part.split("=", 1)[1]
                break
        if tcs is None:
            return None
        composite = tcs.split("|")
        if len(composite) < 2:
            return None
        return "|".join(composite[0:2])

    parent = None
    for part in attr.split(";"):
        if part.startswith("Parent="):
            parent = part.split("=", 1)[1]
            break
    return parent


def read_cds(gff_file: str, is_metaeuk: bool) -> Dict[str, Transcript]:
    """
    Returns a dict: transcript_key -> Transcript(contig, strand, exons=[(start, end), ...]).
    """
    transcripts: Dict[str, Transcript] = {}
    with open(gff_file, "r") as handle:
        for line in handle:
            if line.startswith("##FASTA"):
                break
            if line.startswith("#"):
                continue
            feature = GffFeature.parse(line)
            if feature is None:
                if line.strip():
                    logger.debug(
                        f"Skipping malformed (non 9-column) line: {line.rstrip()}"
                    )
                continue
            if feature.feature_type != "CDS":
                continue
            key = transcript_key(feature.attributes, is_metaeuk)
            if key is None:
                logger.debug(
                    f"Skipping CDS with no transcript key: {feature.attributes}"
                )
                continue
            transcript = transcripts.setdefault(
                key, Transcript(contig=feature.seqid, strand=feature.strand)
            )
            coord = (int(feature.start), int(feature.end))
            transcript.exons.append(coord)
            transcript.phases[coord] = feature.phase

    for transcript in transcripts.values():
        transcript.exons.sort(key=lambda coord: coord[0])
    caller = "MetaEuk" if is_metaeuk else "BRAKER"
    logger.info(f"Read {len(transcripts)} {caller} CDS transcripts from {gff_file}")
    return transcripts


def exon_overlap(
    transcript1: Transcript, transcript2: Transcript, threshold: float
) -> Tuple[bool, float]:
    """
    Reciprocal CDS overlap test between two transcripts.
    """
    exons1, exons2 = transcript1.exons, transcript2.exons
    total1, total2 = transcript1.length, transcript2.length

    overlap = 0
    i, j = 0, 0
    while i < len(exons1) and j < len(exons2):
        start = max(exons1[i][0], exons2[j][0])
        end = min(exons1[i][1], exons2[j][1])
        if start <= end:
            overlap += end - start + 1
        if exons1[i][1] < exons2[j][1]:
            i += 1
        else:
            j += 1

    cov1 = overlap / total1 if total1 > 0 else 0
    cov2 = overlap / total2 if total2 > 0 else 0
    return (cov1 >= threshold and cov2 >= threshold), cov1


def matched_secondary_transcripts(
    primary: Dict[str, Transcript], secondary: Dict[str, Transcript], threshold: float
) -> Tuple[Set[str], Dict[str, float]]:
    """Return the set of tool2 transcript keys that overlap a tool1 transcript, plus a map of
    tool1 transcript key -> cov1 (overlapped fraction) for each overlapped tool1 transcript.
    """
    primary_by_contig = defaultdict(list)
    for key1, transcript in primary.items():
        primary_by_contig[transcript.contig].append((key1, transcript))

    matched = set()
    overlapped_fraction: Dict[str, float] = {}
    for key2, transcript2 in secondary.items():
        for key1, transcript1 in primary_by_contig.get(transcript2.contig, []):
            if transcript1.strand != transcript2.strand:
                continue
            is_match, cov1 = exon_overlap(transcript1, transcript2, threshold)
            if is_match:
                matched.add(key2)
                overlapped_fraction[key1] = cov1
                logger.debug(f"MetaEuk {key2} overlaps BRAKER {key1} (cov1={cov1:.4f})")
                break
            if cov1 > 0:
                logger.debug(
                    f"MetaEuk {key2} not overlaps BRAKER {key1} (cov1={cov1:.4f})"
                )
    return matched, overlapped_fraction


def parse_braker_genes(gff_file: str) -> Tuple[Dict[int, BrakerGene], List[str]]:
    """Group BRAKER GFF feature lines by gene number, recording each gene's position."""
    gene_re = re.compile(r"(?:ID|Parent)=g(\d+)")
    genes: Dict[int, BrakerGene] = {}
    contig_order = []
    with open(gff_file, "r") as handle:
        for line in handle:
            if line.startswith("#"):
                continue
            feature = GffFeature.parse(line)
            if feature is None:
                if line.strip():
                    logger.debug(
                        f"Skipping malformed (non 9-column) line: {line.rstrip()}"
                    )
                continue
            match = gene_re.search(feature.attributes)
            if match is None:
                continue
            old_number = int(match.group(1))
            contig = feature.seqid
            start = int(feature.start)
            if contig not in contig_order:
                contig_order.append(contig)
            gene = genes.setdefault(old_number, BrakerGene(contig=contig, start=start))
            gene.start = min(gene.start, start)
            gene.lines.append(feature)
    logger.info(
        f"Parsed {len(genes)} BRAKER genes across {len(contig_order)} contigs from {gff_file}"
    )
    return genes, contig_order


def braker_gene_predictor(lines: List[GffFeature]) -> str:
    """Return the BRAKER predictor source for a gene (e.g. 'AUGUSTUS', 'GeneMark.hmm3')."""
    return lines[0].source if lines else ""


def build_metaeuk_gff_lines(
    transcript: Transcript, gene_id: str, tool_name: str, original_gene_id: str
) -> List[str]:
    """Reconstruct standard gene/mRNA/exon/CDS lines for a MetaEuk gene with a BRAKER-style ID."""
    contig = transcript.contig
    strand = transcript.strand
    exons = transcript.exons
    gene_start, gene_end = transcript.start, transcript.end
    transcript_id = f"{gene_id}.t1"

    lines = [
        "\t".join(
            [
                contig,
                tool_name,
                "gene",
                str(gene_start),
                str(gene_end),
                ".",
                strand,
                ".",
                f"ID={gene_id};original_gene_id={original_gene_id};"
                f"prediction_support=1;prediction_tools=MetaEuk",
            ]
        ),
        "\t".join(
            [
                contig,
                tool_name,
                "mRNA",
                str(gene_start),
                str(gene_end),
                ".",
                strand,
                ".",
                f"ID={transcript_id};Parent={gene_id}",
            ]
        ),
    ]
    for exon_number, coord in enumerate(exons, start=1):
        lines.append(
            "\t".join(
                [
                    contig,
                    tool_name,
                    "exon",
                    str(coord[0]),
                    str(coord[1]),
                    ".",
                    strand,
                    ".",
                    f"ID={transcript_id}.exon{exon_number};Parent={transcript_id}",
                ]
            )
        )
    for cds_number, coord in enumerate(exons, start=1):
        lines.append(
            "\t".join(
                [
                    contig,
                    tool_name,
                    "CDS",
                    str(coord[0]),
                    str(coord[1]),
                    ".",
                    strand,
                    transcript.phases.get(coord, "."),
                    f"ID={transcript_id}.CDS{cds_number};Parent={transcript_id}",
                ]
            )
        )
    return lines


def load_fasta_metaeuk(path: str) -> Dict[str, SeqRecord]:
    """Load MetaEuk FASTA records and return a dictionary keyed by gene/transcript ID."""
    records = {}
    for record in SeqIO.parse(path, "fasta"):
        parts = record.id.split("|")
        key = "|".join(parts[0:2]) if len(parts) >= 2 else record.id
        records[key] = record
    return records


def load_fasta_braker(path: str) -> Dict[str, List[SeqRecord]]:
    """Load BRAKER FASTA and group records by gene ID (the part before the first dot)."""
    grouped = {}
    for record in SeqIO.parse(path, "fasta"):
        gene = record.id.partition(".")[0]
        grouped.setdefault(gene, []).append(record)
    return grouped


def append_attribute(col9: str, key: str, value: str) -> str:
    """Append key=value to a GFF attribute column, unless the key is already present."""
    if f"{key}=" in col9:
        return col9
    if col9 and not col9.endswith(";"):
        col9 += ";"
    return f"{col9}{key}={value}"


def order_genes_by_position(
    braker_genes: Dict[int, BrakerGene],
    braker_contig_order: List[str],
    metaeuk_cds: Dict[str, Transcript],
    unique_metaeuk: List[str],
) -> Tuple[List[Tuple[bool, object]], Dict[str, str], Dict[str, str]]:
    """Order all kept genes by genomic position and assign contiguous BRAKER-style placeholder IDs.

    Returns:
        ordered_genes   -- list of (is_braker, ref) in (contig, start) order
        braker_id_map   -- {"g<old>": "g<new>"} for BRAKER genes
        metaeuk_new_ids -- {metaeuk_key: "g<new>"} for MetaEuk-unique genes
    """
    contig_order = list(braker_contig_order)
    for key in unique_metaeuk:
        contig = metaeuk_cds[key].contig
        if contig not in contig_order:
            contig_order.append(contig)
    contig_index = {contig: index for index, contig in enumerate(contig_order)}

    placed = [
        (contig_index[gene.contig], gene.start, True, old_number)
        for old_number, gene in braker_genes.items()
    ]
    placed += [
        (contig_index[metaeuk_cds[key].contig], metaeuk_cds[key].start, False, key)
        for key in unique_metaeuk
    ]
    placed.sort(key=lambda entry: (entry[0], entry[1]))

    braker_id_map, metaeuk_new_ids, ordered_genes = {}, {}, []
    for new_number, (_, _, is_braker, ref) in enumerate(placed, start=1):
        if is_braker:
            braker_id_map[f"g{ref}"] = f"g{new_number}"
            logger.debug(f"Assigned g{new_number} to BRAKER gene g{ref}")
        else:
            metaeuk_new_ids[ref] = f"g{new_number}"
            logger.debug(f"Assigned g{new_number} to MetaEuk gene {ref}")
        ordered_genes.append((is_braker, ref))
    return ordered_genes, braker_id_map, metaeuk_new_ids


def remap_braker_ids(col9: str, braker_id_map: Dict[str, str]) -> str:
    """Remap BRAKER gene IDs (g<old> -> g<new>) in the ID= and Parent= attributes of a GFF column 9."""
    col9 = re.sub(
        r"ID=(g\d+)", lambda m: f"ID={braker_id_map.get(m.group(1), m.group(1))}", col9
    )
    col9 = re.sub(
        r"Parent=(g\d+)",
        lambda m: f"Parent={braker_id_map.get(m.group(1), m.group(1))}",
        col9,
    )
    return col9


def render_braker_gff_lines(
    gene: BrakerGene,
    old_number: int,
    braker_id_map: Dict[str, str],
    overlapped_fraction: Dict[str, float],
) -> List[str]:
    """
    Rewrite a BRAKER gene's GFF lines: remap IDs, set source to predictor, add original_gene_id,
    and add prediction_support/prediction_tools/prediction_overlap to genes that overlap a MetaEuk
    transcript.
    """
    original_gene_id = f"g{old_number}"
    predictor = braker_gene_predictor(gene.lines)

    gene_overlap_fractions = []
    for feature in gene.lines:
        if feature.feature_type != "mRNA":
            continue
        transcript_match = re.search(r"ID=(g\d+\.t\d+)", feature.attributes)
        if transcript_match and transcript_match.group(1) in overlapped_fraction:
            gene_overlap_fractions.append(
                overlapped_fraction[transcript_match.group(1)]
            )
    lines = []
    for feature in gene.lines:
        col9 = remap_braker_ids(feature.attributes, braker_id_map)
        if feature.feature_type == "gene":
            col9 = append_attribute(col9, "original_gene_id", original_gene_id)
            if gene_overlap_fractions:
                col9 = append_attribute(col9, "prediction_support", "2")
                col9 = append_attribute(col9, "prediction_tools", "BRAKER3,MetaEuk")
                col9 = append_attribute(
                    col9,
                    "prediction_overlap",
                    f"{max(gene_overlap_fractions):.4f}",
                )
            else:
                col9 = append_attribute(col9, "prediction_support", "1")
                col9 = append_attribute(col9, "prediction_tools", "BRAKER3")
        lines.append(feature.render(source=predictor, attributes=col9))
    return lines


def write_merged_gff(
    output_path: str,
    ordered_genes: List[Tuple[bool, object]],
    braker_genes: Dict[int, BrakerGene],
    metaeuk_cds: Dict[str, Transcript],
    braker_id_map: Dict[str, str],
    metaeuk_new_ids: Dict[str, str],
    overlapped_fraction: Dict[str, float],
) -> None:
    """Write the position-sorted merged GFF (BRAKER lines remapped, MetaEuk-unique reconstructed)."""
    with open(output_path, "w") as gff_out:
        gff_out.write("##gff-version 3\n")
        for is_braker, ref in ordered_genes:
            if is_braker:
                lines = render_braker_gff_lines(
                    braker_genes[ref], ref, braker_id_map, overlapped_fraction
                )
            else:
                lines = build_metaeuk_gff_lines(
                    metaeuk_cds[ref], metaeuk_new_ids[ref], "MetaEuk", ref
                )
            gff_out.write("\n".join(lines) + "\n")
    logger.info(f"Wrote merged GFF ({len(ordered_genes)} genes) to {output_path}")


def write_renamed_record(record: SeqRecord, new_id: str, out_handle: TextIO) -> None:
    """Write a FASTA record under a new ID, dropping its description."""
    record.id = new_id
    record.description = ""
    SeqIO.write(record, out_handle, "fasta")


def write_merged_fasta(
    output_path: str,
    ordered_genes: List[Tuple[bool, object]],
    braker_by_gene: Dict[str, List[SeqRecord]],
    metaeuk_by_key: Dict[str, SeqRecord],
    braker_id_map: Dict[str, str],
    metaeuk_new_ids: Dict[str, str],
) -> None:
    """Write one merged FASTA (FAA or FFN), IDs remapped, in the GFF gene order."""
    written = 0
    with open(output_path, "w") as out_handle:
        for is_braker, ref in ordered_genes:
            if is_braker:
                new_gene = braker_id_map[f"g{ref}"]
                records = braker_by_gene.get(f"g{ref}", [])
                if not records:
                    logger.warning(
                        f"BRAKER gene g{ref} has no FASTA records for {output_path}"
                    )
                for record in records:
                    _, _, transcript = record.id.partition(".")
                    new_id = f"{new_gene}.{transcript}" if transcript else new_gene
                    write_renamed_record(record, new_id, out_handle)
                    written += 1
            else:
                new_id = f"{metaeuk_new_ids[ref]}.t1"
                write_renamed_record(metaeuk_by_key[ref], new_id, out_handle)
                written += 1
    logger.info(f"Wrote {written} records to {output_path}")


def main(args: argparse.Namespace) -> None:
    braker_cds = read_cds(args.gff_braker, is_metaeuk=False)
    metaeuk_cds = read_cds(args.gff_metaeuk, is_metaeuk=True)
    matched, overlapped_fraction = matched_secondary_transcripts(
        braker_cds, metaeuk_cds, args.threshold
    )
    unique_metaeuk = [key for key in metaeuk_cds if key not in matched]
    logger.info(
        f"{len(matched)} MetaEuk transcripts overlap BRAKER (threshold {args.threshold}); "
        f"{len(unique_metaeuk)} unique MetaEuk transcripts kept"
    )

    braker_genes, braker_contig_order = parse_braker_genes(args.gff_braker)
    ordered_genes, braker_id_map, metaeuk_new_ids = order_genes_by_position(
        braker_genes, braker_contig_order, metaeuk_cds, unique_metaeuk
    )
    logger.info(
        f"Merged into {len(ordered_genes)} genes "
        f"({len(braker_id_map)} BRAKER, {len(metaeuk_new_ids)} MetaEuk-unique)"
    )

    write_merged_gff(
        f"{args.output_prefix}.gff",
        ordered_genes,
        braker_genes,
        metaeuk_cds,
        braker_id_map,
        metaeuk_new_ids,
        overlapped_fraction,
    )

    braker_faa = load_fasta_braker(args.faa_braker)
    braker_ffn = load_fasta_braker(args.ffn_braker)
    metaeuk_faa = load_fasta_metaeuk(args.faa_metaeuk)
    metaeuk_ffn = load_fasta_metaeuk(args.ffn_metaeuk)

    write_merged_fasta(
        f"{args.output_prefix}.faa",
        ordered_genes,
        braker_faa,
        metaeuk_faa,
        braker_id_map,
        metaeuk_new_ids,
    )
    write_merged_fasta(
        f"{args.output_prefix}.ffn",
        ordered_genes,
        braker_ffn,
        metaeuk_ffn,
        braker_id_map,
        metaeuk_new_ids,
    )


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Merge two eukaryotic gene callers' predictions (BRAKER3 + MetaEuk) into a single "
            "non-redundant gene set (GFF/FAA/FFN) with BRAKER-style placeholder IDs."
        )
    )
    parser.add_argument(
        "--gff-braker", required=True, help="BRAKER GFF (kept on overlaps)."
    )
    parser.add_argument("--faa-braker", required=True, help="BRAKER protein FASTA.")
    parser.add_argument(
        "--ffn-braker", required=True, help="BRAKER CDS (nucleotide) FASTA."
    )
    parser.add_argument("--gff-metaeuk", required=True, help="MetaEuk GFF.")
    parser.add_argument("--faa-metaeuk", required=True, help="MetaEuk protein FASTA.")
    parser.add_argument(
        "--ffn-metaeuk", required=True, help="MetaEuk CDS (nucleotide) FASTA."
    )
    parser.add_argument(
        "--threshold", type=float, default=0.1, help="Reciprocal CDS overlap threshold."
    )
    parser.add_argument(
        "--output-prefix",
        required=True,
        help="Output prefix (writes .gff/.faa/.ffn).",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable verbose DEBUG logging (per-transcript matches and skips).",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    main(args)
