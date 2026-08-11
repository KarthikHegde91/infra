#!/usr/bin/env python3
"""Render the Prometheus ConfigMaps into files promtool can actually check.

Why this exists
---------------
prometheus.yml and the alert rules live inside ConfigMap `data:` blocks, which
means every YAML tool in CI sees them as opaque strings. kubeconform happily
validates that prometheus-rules is a well-formed ConfigMap without ever looking
at the PromQL inside it. So a rule with a typo'd metric or an unbalanced paren
passes every check, reaches the cluster, and is silently skipped at load time —
the rule group exists, nothing fires, and the dashboard stays green. That is
the same class of bug as the outage that prompted the rules in the first place.

This script pulls the strings back out onto disk so `promtool check rules` and
`promtool check config` — the real parser — can run over them.

Two paths have to be rewritten for the check to work off-cluster:

  rule_files      points at /etc/prometheus/rules, a ConfigMap mount that only
                  exists in the pod.

  ca_file and     point into the ServiceAccount token volume. promtool does not
  bearer_token_   just parse these paths, it OPENS them: the token must be
  file            readable and the CA must be a parseable PEM. Substituting
                  throwaway files keeps the rest of the scrape config — relabel
                  rules, regexes, durations, scheme/port handling — genuinely
                  validated rather than skipped.

Usage:  prometheus-ci-render.py <workdir>
Then:   promtool check rules <workdir>/rules/*.yml
        promtool check config <workdir>/prometheus.yml
"""
import pathlib
import subprocess
import sys

import yaml

REPO = pathlib.Path(__file__).resolve().parent.parent
MONITORING = REPO / "k8s" / "monitoring" / "prometheus"


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2

    work = pathlib.Path(sys.argv[1]).resolve()
    rules_dir = work / "rules"
    rules_dir.mkdir(parents=True, exist_ok=True)

    # Every key in the rules ConfigMap, written under its own name. Iterating
    # rather than hardcoding alerts.yml keeps this honest if a second rule file
    # is added later: the rule_files glob would pick it up, so CI must too.
    rules_cm = yaml.safe_load((MONITORING / "rules.yaml").read_text(encoding="utf-8"))
    for name, body in rules_cm["data"].items():
        (rules_dir / name).write_text(body, encoding="utf-8")
        print(f"  rules: {name}")

    # A throwaway self-signed cert. Contents are irrelevant; it only has to
    # parse as PEM so promtool's TLS config loader succeeds.
    ca = work / "ca.crt"
    token = work / "token"
    token.write_text("ci-placeholder-token\n", encoding="utf-8")
    subprocess.run(
        ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
         "-keyout", str(work / "ca.key"), "-out", str(ca),
         "-days", "1", "-subj", "/CN=ci"],
        check=True, capture_output=True,
    )
    print(f"  generated: {ca.name}, {token.name}")

    config_cm = yaml.safe_load((MONITORING / "configmap.yaml").read_text(encoding="utf-8"))
    cfg = yaml.safe_load(config_cm["data"]["prometheus.yml"])
    cfg["rule_files"] = [rules_dir.as_posix() + "/*.yml"]
    for scrape in cfg.get("scrape_configs", []):
        if "bearer_token_file" in scrape:
            scrape["bearer_token_file"] = token.as_posix()
        tls = scrape.get("tls_config") or {}
        if "ca_file" in tls:
            tls["ca_file"] = ca.as_posix()

    (work / "prometheus.yml").write_text(yaml.safe_dump(cfg), encoding="utf-8")
    print(f"  config: prometheus.yml ({len(cfg.get('scrape_configs', []))} scrape jobs)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
