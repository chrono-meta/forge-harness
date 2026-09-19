#!/usr/bin/env python3
"""psa_extract_text.py — emit a file's SCANNABLE TEXT, or refuse.

WHY THIS EXISTS (2026-09-19). The public-surface scanners are line/byte matchers. For a container
format they read the container, not the text: a `.pptx` is a zip of XML, a PDF encodes glyphs. So
the scan returns "no hits" about bytes it never understood, and on the publish path that reads as
CLEAN. Measured the day this was written, on the real deposit artifact:

    paper/forge_harness_v1.0.2.pdf     PyMuPDF: <operator-token>=1 <org-token>=1     psa_scan: rc=0 CLEAN

🟥 The fix is NOT "skip containers" — skipping is the same false clean with a different name, and
the challenger round that chose `grep -a` in public_surface_scan_files.sh was right to refuse it.
The fix is: extract the text where we can, and REFUSE (non-zero) where we cannot. A refusal is a
verdict the caller can act on; a silent zero is not.

PRIOR ART CHECKED (no-reinvention gate, same day). The repo already has an OOXML reader —
`plugins/fh-preprep/skills/preprep/oox.py` — and it is the WRONG tool here, deliberately so:
it is a geometry/shape reader for the preprep lanes (slide order, EMU coordinates, paragraph and
run text) and it reads slides only, as prose. A private token hides in a relationship target, a
docProps field, a comment or an embedded hyperlink — precisely the parts a prose-and-slides
extractor drops. This module joins EVERY `.xml`/`.rels` part as raw text for that reason. Two
different jobs on the same file format; neither should be bent into the other.

CONTRACT
  stdout : the file's scannable text (possibly empty for a genuinely empty file)
  exit 0 : text emitted; the caller may scan it and trust a clean result
  exit 3 : CANNOT EXTRACT — the caller must treat this as NOT SCANNED, never as 0 hits
  exit 2 : usage / missing file

🟥 exit 3 is the whole point. Every new branch added here must keep the property that an
unsupported or damaged input leaves through exit 3 and not through exit 0 with empty output.
"""
import sys
import os
import zipfile

# Formats whose bytes ARE their text — passed through unchanged.
# 🟥 This list is on the SCANNABLE side on purpose: an unfamiliar type falls through to the
# container branches and then to exit 3, never to a bare "clean". A known-binary list would have
# the opposite failure direction (everything nobody listed sails past).
_TEXTISH_SUFFIX = (
    ".txt", ".md", ".html", ".htm", ".xml", ".svg", ".json", ".yaml", ".yml",
    ".sh", ".bash", ".zsh", ".py", ".js", ".mjs", ".cjs", ".ts", ".tsv", ".csv",
    ".toml", ".ini", ".cfg", ".cff", ".rst", ".tex", ".patch", ".diff", ".snippet",
)
_OOXML_SUFFIX = (".pptx", ".docx", ".xlsx", ".potx", ".dotx", ".xltx")


def _looks_textish(path: str) -> bool:
    """A file is text if it decodes as UTF-8 and carries no NUL. Suffix is only a fast path.

    🟥 Suffix alone is not the test — a `.txt` holding binary must not be waved through, and a
    suffix-less text file must not be refused. The decode is the discriminator; the suffix just
    avoids reading big binaries twice.
    """
    try:
        with open(path, "rb") as fh:
            head = fh.read(65536)
    except OSError:
        return False
    if b"\x00" in head:
        return False
    if path.lower().endswith(_TEXTISH_SUFFIX):
        return True
    try:
        head.decode("utf-8")
    except UnicodeDecodeError:
        return False
    return True


def _ooxml_text(path: str) -> str:
    """Join every XML part of an OOXML container.

    We deliberately do NOT parse the XML into prose: a private token can sit in a relationship
    target, a docProps field, a comment, or an embedded hyperlink, and a prose-only extractor
    would miss exactly the places a leak hides. The raw XML text is the safer scan surface.
    """
    out = []
    with zipfile.ZipFile(path) as zf:
        for name in zf.namelist():
            if name.endswith((".xml", ".rels")):
                out.append(zf.read(name).decode("utf-8", "ignore"))
    return "\n".join(out)


def _pdf_text(path: str) -> str:
    try:
        import pymupdf  # type: ignore
    except ImportError:
        try:
            import fitz as pymupdf  # type: ignore
        except ImportError:
            raise RuntimeError("no PDF text extractor available (pymupdf)")
    with pymupdf.open(path) as doc:
        return "".join(page.get_text() for page in doc)


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("usage: psa_extract_text.py <path>\n")
        return 2
    path = argv[1]
    if not os.path.isfile(path):
        sys.stderr.write("psa_extract_text: not a file: %s\n" % path)
        return 2

    low = path.lower()
    # 🟥 CONTAINER SUFFIX WINS OVER THE TEXT HEURISTIC — this was a real bug, caught by a fixture
    # whose extraction returned the file's RAW BYTES ("%PDF-1.4 4 0 obj<</Length 55>>stream ...").
    # `_looks_textish` says True for any NUL-free UTF-8-decodable file, and a PDF can easily be
    # NUL-free — measured: a hand-built one AND one written by MuPDF itself were both NUL-free.
    # So those PDFs took the text path, the scanner matched raw bytes, and the encoded text was
    # never read. The real deposit PDF only reached the PDF branch by accident: it happened to
    # contain a NUL. An accident is not a code path.
    if low.endswith(_OOXML_SUFFIX) or low.endswith(".pdf"):
        try:
            text = _ooxml_text(path) if low.endswith(_OOXML_SUFFIX) else _pdf_text(path)
        except Exception as exc:  # noqa: BLE001 — every failure leaves through exit 3
            sys.stderr.write("psa_extract_text: CANNOT EXTRACT %s: %s\n" % (path, exc))
            return 3
        # 🟥 EMPTY IS NOT CLEAN. A container that yields zero characters was not read — it was
        # opened and gave nothing, which is the same false clean one layer down. Measured: a
        # malformed PDF returned 0 chars with exit 0, and the caller scanned emptiness and said
        # CLEAN. A real document has text; "0 characters out of a %d-byte container" is a
        # measurement failure, not a result.
        if not text.strip():
            sys.stderr.write(
                "psa_extract_text: CANNOT EXTRACT %s: container yielded no text (%d bytes in)\n"
                % (path, os.path.getsize(path))
            )
            return 3
        sys.stdout.write(text)
        return 0

    if _looks_textish(path):
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                sys.stdout.write(fh.read())
            return 0
        except OSError as exc:
            sys.stderr.write("psa_extract_text: read failed: %s\n" % exc)
            return 3

    sys.stderr.write(
        "psa_extract_text: CANNOT EXTRACT %s: unsupported non-text format\n" % path
    )
    return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
