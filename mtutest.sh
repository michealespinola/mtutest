#!/usr/bin/env bash
#
# A script to automagically determine the ideal Maximum Transmission Unit (MTU) size
#
# Author @michealespinola https://github.com/michealespinola/mtutest
#
# shellcheck disable=SC2034,SC2207
# shellcheck source=/dev/null
# bash /volume1/homes/admin/scripts/bash/mtutest.sh

SCRIPT_VERSION=1.0.2

get_source_info() {                                                                               # FUNCTION TO GET SOURCE SCRIPT INFORMATION
  srcScrpVer="${SCRIPT_VERSION}"                                                                  # Source script version
  srcFullDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"                             # Source script absolute physical directory
  srcFullPth="${srcFullDir}/$(basename -- "${BASH_SOURCE[0]}")"                                   # Source script absolute path
  srcFileNam="${srcFullPth##*/}"                                                                  # Source script file name
}
get_source_info

# DEFAULT VALUES
boundLower=68        # Default low range for buffer size in bytes, per RFC 791
boundUpper=65536     # Default high range for buffer size (64 KiB) in bytes, per RFC 791
icmpHeader=8         # Typical ICMP header size in bytes, per RFC 792
ipv4Header=20        # Typical IPv4 header size in bytes, per RFC 791
ipv4Target="1.1.1.1" # The IP address or hostname to ping (https://one.one.one.one/)
probeDelay=0.06      # Seconds to wait before treating an unanswered probe as failed

# DETECT OPERATING SYSTEM
OStype="$(uname -s)"
case "$OStype" in
  Darwin|FreeBSD|OpenBSD|NetBSD)
    # BSD-family ping
    # -c = Count of pings
    # -D = Don't fragment
    # -s = payload Size
    # -W = Wait in milliseconds
    PING_TIMEOUT=1000
    PING_CMD=(ping -c 1 -D -W "$PING_TIMEOUT")
    PING_SIZE_OPT=(-s)
    ;;
  Linux)
    # GNU iputils ping
    # -M "do" = Mtu do prohibit fragmentation
    # -s = payload Size
    # -W = Wait in seconds
    PING_TIMEOUT=1
    PING_CMD=(ping -c 1 -M "do" -W "$PING_TIMEOUT")
    PING_SIZE_OPT=(-s)
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Windows native ping.exe
    # -f = don't Fragment
    # -l = payLoad size
    # -n = Number of pings
    # -w = Wait in milliseconds
    PING_TIMEOUT=1000
    PING_CMD=(ping.exe -n 1 -f -w "$PING_TIMEOUT")
    PING_SIZE_OPT=(-l)
    ;;
  *)
    printf '\nUnsupported OS: %s\n\n' "$OStype"
    exit 1
    ;;
esac

# OVERRIDE DEFAULT VALUES WITH CLI OPTIONS
while getopts "b:t:qh" opt; do
  case $opt in
  b)
    if ! [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
      printf '\n%16s %s\n\n' "Bad Option:" "-b, Requires a number value"
      exit 1
    fi
    boundUpper="$OPTARG"
    ;;
  t)
    if ! [[ "$OPTARG" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && "$OPTARG" =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then
      printf '\n%16s %s\n\n' "Bad Option:" "-t, Requires a valid IPv4 address"
      exit 1
    fi
    ipv4Target="$OPTARG"
    ;;
  q) # Quiet Mode Option
    resultOnly=true
    ;;
  h) # HELP OPTION
    printf '\n%s\n\n' "Usage: $srcFileNam [-b #] [-t #.#.#.#] [-q] [-h]"
    printf ' %s\n'    "-b: Override the default buffer max size of $boundUpper"
    printf ' %s\n'    "-t: Override the default ping target of $ipv4Target"
    printf ' %s\n'    "-q: Quiet mode, only output the final result"
    printf ' %s\n\n'  "-h: Display this help message"
    exit 0
    ;;
  \?) # INVALID OPTION
    printf '\n%16s %s\n\n' "Bad Option:" "-$OPTARG, Invalid (-h for Help)"
    exit 1
    ;;
  :) # MISSING ARGUMENT
    printf '\n%16s %s\n\n' "Bad Option:" "-$OPTARG, Requires an argument"
    exit 1
    ;;
  esac
done

ping_test() {
  local pingOutput pingStatus pid

  pingOutput="$(
    "${PING_CMD[@]}" "${PING_SIZE_OPT[@]}" "$1" "$ipv4Target" 2>&1 &
    pid=$!

    sleep "$probeDelay"

    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      printf '\n__PING_STATUS__:124\n'
    else
      wait "$pid"
      printf '\n__PING_STATUS__:%s\n' "$?"
    fi
  )"

  pingStatus=${pingOutput##*__PING_STATUS__:}

  if printf '%s\n' "$pingOutput" | awk '
    {
      line = tolower($0)
      found = found || line ~ /frag needed/
      found = found || line ~ /fragmented but df set/
      found = found || line ~ /too long/
      found = found || line ~ /too large/
      found = found || line ~ /message too long/
      found = found || line ~ /packet needs to be fragmented/
      found = found || line ~ /but df set/
    }

    END {
      exit found ? 0 : 1
    }
  '; then
    return 1
  fi

  case "$pingStatus" in
    0)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Print the header
if [ -z "$resultOnly" ]; then
  printf "\nStarting MTU test for %d bytes against %s...\n\n" "$boundUpper" "$ipv4Target"
fi

if ping_test "$boundUpper"; then
  maximumSiz=$boundUpper
else
  if [ -z "$resultOnly" ]; then
    printf '%16s %s\n' "Ping Buffer:" "$boundUpper bytes (fragmented)"
  fi
  boundUpper=$((boundUpper - 1))
fi

# BINARY SEARCH TO FIND THE MAXIMUM BUFFER SIZE
while [ $((boundUpper - boundLower)) -gt 1 ]; do
  testingBuf=$(((boundLower + boundUpper) / 2))
  if ping_test "$testingBuf"; then
    if [ -z "$resultOnly" ]; then
      printf '%16s %s\n' "Ping Buffer:" "$testingBuf bytes"
    fi
    boundLower=$testingBuf
  else
    if [ -z "$resultOnly" ]; then
      printf '%16s %s\n' "Ping Buffer:" "$testingBuf bytes (fragmented)"
    fi
    boundUpper=$testingBuf
  fi
done

# boundLower should now be the maximum buffer size that doesn't fragment
maximumSiz=$boundLower

# CALCULATE THE IDEAL MTU DATA PACKET SIZE
idealMtuDp=$((maximumSiz + ipv4Header + icmpHeader))

# PRINT RESULTS
if [ -z "$resultOnly" ]; then
  printf '%16s %s\n'             "" "----"
  printf '%16s %s\n'  "Max Buffer:" "$maximumSiz bytes"
  printf '%16s %s\n'   "IP Header:" "$ipv4Header bytes"
  printf '%16s %s\n' "ICMP Header:" "$icmpHeader bytes"
  printf '%16s %s\n'             "" "----"
  printf '%16s %s\n\n' "IDEAL MTU:" "$idealMtuDp"
else
  printf '%d\n' "$idealMtuDp"
fi
