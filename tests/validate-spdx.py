#!/usr/bin/env python3
"""Validate SPDX JSON with the pinned independent spdx-tools package."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from spdx_tools.spdx.parser.parse_anything import parse_file
from spdx_tools.spdx.validation.document_validator import validate_full_spdx_document


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("document", type=Path)
    parser.add_argument(
        "--expect-missing-sha1",
        action="store_true",
        help="pass only when semantic validation rejects a file without SHA1",
    )
    arguments = parser.parse_args()

    try:
        document = parse_file(str(arguments.document))
    except Exception as error:  # parser errors are distinct from semantic errors
        print(f"SPDX parse failed for {arguments.document}: {error}", file=sys.stderr)
        return 1

    messages = validate_full_spdx_document(document, spdx_version="SPDX-2.3")
    if arguments.expect_missing_sha1:
        if any("must contain a SHA1 algorithm checksum" in message.validation_message for message in messages):
            print("SPDX semantic-negative fixture rejected for its missing required SHA1 checksum.")
            return 0
        print("SPDX semantic-negative fixture was not rejected for its missing SHA1 checksum.", file=sys.stderr)
        for message in messages:
            print(message, file=sys.stderr)
        return 1

    if messages:
        print(f"SPDX validation failed for {arguments.document}:", file=sys.stderr)
        for message in messages:
            print(message, file=sys.stderr)
        return 1

    print(f"SPDX 2.3 document is semantically valid: {arguments.document}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
