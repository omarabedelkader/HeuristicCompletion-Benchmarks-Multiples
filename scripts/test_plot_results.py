"""Numerical checks for pooled statistics and the Pareto frontier."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('plots', Path(__file__).with_name('plot-results.py'))
plots = importlib.util.module_from_spec(spec)
spec.loader.exec_module(plots)


class PlotTests(unittest.TestCase):
    def test_weighted_means_and_missing_telemetry(self):
        common = dict(strategy='llmCompletion', model='test:1B', experiment='oneToken',
                      latency_condition='warm')
        rows = [dict(common, count='1', mrr='1', avg_ms='100'),
                dict(common, count='3', mrr='0', avg_ms='20')]
        point, = plots.aggregate(rows)
        self.assertEqual(point['mrr'], .25)
        self.assertEqual(point['avg_ms'], 40)
        self.assertIsNone(point['generation_ms'])

    def test_pareto_front_rejects_dominated_points(self):
        points = [dict(avg_ms=1, mrr=.3), dict(avg_ms=2, mrr=.2),
                  dict(avg_ms=3, mrr=.5), dict(avg_ms=4, mrr=.5)]
        self.assertEqual(plots.pareto_front(points, 'mrr'), [points[0], points[2]])


if __name__ == '__main__':
    unittest.main()
