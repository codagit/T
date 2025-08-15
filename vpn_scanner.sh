#!/bin/bash

# ===== Colors & Table =====
C_RESET="\033[0m"
C_HEADER="\033[1;36m"
C_COUNTRY="\033[1;32m"
C_INFO="\033[1;34m"
C_WARN="\033[1;33m"
C_FAIL="\033[1;31m"

COL_DOMAIN=30
COL_IP=20
COL_PING=10
SEPARATOR=" || "

# ===== Files =====
output_file="collected_domains.txt"
ip_file="resolved_ips.txt"
temp_domains=".temp_domains.txt"

# ===== Helpers =====
print_header(){
  printf "${C_HEADER}%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s${C_RESET}\n" "Domain" "IP Address" "Ping (ms)"
  echo "$(printf '=%.0s' $(seq 1 $((COL_DOMAIN + COL_IP + COL_PING + 10))))"
}

pause_enter(){ read -rp $'Press Enter to continue...\n'; }

# ===== Dependencies (Termux) =====
install_dependencies(){
  echo -e "${C_INFO}Updating & installing dependencies...${C_RESET}"
  pkg update -y && pkg upgrade -y
  pkg install curl git coreutils busybox grep dos2unix -y
  echo -e "${C_INFO}Dependencies finished.${C_RESET}"
}

# ===== CTRL+C handling for scans =====
stop_scan=false
scan_trap_on(){ trap 'stop_scan=true; echo -e "\n${C_FAIL}Scan interrupted by user!${C_RESET}"' SIGINT; }
scan_trap_off(){ trap - SIGINT; stop_scan=false; }

# ===== vpnjantit scan (parallel per-country) =====
scan_vpnjantit_country(){
  local country="$1"
  local domains
  domains=$(curl -s --max-time 10 "https://www.vpnjantit.com/free-ssh-$country" \
    | grep -oE '[a-z0-9.-]+\\.vpnjantit\\.com' | grep -v 'www\\.' | sort -u)

  echo -e "${C_COUNTRY}${country//-/ }:${C_RESET}"
  if [ -z "$domains" ]; then
    echo "${country//-/ }: No servers" >> "$output_file"
  else
    echo "${country//-/ }:" >> "$output_file"
    echo "$domains" | sed 's/^/  /' >> "$output_file"
    echo "$domains" >> "$temp_domains"
  fi
  \$stop_scan && exit 0
}

scan_vpnjantit(){
  local countries=(argentina australia brazil canada france germany india indonesia \
    japan malaysia netherlands singapore sweden turkey united-kingdom \
    united-states united-arab-emirates vietnam ukraine thailand switzerland \
    spain south-korea south-africa slovakia saudi-arabia russia romania qatar \
    portugal poland philippines pakistan oman moldova mexico luxembourg latvia \
    kuwait kazakhstan italy israel iraq ireland hungary hong-kong greece \
    finland estonia egypt denmark czech-republic chile cambodia bulgaria \
    bangladesh bahrain armenia)

  : > "$output_file"
  : > "$temp_domains"
  echo -e "${C_INFO}Starting VPNJantit scan (${#countries[@]} locations)...${C_RESET}"
  scan_trap_on
  export -f scan_vpnjantit_country
  export output_file temp_domains C_COUNTRY C_RESET stop_scan
  printf "%s\n" "${countries[@]}" | xargs -n1 -P4 bash -c 'scan_vpnjantit_country "$0"'
  scan_trap_off
  echo -e "\nScan completed at $(date +'%F %T')"
}

# ===== opentunnel scan (single page, filter dns.*) =====
scan_opentunnel(){
  : > "$output_file"
  : > "$temp_domains"
  echo -e "${C_INFO}Starting OpenTunnel scan...${C_RESET}"
  scan_trap_on
  local domains
  domains=$(curl -s --max-time 15 "https://opentunnel.net/ssh/#gsc.tab=0" \
    | grep -oE '[a-z0-9.-]+\\.optnl\\.com' \
    | grep -v '^dns\\.' \
    | sort -u)

  echo "OpenTunnel:" >> "$output_file"
  if [ -z "$domains" ]; then
    echo "OpenTunnel: No servers" >> "$output_file"
  else
    echo "$domains" | sed 's/^/  /' >> "$output_file"
    echo "$domains" >> "$temp_domains"
  fi
  scan_trap_off
  echo -e "\nScan completed at $(date +'%F %T')"
}

# ===== Resolve domains to IPs (parallel) =====
resolve_domains(){
  if [ ! -s "$temp_domains" ]; then
    echo -e "${C_WARN}No domains collected yet. Run a scan first.${C_RESET}"
    return 1
  fi
  : > "$ip_file"
  echo -e "\n${C_INFO}Resolving domains using Google's DNS API...${C_RESET}"
  print_header

  resolve_one(){
    local domain="$1"
    local response ip
    response=$(curl -s "https://dns.google/resolve?name=$domain&type=A")
    ip=$(echo "$response" | grep -oE '"data":"[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+"' | head -1 | cut -d '"' -f4)
    if [ -n "$ip" ]; then
      echo "$domain $ip" >> "$ip_file"
      printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s\n" "$domain" "$ip" "N/A"
    else
      printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s\n" "$domain" "Resolution failed" "N/A"
    fi
  }
