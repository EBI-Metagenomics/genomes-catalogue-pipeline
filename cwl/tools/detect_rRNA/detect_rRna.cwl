class: CommandLineTool
cwlVersion: v1.2

requirements:
  ResourceRequirement:
    ramMin: 1000
    coresMin: 4
  InlineJavascriptRequirement: {}

hints:
  DockerRequirement:
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.detect_rrna:v3.1"

baseCommand: [ rna-detect.sh ]

inputs:
  fasta:
    type: File
    inputBinding:
      position: 2
  cm_models:
    type: Directory
    inputBinding:
      position: 3

arguments:
  - valueFrom: $(runtime.outdir)
    position: 1

outputs:
  out_counts:
    type: Directory
    outputBinding:
      glob: "*_out-results"
  fasta_seq:
    type: Directory
    outputBinding:
      glob: "*_fasta-results"

$namespaces:
 s: http://schema.org/
$schemas:
 - https://schema.org/version/latest/schemaorg-current-http.rdf
s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder:
  - class: s:Organization
    s:name: "EMBL - European Bioinformatics Institute"
    s:url: "https://www.ebi.ac.uk"