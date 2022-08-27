#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  ResourceRequirement:
    ramMin: 500000
    coresMin: 32
  InlineJavascriptRequirement: {}
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.refdata)
        entryname: $("/refdata")
      - entry: $(inputs.drep_folder)
        entryname: $("/data")

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.gtdb-tk:v1"

baseCommand: ["gtdbtk", "classify_wf"]

inputs:
  drep_folder: Directory
  gtdb_outfolder:
    type: string
  refdata: Directory

arguments:
  - prefix: --cpus
    valueFrom: $(runtime.cores)
    position: 1
  - prefix: --genome_dir
    valueFrom: "/data"
    position: 2
  - prefix: -x
    valueFrom: 'fna'
    position: 4
  - prefix: --out_dir
    valueFrom: $(runtime.outdir)/$(inputs.gtdb_outfolder)

outputs:
  gtdbtk_folder:
    type: Directory
    outputBinding:
      glob: $(inputs.gtdb_outfolder)
  gtdbtk_bac:
    type: File?
    outputBinding:
      glob: $(inputs.gtdb_outfolder)/classify/gtdbtk.bac120.summary.tsv
  gtdbtk_arc:
    type: File?
    outputBinding:
      glob: $(inputs.gtdb_outfolder)/classify/gtdbtk.ar122.summary.tsv

$namespaces:
 s: http://schema.org/
$schemas:
 - https://schema.org/version/latest/schemaorg-current-http.rdf
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - class: s:Organization
    s:name: "EMBL - European Bioinformatics Institute"
    s:url: "https://www.ebi.ac.uk"