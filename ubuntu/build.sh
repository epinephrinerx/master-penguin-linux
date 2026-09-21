#!/bin/bash
# Build the Master Penguin Linux ISO, end to end.
#
#   sudo ./build.sh              everything
#   sudo ./build.sh 30 40        just those stages
#
# Stages are independent and re-runnable. 10 and 20 are the slow ones; once the
# chroot is built, iterating on the ISO is 30 and 40 only, a couple of minutes.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
source ./config/build.conf

[ "$(id -u)" -eq 0 ] || { echo "needs root: sudo ./build.sh" >&2; exit 1; }

STAGES=("$@")
if [ ${#STAGES[@]} -eq 0 ]; then
    STAGES=(10 20 30 40)
fi

for n in "${STAGES[@]}"; do
    s=$(ls scripts/"$n"-*.sh 2>/dev/null | head -1)
    [ -n "$s" ] || { echo "no such stage: $n" >&2; exit 1; }
    echo
    echo "################ $(basename "$s") ################"
    bash "$s"
done

echo
echo "images in $MP_OUT:"
ls -lh "$MP_OUT"/*.iso 2>/dev/null || echo "  (no iso yet)"
