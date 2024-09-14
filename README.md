This script (available in both Bash and Batch versions) determines the optimal Maximum Transmission Unit (MTU) for a network connection using a binary search methodology to find the largest buffer size that can be transmitted without fragmentation. By pinging a target IP address with progressively adjusted packet sizes, it uses reductive math and logic to narrow the search range with each test iteration. Once the largest non-fragmented buffer size is found, the script calculates the final MTU by adding the standard IP and ICMP header sizes.

It includes options for setting custom buffer sizes, a target IP, and a quiet mode for displaying only the final MTU value.

# Example Output

### Help (-h)

    @SYSTEM:/volume1/homes/admin/scripts/bash# bash mtutest.sh -h
    
    Usage: mtutest.sh [-b #] [-t #.#.#.#] [-q] [-h]
    
    -b: Override the default buffer max size of 65536
    -t: Override the default ping target of 1.1.1.1
    -q: Quiet mode, only output the final result
    -h: Display this help message

### Default Run (timed)

    @SYSTEM:/volume1/homes/admin/scripts/bash# bash mtutest.sh
    
    Starting MTU check for 65536 bytes against 1.1.1.1...
    
        Ping Buffer: 65536 bytes (fragmented)
        Ping Buffer: 32801 bytes (fragmented)
        Ping Buffer: 16434 bytes (fragmented)
        Ping Buffer: 8251 bytes (fragmented)
        Ping Buffer: 4159 bytes (fragmented)
        Ping Buffer: 2113 bytes (fragmented)
        Ping Buffer: 1090 bytes
        Ping Buffer: 1601 bytes (fragmented)
        Ping Buffer: 1345 bytes
        Ping Buffer: 1473 bytes (fragmented)
        Ping Buffer: 1409 bytes
        Ping Buffer: 1441 bytes
        Ping Buffer: 1457 bytes
        Ping Buffer: 1465 bytes
        Ping Buffer: 1469 bytes
        Ping Buffer: 1471 bytes
        Ping Buffer: 1472 bytes
                    ----
        Max Buffer: 1472 bytes
          IP Header: 20 bytes
        ICMP Header: 8 bytes
                    ----
          IDEAL MTU: 1500
    
    real    0m1.073s
    user    0m0.076s
    sys     0m0.039s

### Quiet Run

    @SYSTEM:/volume1/homes/admin/scripts/bash# mtutest.sh -q
    1500
