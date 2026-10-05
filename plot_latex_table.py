#!/usr/bin/env python3
import re
import sys
from pathlib import Path
import matplotlib.pyplot as plt

def clean_latex(s):
    s = re.sub(r"\\textbf\{([^{}]*)\}", r"\1", s)
    s = re.sub(r"\\[a-zA-Z]+\*?(?:\[[^\]]*\])?", "", s)
    s = s.replace("{", "").replace("}", "").strip()
    return s

def parse_table(tex_file):
    text = Path(tex_file).read_text(encoding="utf-8")

    # Find header: Strategy, Average, then changing x-axis columns.
    header_match = re.search(
        r"\\textbf\{\}\s*&\s*\\textbf\{Strategy\}\s*&\s*\\textbf\{Average\}\s*&(.+?)\\\\",
        text, re.S
    )
    if not header_match:
        raise ValueError("Could not find the expected table header.")

    header_tail = header_match.group(1)
    x_labels = [
        clean_latex(x)
        for x in header_tail.split("&")
        if clean_latex(x)
    ]

    sections = {}
    current_section = None

    # Work line-by-line; section names come from \multirow{...}{...}{\textbf{Name}}
    for raw_line in text.splitlines():
        line = raw_line.strip()

        section_match = re.search(
            r"\\multirow\{\d+\}\{\*\}\{\\textbf\{([^}]+)\}\}",
            line
        )
        if section_match:
            current_section = section_match.group(1).strip()
            sections[current_section] = {}
            continue

        if current_section is None or not line.startswith("&"):
            continue

        # Remove LaTeX row ending / cline.
        row = re.split(r"\\\\", line, maxsplit=1)[0].strip()
        cells = [clean_latex(c) for c in row.split("&")]
        cells = [c for c in cells if c != ""]

        # Expected: strategy, average, x1, x2, ...
        if len(cells) < 2 + len(x_labels):
            continue

        strategy = cells[0]

        try:
            # Average is intentionally skipped for the line graph.
            values = [float(v) for v in cells[2:2 + len(x_labels)]]
        except ValueError:
            continue

        sections[current_section][strategy] = values

    if not sections:
        raise ValueError("No sections were extracted from the table.")

    return x_labels, sections

def plot_section(x_labels, strategies, section_name, output_dir):
    # Convert numeric labels when possible, otherwise keep strings.
    try:
        x = [float(v) for v in x_labels]
        if all(v.is_integer() for v in x):
            x = [int(v) for v in x]
    except ValueError:
        x = list(range(len(x_labels)))

    plt.figure(figsize=(10, 6))

    for strategy, values in strategies.items():
        plt.plot(x, values, marker="o", linewidth=1.8, label=strategy)

    plt.xlabel("Prefix Length")
    plt.ylabel("Completion Performance")
    plt.title(f"Completion Performance — {section_name}")
    plt.xticks(x, x_labels)
    plt.ylim(0, 1)
    plt.grid(True, alpha=0.25)
    plt.legend(bbox_to_anchor=(1.02, 1), loc="upper left", fontsize=8)
    plt.tight_layout()

    safe_name = re.sub(r"[^A-Za-z0-9_-]+", "_", section_name.lower()).strip("_")
    pdf = output_dir / f"completion_{safe_name}.pdf"
    png = output_dir / f"completion_{safe_name}.png"

    plt.savefig(pdf, bbox_inches="tight")
    plt.savefig(png, dpi=300, bbox_inches="tight")
    plt.close()

    return pdf, png

def main():
    if len(sys.argv) < 2:
        print("Usage: python plot_latex_table.py results-table.tex [output-directory]")
        raise SystemExit(1)

    tex_file = Path(sys.argv[1])
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else tex_file.parent
    output_dir.mkdir(parents=True, exist_ok=True)

    x_labels, sections = parse_table(tex_file)

    print("Detected x-axis values:", ", ".join(x_labels))
    print("Detected sections:", ", ".join(sections))

    for section_name, strategies in sections.items():
        pdf, png = plot_section(x_labels, strategies, section_name, output_dir)
        print(f"{section_name}:")
        print(f"  {pdf}")
        print(f"  {png}")

if __name__ == "__main__":
    main()
