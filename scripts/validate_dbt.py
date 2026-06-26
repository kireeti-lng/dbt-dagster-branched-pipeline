#!/usr/bin/env python3
"""
===============================================================================
validate_dbt.py

Custom Repository Validator for dbt Projects

This script replaces dbt-checkpoint and validates the repository before
allowing code to reach the build stage.

Checks performed
----------------
✓ Repository structure
✓ Required files
✓ YAML syntax
✓ Manifest exists
✓ Model metadata
✓ Source metadata
✓ Macro metadata
✓ Data test metadata
✓ Duplicate resource names
✓ Orphan SQL files
✓ Orphan YAML entries

Exit Codes
----------
0 = Success
1 = Validation Failed
===============================================================================
"""

from pathlib import Path
import json
import sys
import time
import yaml

ROOT = Path(__file__).resolve().parents[1]
DBT = ROOT / "dbt_dagster_pipeline"

MANIFEST = DBT / "target" / "manifest.json"

ERRORS = []


# =============================================================================
# Helpers
# =============================================================================

def error(message: str):
    ERRORS.append(message)


def header(title: str):
    print("\n" + "=" * 72)
    print(title)
    print("=" * 72)


def result(name: str, success: bool):
    status = "PASS" if success else "FAIL"
    dots = "." * max(2, 55 - len(name))
    print(f"{name} {dots} {status}")


def load_yaml(path: Path):
    try:
        with open(path, encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except Exception as exc:
        error(f"Invalid YAML: {path}\n  {exc}")
        return {}


def collect_resources(section: str):
    resources = {}

    for yml in DBT.rglob("*.yml"):

        # --- MANDATORY PACKAGES GUARD FIX ---
        # Skip files auto-generated in the target folder OR managed by dbt deps
        if "target" in yml.parts or "dbt_packages" in yml.parts:
            continue

        data = load_yaml(yml)
        for obj in data.get(section, []) or []:

            # --- TYPE GUARD ---
            if not isinstance(obj, dict):
                continue

            name = obj.get("name")
            if not name:
                continue

            if name in resources:
                error(
                    f"Duplicate {section[:-1]} '{name}'\n"
                    f"  {resources[name]['file']}\n"
                    f"  {yml}"
                )

            resources[name] = {
                "object": obj,
                "file": yml
            }

    return resources


# =============================================================================
# Validation
# =============================================================================

def validate_repository():
    header("Repository Structure")

    required = [
        DBT / "dbt_project.yml",
        DBT / "profiles.yml",
        DBT / "models",
        DBT / "macros",
        DBT / "tests",
        ROOT / "pyproject.toml",
        ROOT / ".pre-commit-config.yaml",
        ROOT / ".github" / "workflows" / "dev_testing.yml",
    ]

    ok = True
    for item in required:
        if not item.exists():
            error(f"Missing required path:\n  {item}")
            ok = False

    result("Repository Structure", ok)


def validate_manifest():
    header("Manifest")
    ok = True

    if not MANIFEST.exists():
        error(
            "manifest.json not found.\n"
            "Run:\n"
            "    dbt parse --target ci"
        )
        ok = False
    else:
        try:
            with open(MANIFEST, encoding="utf-8") as f:
                json.load(f)
        except Exception as exc:
            error(f"Invalid manifest.json\n{exc}")
            ok = False

    result("Manifest", ok)


def validate_models():
    header("Models")
    ok = True

    models = collect_resources("models")
    sql_models = {
        p.stem
        for p in (DBT / "models").rglob("*.sql")
        if "dbt_packages" not in p.parts # Protect model searches from package schemas
    }

    for model in sql_models:
        if model not in models:
            error(f"Model '{model}' missing YAML entry")
            ok = False
            continue

        desc = models[model]["object"].get("description")
        if not desc or not str(desc).strip():
            error(f"Model '{model}' missing description")
            ok = False

    for model in models:
        if model not in sql_models:
            error(f"YAML model '{model}' has no SQL file")
            ok = False

    result("Models", ok)


def validate_macros():
    header("Macros")
    ok = True

    macros = collect_resources("macros")
    sql_macros = {
        p.stem
        for p in (DBT / "macros").glob("*.sql")
        if "dbt_packages" not in p.parts
    }

    for macro in sql_macros:
        if macro not in macros:
            error(f"Macro '{macro}' missing YAML entry")
            ok = False
            continue

        desc = macros[macro]["object"].get("description")
        if not desc or not str(desc).strip():
            error(f"Macro '{macro}' missing description")
            ok = False

    for macro in macros:
        if macro not in sql_macros:
            error(f"YAML macro '{macro}' has no SQL file")
            ok = False

    result("Macros", ok)


def validate_tests():
    header("Data Tests")
    ok = True

    tests = collect_resources("data_tests")
    sql_tests = {
        p.stem
        for p in (DBT / "tests").glob("*.sql")
        if "dbt_packages" not in p.parts
    }

    for test in sql_tests:
        if test not in tests:
            error(f"Data Test '{test}' missing YAML entry")
            ok = False
            continue

        desc = tests[test]["object"].get("description")
        if not desc or not str(desc).strip():
            error(f"Data Test '{test}' missing description")
            ok = False

    for test in tests:
        if test not in sql_tests:
            error(f"YAML Data Test '{test}' has no SQL file")
            ok = False

    result("Data Tests", ok)


def validate_sources():
    header("Sources")
    ok = True

    sources = collect_resources("sources")
    for source_name, src in sources.items():
        source = src["object"]

        if not source.get("description"):
            error(f"Source '{source_name}' missing description")
            ok = False

        if not source.get("schema"):
            error(f"Source '{source_name}' missing schema")
            ok = False

        tables = source.get("tables", [])
        if not tables:
            error(f"Source '{source_name}' has no tables")
            ok = False

        for table in tables:
            if not table.get("description"):
                error(
                    f"Source table '{source_name}.{table.get('name')}' "
                    "missing description"
                )
                ok = False

    result("Sources", ok)


# =============================================================================
# Main
# =============================================================================

def main():
    start = time.time()

    validate_repository()
    validate_manifest()
    validate_models()
    validate_macros()
    validate_tests()
    validate_sources()

    print("\n")
    print("=" * 72)

    if ERRORS:
        print("VALIDATION FAILED\n")
        for err in ERRORS:
            print(f"• {err}")

        print("\n" + "=" * 72)
        print(f"Total Errors : {len(ERRORS)}")
        print(f"Elapsed Time : {time.time()-start:.2f} sec")
        print("=" * 72)
        sys.exit(1)

    print("SUCCESS")
    print("Repository validation completed successfully.")
    print(f"Elapsed Time : {time.time()-start:.2f} sec")
    print("=" * 72)
    sys.exit(0)


if __name__ == "__main__":
    main()
