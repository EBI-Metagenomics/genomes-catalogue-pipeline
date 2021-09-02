#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

label: split FAA by number of records
doc: based upon code by Maxim Scheremetjew, EMBL-EBI


requirements:
  ResourceRequirement:
    coresMax: 1
    ramMin: 5000
  InitialWorkDirRequirement:
    listing:
      - class: File
        location: ../../docker/python3_scripts/split_to_chunks.py

hints:
  DockerRequirement:
    dockerPull: microbiomeinformatics/genomes-pipeline.python3:v1

  SoftwareRequirement:
    packages:
      biopython:
        specs: [ "https://identifiers.org/rrid/RRID:SCR_007173" ]
        version: [ "1.65", "1.66", "1.69" ]

baseCommand: [ split_to_chunks.py ]

inputs:
  seqs:
    type: File
    inputBinding:
      prefix: -i
  chunk_size:
    type: int
    inputBinding:
      prefix: -s
  file_format:
    type: string?
    inputBinding:
      prefix: -f

outputs:
  chunks:
    format: edam:format_1929  # FASTA
    type: File[]
    outputBinding:
      glob: '*_*$(inputs.seqs.nameext)'

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
    - name: "EMBL - European Bioinformatics Institute"
    - url: "https://www.ebi.ac.uk/"
