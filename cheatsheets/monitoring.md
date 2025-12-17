# System Monitoring Tools

Quick reference for the monitoring stack.

## Process & System

### strace — trace system calls
```bash
# Trace a command
strace ls -la

# Trace a running process
strace -p <PID>

# Show only file operations
strace -e trace=file ls

# Show only network calls
strace -e trace=network curl example.com

# Count syscalls (summary)
strace -c ls -la

# Write trace to file
strace -o trace.log ./myprogram
```

### lsof — list open files & sockets
```bash
# Files opened by a process
lsof -p <PID>

# What process is using a port?
lsof -i :8080

# All network connections
lsof -i

# Files opened in a directory
lsof +D /path/to/dir

# Files opened by a user
lsof -u gustavo
```

## Disk I/O

### iotop — per-process disk I/O
```bash
# Run iotop (needs root)
sudo iotop

# Only show processes doing I/O
sudo iotop -o

# Batch mode (for scripts)
sudo iotop -b -n 5    # 5 iterations
```

### iostat (from sysstat) — device I/O stats
```bash
# Basic I/O stats
iostat

# Update every 2 seconds
iostat 2

# Extended stats for specific device
iostat -x /dev/nvme0n1 2
```

## Network

### iftop — per-connection bandwidth
```bash
# Monitor default interface (needs root)
sudo iftop

# Monitor specific interface
sudo iftop -i wlan0

# Don't resolve hostnames (faster)
sudo iftop -n
```

### mtr — traceroute + ping combined
```bash
# Trace route to host
mtr example.com

# Report mode (non-interactive)
mtr -r -c 10 example.com

# Show IP addresses instead of hostnames
mtr -n example.com
```

### nmap — network scanner
```bash
# Scan a host
nmap 192.168.1.1

# Scan a subnet
nmap 192.168.1.0/24

# Quick scan (top 100 ports)
nmap -F 192.168.1.1

# Service/version detection
nmap -sV 192.168.1.1

# OS detection
sudo nmap -O 192.168.1.1
```

## Hardware

### lm_sensors — temperatures & fans
```bash
# Detect sensors (run once)
sudo sensors-detect

# Show all sensor readings
sensors

# Watch continuously
watch -n 1 sensors
```

### lspci / lsusb — hardware listing
```bash
# List PCI devices
lspci

# Verbose (show drivers)
lspci -v

# Show GPU details
lspci -v | grep -A 20 VGA

# List USB devices
lsusb

# Verbose USB
lsusb -v
```

## System Performance (sysstat)

### sar — historical system stats
```bash
# CPU usage every 2 sec, 5 times
sar 2 5

# Memory usage
sar -r 2 5

# Disk I/O
sar -d 2 5

# Network
sar -n DEV 2 5
```

### mpstat — per-CPU stats
```bash
# All CPUs
mpstat -P ALL 2 5
```

## Quick Diagnosis Cheatsheet

| Symptom | Tool | Command |
|---------|------|---------|
| System slow | `iotop` | `sudo iotop -o` |
| High CPU | `mpstat` | `mpstat -P ALL 2` |
| Network slow | `mtr` | `mtr -r example.com` |
| Port in use | `lsof` | `lsof -i :PORT` |
| Overheating | `sensors` | `watch sensors` |
| Mystery process | `strace` | `strace -p PID` |
| Bandwidth hog | `iftop` | `sudo iftop -n` |
| Disk full | `lsof` | `lsof +D /path` |
