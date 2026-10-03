#!/usr/bin/env python3
"""Plot a Pharo comparison or model matrix export; never run inference.

Each experiment and latency condition gets a separate figure. Aggregate quality
and mean latency by request count, never by averaging package/prefix means.
"""
import argparse
import csv
from collections import defaultdict
from pathlib import Path

LABELS = {
    'heuristicsBaseline': 'Baseline', 'heuristicsDependency': 'Dependency',
    'llmCompletion': 'LLM', 'hybridCompletion': 'Prompt hybrid',
    'llmNameCompletion': 'LLM', 'hybridNameCompletion': 'Prompt hybrid',
    'rerankingCompletion': 'Blended reranker',
    'neuralRerankingCompletion': 'Neural-only reranker',
    'dependencyRerankingCompletion': 'Dependency + neural reranker',
}
FIELDS = ('mrr', 'recall_1', 'recall_3', 'recall_5', 'recall_10', 'avg_ms',
          'ollama_total_ms', 'ollama_load_ms', 'prompt_eval_ms',
          'generation_ms', 'heuristic_ms')


def aggregate(rows):
    groups = defaultdict(list)
    for row in rows:
        if int(row['count']):
            key = tuple(row[k] for k in ('strategy', 'model', 'experiment', 'latency_condition'))
            groups[key].append(row)
    points = []
    for (strategy, model, experiment, condition), observations in groups.items():
        count = sum(int(r['count']) for r in observations)
        point = dict(strategy=strategy, model=model, experiment=experiment,
                     condition=condition, count=count)
        for field in FIELDS:
            # Partial telemetry is unknown, not zero and not a biased subset mean.
            point[field] = (sum(float(r[field]) * int(r['count']) for r in observations) / count
                            if all(r.get(field, '') != '' for r in observations) else None)
        point['label'] = LABELS.get(strategy, strategy)
        if model != 'none':
            point['label'] += ' / ' + model.rsplit(':', 1)[-1]
        points.append(point)
    return points


def pareto_front(points, quality):
    return sorted([p for p in points if not any(
        q['avg_ms'] <= p['avg_ms'] and q[quality] >= p[quality]
        and (q['avg_ms'] < p['avg_ms'] or q[quality] > p[quality])
        for q in points)], key=lambda p: p['avg_ms'])


def plot(points, kind, experiment, condition, output):
    import matplotlib.pyplot as plt
    quality = 'mrr' if experiment == 'ranking' else 'recall_1'
    points = [p for p in points if p['avg_ms'] is not None and p[quality] is not None]
    if not points:
        return
    title = {'ranking': 'Candidate ranking', 'completion': 'Complete-name generation',
             'oneToken': 'One-token generation'}.get(experiment, experiment)
    fig, (ax, bars) = plt.subplots(1, 2, figsize=(15, max(5, len(points) * .38)),
                                  gridspec_kw={'width_ratios': [1, 1.3]}, layout='constrained')
    for index, point in enumerate(points):
        ax.scatter(point['avg_ms'], point[quality], marker='o' if point['model'] == 'none' else 's')
        ax.annotate(str(index + 1), (point['avg_ms'], point[quality]),
                    xytext=(5, 5), textcoords='offset points')
    front = pareto_front(points, quality)
    ax.plot([p['avg_ms'] for p in front], [p[quality] for p in front], '--', color='0.6',
            linewidth=1, label='Observed Pareto frontier')
    ax.set(xlabel='Mean end-to-end completion latency (ms)',
           ylabel='MRR' if quality == 'mrr' else 'Recall@1 / exact match', ylim=(-.02, 1.08))
    ax.set_xscale('symlog', linthresh=1)
    ax.grid(alpha=.2)
    ax.legend(loc='lower right')
    components = [('heuristic_ms', 'Heuristics', '#4c78a8'),
                  ('ollama_load_ms', 'Model load', '#bab0ac'),
                  ('prompt_eval_ms', 'Prompt evaluation', '#f2cf5b'),
                  ('generation_ms', 'Decode', '#59a14f')]
    seen = set()
    for i, point in enumerate(points):
        parts = ([('heuristic_ms', 'Heuristics', '#4c78a8', point['avg_ms'])]
                 if point['model'] == 'none' else
                 [(k, label, color, point[k]) for k, label, color in components])
        # Only show decomposition when every component is measured. An empty
        # candidate set or a server missing telemetry must not become zero cost.
        complete = all(value is not None for _, _, _, value in parts)
        total = sum(value for _, _, _, value in parts if value is not None)
        if not complete or total > point['avg_ms'] + .01:
            parts = [('e2e', 'E2E (decomposition unavailable)', '#b279a2', point['avg_ms'])]
        else:
            parts.append(('other', 'Other client/server time', '#e4e4e4', max(0, point['avg_ms'] - total)))
        left = 0
        for key, label, color, value in parts:
            bars.barh(i, value, left=left, color=color, label=label if key not in seen else None)
            seen.add(key)
            left += value
    bars.set_yticks(range(len(points)), [f'{i+1}. {p["label"]}' for i, p in enumerate(points)])
    bars.invert_yaxis()
    bars.set_xlabel('Mean completion latency (ms)')
    bars.legend(loc='upper center', bbox_to_anchor=(.5, -.15), ncol=2, fontsize=8)
    fig.suptitle(f'{kind.title()} — {title} — {condition}\n'
                 'Static baselines are references; latency axis uses a symmetric log scale below/above 1 ms', fontsize=12)
    for extension in ('png', 'pdf'):
        fig.savefig(output / f'{kind}-{experiment}-{condition}.{extension}', dpi=180)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--prefix', type=int, choices=range(2, 9))
    args = parser.parse_args()
    output = args.output or args.directory / 'figures'
    output.mkdir(parents=True, exist_ok=True)
    import matplotlib
    matplotlib.use('Agg')
    for kind in ('messages', 'variables'):
        with (args.directory / f'{kind}.csv').open(newline='') as handle:
            rows = list(csv.DictReader(handle))
        if args.prefix:
            rows = [r for r in rows if int(r['prefix']) == args.prefix]
        points = aggregate(rows)
        baseline = [p for p in points if p['model'] == 'none']
        experiments = {(p['experiment'], p['condition']) for p in points if p['model'] != 'none'}
        for experiment, condition in sorted(experiments or {('ranking', 'uncontrolled')}):
            selected = baseline + [p for p in points if p['model'] != 'none'
                                   and (p['experiment'], p['condition']) == (experiment, condition)]
            plot(selected, kind, experiment, condition, output)
    print(f'Figures saved to {output}')


if __name__ == '__main__':
    main()
