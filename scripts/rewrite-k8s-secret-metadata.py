#!/usr/bin/env python3
"""Rewrite Kubernetes Secret metadata without touching secret data values.

Reads a Kubernetes Secret JSON from stdin and writes sanitized JSON to stdout.
Use for metadata-only secret rename/copy preparation where secret values must
remain opaque and must not be printed or committed.
"""

import json
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: rewrite-k8s-secret-metadata.py <new-name> <namespace>")

new_name = sys.argv[1]
namespace = sys.argv[2]
obj = json.load(sys.stdin)

obj["metadata"] = {
    "name": new_name,
    "namespace": namespace,
}

for key in (
    "resourceVersion",
    "uid",
    "creationTimestamp",
    "managedFields",
    "annotations",
):
    obj.pop(key, None)

print(json.dumps(obj))
