"""Convert commercial-offer.md to PDF using Edge headless."""
import subprocess
import sys
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
MD = ROOT / "docs" / "commercial-offer.md"
HTML = ROOT / "docs" / "commercial-offer.html"
PDF = ROOT / "docs" / "commercial-offer.pdf"
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

CSS = """
<style>
  @page { size: A4; margin: 20mm 16mm; }
  body {
    font-family: -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    font-size: 10.5pt; line-height: 1.5; color: #1a1a1a; max-width: 100%;
  }
  h1 { font-size: 22pt; color: #2c3e50; border-bottom: 3px solid #C9A24A; padding-bottom: 8px; margin-top: 24pt; }
  h2 { font-size: 16pt; color: #34495e; border-bottom: 1px solid #ddd; padding-bottom: 4px; margin-top: 18pt; page-break-after: avoid; }
  h3 { font-size: 13pt; color: #C9A24A; margin-top: 14pt; page-break-after: avoid; }
  h4 { font-size: 11pt; color: #555; margin-top: 10pt; }
  p, ul, ol { margin: 6pt 0; }
  table {
    border-collapse: collapse; width: 100%; margin: 10pt 0;
    font-size: 9.5pt; page-break-inside: avoid;
  }
  th, td { border: 1px solid #ccc; padding: 5pt 8pt; text-align: left; vertical-align: top; }
  th { background: #f4f0e6; color: #2c3e50; font-weight: 600; }
  tr:nth-child(even) td { background: #fafafa; }
  td:last-child, th:last-child { text-align: right; }
  code { background: #f4f4f4; padding: 1pt 4pt; border-radius: 3px; font-size: 9pt; }
  pre {
    background: #2c3e50; color: #ecf0f1; padding: 10pt; border-radius: 4px;
    overflow-x: auto; font-size: 8.5pt; line-height: 1.4; page-break-inside: avoid;
  }
  pre code { background: transparent; color: inherit; padding: 0; }
  blockquote {
    border-left: 4px solid #C9A24A; padding: 4pt 12pt; margin: 8pt 0;
    background: #fdf9ee; color: #555; font-style: italic;
  }
  hr { border: none; border-top: 1px solid #ddd; margin: 16pt 0; }
  a { color: #C9A24A; text-decoration: none; }
  strong { color: #2c3e50; }
  .header-meta { color: #888; font-size: 9pt; }
</style>
"""


def main() -> int:
    if not MD.exists():
        print(f"ERROR: {MD} not found", file=sys.stderr)
        return 1

    md_text = MD.read_text(encoding="utf-8")

    # strip YAML frontmatter
    if md_text.startswith("---"):
        end = md_text.find("---", 3)
        if end != -1:
            md_text = md_text[end + 3 :].lstrip()

    html_body = markdown.markdown(
        md_text,
        extensions=["tables", "fenced_code", "toc", "sane_lists"],
        output_format="html5",
    )

    html = f"""<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<title>Коммерческое предложение — Клуб 33</title>
{CSS}
</head>
<body>
{html_body}
</body>
</html>
"""
    HTML.write_text(html, encoding="utf-8")
    print(f"HTML written: {HTML}")

    if not Path(EDGE).exists():
        print(f"ERROR: Edge not found at {EDGE}", file=sys.stderr)
        return 2

    cmd = [
        EDGE,
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        f"--print-to-pdf={PDF}",
        "--print-to-pdf-no-header",
        f"file:///{HTML.as_posix()}",
    ]
    print(f"Running Edge headless...")
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        print("Edge stderr:", result.stderr, file=sys.stderr)
        return 3

    if PDF.exists():
        size_kb = PDF.stat().st_size / 1024
        print(f"PDF generated: {PDF} ({size_kb:.1f} KB)")
        return 0
    print("ERROR: PDF not generated", file=sys.stderr)
    return 4


if __name__ == "__main__":
    sys.exit(main())
