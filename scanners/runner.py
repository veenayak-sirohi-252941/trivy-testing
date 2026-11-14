#!/usr/bin/env python3
"""Run the pinned local scanner images and retain redacted results only."""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_IMAGES = {
    "trivy": ("aquasec/trivy:latest", "sha256:52389f537db07a4dc0d289f61893ec791a3244d2f5cf21c819a2e874d72f3764"),
    "trufflehog": ("trufflesecurity/trufflehog:latest", "sha256:c50b55a0cdcc7ac7ee8b29d209833a22d6e2b44d4f0d8fc87099e8c877cb6afe"),
    "gitleaks": ("zricethezav/gitleaks:latest", "sha256:4b81af4c7b4159acfdbbbfede6647bf49b4c9f24dc2a2bbd4581f39d5223fcfa"),
}


def run(cmd: list[str], **kwargs: Any) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=False, **kwargs)


def image_info(scanner: str) -> tuple[str, str | None, str | None]:
    default_name, default_id = EXPECTED_IMAGES[scanner]
    configured = os.environ.get({"trivy": "TRIVY_IMAGE", "trufflehog": "TRUFFLEHOG_IMAGE", "gitleaks": "GITLEAKS_IMAGE"}[scanner], default_name)
    inspected = run(["docker", "image", "inspect", "--format", "{{.Id}}", configured], capture_output=True, text=True)
    if inspected.returncode:
        return configured, None, "configured image is not present locally"
    image_id = inspected.stdout.strip()
    if configured == default_name and image_id != default_id:
        return configured, image_id, "local image ID differs from the supplied image ID"
    if configured != default_name and os.environ.get("ALLOW_IMAGE_OVERRIDE") != "1":
        return configured, image_id, "image override requires ALLOW_IMAGE_OVERRIDE=1"
    return configured, image_id, None


def version(scanner: str, image_id: str) -> str | None:
    arg = "version" if scanner == "gitleaks" else "--version"
    result = run(["docker", "run", "--network", "none", "--pull=never", "--rm", image_id, arg], capture_output=True, text=True)
    text = (result.stdout or result.stderr).strip().splitlines()
    return text[0] if result.returncode == 0 and text else None


def normalized_file(path: str) -> str:
    path = path.replace("\\", "/")
    if path.startswith("/repo/"):
        return path[len("/repo/"):]
    return path.lstrip("/")


def sanitize(scanner: str, mode: str, raw_path: Path, output_path: Path) -> tuple[int, list[dict[str, Any]]]:
    findings: list[dict[str, Any]] = []
    data: Any = None
    raw_text = raw_path.read_text(encoding="utf-8", errors="replace") if raw_path.exists() else ""
    if scanner == "trufflehog":
        records = []
        for line in raw_text.splitlines():
            try:
                item = json.loads(line)
                if isinstance(item, dict) and item.get("DetectorName"):
                    records.append(item)
            except json.JSONDecodeError:
                continue
        for item in records:
            meta = item.get("SourceMetadata", {}).get("Data", {})
            source_type = "Git" if "Git" in meta else "Filesystem"
            loc = meta.get(source_type, {})
            filename = loc.get("file") or loc.get("repository") or ""
            findings.append({"scanner": scanner, "mode": mode, "file": normalized_file(filename) if filename else "", "start_line": loc.get("line"), "end_line": loc.get("line"), "rule_id": item.get("DetectorType"), "detector": item.get("DetectorName"), "category": item.get("DetectorName"), "verified": bool(item.get("Verified")), "redacted": True})
    else:
        try:
            data = json.loads(raw_text)
        except (json.JSONDecodeError, TypeError):
            data = None
        if scanner == "gitleaks" and isinstance(data, list):
            for item in data:
                findings.append({"scanner": scanner, "mode": mode, "file": normalized_file(str(item.get("File", ""))), "start_line": item.get("StartLine"), "end_line": item.get("EndLine"), "rule_id": item.get("RuleID"), "detector": item.get("Description"), "category": item.get("RuleID"), "redacted": True})
        elif scanner == "trivy" and isinstance(data, dict):
            for result in data.get("Results") or []:
                target = normalized_file(str(result.get("Target", "")))
                for item in result.get("Secrets") or []:
                    findings.append({"scanner": scanner, "mode": mode, "file": target, "start_line": item.get("StartLine"), "end_line": item.get("EndLine"), "rule_id": item.get("RuleID"), "detector": item.get("Title"), "category": item.get("Category"), "severity": item.get("Severity"), "redacted": True})
    output_path.write_text(json.dumps({"scanner": scanner, "mode": mode, "raw_findings": len(findings), "findings": findings}, indent=2) + "\n", encoding="utf-8")
    os.chmod(output_path, 0o600)
    raw_path.unlink(missing_ok=True)
    return len(findings), findings


