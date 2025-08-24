#!/bin/bash

# ────────────────────────[ Colors and Table Settings ]────────────────────────
COL_DOMAIN=30
COL_IP=20
COL_PING=10
SEPARATOR=" || "
C_RESET="\033[0m"
C_HEADER="\033[1;36m"
C_COUNTRY="\033[1;32m"
C_SUCCESS="\033[1;33m"
C_FAIL="\033[1;31m"

# ────────────────────────[ Files ]────────────────────────────────────────────
output_file="vpn_domains.txt"
ip_file="vpn_ips.txt"
temp_domains="temp_domains.txt"

# ────────────────────────[ Functions ]────────────────────────────────────────
print_header() {
    printf "${C_HEADER}%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s${C_RESET}\n" "Domain" "IP Address" "Ping (ms)"
    echo "$(printf '=%.0s' $(seq 1 $((COL_DOMAIN + COL_IP + COL_PING + 10))))"
}

# ────────────────────────[ Dependency Check and Update ]──────────────────────
check_and_update_dependencies() {
    echo -e "${C_HEADER}Checking dependencies...${C_RESET}"
    local packages=("curl" "git" "coreutils" "busybox" "grep" "dos2unix" "tor")
    local missing_packages=()

    # Check if each package is installed
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    # Install missing packages
    if [ ${#missing_packages[@]} -gt 0 ]; then
        echo -e "${C_FAIL}Missing packages: ${missing_packages[*]}${C_RESET}"
        echo -e "${C_HEADER}Installing missing packages...${C_RESET}"
        pkg install "${missing_packages[@]}" -y || {
            echo -e "${C_FAIL}Failed to install packages. Please check your internet connection or Termux repository.${C_RESET}"
            return 1
        }
    else
        echo -e "${C_SUCCESS}All required packages are already installed.${C_RESET}"
    fi

    # Update package list and upgrade installed packages
    echo -e "${C_HEADER}Updating package list and upgrading packages...${C_RESET}"
    pkg update -y && pkg upgrade -y || {
        echo -e "${C_FAIL}Failed to update packages. Please check your internet connection or Termux repository.${C_RESET}"
        return 1
    }
    echo -e "${C_SUCCESS}Package check and update completed.${C_RESET}"
}

# ────────────────────────[ Start Tor if not running ]─────────────────────────
start_tor() {
    if ! pgrep -x "tor" > /dev/null; then
        echo -e "${C_HEADER}Starting Tor service...${C_RESET}"
        tor &  # Run Tor in background
        sleep 10  # Wait for Tor to initialize
        if pgrep -x "tor" > /dev/null; then
            echo -e "${C_SUCCESS}Tor is running.${C_RESET}"
        else
            echo -e "${C_FAIL}Failed to start Tor. Please ensure Tor is installed and try again.${C_RESET}"
            exit 1
        fi
    else
        echo -e "${C_SUCCESS}Tor is already running.${C_RESET}"
    fi
}

# ────────────────────────[ Country List for vpnjantit ]───────────────────────
countries=(argentina australia brazil canada france germany india indonesia japan malaysia netherlands singapore sweden turkey united-kingdom united-states united-arab-emirates vietnam ukraine thailand switzerland spain south-korea south-africa slovakia saudi-arabia russia romania qatar portugal poland philippines pakistan oman moldova mexico luxembourg latvia kuwait kazakhstan italy israel iraq ireland hungary hong-kong greece finland estonia egypt denmark czech-republic chile cambodia bulgaria bangladesh bahrain armenia)

# ────────────────────────[ Stop on CTRL+C ]────────────────────────────────────
stop_scan=false
trap 'echo -e "\n${C_FAIL}Scan interrupted by user!${C_RESET}"; stop_scan=true' SIGINT

# ────────────────────────[ Scan Functions ]───────────────────────────────────
scan_vpnjantit() {
    local country="$1"
    echo -e "${C_HEADER}Scanning VPNJantit for $country...${C_RESET}"
    domains=$(curl -s --max-time 10 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" --socks5-hostname 127.0.0.1:9050 "https://www.vpnjantit.com/free-ssh-$country" \
        | grep -oE '[a-z0-9]+\.vpnjantit\.com' \
        | grep -v 'www\.' \
        | sort -u)

    echo -e "${C_COUNTRY}${country//-/ }:${C_RESET}" >> "$output_file"
    if [ -z "$domains" ]; then
        echo "  No servers found for $country" >> "$output_file"
        echo -e "${C_FAIL}No domains collected for $country${C_RESET}"
    else
        echo -e "${C_SUCCESS}Domains found for $country:${C_RESET} $domains"
        echo "$domains" >> "$temp_domains"
        echo "$domains" >> "$output_file"
    fi
    $stop_scan && exit 0
}

scan_opentunnel() {
    echo -e "${C_HEADER}Scanning OpenTunnel...${C_RESET}"
    domains=$(curl -s --max-time 15 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" --socks5-hostname 127.0.0.1:9050 "https://opentunnel.net/ssh/" \
        | grep -oE '[a-z0-9.-]+\.optnl\.com' \
        | grep -v '^dns\.' \
        | sort -u)

    echo -e "${C_COUNTRY}OpenTunnel:${C_RESET}" >> "$output_file"
    if [ -z "$domains" ]; then
        echo "  No servers found for OpenTunnel" >> "$output_file"
        echo -e "${C_FAIL}No domains collected for OpenTunnel${C_RESET}"
    else
        echo -e "${C_SUCCESS}Domains found for OpenTunnel:${C_RESET} $domains"
        echo "$domains" >> "$temp_domains"
        echo "$domains" >> "$output_file"
    fi
    $stop_scan && exit 0
}

# ────────────────────────[ Main Menu Loop ]────────────────────────────────────
while true; do
    echo -e "\nChoose an option:"
    echo "1) Check and update dependencies"
    echo "2) Scan vpnjantit.com"
    echo "3) Scan opentunnel.net"
    echo "4) Return to Main Menu"
    echo "5) Exit"
    read -p "Enter choice [1-5]: " site_choice

    # Initialize files only if starting a new scan
    if [[ "$site_choice" == "2" || "$site_choice" == "3" ]]; then
        > "$output_file"
        > "$temp_domains"
    fi

    case $site_choice in
        1)
            check_and_update_dependencies
            ;;
        2)
            start_tor
            echo "Starting VPNJantit scan..."
            export -f scan_vpnjantit
            export output_file temp_domains C_COUNTRY C_RESET C_HEADER C_SUCCESS C_FAIL stop_scan
            printf "%s\n" "${countries[@]}" | xargs -n1 -P4 bash -c 'scan_vpnjantit "$0"'
            ;;
        3)
            start_tor
            echo "Starting OpenTunnel scan..."
            scan_opentunnel
            ;;
        4)
            echo "Returning to main menu..."
            continue
            ;;
        5)
            echo "Exiting script."
            rm -f "$temp_domains"
            exit 0
            ;;
        *)
            echo "Invalid choice!"
            continue
            ;;
    esac

    if $stop_scan; then
        echo "Proceeding with collected domains so far..."
    fi

    # Skip domain check if only checking dependencies
    if [[ "$site_choice" != "1" ]]; then
        echo -e "\nScan completed at $(date +'%F %T')"
        # ────────────────────────[ Check temp_domains file ]──────────────────────
        if [ ! -f "$temp_domains" ] || [ ! -s "$temp_domains" ]; then
            echo -e "${C_FAIL}⚠️  No domains collected. Please scan again from main menu.${C_RESET}"
            echo -e "${C_HEADER}Debug: temp_domains file content:${C_RESET}"
            cat "$temp_domains" 2>/dev/null || echo "File does not exist or is empty"
            continue
        else
            echo -e "${C_SUCCESS}Domains collected successfully. Total domains: $(wc -l < "$temp_domains")${C_RESET}"
            echo -e "${C_HEADER}Debug: temp_domains file content:${C_RESET}"
            cat "$temp_domains"
        fi
    fi

    read -p "Do you want to resolve domains to IP addresses? (y=Yes / 4=Menu / 5=Exit): " -n 1 -r
    echo
    [[ $REPLY == "4" ]] && continue
    [[ $REPLY == "5" ]] && rm -f "$temp_domains" && exit 0
    [[ ! $REPLY =~ ^[Yy]$ ]] && echo "Skipping DNS resolution" && continue

    start_tor  # Ensure Tor is running for DNS resolution

    echo -e "\nResolving domains using Google's DNS API..."
    > "$ip_file"
    print_header

    resolve_domain() {
        local domain="$1"
        response=$(curl -s --socks5-hostname 127.0.0.1:9050 "https://dns.google/resolve?name=$domain&type=A")
        ip=$(echo "$response" | grep -oE '"data":"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' | head -1 | cut -d'"' -f4)
        if [ -n "$ip" ]; then
            echo "$domain $ip" >> "$ip_file"
            printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s\n" "$domain" "$ip" "N/A"
        else
            printf "%-${COL_DOMAIN}s${SEPARATOR}%-${COL_IP}s${SEPARATOR}%-${COL_PING}s\n" "$domain" "Resolution failed" "N/A"
        fi
    }

    export -f resolve_domain
    export COL_DOMAIN COL_IP COL_PING SEPARATOR ip_file
    sort -u "$temp_domains" | xargs -n1 -P8 bash -c 'resolve_domain "$0"'

    # ────────────────────────[ Ping Test ]────────────────────────────────────
    while true; do
        if [ -s "$ip_file" ]; then
            read -p "Do you want to ping all resolved IPs? (y=Yes / 4=Menu / 5=Exit): " -n 1 -r
            echo
            [[ $REPLY == "4" ]] && continue 2
            [[ $REPLY == "5" ]] && rm -f "$temp_domains" && exit 0
            [[ ! $REPLY =~ ^[Yy]$ ]] && break
            echo -e "\nPinging IP addresses (2 packets each)..."
            print_header

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

            export -f ping_ip
            export C_SUCCESS C_FAIL C_RESET COL_DOMAIN COL_IP COL_PING SEPARATOR
            while read -r domain ip; do
                bash -c "ping_ip '$domain' '$ip'"
            done < "$ip_file"
            echo -e "\nPing tests completed at $(date +'%F %T')"
        else
            echo "No resolvable domains available for ping testing"
            break
        fi
    done
done

# ────────────────────────[ Cleanup ]──────────────────────────────────────────
rm -f "$temp_domains"
