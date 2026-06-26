#!/usr/bin/env python3
"""Patch historical portal-gateway upstream JSON.

Reads a Kubernetes ConfigMap JSON from stdin and writes sanitized JSON to stdout.
This preserves the completed nof-platform -> nof-mp gateway migration pattern as
historical evidence; it is not a routine active-state apply script.
"""

import json
import sys

obj = json.load(sys.stdin)
conf = obj.get("data", {}).get("default.conf", "")
old = "server nof-platform:3000;"
new = "server nof-mp:3000;"

if old not in conf:
    raise SystemExit("expected upstream not found")

obj["data"]["default.conf"] = conf.replace(old, new, 1)

metadata = obj.get("metadata", {})
obj["metadata"] = {
    "name": metadata["name"],
    "namespace": metadata["namespace"],
}

for key in ("status", "resourceVersion", "uid", "creationTimestamp", "managedFields"):
    obj.pop(key, None)

print(json.dumps(obj))
