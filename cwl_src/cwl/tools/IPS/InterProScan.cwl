class: CommandLineTool
cwlVersion: v1.2

label: 'InterProScan: protein sequence classifier'

requirements:
  - class: ResourceRequirement
    ramMin: 20000
    coresMin: 16
  - class: InlineJavascriptRequirement
  - class: InitialWorkDirRequirement
    listing:
      - entry: $(inputs.databases)
        entryname: $("/opt/interproscan-5.52-86.0/data") 
  - class: DockerRequirement
    dockerPull: "quay.io/microbiome-informatics/genomes-pipeline.ips:v1"


baseCommand: [interproscan.sh]

arguments:
  - position: 3
    prefix: '-cpu'
    valueFrom: '16'

  - position: 4
    valueFrom: '-dp'
  - position: 5
    valueFrom: '--goterms'
  - position: 6
    valueFrom: '-pa'
  - position: 7
    valueFrom: 'TSV'
    prefix: '-f'
  - position: 8
    valueFrom: $(runtime.outdir)/$(inputs.inputFile.nameroot).IPS.tsv
    prefix: '-o'

inputs:
  - id: inputFile
    type: File
    inputBinding:
      position: 9
      prefix: '--input'
    label: Input file path
    doc: >-
      Optional, path to fasta file that should be loaded on Master startup.
      Alternatively, in CONVERT mode, the InterProScan 5 XML file to convert.
  - id: databases
    type: [string?, Directory]

outputs:
  - id: annotations
    type: File
    outputBinding:
      glob: $(inputs.inputFile.nameroot).IPS.tsv


$namespaces:
  edam: 'http://edamontology.org/'
  s: 'http://schema.org/'

$schemas:
   - http://edamontology.org/EDAM_1.16.owl
   - https://schema.org/version/latest/schemaorg-current-https.rdf
's:author': 'Michael Crusoe, Aleksandra Ola Tarkowska, Maxim Scheremetjew, Ekaterina Sakharova'
's:copyrightHolder': EMBL - European Bioinformatics Institute
's:license': 'https://www.apache.org/licenses/LICENSE-2.0'


doc: >-
  InterProScan is the software package that allows sequences (protein and
  nucleic) to be scanned against InterPro's signatures. Signatures are
  predictive models, provided by several different databases, that make up the
  InterPro consortium.

  Documentation on how to run InterProScan 5 can be found here:
  https://github.com/ebi-pf-team/interproscan/wiki/HowToRun
