#!/bin/bash
# Count number of files older than 30 days in /var/log
COUNT=$(find /var/log -type f -mtime +30 | wc -l)
echo "custom_files_old_count count=$COUNT"
