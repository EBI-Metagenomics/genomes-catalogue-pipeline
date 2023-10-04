/*
 * De-replicate
 */

include { DREP_CHUNKED } from '../modules/drep_chunked'
include { DREP_RERUN } from '../modules/drep_chunked'
include { COMBINE_CHUNKED_DREP } from '../modules/combine_chunked_drep'
include { SPLIT_DREP_LARGE } from '../modules/split_drep_large'
include { CLASSIFY_CLUSTERS } from '../modules/classify_clusters'
include { MASH_COMPARE } from '../modules/mash_compare'

workflow DREP_LARGE_SWF {
    take:
        genomes_directory
        checkm_csv
        extra_weight_table
    main:
        
        files = fileTree(dir: genomes_directory).filter { it.isFile() }
        
        // split genomes from genomes_directory into chunks 25000 files each (probably doesnt work)
        fileGroups = files.collect { file ->
            groupTuple = fileGroups.size() > 0 ? fileGroups[-1] : null
            if (groupTuple == null || groupTuple.size() == 25000) {
                groupTuple = []
                fileGroups << groupTuple
            }
            groupTuple << file
        }
        
        chunks = genomes_directory.groupTuple(fileGroups)
        
        // run process on each chunk
        DREP_CHUNKED(
            chunks,
            checkm_csv,
            extra_weight_table)
        
        // collect all species representative fasta files (emitted as dereplicated_genomes directories)
        // THIS PROBABLY DOESNT WORK
        drep_dirs = fileGroups.collect { subdir ->
             path("DREP_CHUNKED.out.dereplicated_genomes", subdir)
        }

        all_dereplicated_genomes = drep_dirs.collectMany { resultDir ->
            fileTree(resultDir).filter { it.isFile() }
        }
        
        // run drep on species representatives from all DREP_CHUNKED runs
        DREP_RERUN(
            chunks,
            checkm_csv,
            extra_weight_table)
            
        // THIS NEEDS REAL CODE
        all_cdb_files = gather all DREP_CHUNKED.out.cdb_csv into an array
        all_sdb_files = gather all DREP_CHUNKED.out.sdb_csv into an array
        
        // run a python script to combine the outputs
        COMBINE_CHUNKED_DREP(
            all_cbd_files,
            all_sbd_files,
            DREP_RERUN.out.cbd_csv
        )

        SPLIT_DREP_LARGE(
            DREP.out.cdb_csv,
            DREP.out.sdb_csv
        )

        CLASSIFY_CLUSTERS(
            genomes_directory,
            SPLIT_DREP.out.text_split
        )

        groupGenomes = { fna_file ->
            def cluster = fna_file.parent.toString().tokenize("/")[-1]
            return tuple(cluster, fna_file)
        }
        
        // Run mash on each group of fastas in many_genomes_fnas
        // THESE NEED TO BE PUBLISHED
        MASH_COMPARE(
            CLASSIFY_CLUSTERS.out.many_genomes_fnas
        )
        
        // TODO: cat all mash outputs into one Mdb.csv file and add to emit list

        many_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.many_genomes_fnas | flatten | map(groupGenomes)
        single_genomes_fna_tuples = CLASSIFY_CLUSTERS.out.one_genome_fnas | flatten | map(groupGenomes)

    emit:
        many_genomes_fna_tuples = many_genomes_fna_tuples
        single_genomes_fna_tuples = single_genomes_fna_tuples
        drep_split_text = SPLIT_DREP_LARGE.out.text_split
        // mash splits need to be pulled together from each run of MASH_COMPARE
        mash_splits = MASH_COMPARE.out.mash_split
        drep_cdb_csv = DREP.out.cdb_csv
        //drep_mdb_csv = DREP.out.mdb_csv
        drep_sdb_csv = DREP.out.sdb_csv
}
