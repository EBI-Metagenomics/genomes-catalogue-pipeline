class: CommandLineTool
cwlVersion: v1.0

label: 'InterProScan: protein sequence classifier'

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
    valueFrom: $(inputs.inputFile.nameroot).IPS.tsv
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

requirements:

  - class: ResourceRequirement
    ramMin: 20000
    coresMin: 16
  - class: InlineJavascriptRequirement

hints:
  - class: DockerRequirement
    dockerPull: "docker.io/microbiomeinformatics/genomes-pipeline.interproscan:v1"
  - class: gx:interface
    gx:inputs:
      - gx:name: applications
        gx:type: text
        gx:optional: True
      - gx:name: proteinFile
        gx:type: data
        gx:format: 'txt'

$namespaces:
  gx: "http://galaxyproject.org/cwl#"
  edam: 'http://edamontology.org/'
  iana: 'https://www.iana.org/assignments/media-types/'
  s: 'http://schema.org/'

$schemas:
  - 'http://edamontology.org/EDAM_1.20.owl'
  - 'https://schema.org/version/latest/schema.rdf'
's:author': 'Michael Crusoe, Aleksandra Ola Tarkowska, Maxim Scheremetjew, Ekaterina Sakharova'
's:copyrightHolder': EMBL - European Bioinformatics Institute
's:license': 'https://www.apache.org/licenses/LICENSE-2.0'


doc: >-
  InterProScan is the software package that allows sequences (protein and
  nucleic) to be scanned against InterPro's signatures. Signatures are
  predictive models, provided by several different databases, that make up the
  InterPro consortium.


  This tool description is using a Docker container tagged as version
  v5.30-69.0.


  Documentation on how to run InterProScan 5 can be found here:
  https://github.com/ebi-pf-team/interproscan/wiki/HowToRun
