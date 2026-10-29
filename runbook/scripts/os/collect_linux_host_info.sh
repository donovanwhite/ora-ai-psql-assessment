#!/usr/bin/env bash
# Read-only Oracle host sizing evidence. No packages are installed.
set -uo pipefail
umask 077
export LC_ALL=C
export PATH="${PATH}:/usr/sbin:/sbin"

usage() {
  printf 'Usage: %s OUTPUT_DIR [SAMPLE_COUNT=5] [SAMPLE_INTERVAL_SECONDS=1]\n' "$0"
}

if [[ $# -lt 1 || $# -gt 3 ]]; then usage >&2; exit 2; fi
out_dir="$1"
samples="${2:-5}"
interval="${3:-1}"
if [[ ! "$samples" =~ ^[1-9][0-9]{0,2}$ || ! "$interval" =~ ^[1-9][0-9]{0,2}$ ]]; then
  printf 'ERROR: sample count and interval must be positive integers.\n' >&2
  exit 2
fi
mkdir -p -- "$out_dir" || { printf 'ERROR: cannot create output directory.\n' >&2; exit 1; }
chmod 700 "$out_dir" || { printf 'ERROR: cannot protect output directory.\n' >&2; exit 1; }
log="$out_dir/host_collection_status.txt"
start_seconds=$SECONDS
failures=0
skipped=0
{
  printf 'COLLECTION_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'HOST=%s\n' "$(hostname)"
  printf 'COLLECTION_USER=%s\n' "$(id -un)"
  printf 'NOMINAL_WINDOW_SECONDS_PER_SAMPLER=%s\n' "$((samples * interval))"
  printf 'SAMPLE_COUNT=%s\nSAMPLE_INTERVAL_SECONDS=%s\n' "$samples" "$interval"
  printf 'SAMPLING_MODE=SEQUENTIAL\n'
  printf 'FIRST_VMSTAT_IOSTAT_REPORT=SINCE_BOOT_NOT_INTERVAL\n'
  printf 'RESOURCE_LIMITS_SCOPE=COLLECTOR_SHELL_NOT_ORACLE_PROCESS\n'
} > "$log" || { printf 'ERROR: cannot write collection status.\n' >&2; exit 1; }

capture() {
  local file="$1"; shift
  local result=0
  local reason=COMMAND_EXIT
  if command -v "$1" >/dev/null 2>&1; then
    printf 'COMMAND_START_UTC=%s,%s\n' "$file" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log"
    "$@" > "$out_dir/$file" 2>&1 || result=$?
    if [[ "$file" == lvm_* ]] &&
       grep -Eq 'Permission denied|Unable to obtain global lock|Failure to communicate with kernel device-mapper driver' "$out_dir/$file"; then
      reason=ACCESS_DIAGNOSTIC
    fi
    if [[ "$result" -eq 0 && "$reason" == COMMAND_EXIT ]]; then
      printf 'CAPTURED=%s\n' "$file" >> "$log"
    else
      printf 'COMMAND_EXIT=%s\n' "$result" >> "$out_dir/$file"
      printf 'FAILED=%s,EXIT=%s,REASON=%s\n' "$file" "$result" "$reason" >> "$log"
      failures=$((failures + 1))
    fi
    printf 'COMMAND_END_UTC=%s,%s\n' "$file" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log"
  else
    printf 'SKIPPED=%s (command unavailable: %s)\n' "$file" "$1" >> "$log"
    skipped=$((skipped + 1))
  fi
}

capture os_release.txt cat /etc/os-release
capture kernel_host.txt uname -a
capture cpu_inventory.txt lscpu
capture memory_current.txt free -h
capture memory_details.txt cat /proc/meminfo
capture uptime.txt uptime
capture filesystem_capacity.txt df -hPT
capture disk_layout.txt lsblk -o NAME,TYPE,SIZE,ROTA,MODEL
capture network_interfaces.txt ip -brief address
capture numa_topology.txt numactl --hardware
capture multipath_layout.txt multipath -ll
capture lvm_physical_volumes.txt pvs --noheadings -o pv_name,pv_size,pv_free
capture lvm_volume_groups.txt vgs --noheadings -o vg_name,vg_size,vg_free
capture lvm_logical_volumes.txt lvs --noheadings -o lv_name,vg_name,lv_size,lv_attr
capture resource_limits.txt sh -c 'ulimit -a'
capture hugepages.txt sh -c "grep -E 'HugePages|Hugepagesize|AnonHugePages' /proc/meminfo"

for utility in vmstat iostat sar mpstat; do
  if command -v "$utility" >/dev/null 2>&1; then
    case "$utility" in
      vmstat) capture "sample_${utility}.txt" "$utility" "$interval" "$samples" ;;
      iostat) capture "sample_${utility}.txt" "$utility" -xz "$interval" "$samples" ;;
      sar) capture "sample_${utility}.txt" "$utility" -u -r -d "$interval" "$samples" ;;
      mpstat) capture "sample_${utility}.txt" "$utility" -P ALL "$interval" "$samples" ;;
    esac
  else
    printf 'SKIPPED=sample_%s.txt (utility unavailable)\n' "$utility" >> "$log"
    skipped=$((skipped + 1))
  fi
done

printf 'COLLECTION_END_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$log"
printf 'ELAPSED_SECONDS=%s\nFAILED_COUNT=%s\nSKIPPED_COUNT=%s\n' \
  "$((SECONDS - start_seconds))" "$failures" "$skipped" >> "$log"
if [[ "$failures" -gt 0 ]]; then
  printf 'STATUS=PARTIAL_FAILURE\n' >> "$log"
  printf 'ERROR: %s collection command(s) failed; review %s.\n' "$failures" "$log" >&2
  exit 1
fi
printf 'STATUS=COMPLETE_WITH_REVIEW\n' >> "$log"
printf 'Host evidence written to %s\n' "$out_dir"
printf 'Review host_collection_status.txt for skipped tools; redact approved network/host details before sharing.\n'
