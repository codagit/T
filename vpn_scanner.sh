#!/bin/bash

Colors

C_RESET="\033[0m"; C_HEADER="\033[1;36m"; C_COUNTRY="\033[1;32m"; C_SUCCESS="\033[1;33m"; C_FAIL="\033[1;31m"

COL_DOMAIN=30; COL_IP=20; COL_PING=10; SEPARATOR=" || "

Files

output_file="collected_domains.txt" ip_file="resolved_ips.txt" temp_domains=".temp_domains.txt"

Functions

print_header(){ printf "${C_HEADER}%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s${C_RESET}\n" "Domain" "IP Address" "Ping (ms)" echo "$(printf '=%.0s' $(seq 1 $((COL_DOMAIN + COL_IP + COL_PING + 10))))" }

install_dependencies(){ echo -e "${C_HEADER}Installing dependencies...${C_RESET}" pkg update -y && pkg upgrade -y pkg install curl git coreutils busybox grep dos2unix -y }

scan_vpnjantit(){ countries=(argentina australia brazil canada france germany india indonesia japan malaysia netherlands singapore sweden turkey united-kingdom united-states united-arab-emirates vietnam ukraine thailand switzerland spain south-korea south-africa slovakia saudi-arabia russia romania qatar portugal poland philippines pakistan oman moldova mexico luxembourg latvia kuwait kazakhstan italy israel iraq ireland hungary hong-kong greece finland estonia egypt denmark czech-republic chile cambodia bulgaria bangladesh bahrain armenia) > "$output_file"; > "$temp_domains" echo -e "${C_HEADER}Starting VPNJantit scan...${C_RESET}" for country in "${countries[@]}"; do domains=$(curl -s --max-time 10 "https://www.vpnjantit.com/free-ssh-$country" | grep -oE '[a-z0-9]+.vpnjantit.com' | grep -v 'www.' | sort -u) echo -e "${C_COUNTRY}${country//-/ }:${C_RESET}" >> "$output_file" if [ -z "$domains" ]; then echo "  No servers" >> "$output_file" else echo "$domains" | tee -a "$output_file" >> "$temp_domains" fi done echo -e "${C_SUCCESS}VPNJantit scan completed.${C_RESET}" }

scan_opentunnel(){ > "$output_file"; > "$temp_domains" echo -e "${C_HEADER}Starting OpenTunnel scan...${C_RESET}" domains=$(curl -s --max-time 15 "https://opentunnel.net/ssh/#gsc.tab=0" | grep -oE '[a-z0-9.-]+.optnl.com' | grep -v '^dns.' | sort -u) if [ -z "$domains" ]; then echo "  No servers found" >> "$output_file" else echo "$domains" | tee -a "$output_file" >> "$temp_domains" fi echo -e "${C_SUCCESS}OpenTunnel scan completed.${C_RESET}" }

resolve_domains(){ > "$ip_file" print_header while read -r domain; do ip=$(curl -s "https://dns.google/resolve?name=$domain&type=A" | grep -oE '"data":"[0-9]+.[0-9]+.[0-9]+.[0-9]+"' | head -1 | cut -d '"' -f4) if [ -n "$ip" ]; then echo "$domain $ip" >> "$ip_file" printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s\n" "$domain" "$ip" "N/A" else printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s\n" "$domain" "Resolution failed" "N/A" fi done < <(sort -u "$temp_domains") }

ping_ips(){ print_header while read -r domain ip; do ping_result=$(ping -c 2 -W 2 -i 0.2 "$ip" 2>&1) if echo "$ping_result" | grep -q 'time='; then avg_ping=$(echo "$ping_result" | awk -F '/' 'END{print $5}' | cut -d '.' -f 1) ping_display="${avg_ping}ms"; color="$C_SUCCESS" else ping_display="Timeout"; color="$C_FAIL" fi printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}${color}%-${COL_PING}s${C_RESET}\n" "$domain" "$ip" "$ping_display" done < "$ip_file" }

main_menu(){ while true; do echo -e "${C_HEADER}\n==== Domain Scanner Menu ====${C_RESET}" echo "1) Scan VPNJantit" echo "2) Scan OpenTunnel" echo "Q) Quit" read -p "Choose an option: " choice case "$choice" in 1) scan_vpnjantit; next_menu;; 2) scan_opentunnel; next_menu;; [Qq]) echo "Goodbye!"; exit 0;; *) echo "Invalid choice";; esac done }

next_menu(){ while true; do echo -e "${C_HEADER}\n==== Next Step ====${C_RESET}" echo "1) Resolve Domains to IPs" echo "2) Ping IPs" echo "M) Back to Main Menu" echo "Q) Quit" read -p "Choose an option: " step case "$step" in 1) resolve_domains;; 2) ping_ips;; [Mm]) return;; [Qq]) echo "Goodbye!"; exit 0;; *) echo "Invalid choice";; esac done }

Run

install_dependencies main_menu

