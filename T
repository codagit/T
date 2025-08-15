#!/bin/bash

────────────────────────[ Colors & Table Settings ]──────────────────────────

COL_DOMAIN=30 COL_IP=20 COL_PING=10 SEPARATOR=" || " C_RESET="\033[0m" C_HEADER="\033[1;36m" C_COUNTRY="\033[1;32m" C_INFO="\033[1;34m" C_WARN="\033[1;33m" C_FAIL="\033[1;31m" C_MENU="\033[1;35m"

────────────────────────[ Files ]────────────────────────────────────────────

output_file="vpn_domains.txt"      # list of collected domains ip_file="vpn_ips.txt"              # domain + ip (after resolve) temp_domains=".temp_domains.txt"   # internal temp list

────────────────────────[ Helpers ]──────────────────────────────────────────

print_header() { printf "${C_HEADER}%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s${C_RESET}\n" 
"Domain" "IP Address" "Ping (ms)" echo "$(printf '=%.0s' $(seq 1 $((COL_DOMAIN + COL_IP + COL_PING + 10))))" }

pause_enter() { read -rp $'Press Enter to continue…\n'; }

────────────────────────[ Dependencies (Termux) ]────────────────────────────

install_deps() { echo -e "${C_INFO}Updating & installing dependencies (Termux)…${C_RESET}" pkg update -y && pkg upgrade -y pkg install curl git coreutils busybox grep dos2unix -y }

────────────────────────[ Scan Sources ]─────────────────────────────────────

Country list for vpnjantit

countries=(argentina australia brazil canada france germany india indonesia 
japan malaysia netherlands singapore sweden turkey united-kingdom 
united-states united-arab-emirates vietnam ukraine thailand switzerland 
spain south-korea south-africa slovakia saudi-arabia russia romania qatar 
portugal poland philippines pakistan oman moldova mexico luxembourg latvia 
kuwait kazakhstan italy israel iraq ireland hungary hong-kong greece 
finland estonia egypt denmark czech-republic chile cambodia bulgaria 
bangladesh bahrain armenia)

Shared CTRL+C handling during scanning phase

stop_scan=false scan_trap_on()  { trap 'echo -e "\n'"${C_FAIL}"'Scan interrupted by user!"'"${C_RESET}"'; stop_scan=true' SIGINT; } scan_trap_off() { trap - SIGINT; stop_scan=false; }

scan_vpnjantit_country() { local country="$1" local domains domains=$(curl -s --max-time 10 "https://www.vpnjantit.com/free-ssh-$country" 
| grep -oE '[a-z0-9.-]+\.vpnjantit\.com' | grep -v 'www\.' | sort -u)

echo -e "${C_COUNTRY}${country//-/ }:${C_RESET}" >> "$output_file" if [ -z "$domains" ]; then echo "  No servers" >> "$output_file" else echo "$domains" | tee -a "$output_file" >> "$temp_domains" fi $stop_scan && exit 0 }

scan_vpnjantit() {

> "$output_file"; > "$temp_domains" echo -e "${C_INFO}Starting VPNJantit scan (${#countries[@]} locations)…${C_RESET}" scan_trap_on export -f scan_vpnjantit_country export output_file temp_domains C_COUNTRY C_RESET stop_scan printf "%s\n" "${countries[@]}" | xargs -n1 -P4 bash -c 'scan_vpnjantit_country "$0"' scan_trap_off echo -e "\nScan completed at $(date +'%F %T')" }



scan_opentunnel() {

> "$output_file"; > "$temp_domains" echo -e "${C_INFO}Starting OpenTunnel scan…${C_RESET}" scan_trap_on local domains domains=$(curl -s --max-time 15 "https://opentunnel.net/ssh/#gsc.tab=0" 
| grep -oE '[a-z0-9.-]+\.optnl\.com' 
| grep -v '^dns\.' 
| sort -u)



echo -e "${C_COUNTRY}OpenTunnel:${C_RESET}" >> "$output_file" if [ -z "$domains" ]; then echo "  No servers" >> "$output_file" else echo "$domains" | tee -a "$output_file" >> "$temp_domains" fi scan_trap_off echo -e "\nScan completed at $(date +'%F %T')" }

