cwlVersion: v1.2
class: ExpressionTool
label: Returns a directory named after inputs.newname, containing all input files and directories.

requirements:
  InlineJavascriptRequirement: {}
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1

inputs:
  directory:
    type: Directory?
  directory_array:
    type: Directory[]?
  newname:
    type: string

outputs:
  pool_directory:
    type: Directory?
  dir_of_dir:
    type: Directory?

expression: |
  ${
    if (inputs.directory)
      {
      return {
        "dir_of_dir": {
          "class": "Directory",
          "basename": inputs.newname,
          "listing": [ inputs.directory ]
       }
      };
    }
    if (inputs.directory_array)
    {
    return {
        "pool_directory": {
          "class": "Directory",
          "basename": inputs.newname,
          "listing": inputs.directory_array
       }
      };
    }
  }

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/version/latest/schemaorg-current-http.rdf

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"