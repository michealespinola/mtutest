#!/bin/bash
#
# A script to automagically determine the ideal Maximum Transmission Unit (MTU) size
#
# Author @michealespinola https://github.com/michealespinola/mtutest

# SCRAPE SCRIPT PATH INFO
SrceFllPth=$(readlink -f "${BASH_SOURCE[0]}")
#SrceFolder=$(dirname "$SrceFllPth")
SrceFileNm=${SrceFllPth##*/}

# DEFAULT VALUES
targetIpv4="1.1.1.1" # The IP address or hostname to ping (https://one.one.one.one/)
lowerBound=68        # Default low range for buffer size, per RFC 791
upperBound=65536     # Default high range for buffer size (64 KiB), per RFC 791

# OVERRIDE DEFAULT VALUES WITH CLI OPTIONS
while getopts "b:t:qh" opt; do
  case $opt in
  b)
    if ! [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
      printf '\n%16s %s\n\n' "Bad Option:" "-b, Requires a number value"
      exit 1
    fi
    upperBound="$OPTARG"
    ;;
  t)
    if ! [[ "$OPTARG" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && "$OPTARG" =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then
      printf '\n%16s %s\n\n' "Bad Option:" "-t, Requires a valid IPv4 address"
      exit 1
    fi
    targetIpv4="$OPTARG"
    ;;
  q) # Quiet Mode Option
    resultOnly=true
    ;;
  h) # HELP OPTION
    printf '\n%s\n\n' "Usage: $SrceFileNm [-b #] [-t #.#.#.#] [-q] [-h]"
    printf ' %s\n'    "-b: Override the default buffer max size of $upperBound"
    printf ' %s\n'    "-t: Override the default ping target of $targetIpv4"
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

# PING TEST FUNCTION
ping_test() {
  if {
    ping -c 1 -M "do" -s "$1" -W 1 "$targetIpv4" &
    pid=$!
    sleep 0.06
    kill $pid
  } 2>&1 | grep -E -q "frag needed|too long|too large"; then
    return 1
  else
    return 0
  fi
}

# Print the header
if [ -z "$resultOnly" ]; then
  if [ -z "$resultOnly" ]; then
    printf "\nStarting MTU check for %d bytes against %s...\n\n" "$upperBound" "$targetIpv4"
  fi
fi

if ping_test "$upperBound"; then
  maximumSiz=$upperBound
else
  if [ -z "$resultOnly" ]; then
    printf '%16s %s\n' "Ping Buffer:" "$upperBound bytes (fragmented)"
  fi
  upperBound=$((upperBound - 1))
fi

# BINARY SEARCH TO FIND THE MAXIMUM BUFFER SIZE
while [ $((upperBound - lowerBound)) -gt 1 ]; do
  testingBuf=$(((lowerBound + upperBound) / 2))
  if ping_test $testingBuf; then
    if [ -z "$resultOnly" ]; then
      printf '%16s %s\n' "Ping Buffer:" "$testingBuf bytes"
    fi
    lowerBound=$testingBuf
  else
    if [ -z "$resultOnly" ]; then
      printf '%16s %s\n' "Ping Buffer:" "$testingBuf bytes (fragmented)"
    fi
    upperBound=$testingBuf
  fi
done

# lowerBound should now be the maximum buffer size that doesn't fragment
maximumSiz=$lowerBound

# CALCULATE THE IDEAL MTU DATA PACKET SIZE
ipv4Header=20 # Typical IPv4 header size, per RFC 791
icmpHeader=8  # Typical ICMP header size, per RFC 792
idealMtuDp=$((maximumSiz + ipv4Header + icmpHeader))

# PRINT RESULTS
if [ -z "$resultOnly" ]; then
  printf '%16s %s\n'             "" "----"
  printf '%16s %s\n' "Max Buffer:"  "$maximumSiz bytes"
  printf '%16s %s\n' "IP Header:"   "$ipv4Header bytes"
  printf '%16s %s\n' "ICMP Header:" "$icmpHeader bytes"
  printf '%16s %s\n'             "" "----"
  printf '%16s %s\n\n' "IDEAL MTU:" "$idealMtuDp"
else
  printf '%d\n' "$idealMtuDp"
fi