────────────────────────[ Resolve ]──────────────────────────────────────────

resolve_domains() { if [ ! -s "$temp_domains" ]; then echo -e "${C_WARN}No domains collected yet. Run a scan first.${C_RESET}" return 1 fi

> "$ip_file" echo -e "\n${C_INFO}Resolving domains using Google's DNS API…${C_RESET}" print_header



resolve_one() { local domain="$1" local response ip response=$(curl -s "https://dns.google/resolve?name=$domain&type=A") ip=$(echo "$response" | grep -oE '"data":"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' | head -1 | cut -d '"' -f4) if [ -n "$ip" ]; then echo "$domain $ip" >> "$ip_file" printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s\n" "$domain" "$ip" "N/A" else printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s\n" "$domain" "Resolution failed" "N/A" fi } export -f resolve_one export COL_DOMAIN COL_IP COL_PING SEPARATOR ip_file sort -u "$temp_domains" | xargs -n1 -P8 bash -c 'resolve_one "$0"' }

────────────────────────[ Ping ]─────────────────────────────────────────────

ping_all() { if [ ! -s "$ip_file" ]; then echo -e "${C_WARN}No IPs to ping. Resolve first.${C_RESET}" return 1 fi echo -e "\n${C_INFO}Pinging IP addresses (2 packets each)…${C_RESET}" print_header

ping_ip() { local domain="$1" ip="$2" ping_result avg_ping ping_display color ping_result=$(ping -c 2 -W 2 -i 0.2 "$ip" 2>&1) if echo "$ping_result" | grep -q 'time='; then avg_ping=$(echo "$ping_result" | awk -F '/' 'END{print $5}' | cut -d '.' -f 1) ping_display="${avg_ping}ms"; color="$C_WARN" else ping_display="Timeout"; color="$C_FAIL" fi printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}${color}%-${COL_PING}s${C_RESET}\n" 
"$domain" "$ip" "$ping_display" } export -f ping_ip export C_WARN C_FAIL C_RESET COL_DOMAIN COL_IP COL_PING SEPARATOR while read -r domain ip; do bash -c "ping_ip '$domain' '$ip'"; done < "$ip_file" echo -e "\nPing tests completed at $(date +'%F %T')" }

────────────────────────[ Menus ]────────────────────────────────────────────

main_menu() { clear echo -e "${C_MENU}==================== MAIN MENU ====================${C_RESET}" echo -e "${C_COUNTRY}1)${C_RESET} Scan from ${C_INFO}vpnjantit.com${C_RESET}" echo -e "${C_COUNTRY}2)${C_RESET} Scan from ${C_INFO}opentunnel.net${C_RESET}" echo -e "${C_FAIL}3) Exit${C_RESET}" echo -e "${C_MENU}====================================================${C_RESET}" read -rp "Choose an option [1-3]: " choice case "$choice" in 1) scan_vpnjantit; post_scan_menu ;; 2) scan_opentunnel; post_scan_menu ;; 3) echo "Goodbye"; exit 0 ;; *) echo -e "${C_FAIL}Invalid choice!${C_RESET}"; pause_enter ;; esac }

post_scan_menu() { while true; do echo -e "\n${C_MENU}-------------------- NEXT STEP ---------------------${C_RESET}" echo -e "${C_COUNTRY}1)${C_RESET} Resolve collected domains to IPs" echo -e "${C_COUNTRY}2)${CRESET:-\033[0m} Ping resolved IPs" echo -e "${C_INFO}M)${C_RESET} Back to Main Menu" echo -e "${C_FAIL}Q)${C_RESET} Quit" echo -e "${C_MENU}----------------------------------------------------${C_RESET}" read -rp "Choose an option [1/2/M/Q]: " step case "${step^^}" in 1) resolve_domains ;; 2) ping_all ;; M) return ;; Q) echo "Goodbye"; exit 0 ;; *) echo -e "${C_FAIL}Invalid option!${C_RESET}" ;; esac done }

────────────────────────[ Bootstrap ]────────────────────────────────────────

install_deps while true; do main_menu; done