def write_private(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    os.chmod(path, 0o600)


def execute(scanner: str, mode: str, image_id: str, target: Path, run_dir: Path, cfg_path: Path) -> dict[str, Any]:
    final_dir = run_dir / scanner / mode
    final_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(final_dir, 0o700)
    config_mount: list[str] = []
    raw_args: list[str]
    with tempfile.TemporaryDirectory(prefix="secret-scan-") as temp_name:
        out_dir = Path(temp_name)
        os.chmod(out_dir, 0o700)
        raw = out_dir / "findings.raw"
        raw.touch(mode=0o600)
        error_log = out_dir / "stderr.private"
        if scanner == "gitleaks":
            raw_args = ["detect", "--source", "/repo", "--config", "/config/gitleaks.toml", "--report-format", "json", "--report-path", "/out/findings.raw", "--redact"]
            if mode == "filesystem":
                raw_args.append("--no-git")
            runtime_config = out_dir / "gitleaks.toml"
            write_private(runtime_config, cfg_path.read_text(encoding="utf-8") + "\n[allowlist]\npaths = [\"(^|/)results/\"]\n")
            config_mount = ["--mount", f"type=bind,src={runtime_config},dst=/config/gitleaks.toml,readonly"]
        elif scanner == "trufflehog":
            raw_args = (["--no-update", "filesystem", "--no-verification", "--no-color", "--json", "--exclude-paths", "/out/exclude-paths.txt", "/repo"] if mode == "filesystem" else ["--no-update", "git", "file:///repo", "--no-verification", "--no-color", "--json"])
        else:
            raw_args = ["fs", "--scanners", "secret", "--secret-config", "", "--format", "json", "--output", "/out/findings.raw", "--skip-dirs", ".git", "--skip-dirs", "results", "/repo"]
        if scanner == "trufflehog" and mode == "filesystem":
            write_private(out_dir / "exclude-paths.txt", "(^|/)\\.git(/|$)\n(^|/)results(/|$)\n")
        command = ["docker", "run", "--network", "none", "--pull=never", "--rm", "--user", f"{os.getuid()}:{os.getgid()}", "--env", "HOME=/tmp", "--mount", f"type=bind,src={target},dst=/repo,readonly", "--mount", f"type=bind,src={out_dir},dst=/out"]
        command.extend(config_mount)
        command.extend([image_id, *raw_args])
        with error_log.open("w", encoding="utf-8") as err:
            os.chmod(error_log, 0o600)
            if scanner == "trufflehog":
                with raw.open("w", encoding="utf-8") as stdout:
                    proc = run(command, stdout=stdout, stderr=err, text=True)
            else:
                proc = run(command, stdout=subprocess.DEVNULL, stderr=err, text=True)
        try:
            raw_count, _ = sanitize(scanner, mode, raw, out_dir / "findings.redacted.json")
            redacted = out_dir / "findings.redacted.json"
            shutil.copyfile(redacted, final_dir / redacted.name)
            os.chmod(final_dir / redacted.name, 0o600)
        except Exception as exc:
            error_log.unlink(missing_ok=True)
            return {"scanner": scanner, "mode": mode, "status": "EXECUTION_ERROR", "exit_code": proc.returncode, "findings": 0, "command": shlex.join(command), "error": f"report sanitization failed: {type(exc).__name__}"}
        # Gitleaks returns 1 when findings exist; a valid report differentiates
        # the normal finding exit from a report/command failure.
        if proc.returncode == 0:
            status = "COMPLETED_WITH_FINDINGS" if raw_count else "COMPLETED_NO_FINDINGS"
            error = None
        elif scanner == "gitleaks" and raw_count:
            status, error = "COMPLETED_WITH_FINDINGS", None
        else:
            status, error = "EXECUTION_ERROR", "scanner exited nonzero; private stderr discarded"
        error_log.unlink(missing_ok=True)
        return {"scanner": scanner, "mode": mode, "status": status, "exit_code": proc.returncode, "findings": raw_count, "command": shlex.join(command), "error": error}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scanner", choices=["trivy", "trufflehog", "gitleaks", "all"])
    parser.add_argument("--target", default=os.environ.get("SCAN_TARGET", str(ROOT)))
    parser.add_argument("--results-dir", default=os.environ.get("RESULTS_DIR", str(ROOT / "results" / "runs")))
    parser.add_argument("--history", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--only", choices=["trivy","trufflehog","gitleaks"], help="select one scanner when invoking the all-scanner runner")
    parser.add_argument("--run-dir", help=argparse.SUPPRESS)
    args = parser.parse_args()
    target = Path(args.target).resolve()
    if not target.is_dir():
        parser.error(f"scan target is not a directory: {target}")
    config = ROOT / "fixtures" / ".gitleaks.toml"
    if not config.is_file():
        parser.error(f"preserved Gitleaks config is missing: {config}")
    results_base = Path(args.results_dir).resolve()
    if args.run_dir:
        run_dir = Path(args.run_dir).resolve()
        run_dir.mkdir(parents=True,exist_ok=True,mode=0o700)
    else:
        results_base.mkdir(parents=True,exist_ok=True,mode=0o700)
        run_dir=results_base/"latest"
        if run_dir.exists():
            shutil.rmtree(run_dir)
        # The standard output location is replaced on each run, so old
        # timestamped scan directories do not accumulate alongside it.
        for previous in results_base.glob("run-*"):
            if previous.is_dir():
                shutil.rmtree(previous)
        run_dir.mkdir(mode=0o700)
    os.chmod(run_dir,0o700)
    selected=([args.only] if args.only else list(EXPECTED_IMAGES)) if args.scanner=="all" else [args.scanner]
    metadata={"run_id":run_dir.name,"timestamp":dt.datetime.now().astimezone().isoformat(),"repository_commit":None,"scan_target":str(target),"scan_scope":["repository root: application/, fixtures/, fixtures-extra/, misc/, root-level files and scanner configuration"],"excluded_from_filesystem":[".git metadata","results generated output","temporary backup files"],"runs":[]}
    commit=run(["git","rev-parse","HEAD"],cwd=ROOT,capture_output=True,text=True)
    if commit.returncode==0: metadata["repository_commit"]=commit.stdout.strip()
    docker_present=shutil.which("docker") is not None
    for scanner in selected:
        image_name,image_id,image_error=image_info(scanner) if docker_present else (EXPECTED_IMAGES[scanner][0],None,"Docker CLI unavailable")
        ver=version(scanner,image_id) if image_id and not image_error else None
        image_meta={"scanner":scanner,"image_name":image_name,"image_id":image_id,"version":ver}
        modes=["filesystem"]+( ["git-history"] if args.history and scanner in ("gitleaks","trufflehog") else [])
        for mode in modes:
            if image_error or not ver or (mode=="git-history" and not (target/".git").exists()):
                outcome={"scanner":scanner,"mode":mode,"status":"NOT_RUN","exit_code":None,"findings":0,"command":None,"error":image_error or "scanner version unavailable"}
            else:
                # Filesystem source scan is intentionally the complete working tree.
                outcome=execute(scanner,mode,image_id,target,run_dir,config)
            outcome.update(image_meta)
            metadata["runs"].append(outcome)
            print(f"{scanner} {mode}: {outcome['status']} findings={outcome['findings']} exit={outcome['exit_code']}")
    meta_path=run_dir/"metadata.json"
    meta_path.write_text(json.dumps(metadata,indent=2)+"\n",encoding="utf-8"); os.chmod(meta_path,0o600)
    compare=run([sys.executable,str(ROOT/"compare"/"compare_results.py"),"--run-dir",str(run_dir)],cwd=ROOT,capture_output=True,text=True)
    (run_dir/"comparison-command.log").write_text((compare.stdout+compare.stderr)[:4000],encoding="utf-8"); os.chmod(run_dir/"comparison-command.log",0o600)
    print(f"run directory: {run_dir}")
    return 0 if all(x["status"] not in ("EXECUTION_ERROR","NOT_RUN") for x in metadata["runs"]) and compare.returncode==0 else 1

if __name__=="__main__":
    raise SystemExit(main())
