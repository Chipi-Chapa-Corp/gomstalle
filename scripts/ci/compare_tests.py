#!/usr/bin/env python3
import argparse
import os
import sys
import xml.etree.ElementTree as ET


def parse_junit(path: str) -> dict:
    tree = ET.parse(path)
    root = tree.getroot()
    results = {}
    for case in root.iter("testcase"):
        name = case.get("name") or ""
        classname = case.get("classname") or ""
        key = f"{classname}::{name}" if classname else name
        status = "pass"
        if case.find("failure") is not None or case.find("error") is not None:
            status = "fail"
        elif case.find("skipped") is not None:
            status = "skip"
        results[key] = status
    return results


def render_list(title: str, items: list, max_items: int = 200) -> str:
    if not items:
        return f"✅ **0 {title.lower()}**\n"
    lines = [f"<details><summary>{title} ({len(items)})</summary>", ""]
    for item in items[:max_items]:
        lines.append(f"- {item}")
    if len(items) > max_items:
        lines.append("- ...")
    lines.append("</details>\n")
    return "\n".join(lines)


def write_github_output(broken_count: int, output_path: str | None) -> None:
    if not output_path:
        return
    with open(output_path, "a", encoding="utf-8") as out:
        out.write(f"broken_count={broken_count}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--main", required=True)
    parser.add_argument("--branch", required=True)
    parser.add_argument("--comment-out", required=True)
    args = parser.parse_args()

    if not os.path.exists(args.main):
        print(f"Missing main test report: {args.main}", file=sys.stderr)
        return 2
    if not os.path.exists(args.branch):
        print(f"Missing branch test report: {args.branch}", file=sys.stderr)
        return 2

    main_results = parse_junit(args.main)
    branch_results = parse_junit(args.branch)

    main_failed = {k for k, v in main_results.items() if v == "fail"}
    main_passed = {k for k, v in main_results.items() if v == "pass"}
    branch_failed = {k for k, v in branch_results.items() if v == "fail"}
    branch_passed = {k for k, v in branch_results.items() if v == "pass"}

    fixed_tests = sorted(main_failed & branch_passed)
    broken_tests = sorted(main_passed & branch_failed)
    debt_tests = sorted(main_failed & branch_failed)
    passed_tests = sorted(main_passed & branch_passed)

    lines = [
        "<!-- gut-test-report -->",
        "## ✅ GUT test report",
        "",
        render_list("✅ Fixed tests", fixed_tests),
        render_list("✅ Passed tests", passed_tests),
        render_list("❌ Broken tests", broken_tests),
        render_list("🧹 Technical debt", debt_tests),
    ]

    with open(args.comment_out, "w", encoding="utf-8") as out:
        out.write("\n".join(lines).strip() + "\n")

    write_github_output(len(broken_tests), os.environ.get("GITHUB_OUTPUT"))
    return 1 if broken_tests else 0


if __name__ == "__main__":
    sys.exit(main())
