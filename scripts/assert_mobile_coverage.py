from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Coverage:
    hit: int
    found: int

    @property
    def percent(self) -> float:
        return 100.0 if self.found == 0 else self.hit * 100.0 / self.found


def parse_lcov(path: Path) -> dict[str, Coverage]:
    records: dict[str, Coverage] = {}
    source: str | None = None
    hit = 0
    found = 0
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        if raw_line.startswith("SF:"):
            source = raw_line[3:].replace("\\", "/")
        elif raw_line.startswith("LH:"):
            hit = int(raw_line[3:])
        elif raw_line.startswith("LF:"):
            found = int(raw_line[3:])
        elif raw_line == "end_of_record" and source is not None:
            records[source] = Coverage(hit=hit, found=found)
            source = None
            hit = 0
            found = 0
    if not records:
        raise ValueError(f"No LCOV records found in {path}")
    return records


def combine(records: dict[str, Coverage], selected: set[str]) -> Coverage:
    missing = sorted(selected.difference(records))
    if missing:
        raise ValueError(f"LCOV does not contain required files: {', '.join(missing)}")
    return Coverage(
        hit=sum(records[name].hit for name in selected),
        found=sum(records[name].found for name in selected),
    )


def meaningful_files(source_root: Path) -> set[str]:
    if not source_root.is_dir():
        raise ValueError(f"Dart source root does not exist: {source_root}")
    return {
        f"lib/{path.relative_to(source_root).as_posix()}"
        for path in source_root.rglob("*.dart")
        if path.name != "main.dart"
        and not path.name.endswith((".g.dart", ".freezed.dart"))
        and not path.relative_to(source_root).as_posix().startswith("l10n/app_localizations")
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Enforce the T02B meaningful Dart coverage gates.")
    parser.add_argument("--lcov", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--output-json", type=Path)
    parser.add_argument("--output-md", type=Path)
    args = parser.parse_args()

    records = parse_lcov(args.lcov)
    meaningful = meaningful_files(args.source_root)
    categories: dict[str, tuple[Coverage, float, str]] = {
        "overall_meaningful": (
            combine(records, meaningful),
            80.0,
            "All authored Dart under lib, excluding generated DTO/localization code",
        ),
        "auth_network_security": (
            combine(
                records,
                {
                    name
                    for name in meaningful
                    if name.startswith(
                        (
                            "lib/core/auth/",
                            "lib/core/config/",
                            "lib/core/network/",
                            "lib/core/storage/",
                        )
                    )
                },
            ),
            90.0,
            "Authentication, fail-closed configuration, transport and protected storage",
        ),
        "sse_ai_protocol": (
            combine(
                records,
                {
                    "lib/core/network/sse_parser.dart",
                    "lib/core/network/compliance_repository.dart",
                    "lib/features/ai_assistant/ai_assistant_screen.dart",
                },
            ),
            90.0,
            "SSE parser, AI API protocol and complete AI interaction state",
        ),
        "tenant_isolation": (
            combine(
                records,
                {
                    "lib/core/network/compliance_repository.dart",
                    "lib/features/organizations/organization_controller.dart",
                },
            ),
            95.0,
            "Organization-scoped repository calls and validated organization selection",
        ),
        "critical_mutations": (
            combine(
                records,
                {
                    "lib/core/network/api_client.dart",
                    "lib/core/network/compliance_repository.dart",
                },
            ),
            85.0,
            "Mutation transport plus repository methods, including ETag and idempotency",
        ),
    }

    results: dict[str, object] = {}
    failed = False
    for name, (coverage, threshold, scope) in categories.items():
        passed = coverage.percent + 1e-9 >= threshold
        failed = failed or not passed
        results[name] = {
            "hit": coverage.hit,
            "found": coverage.found,
            "percent": round(coverage.percent, 2),
            "threshold": threshold,
            "status": "PASS" if passed else "FAIL",
            "scope": scope,
        }

    payload = {
        "status": "PASS" if not failed else "FAIL",
        "source": args.lcov.as_posix(),
        "categories": results,
    }
    rendered_json = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    print(rendered_json, end="")

    if args.output_json:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(rendered_json, encoding="utf-8")
    if args.output_md:
        args.output_md.parent.mkdir(parents=True, exist_ok=True)
        rows = [
            "# Mobile coverage gates",
            "",
            "| Gate | Covered | Total | Result | Required | Status |",
            "|---|---:|---:|---:|---:|---|",
        ]
        for name, result in results.items():
            assert isinstance(result, dict)
            rows.append(
                f"| `{name}` | {result['hit']} | {result['found']} | "
                f"{result['percent']:.2f}% | {result['threshold']:.2f}% | "
                f"{result['status']} |"
            )
        rows.extend(
            [
                "",
                "Generated DTO and localization files are excluded only from the "
                "overall authored-code denominator.",
            ]
        )
        args.output_md.write_text("\n".join(rows) + "\n", encoding="utf-8")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
