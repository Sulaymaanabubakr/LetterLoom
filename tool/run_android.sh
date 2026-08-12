#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
defines_file="$project_root/dart_defines.local.json"

if [[ ! -s "$defines_file" ]]; then
  echo "Missing $defines_file. This file must contain the public Supabase URL and publishable key." >&2
  exit 1
fi

cd "$project_root"
exec flutter run --dart-define-from-file=dart_defines.local.json "$@"
