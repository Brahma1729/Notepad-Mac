#!/bin/bash
# Run the latest build directly from source (always up to date — no stale .app).
cd "$(dirname "$0")"
exec swift run "$@"