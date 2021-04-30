# Tests

## download
### Fetch data
-- download from ENA [ 1 test ]
-- download from NCBI [ 1 test ]

TODO: test for empty input
 
## wf-1
### Part 1. Step 0: taxcheck subwf [ not in use ]

-- preparation [ no test ]
-- taxcheck [ no test ]
-- return directory [ no test ]

### Part 1. Step 1: checkM (only for NCBI) [ no test ]


### Part 1. Step 2: drep sub-wf [ 3 tests ]
- one genome
- many genomes
- mixed (one and many) genomes

-- drep [ no test ]
-- split drep [no test ]
-- classify clusters [ 3 tests ]

## wf-2
### Step 1.1: Process many-genomes folders

-- wrapper 

-- sub-wf:

----- Step 1.1.1: return files list from directory

----- Step 1.1.2: prokka

----- Step 1.1.3: panaroo

----- Step 1.1.4: translate

----- Step 1.1.5.1: IPS

----- Step 1.1.5.2: EggNOG

### Step 1.2: Process one-genome folders

-- wrapper 

-- sub-wf:

----- Step 1.1.1: return files list from directory

----- Step 1.1.2: prokka

----- Step 1.1.3.1: IPS

----- Step 1.1.3.2: EggNOG

### Step 2: mmseqs