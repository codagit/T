#!/bin/bash

# ===== Colors =====
C_RESET="\033[0m"
C_HEADER="\033[1;36m"
C_INFO="\033[1;34m"
C_WARN="\033[1;33m"
C_FAIL="\033[1;31m"

# ===== Files =====
temp_domains=".temp_domains.txt"

# ===== Helpers =====
clear_screen(){ printf "\033c"; }
pause_enter(){ read -rp "Press Enter to continue..."; }

# ===== Dependencies =====
check_deps(){
  if ! command -v curl &> /dev/null; then
    echo -e "${C_WARN}Installing dependencies...${C_RESET}"
    pkg update -y && pkg install curl -y
  fi
}

# ===== VPNJantit Scan (Lightweight) =====
scan_vpnjantit(){
  echo -e "${C_INFO}Starting VPNJantit scan...${C_RESET}"
  
  : > "$temp_domains"
  countries=("japan" "united-states" "germany" "france" "singapore")
  
  for country in "${countries[@]}"; do
    echo -e "\n${C_INFO}Scanning ${country}...${C_RESET}"
    curl -s -L -A "Mozilla/5.0" "https://www.vpnjantit.com/free-ssh-server-$country" \
      | grep -oE '[a-z0-9.-]+\.vpnjantit\.com' \
      | grep -v 'www\.' \
      | sort -u \
      | tee -a "$temp_domains"
  done
  
  echo -e "\n${C_INFO}Scan completed! Domains saved.${C_RESET}"
}

# ===== OpenTunnel Scan (Lightweight) =====
scan_opentunnel(){
  echo -e "${C_INFO}Starting OpenTunnel scan...${C_RESET}"
  
  : > "$temp_domains"
  curl -s -L -A "Mozilla/5.0" "https://opentunnel.net/ssh/" \
    | grep -oE '[a-z0-9.-]+\.optnl\.com' \
    | grep -v '^dns\.' \
    | sort -u \
    | tee "$temp_domains"
  
  echo -e "\n${C_INFO}Scan completed! Domains saved.${C_RESET}"
}

# ===== Resolve Domains =====
resolve_domains(){
  [ ! -s "$temp_domains" ] && {
    echo -e "${C_WARN}No domains found! Run scan first.${C_RESET}"
    return
  }
  
  echo -e "\n${C_INFO}Resolving domains...${C_RESET}"
  while read -r domain; do
    ip=$(curl -s "https://dns.google/resolve?name=$domain&type=A" \
          | grep -oE '"data":"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' \
          | head -1 \
          | cut -d '"' -f4)
    
    if [ -n "$ip" ]; then
      echo -e "${C_INFO}$domain → $ip${C_RESET}"
      echo "$domain $ip" >> resolved_ips.txt
    else
      echo -e "${C_FAIL}$domain → Resolution failed${C_RESET}"
    fi
  done < "$temp_domains"
}

# ===== Ping IPs =====
ping_ips(){
  [ ! -f "resolved_ips.txt" ] && {
    echo -e "${C_WARN}No IPs found! Resolve domains first.${C_RESET}"
    return
  }
  
  echo -e "\n${C_INFO}Pinging IPs...${C_RESET}"
  while read -r line; do
    domain=$(echo "$line" | awk '{print $1}')
    ip=$(echo "$line" | awk '{print $2}')
    
    result=$(ping -c 2 -W 2 "$ip" 2>&1)
    if [[ "$result" == *"time="* ]]; then
      avg=$(echo "$result" | awk -F'/' 'END {print $5}')
      echo -e "${C_INFO}$domain ($ip) → ${avg}ms${C_RESET}"
    else
      echo -e "${C_FAIL}$domain ($ip) → Timeout${C_RESET}"
    fi
  done < "resolved_ips.txt"
}

# ===== Main Menu =====
main_menu(){
  while true; do
    clear_screen
    echo -e "${C_HEADER}===== VPN DOMAIN SCANNER ====="
    echo "1. Scan VPNJantit (5 countries)"
    echo "2. Scan OpenTunnel"
    echo "3. Resolve domains to IPs"
    echo "4. Ping resolved IPs"
    echo "5. Exit"
    echo "=============================${C_RESET}"
    
    read -rp "Choose option [1-5]: " choice
    case $choice in
      1) scan_vpnjantit ;;
      2) scan_opentunnel ;;
      3) resolve_domains ;;
      4) ping_ips ;;
      5) echo "Goodbye!"; exit 0 ;;
      *) echo -e "${C_FAIL}Invalid choice!${C_RESET}";;
    esac
    
    pause_enter
  done
}

# ===== Start =====
check_deps
main_menu
