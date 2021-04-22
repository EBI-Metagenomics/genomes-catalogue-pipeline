cwlVersion: v1.0
class: ExpressionTool
label: Returns a directory named after inputs.newname, containing all input files and directories.

requirements:
  InlineJavascriptRequirement: {}
  ResourceRequirement:
    ramMin: 200
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