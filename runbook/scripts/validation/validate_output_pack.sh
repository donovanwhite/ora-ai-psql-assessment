#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required_file="${script_dir}/required-files.txt"
if [[ $# -ne 1 || ! -d "$1" ]]; then
  printf 'Usage: %s INPUT_DIRECTORY\n' "$0" >&2
  exit 2
fi
root="$(cd "$1" && pwd)"
summary="${root}/validation_summary.csv"
issues=0

printf 'file,size_bytes,sha256\n' > "$summary"
while IFS= read -r relative || [[ -n "$relative" ]]; do
  relative="${relative%$'\r'}"
  [[ -z "$relative" ]] && continue
  if [[ -f "${root}/${relative}" ]]; then
    continue
  fi
  pattern="${relative##*/}"
  pattern="${pattern//<OWNER>/*}"
  if ! find "$root" -type f -name "$pattern" -print -quit | grep -q .; then
    printf 'ISSUE=MISSING_REQUIRED_FILE:%s\n' "$relative"
    issues=$((issues + 1))
  fi
done < "$required_file"

while IFS= read -r -d '' file; do
  relative="${file#${root}/}"
  size="$(wc -c < "$file" | tr -d ' ')"
  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    hash="$(shasum -a 256 "$file" | awk '{print $1}')"
  else
    printf 'ERROR: sha256sum or shasum is required.\n' >&2
    exit 2
  fi
  printf '"%s",%s,%s\n' "$relative" "$size" "$hash" >> "$summary"
  if [[ "$size" -eq 0 ]]; then
    printf 'ISSUE=ZERO_BYTE_FILE:%s\n' "$relative"; issues=$((issues + 1))
  fi
  if grep -Eiq 'ORA-[0-9]{5}|SP2-[0-9]{4}|TNS-[0-9]{5}' "$file" 2>/dev/null; then
    printf 'ISSUE=ORACLE_ERROR_MARKER:%s\n' "$relative"; issues=$((issues + 1))
  fi
  if grep -Eiq '(password|passwd|pwd)[[:space:]]*[:=][[:space:]]*[^,;[:space:]]+|(api[_-]?key|client[_-]?secret|access[_-]?token)[[:space:]]*[:=][[:space:]]*[^,;[:space:]]+' "$file" 2>/dev/null; then
    printf 'ISSUE=SECRET_PATTERN:%s\n' "$relative"; issues=$((issues + 1))
  fi
done < <(find "$root" -type f ! -name 'validation_summary.csv' -print0)

if [[ "$issues" -gt 0 ]]; then
  printf 'Validation failed with %s issue(s). No secret values were printed.\n' "$issues"
  exit 1
fi
printf 'Validation passed. SHA-256 inventory: %s\n' "$summary"
