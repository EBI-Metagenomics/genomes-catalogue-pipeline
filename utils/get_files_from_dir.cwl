class: ExpressionTool
requirements: { InlineJavascriptRequirement: {} }
inputs:
  dir: Directory
expression: '${return {"files": inputs.dir.listing};}'
outputs:
  files: File[]