/*
 * Interproscan
*/

process IPS {

    container 'quay.io/microbiome-informatics/interproscan:5.73-104.0'
    containerOptions '--bind data:/opt/interproscan/data'

    label 'ips'

    input:
    file faa_fasta
    path interproscan_db

    output:
    path '*.IPS.tsv', emit: ips_annotations

    script:
    """
    interproscan.sh \
    -cpu ${task.cpus} \
    -dp \
    --goterms \
    -pa \
    -f TSV \
    --input ${faa_fasta} \
    -o ${faa_fasta.baseName}.IPS.tsv
    """

    // TODO: this of a more clever way to create the stubs for this.
    // stub:
    // """
    // touch ${faa_fasta.baseName}.IPS.tsv

    // echo "MGYG000000001_00001	5eaf2535c6c9d2be7320ae5758a73dca	357	PANTHER	PTHR43297	OLIGOPEPTIDE TRANSPORT ATP-BINDING PROTEIN APPD	27	348	2.8E-151	T	08-01-2023	-	-" >> ${faa_fasta.baseName}.IPS.tsv

    // echo "MGYG000000012_00001	63c30759534673d1ee49fcfca8f37f08	352	PANTHER	PTHR33055	TRANSPOSASE FOR INSERTION SEQUENCE ELEMENT IS1111A	1	337	6.0E-55	T	08-01-2023	-	-" >> ${faa_fasta.baseName}.IPS.tsv

    // echo "MGYG000000020_00001	959328d9189f2b7998e0f9849f07b960	237	PANTHER	PTHR42703	NADH DEHYDROGENASE	1	225	6.5E-49	T	08-01-2023	-	-" >> ${faa_fasta.baseName}.IPS.tsv
    // """
}
