/*
 * eggNOG-mapper
*/

process EGGNOG_MAPPER {

    container 'quay.io/microbiome-informatics/genomes-pipeline.eggnog-mapper:v2.1.11'

    input:
    // on mode "annotations" will be ignored, submit an empty path (channel.path("NO_FILE"))
    tuple val(id), file(fasta)
    // on mode "mapper" will be ignored, submit an empty path (channel.path("NO_FILE"))
    tuple val(id), file(annotation_hit_table)
    val mode // mapper or annotations
    path eggnog_db
    path eggnog_diamond_db
    path eggnog_data_dir

    output:
    tuple val(id), path ("*annotations*"), emit: annotations, optional: true
    tuple val(id), path ("*orthologs*"), emit: orthologs, optional: true

    script:
    if ( mode == "mapper" )
        """
        emapper.py -i ${fasta} \
        --database ${eggnog_db} \
        --dmnd_db ${eggnog_diamond_db} \
        --data_dir ${eggnog_data_dir} \
        -m diamond \
        --no_file_comments \
        --cpu ${task.cpus} \
        --no_annot \
        --dbmem \
        -o ${fasta.baseName}
        """
    else if ( mode == "annotations" )
        """
        emapper.py \
        --data_dir ${eggnog_data_dir} \
        --no_file_comments \
        --cpu ${task.cpus} \
        --annotate_hits_table ${annotation_hit_table} \
        --dbmem \
        --tax_scope 'prokaryota_broad' \
        -o ${annotation_hit_table.baseName}
        """
    else
        error "Invalid mode: ${mode}"


    // TODO: there must be a more clever way to create the stubs for this.
    stub:
    if ( mode == "mapper" )
        """
        touch eggnog-output.emapper.seed_orthologs

        echo "#query	seed_ortholog	evalue	score	eggNOG_OGs	max_annot_lvl	COG_category	Description	Preferred_name	GOs	EC	KEGG_ko	KEGG_Pathway	KEGG_Module	KEGG_Reaction	KEGG_rclass	BRITE	KEGG_TC	CAZy	BiGG_Reaction	PFAMs" > eggnog-output.emapper.seed_orthologs

        echo "MGYG000000012_00001	948106.AWZT01000053_gene1589	1.1e-63	199.0	COG5654@1|root,COG5654@2|Bacteria,1N6P3@1224|Proteobacteria,2VSGY@28216|Betaproteobacteria,1KFU4@119060|Burkholderiaceae	28216|Betaproteobacteria	S	RES	-	-	-	-	-	-	-	-	-	-	-	-	RES" >> eggnog-output.emapper.seed_orthologs

        echo "MGYG000000001_00001	948106.AWZT01000053_gene1589	1.1e-63	199.0	COG5654@1|root,COG5654@2|Bacteria,1N6P3@1224|Proteobacteria,2VSGY@28216|Betaproteobacteria,1KFU4@119060|Burkholderiaceae	28216|Betaproteobacteria	S	RES	-	-	-	-	-	-	-	-	-	-	-	-	RES" >> eggnog-output.emapper.seed_orthologs

        echo "MGYG000000020_00001	948106.AWZT01000053_gene1589	1.1e-63	199.0	COG5654@1|root,COG5654@2|Bacteria,1N6P3@1224|Proteobacteria,2VSGY@28216|Betaproteobacteria,1KFU4@119060|Burkholderiaceae	28216|Betaproteobacteria	S	RES	-	-	-	-	-	-	-	-	-	-	-	-	RES" >> eggnog-output.emapper.seed_orthologs
        """
    else if ( mode == "annotations" )
        """
        touch eggnog-output.emapper.annotations
        echo "#query	seed_ortholog	evalue	score	eggNOG_OGs	max_annot_lvl	COG_category	Description	Preferred_name	GOs	EC	KEGG_ko	KEGG_Pathway	KEGG_Module	KEGG_Reaction	KEGG_rclass	BRITE	KEGG_TC	CAZy	BiGG_Reaction	PFAMs" > eggnog-output.emapper.annotations

        echo "MGYG000000012_00001	59538.XP_005971304.1	7.97e-152	431.0	COG0101@1|root,KOG4393@2759|Eukaryota,39RAQ@33154|Opisthokonta,3BK4Y@33208|Metazoa,3D27W@33213|Bilateria,48A93@7711|Chordata,494G6@7742|Vertebrata,3J2WS@40674|Mammalia 33208|Metazoa	J	synthase-like 1 -	GO:0001522	-	-	-	-	-	-	-	-	-	-	DSPc,Laminin_G_3,PseudoU_synth_1" >> eggnog-output.emapper.annotations

        echo "MGYG000000001_00001	 59538.XP_005971304.1	7.97e-152	431.0	COG0101@1|root,KOG4393@2759|Eukaryota,39RAQ@33154|Opisthokonta,3BK4Y@33208|Metazoa,3D27W@33213|Bilateria,48A93@7711|Chordata,494G6@7742|Vertebrata,3J2WS@40674|Mammalia 33208|Metazoa	J	synthase-like 1 -	GO:0001522	-	-	-	-	-	-	-	-	-	-	DSPc,Laminin_G_3,PseudoU_synth_1" >> eggnog-output.emapper.annotations

        echo "MGYG000000020_00001	59538.XP_005971304.1	7.97e-152	431.0	COG0101@1|root,KOG4393@2759|Eukaryota,39RAQ@33154|Opisthokonta,3BK4Y@33208|Metazoa,3D27W@33213|Bilateria,48A93@7711|Chordata,494G6@7742|Vertebrata,3J2WS@40674|Mammalia 33208|Metazoa	J	synthase-like 1 -	GO:0001522	-	-	-	-	-	-	-	-	-	-	DSPc,Laminin_G_3,PseudoU_synth_1" >> eggnog-output.emapper.annotations
        """
    else
        error "Invalid mode: ${mode}"
}
