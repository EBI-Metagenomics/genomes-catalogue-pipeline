#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

inputs:
  prokka_gffs: File[]
  panaroo_folder_name: string

outputs:
  gene_presence_absence:
    type: File
    outputSource: panaroo/gene_presence_absence
  panaroo_fna:
    type: File
    outputSource: panaroo/pan_genome_reference
  panaroo_dir:
    type: Directory
    outputSource: panaroo/panaroo_dir

steps:

  panaroo:
    run: ../../../tools/panaroo/panaroo.cwl
    in:
      gffs: prokka_gffs
      panaroo_outfolder: panaroo_folder_name
      threads: {default: 8 }
    out:
      - pan_genome_reference
      - gene_presence_absence
      - panaroo_dir

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"