#!/bin/bash
# Collect Disk and CPU stats
iostat -cdxz 60 20 > iostat_output.log &

# Collect Memory stats
vmstat 60 20 > vmstat_output.log &

# Collect Network stats
sar -n DEV 60 20 > sar_network.log &

# Wait for all processes to complete
wait

echo "Data collection completed. Check the log files for results:"
echo " - Disk and CPU: iostat_output.log"
echo " - Memory: vmstat_output.log"
echo " - Network: sar_network.log"
