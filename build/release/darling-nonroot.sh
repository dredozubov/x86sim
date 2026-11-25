#!/bin/sh
# x86Sim: Darling without root and without namespaces (the AppImage's "nonroot" mode, docs/RELEASE.md). Installed as
# bin/darling of <data>/app/<version>/darling-nonroot, which <data>/darling-prefix points at.
# For hosts that allow neither the setuid install nor unprivileged user namespaces (some containers, hardened
# kernels). Darling's own launcher, unprivileged and with DARLING_NONROOT=1, takes its install prefix from the path of
# its executable (<app>/darling), copies the system image into each prefix instead of mounting an overlay, and shares
# the host's process table (no PID namespace).
W=$(cd "$(dirname "$0")/.." && pwd -P)
export DARLING_NONROOT=1
exec "$W/../darling/bin/darling" "$@"
