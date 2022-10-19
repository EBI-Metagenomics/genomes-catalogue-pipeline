# GTDB taxonomy dump script

Taken from: https://gist.github.com/lskatz/7403e9693a49cbb60c4a1cb2ce5c3475

## Container

### Build
```bash
$ docker build -t quay.io/microbiome-informatics/genomes-pipeline.gtdb-tax-dump:v1 .
```

### Execution

Run it with your user to avoid issues with file permissions.

```bash
docker run -u $(id -u $(whoami)) \
--volume $(pwd):/data:rw \
-it quay.io/microbiome-informatics/genomes-pipeline.gtdb-tax-dump:v1 \
perl gtdbToTaxonomy.pl --sequence-dir /data/fastas_folder --infile /data/gtdb.txt --outputdir /data/output
```
