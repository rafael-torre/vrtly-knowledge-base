#!/usr/bin/env python3
"""
Convert a PDF file to individual PNG images (one per page).
Requires: pip install pymupdf
Usage: python3 pdf-to-images.py /path/to/file.pdf /output/dir
"""

import os
import sys

import fitz  # PyMuPDF


def convert_pdf_to_images(pdf_path: str, output_dir: str, zoom: float = 2.0) -> int:
    os.makedirs(output_dir, exist_ok=True)
    doc = fitz.open(pdf_path)
    mat = fitz.Matrix(zoom, zoom)

    for i, page in enumerate(doc):
        pix = page.get_pixmap(matrix=mat)
        out_path = os.path.join(output_dir, f"slide_{i + 1:02d}.png")
        pix.save(out_path)

    page_count = len(doc)
    doc.close()
    print(f"Converted {page_count} pages → {output_dir}")
    return page_count


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: pdf-to-images.py <pdf_path> <output_dir> [zoom]")
        sys.exit(1)

    pdf_path = sys.argv[1]
    output_dir = sys.argv[2]
    zoom = float(sys.argv[3]) if len(sys.argv) > 3 else 2.0

    if not os.path.exists(pdf_path):
        print(f"Error: file not found: {pdf_path}")
        sys.exit(1)

    convert_pdf_to_images(pdf_path, output_dir, zoom)
