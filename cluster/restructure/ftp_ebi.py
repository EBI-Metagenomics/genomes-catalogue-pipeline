


"""
all_genomes
    --- 000
         ----- 00001
                ----- genomes1
                        ------- GUT_GENOME000001.gff.gz
                        ...
                        ------- GUT_GENOME091053.gff.gz
         ----- 00002
                ----- genomes1
                        ------- GUT_GENOME000002.gff.gz
                        ... ...
                        ------- GUT_GENOME091054.gff.gz
         ...
    --- 001
    ...

genomes-all_metadata.tsv  (script is not ready)

README.txt                (script is not ready)

uhgg_catalogue
    --- 000
         ----- 00001
                ----- genome
                        ----- annotation_coverage.tsv
                        ----- cog_summary.tsv
                        ----- kegg_classes.tsv
                        ----- kegg_modules.tsv
                        ----- MGYG-HGUT-00001_eggNOG.tsv
                        ----- MGYG-HGUT-00001.faa
                        ----- MGYG-HGUT-00001.fna
                        ----- MGYG-HGUT-00001.fna.fai
                        ----- MGYG-HGUT-00001.gff          ( make a file wit link)
                        ----- MGYG-HGUT-00001_InterProScan.tsv
                ----- pan-genome
                        ----- core_genes.faa               ( ready - core_genes.txt )
                        ----- genes_presence-absence.tsv   ( ready - gene_presence_absence.Rtab )
                        ----- mashtree.nwk                 ( ready )
                        ----- pan-genome.fna               ( ready - initial fasta )

uhgp_catalogue  (mmseqs)
    --- mmseqs_1.0_outdir.tar.gz                           ( was uhgp-100.tar.gz)
    --- mmseqs_0.5_outdir.tar.gz
    --- mmseqs_0.9_outdir.tar.gz
    --- mmseqs_0.95_outdir.tar.gz
"""

# gffs from prokka -> gzip
