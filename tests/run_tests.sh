#!/bin/sh
# Offline test: runs every playbook against a fake "az" command that returns sample data.
# It checks the Ansible logic (loops, filters, commands built) without needing an Azure account.
# Usage:  sh tests/run_tests.sh      (needs ansible-core installed)
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN=$(mktemp -d); cp "$ROOT/tests/fake_az.sh" "$BIN/az"; chmod +x "$BIN/az"
export PATH="$BIN:$PATH"; export TMPDIR="$BIN"
cd "$ROOT/ansible" || exit 1
FAIL=0
run() {
  echo "== ansible-playbook $*"
  if ansible-playbook "$@" > "$BIN/out.txt" 2>&1; then
    grep "localhost  *:" "$BIN/out.txt"
  else
    echo "FAILED"; cat "$BIN/out.txt"; FAIL=1
  fi
}
run playbooks/00_login_and_inventory.yml
run playbooks/01_enroll_vms.yml
run playbooks/01_enroll_vms.yml -e enroll=true
run playbooks/02_disk_report.yml
run playbooks/03_top_disks.yml
echo "== az commands produced by enrollment (expect 3 per VM, 2 VMs):"
grep -E "identity assign|extension set|association create" "$BIN/az_calls.log" | cut -c1-110
[ "$FAIL" = 0 ] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
