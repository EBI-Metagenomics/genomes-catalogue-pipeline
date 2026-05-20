import unittest
from unittest.mock import patch, mock_open
from bin.replace_species_representative import (
    remove_genomes_from_clusters,
    invert_clusters,
    add_to_clusters,
    select_replacement,
    new_genome_more_contiguous,
    evaluate_quality_increase,
    calc_qs,
    load_first_column_to_list,
    Quality,
    replacement_decision,
)


def make_qs():
    def q(comp, cont, n50):
        return Quality(
            completeness=comp,
            contamination=cont,
            n50=n50,
            qs=calc_qs(comp, cont, n50),
            length=5000000,
            n_contigs=10
        )

    return {
        "g0": q(90, 2, 100000),
        "g1": q(100, 0, 120000),
        "g2": q(91, 2, 110000),
    }


class TestGenomePipeline(unittest.TestCase):

    def test_remove_genomes_from_clusters(self):
        clusters = {
            "rep1": ["g1", "g2"],
            "rep2": ["g3"]
        }
        remove_list = ["g2", "rep2"]
        expected_clusters = {
            "rep1": {"new_rep": "rep1", "genomes": ["g1"]},
            "rep2": {"new_rep": "", "genomes": ["g3"]}
        }
        updated_clusters, remove_log = remove_genomes_from_clusters(clusters, remove_list)
        self.assertEqual(updated_clusters, expected_clusters)
        self.assertEqual(remove_log["reps"], ["rep2"])
        self.assertEqual(remove_log["members"], ["g2"])

    def test_invert_clusters(self):
        clusters = {
            "rep1": ["g1", "g2"],
            "rep2": ["g3"]
        }
        expected_lookup = {
            "rep1": "rep1",
            "g1": "rep1",
            "g2": "rep1",
            "rep2": "rep2",
            "g3": "rep2"
        }
        self.assertEqual(invert_clusters(clusters), expected_lookup)

    def test_add_to_clusters(self):
        clusters = {
            "rep1": {"new_rep": "rep1", "genomes": []}
        }
        result = add_to_clusters("g1", "rep1", clusters)
        self.assertIn("g1", result["rep1"]["genomes"])

    def test_new_genome_more_contiguous(self):
        old = Quality(completeness=95, contamination=2, n50=100000, qs=90, length=5000000, n_contigs=10)
        new = Quality(completeness=96, contamination=1.5, n50=120000, qs=92, length=5100000, n_contigs=10)
        self.assertTrue(new_genome_more_contiguous(new, old))

        new_bad = Quality(completeness=90, contamination=3, n50=100000, qs=85, length=4900000, n_contigs=10)
        self.assertFalse(new_genome_more_contiguous(new_bad, old))

    def test_evaluate_quality_increase(self):
        old = Quality(completeness=95, contamination=2, n50=100000, qs=90, length=5000000, n_contigs=10)
        new_good = Quality(completeness=95, contamination=2, n50=120000, qs=100, length=5100000, n_contigs=10)
        self.assertTrue(evaluate_quality_increase(new_good, old))
        new_bad = Quality(completeness=90, contamination=3, n50=100000, qs=91, length=4900000, n_contigs=10)
        self.assertFalse(evaluate_quality_increase(new_bad, old))

    def test_calc_qs(self):
        qs = calc_qs(95, 2, 100000)
        # Manually: 95 - 2*5 + 0.5*log10(100000)
        expected = 95 - 10 + 0.5 * (5)  # log10(100000) = 5
        self.assertAlmostEqual(qs, expected)

    @patch("builtins.open", new_callable=mock_open, read_data="g1\nG2.fa\nG3.fna\n")
    def test_load_first_column_to_list(self, mock_file):
        result = load_first_column_to_list("dummy.txt")
        self.assertEqual(result, ["g1", "G2", "G3"])

    @patch("builtins.open", new_callable=mock_open, read_data="Accession\tClosest_rep\tScore_to_closest_rep\tNearest_hit\nG1\trep1\t0.01\thit1\n")
    def test_load_strain_placement(self, mock_file):
        from bin.replace_species_representative import load_strain_placement
        result = load_strain_placement("dummy.tsv", same_strain=False)
        self.assertIn("G1", result)
        self.assertEqual(result["G1"].closest_rep, "rep1")
        self.assertEqual(result["G1"].distance, 0.01)
        self.assertEqual(result["G1"].actual_match, "hit1")

    def test_select_replacement_simple(self):
        qs_values = make_qs()
        replacement_results = {
            "g0": {"new_rep": "", "genomes": ["g1", "g2"]}
        }
        isolates = set()
        new_rep = select_replacement("g0", replacement_results["g0"]["genomes"], qs_values, isolates)
        self.assertEqual(new_rep, "g1")  # highest QS

    def test_replacement_best_qs(self):
        qs = make_qs()

        replacement_results = {
            "g0": {"new_rep": "", "genomes": []}
        }

        added_genomes = {"g0": ["g1", "g2"]}

        new_results, _, _ = replacement_decision(
            replacement_results,
            added_genomes,
            qs,
            remove_list=[],
            stats_to_print={},
            report_to_print={},
            isolates=set(),
            checkm2_switch=False
        )

        self.assertEqual(new_results["g0"]["new_rep"], "g1")
    
    def test_replacement_checkm2_switch_no_new_genomes(self):
        qs = make_qs()

        replacement_results = {
            "g1": {"new_rep": "g1", "genomes": ["g0", "g2"]}
        }

        added_genomes = {}

        new_results, _, _ = replacement_decision(
            replacement_results,
            added_genomes,
            qs,
            remove_list=[],
            stats_to_print={},
            report_to_print={},
            isolates=set(),
            checkm2_switch=False
        )
        # The original species rep is the highest quality genome and no change is needed
        self.assertEqual(new_results["g1"]["new_rep"], "g1")


if __name__ == "__main__":
    unittest.main()
