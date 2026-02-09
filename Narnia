#!/bin/bash

# ==============================================================================
#   Author: Stormotron / Modified by Dnt3e
# ==============================================================================

# --- Safety Check: Ensure Root Access ---
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root."
   exit 1
fi

# --- Global Configuration ---
IFACE="nvpn"
IMG="stormotron/narnia:latest"
CONF_FILE="/etc/narnia.conf"
SERVICE_FILE="/etc/systemd/system/narnia.service"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="narnia"
LOG_FILE="/tmp/narnia_install.log"

# --- Colors & Styling ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Helper: Progress Bar ---
show_progress() {
    local duration=${1}
    local prefix=${2}
    local block="█"
    local empty="░"
    local width=30

    echo -ne "${prefix} "
    for (( i=0; i<=$width; i++ )); do
        local percent=$(( i * 100 / width ))
        local num_block=$i
        local num_empty=$(( width - i ))
        local bar_str=""
        for (( j=0; j<num_block; j++ )); do bar_str="${bar_str}${block}"; done
        for (( j=0; j<num_empty; j++ )); do bar_str="${bar_str}${empty}"; done
        echo -ne "[${BLUE}${bar_str}${NC}] ${percent}%\r"
        sleep $duration
    done
    echo -ne "\n"
}

# --- Helper: Dynamic Header ---
draw_header() {
    clear
    local kernel_fwd=$(sysctl net.ipv4.ip_forward 2>/dev/null | awk '{print $3}')
    local docker_stat=$(systemctl is-active docker 2>/dev/null || echo "inactive")
    local tunnel_stat="OFFLINE"
    local tunnel_color="${RED}"

    if [ "$(docker ps -q -f name=narnia_tunnel)" ]; then
        tunnel_stat="RUNNING"
        tunnel_color="${GREEN}"
    fi

    echo -e "${CYAN}======================================================${NC}"
    echo -e "${BOLD}         N A R N I A   T U N N E L   M A N A G E R    ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    
    if [ "$kernel_fwd" == "1" ]; then
        echo -e " Kernel FWD: ${GREEN}ENABLED${NC}  |  Docker: ${GREEN}${docker_stat^^}${NC}"
    else
        echo -e " Kernel FWD: ${RED}DISABLED${NC} |  Docker: ${YELLOW}${docker_stat^^}${NC}"
    fi

    echo -e " Tunnel Status: ${tunnel_color}${BOLD}${tunnel_stat}${NC}"
    
    if [ "$tunnel_stat" == "RUNNING" ]; then
        local ip_addr=$(ip -4 addr show $IFACE 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        echo -e " Interface IP:  ${YELLOW}${ip_addr:-Unknown}${NC}"
    fi
    echo -e "${CYAN}======================================================${NC}"
    echo ""
}

# --- Core: Dependency Installation ---
install_deps() {
    echo -e "${YELLOW}>>> Starting Dependency Check & Installation...${NC}"
    
    show_progress 0.05 "Checking Tools  "
    if ! command -v ip &> /dev/null || ! command -v iptables &> /dev/null || ! command -v curl &> /dev/null; then
        echo -e "Installing network tools..." >> $LOG_FILE
        if [ -f /etc/debian_version ]; then
            apt-get update -q && apt-get install -y -q iproute2 iptables curl >> $LOG_FILE 2>&1
        elif [ -f /etc/redhat-release ]; then
            yum install -y -q iproute iptables curl >> $LOG_FILE 2>&1
        fi
    fi

    show_progress 0.05 "Checking Docker "
    if ! command -v docker &> /dev/null; then
        echo -e "Installing Docker..." >> $LOG_FILE
        curl -fsSL https://get.docker.com | sh >> $LOG_FILE 2>&1
        systemctl enable --now docker >> $LOG_FILE 2>&1
    fi
    
    # --- Self-Installation Logic ---
    if [[ "$(realpath $0)" != "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        echo -e "Installing script to system..." >> $LOG_FILE
        cp "$(realpath $0)" "$INSTALL_DIR/$SCRIPT_NAME"
        chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    fi

    echo -e "${GREEN}>>> Dependencies Ready.${NC}"
    sleep 1
}

# --- Core: Create Service ---
create_service() {
    cat <<EOF > $SERVICE_FILE
[Unit]
Description=Narnia ICMP Tunnel Service
After=docker.service network.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$INSTALL_DIR/$SCRIPT_NAME start
ExecStop=$INSTALL_DIR/$SCRIPT_NAME stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable narnia.service >> $LOG_FILE 2>&1
}

# --- Core: Firewall Logic (Safe Mode) ---
apply_firewall() {
    source $CONF_FILE 2>/dev/null
    
    sysctl -w net.ipv4.ip_forward=1 >> $LOG_FILE 2>&1

    iptables -t nat -C POSTROUTING -o $DEFAULT_IF -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o $DEFAULT_IF -j MASQUERADE
    
    iptables -t nat -C POSTROUTING -o $IFACE -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE

    if [ "$TYPE" == "1" ] && [ -n "$PORT_LIST" ]; then
        IFS=',' read -ra ADDR <<< "$PORT_LIST"
        for port in "${ADDR[@]}"; do
            port=$(echo $port | xargs)
            iptables -t nat -D PREROUTING -p tcp --dport $port -j DNAT --to-destination $R_INT:$port 2>/dev/null
            iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination $R_INT:$port 2>/dev/null
            
            iptables -t nat -A PREROUTING -p tcp --dport $port -j DNAT --to-destination $R_INT:$port
            iptables -t nat -A PREROUTING -p udp --dport $port -j DNAT --to-destination $R_INT:$port
        done
    fi
}

# --- Logic: Execution ---
start_logic() {
    if [ ! -f $CONF_FILE ]; then
        echo -e "${RED}[ERROR] Config missing.${NC}"; exit 1
    fi
    source $CONF_FILE

    # Ensure we have the latest version of the core
    echo -e "Checking for updates..." >> $LOG_FILE
    docker pull $IMG >> $LOG_FILE 2>&1

    if [ "$(docker ps -aq -f name=narnia_tunnel)" ]; then
        docker rm -f narnia_tunnel >> $LOG_FILE 2>&1
    fi

    docker run --cap-add=NET_ADMIN --device /dev/net/tun:/dev/net/tun --net=host \
               -e INTERFACE=$IFACE -e REMOTE_IP=$R_IP -e PASSWORD=$PSWD \
               --restart unless-stopped --name narnia_tunnel -d $IMG >> $LOG_FILE 2>&1
    
    sleep 3
    
    ip addr add $L_IP/24 dev $IFACE 2>/dev/null
    ip link set $IFACE mtu 1400
    ip link set $IFACE up

    apply_firewall
}

# --- Feature: Check Status & Ping ---
check_status() {
    draw_header
    echo -e "${BOLD}--- 1. Docker Container Info ---${NC}"
    docker ps -f name=narnia_tunnel --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

    echo -e "\n${BOLD}--- 2. Network Interface ($IFACE) ---${NC}"
    ip addr show $IFACE 2>/dev/null | grep inet || echo -e "${RED}Interface not created.${NC}"

    echo -e "\n${BOLD}--- 3. Connection Test (Ping) ---${NC}"
    if [ -f $CONF_FILE ]; then
        source $CONF_FILE
        echo -e "Pinging Peer IP: ${YELLOW}$R_INT${NC} ..."
        ping -c 3 -W 2 $R_INT
        if [ $? -eq 0 ]; then
             echo -e "\n${GREEN}[SUCCESS] Tunnel Connection is Alive!${NC}"
        else
             echo -e "\n${RED}[FAIL] Could not reach peer. Check firewall or remote server.${NC}"
        fi
    else
        echo -e "${RED}Config file missing.${NC}"
    fi
    
    echo -e "\n------------------------------------------------------"
    read -p "Press Enter to return to menu..."
}

# --- Logic: Setup & Start ---
run_setup() {
    install_deps
    
    DEFAULT_IF=$(ip -4 route show default | awk '{print $5}' | head -n1)
    
    echo -e "${BOLD}Detected Main Interface: ${GREEN}$DEFAULT_IF${NC}"
    echo "------------------------------------------"
    echo "1) IRAN Server (Bridge / Port Forwarder)"
    echo "2) FOREIGN Server (Exit Node / Gateway)"
    echo "------------------------------------------"
    read -p "Select Role [1/2]: " TYPE
    
    read -p "Remote Server IP: " R_IP
    read -p "Tunnel Password: " PSWD
    
    if [ "$TYPE" == "1" ]; then
        L_IP="10.200.200.1"; R_INT="10.200.200.2"
        echo ""
        echo "Enter ports to forward (Comma separated)."
        read -p "Ports (e.g. 443,2053,8080): " PORT_LIST
    else
        L_IP="10.200.200.2"; R_INT="10.200.200.1"
        PORT_LIST=""
    fi

    cat <<EOF > $CONF_FILE
TYPE=$TYPE
R_IP=$R_IP
PSWD=$PSWD
L_IP=$L_IP
R_INT=$R_INT
PORT_LIST=$PORT_LIST
DEFAULT_IF=$DEFAULT_IF
EOF

    create_service
    show_progress 0.05 "Configuring Core"
    start_logic
    
    echo -e "\n${GREEN}[SUCCESS] Narnia Tunnel Installed & Running!${NC}"
    echo -e "${CYAN}Info: You can now run 'narnia' directly from terminal.${NC}"
    echo -e "------------------------------------------------------"
    
    read -p "Do you want to check connection status and ping now? (y/n): " do_check
    if [[ "$do_check" == "y" || "$do_check" == "Y" ]]; then
        check_status
    fi
}

# --- Logic: Uninstall ---
clean_all() {
    echo -e "${RED}>>> WARNING: This will remove the tunnel and specific forwarding rules.${NC}"
    read -p "Are you sure? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi

    echo -e "${YELLOW}Stopping Services...${NC}"
    systemctl stop narnia.service 2>/dev/null
    systemctl disable narnia.service 2>/dev/null
    
    echo -e "${YELLOW}Removing Docker Container...${NC}"
    docker stop narnia_tunnel 2>/dev/null
    docker rm narnia_tunnel 2>/dev/null
    
    if [ -f $CONF_FILE ]; then
        source $CONF_FILE
        echo -e "${YELLOW}Cleaning Firewall Rules...${NC}"
        iptables -t nat -D POSTROUTING -o $IFACE -j MASQUERADE 2>/dev/null
        if [ -n "$PORT_LIST" ]; then
            IFS=',' read -ra ADDR <<< "$PORT_LIST"
            for port in "${ADDR[@]}"; do
                port=$(echo $port | xargs)
                iptables -t nat -D PREROUTING -p tcp --dport $port -j DNAT --to-destination $R_INT:$port 2>/dev/null
                iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination $R_INT:$port 2>/dev/null
            done
        fi
    fi

    ip link delete $IFACE 2>/dev/null
    rm -f $CONF_FILE $SERVICE_FILE "$INSTALL_DIR/$SCRIPT_NAME"
    
    echo -e "${GREEN}[SUCCESS] Narnia Tunnel Removed Successfully.${NC}"
    read -p "Press Enter..."
}

# --- Menu: Service Manager ---
service_menu() {
    while true; do
        draw_header
        echo -e "${BOLD}--- Service Management ---${NC}"
        echo "1) View Docker Logs (Live)"
        echo "2) Restart Service"
        echo "3) Stop Service"
        echo "4) Start Service"
        echo "5) Back to Main Menu"
        echo "--------------------------"
        read -p "Select: " s_opt
        
        case $s_opt in
            1) 
                echo -e "${CYAN}Press Ctrl+C to exit logs.${NC}"
                sleep 2
                docker logs -f narnia_tunnel
                ;;
            2) 
                systemctl restart narnia.service
                echo -e "${GREEN}Service Restarted.${NC}"
                sleep 2
                ;;
            3)
                systemctl stop narnia.service
                echo -e "${RED}Service Stopped.${NC}"
                sleep 2
                ;;
            4)
                systemctl start narnia.service
                echo -e "${GREEN}Service Started.${NC}"
                sleep 2
                ;;
            5) break ;;
            *) ;;
        esac
    done
}

# --- Main Entry Point ---
case "$1" in
    start) start_logic ;;
    stop)  docker stop narnia_tunnel ;;
    *)
        while true; do
            draw_header
            echo "1) Install & Configure"
            echo "2) Service Manager (Logs/Restart)"
            echo "3) Show Status / Ping Test"
            echo "4) Uninstall & Remove"
            echo "5) Exit"
            echo "------------------------------------------------------"
            read -p "Select option: " opt
            case $opt in
                1) run_setup ;;
                2) service_menu ;;
                3) check_status ;;
                4) clean_all ;;
                5) exit 0 ;;
                *) echo "Invalid Option"; sleep 1 ;;
            esac
        done
        ;;
esac
