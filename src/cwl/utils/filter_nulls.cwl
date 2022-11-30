cwlVersion: v1.2
class: ExpressionTool

requirements:
  SubworkflowFeatureRequirement: {}
  MultipleInputFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  ScatterFeatureRequirement: {}
  ResourceRequirement:
    ramMin: 1000
    coresMin: 1

inputs:
  list_dirs:
    type:
      - "null"
      - type: array
        items: ["null", "Directory"]
  list_files:
    type:
      - "null"
      - type: array
        items: ["null", "File"]

outputs:
  out_dirs: Directory[]?
  out_files: File[]?

expression: |
  ${
    var filtered = [];
    if (inputs.list_dirs) {
      filtered = inputs.list_dirs.filter(function(el) {
        return el != null;
      });
    } else {
      filtered = inputs.list_files.filter(function(el) {
        return el != null;
      });
    }

    if (inputs.list_dirs) {
      if (filtered.length === 0) {
        return {
          "out_dirs": null
        };
      } else {
        return {
          "out_dirs": filtered
        };
      }
    } else {
      if (filtered.length === 0) {
        return {
          "out_files": null
        };
      } else {
        return {
          "out_files": filtered
        };
      }
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