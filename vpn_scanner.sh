#!/bin/bash

# =========================[ Colors & Table Settings ]=========================
COL_DOMAIN=30
COL_IP=20
COL_PING=10
SEPARATOR=" || "
C_RESET="\033[0m"
C_HEADER="\033[1;36m"
C_COUNTRY="\033[1;32m"
C_SUCCESS="\033[1;33m"
C_FAIL="\033[1;31m"

# =========================[ Files ]===========================================
output_file="vpn_domains.txt"
ip_file="vpn_ips.txt"
temp_domains=".temp_domains.txt"

# =========================[ Functions ]=======================================
print_header() {
    printf "${C_HEADER}%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s${C_RESET}\n" "Domain" "IP Address" "Ping (ms)"
    echo "$(printf '=%.0s' $(seq 1 $((COL_DOMAIN + COL_IP + COL_PING + 10))))"
}

scan_vpnjantit() {
    local country="$1"
    domains=$(curl -s --max-time 10 "https://www.vpnjantit.com/free-ssh-$country" \
        | grep -oE '[a-z0-9]+\.vpnjantit\.com' \
        | grep -v 'www\.' \
        | sort -u)
    echo -e "${C_COUNTRY}${country//-/ }:${C_RESET}" >> "$output_file"
    if [ -z "$domains" ]; then
        echo "  No servers" >> "$output_file"
    else
        echo "$domains" | tee -a "$output_file" >> "$temp_domains"
    fi
}

scan_opentunnel() {
    domains=$(curl -s --max-time 15 "https://opentunnel.net/ssh/" \
        | grep -oE '[a-z0-9.-]+\.optnl\.com' \
        | grep -v '^dns\.' \
        | sort -u)
    echo -e "${C_COUNTRY}OpenTunnel:${C_RESET}" >> "$output_file"
    if [ -z "$domains" ]; then
        echo "  No servers" >> "$output_file"
    else
        echo "$domains" | tee -a "$output_file" >> "$temp_domains"
    fi
}

resolve_domain() {
    local domain="$1"
    response=$(curl -s "https://dns.google/resolve?name=$domain&type=A")
    ip=$(echo "$response" | grep -oE '"data":"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' | head -1 | cut -d'"' -f4)
    if [ -n "$ip" ]; then
        echo "$domain $ip" >> "$ip_file"
        printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s\n" "$domain" "$ip" "N/A"
    else
        printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s\n" "$domain" "Resolution failed" "N/A"
    fi
}

ping_ip() {
    local domain="$1"
    local ip="$2"
    ping_result=$(ping -c 2 -W 2 -i 0.2 "$ip" 2>&1)
    if echo "$ping_result" | grep -q 'time='; then
        avg_ping=$(echo "$ping_result" | awk -F '/' 'END{print $5}' | cut -d '.' -f 1)
        ping_display="${avg_ping}ms"
        color="$C_SUCCESS"
    else
        ping_display="Timeout"
        color="$C_FAIL"
    fi
    printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}${color}%-${COL_PING}s${C_RESET}\n" "$domain" "$ip" "$ping_display"
}

# =========================[ Dependency Check ]================================
echo -e "${C_HEADER}Checking and installing dependencies...${C_RESET}"
pkg update -y && pkg upgrade -y
pkg install curl git coreutils busybox grep dos2unix -y

# =========================[ Main Menu Loop ]==================================
while true; do
    # Prepare files
    > "$output_file"
    > "$temp_domains"

    echo -e "\nChoose the website to scan domains from:"
    echo "1) vpnjantit.com"
    echo "2) opentunnel.net"
    echo "b) Back to Main Menu (reload)"
    echo "q) Quit"
    read -p "Enter choice [1-2/b/q]: " site_choice

    if [[ "$site_choice" == "q" ]]; then
        echo "Exiting..."
        exit 0
    elif [[ "$site_choice" == "b" ]]; then
        continue
    elif [[ "$site_choice" -eq 1 ]]; then
        countries=(argentina australia brazil canada france germany india indonesia japan malaysia netherlands singapore sweden turkey united-kingdom united-states united-arab-emirates vietnam ukraine thailand switzerland spain south-korea south-africa slovakia saudi-arabia russia romania qatar portugal poland philippines pakistan oman moldova mexico luxembourg latvia kuwait kazakhstan italy israel iraq ireland hungary hong-kong greece finland estonia egypt denmark czech-republic chile cambodia bulgaria bangladesh bahrain armenia)
        export -f scan_vpnjantit
        export output_file temp_domains C_COUNTRY C_RESET
        printf "%s\n" "${countries[@]}" | xargs -n1 -P4 bash -c 'scan_vpnjantit "$0"'
    elif [[ "$site_choice" -eq 2 ]]; then
        scan_opentunnel
    else
        echo "Invalid choice!"
        continue
    fi

    echo -e "\nScan completed at $(date +'%F %T')"

    # ===== Resolve Domains =====
    while true; do
        read -p "Do you want to resolve domains to IP addresses? (y/n/b/q): " ans
        case "$ans" in
            y|Y)
                echo -e "\nResolving domains..."
                > "$ip_file"
                print_header
                export -f resolve_domain
                export COL_DOMAIN COL_IP COL_PING SEPARATOR ip_file
                sort -u "$temp_domains" | xargs -n1 -P8 bash -c 'resolve_domain "$0"'
                ;;
            n|N)
                echo "Skipping DNS resolution."
                break
                ;;
            b|B)
                continue 2
                ;;
            q|Q)
                echo "Exiting..."
                exit 0
                ;;
            *) echo "Invalid choice!";;
        esac
        break
    done

    # ===== Ping Test =====
    while true; do
        if [ -s "$ip_file" ]; then
            read -p "Do you want to ping all resolved IPs? (y/n/b/q): " ans
            case "$ans" in
                y|Y)
                    echo -e "\nPinging IP addresses (2 packets each)..."
                    print_header
                    export -f ping_ip
                    export C_SUCCESS C_FAIL C_RESET COL_DOMAIN COL_IP COL_PING SEPARATOR
                    while read -r domain ip; do
                        bash -c "ping_ip '$domain' '$ip'"
                    done < "$ip_file"
                    echo -e "\nPing tests completed at $(date +'%F %T')"
                    ;;
                n|N)
                    echo "Skipping ping test."
                    break
                    ;;
                b|B)
                    continue 2
                    ;;
                q|Q)
                    echo "Exiting..."
                    exit 0
                    ;;
                *) echo "Invalid choice!";;
            esac
        else
            echo "No resolvable domains available for ping testing"
        fi
        break
    done
done
