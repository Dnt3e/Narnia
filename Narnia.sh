#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

IFACE="nvpn"
IMG="stormotron/narnia:0.0.3"
CONF_FILE="/etc/narnia.conf"
SERVICE_FILE="/etc/systemd/system/narnia.service"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="narnia"
LOG_FILE="/tmp/narnia_install.log"

R="\e[38;5;204m"; G="\e[32m"; Y="\e[33m"; C="\e[36m"; W="\e[97m"
DIM="\e[2m"; BOLD="\e[1m"; NC="\e[0m"
LINE="${DIM}────────────────────────────────────────────────────────${NC}"

banner() {
    clear
    echo -e "${R}"
    echo "   ███╗   ██╗ █████╗ ██████╗ ███╗   ██╗██╗ █████╗ "
    echo "   ████╗  ██║██╔══██╗██╔══██╗████╗  ██║██║██╔══██╗"
    echo "   ██╔██╗ ██║███████║██████╔╝██╔██╗ ██║██║███████║"
    echo "   ██║╚██╗██║██╔══██║██╔══██╗██║╚██╗██║██║██╔══██║"
    echo "   ██║ ╚████║██║  ██║██║  ██║██║ ╚████║██║██║  ██║"
    echo "   ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}${W}Narnia${NC}  ${DIM}v2  · Fast & Lightweight · by Dnt3e${NC}"
    echo -e "${LINE}"
    _show_status
    echo -e "${LINE}"
}

_show_status() {
    local kernel_fwd docker_stat tunnel_stat fwd_str docker_str is_running
    kernel_fwd=$(sysctl net.ipv4.ip_forward 2>/dev/null | awk '{print $3}')
    docker_stat=$(systemctl is-active docker 2>/dev/null || echo "inactive")
    if docker ps -q -f name=narnia_tunnel 2>/dev/null | grep -q .; then
        is_running=1; tunnel_stat="${G}${BOLD}RUNNING${NC}"
    else
        is_running=0; tunnel_stat="${R}${BOLD}OFFLINE${NC}"
    fi
    [ "$kernel_fwd" == "1" ] && fwd_str="${G}enabled${NC}" || fwd_str="${R}disabled${NC}"
    [ "$docker_stat" == "active" ] && docker_str="${G}${docker_stat^^}${NC}" || docker_str="${Y}${docker_stat^^}${NC}"
    echo -e "  ${W}Tunnel :${NC} ${tunnel_stat}"
    echo -e "  ${W}Docker :${NC} ${docker_str}   ${W}IP Forward :${NC} ${fwd_str}"
    if [ "$is_running" == "1" ]; then
        local ip_addr
        ip_addr=$(ip -4 addr show "$IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        echo -e "  ${W}Iface  :${NC} ${C}${IFACE}${NC}  ${W}IP :${NC} ${Y}${ip_addr:-unknown}${NC}"
    fi
    if [ -f "$CONF_FILE" ]; then
        source "$CONF_FILE" 2>/dev/null
        local role_str
        if [ "$TYPE" == "1" ]; then
            role_str="${Y}IRAN${NC}  ${DIM}(client → remote ${R_IP:-N/A})${NC}"
        else
            role_str="${C}FOREIGN${NC}  ${DIM}(server, listen ${SERVER_LISTEN:-0.0.0.0})${NC}"
        fi
        echo -e "  ${W}Role   :${NC} ${role_str}"
        [ -n "$TUNNEL_MTU" ] && echo -e "  ${W}MTU    :${NC} ${DIM}${TUNNEL_MTU}${NC}"
    fi
}

show_progress() {
    local duration=${1} prefix=${2}
    local block="█" empty="░" width=30
    local bar_str percent
    for (( i=0; i<=width; i++ )); do
        bar_str=""; percent=$(( i * 100 / width ))
        for (( j=0; j<i; j++ ));     do bar_str="${bar_str}${block}"; done
        for (( j=i; j<width; j++ )); do bar_str="${bar_str}${empty}"; done
        printf "\r  %s [${C}%s${NC}] %3d%%" "$prefix" "$bar_str" "$percent"
        sleep "$duration"
    done
    printf "\r  %s [${C}%s${NC}] %3d%%\n" "$prefix" "$bar_str" "$percent"
}

install_deps() {
    echo -e "${Y}  >>> Dependency Check & Installation...${NC}"
    echo -e "${LINE}"
    show_progress 0.04 "Checking Tools  "
    if ! command -v ip &>/dev/null || ! command -v iptables &>/dev/null || \
       ! command -v curl &>/dev/null; then
        echo "Installing network tools..." >> "$LOG_FILE"
        if [ -f /etc/debian_version ]; then
            apt-get update -q && apt-get install -y -q iproute2 iptables curl >> "$LOG_FILE" 2>&1
        elif [ -f /etc/redhat-release ]; then
            yum install -y -q iproute iptables curl >> "$LOG_FILE" 2>&1
        fi
    fi
    show_progress 0.04 "Checking Docker "
    if ! command -v docker &>/dev/null; then
        echo "Installing Docker..." >> "$LOG_FILE"
        curl -fsSL https://get.docker.com | sh >> "$LOG_FILE" 2>&1
        systemctl enable --now docker >> "$LOG_FILE" 2>&1
    fi
    if [[ "$(realpath "$0")" != "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
        echo "Installing script to system..." >> "$LOG_FILE"
        cp "$(realpath "$0")" "$INSTALL_DIR/$SCRIPT_NAME"
        chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    fi
    echo -e "  ${G}[OK] Dependencies ready.${NC}"
    sleep 1
}

create_service() {
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Narnia ICMP Tunnel Service (ChaCha20)
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$INSTALL_DIR/$SCRIPT_NAME start
ExecStop=$INSTALL_DIR/$SCRIPT_NAME stop
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable narnia.service >> "$LOG_FILE" 2>&1
}

apply_firewall() {
    source "$CONF_FILE" 2>/dev/null
    sysctl -w net.ipv4.ip_forward=1 >> "$LOG_FILE" 2>&1
    grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf 2>/dev/null \
        && sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf \
        || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    iptables -t nat -C POSTROUTING -o "$DEFAULT_IF" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o "$DEFAULT_IF" -j MASQUERADE
    if [ "$TYPE" == "1" ]; then
        iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null || \
        iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
        iptables -C FORWARD -i "$DEFAULT_IF" -o "$IFACE" -j ACCEPT 2>/dev/null || \
        iptables -I FORWARD -i "$DEFAULT_IF" -o "$IFACE" -j ACCEPT
        iptables -C FORWARD -i "$IFACE" -o "$DEFAULT_IF" -j ACCEPT 2>/dev/null || \
        iptables -I FORWARD -i "$IFACE" -o "$DEFAULT_IF" -j ACCEPT
    fi
    if [ "$TYPE" == "1" ] && [ -n "$PORT_LIST" ]; then
        IFS=',' read -ra ADDR <<< "$PORT_LIST"
        for port in "${ADDR[@]}"; do
            port=$(echo "$port" | xargs)
            iptables -t nat -D PREROUTING -p tcp --dport "$port" \
                -j DNAT --to-destination "$R_INT:$port" 2>/dev/null
            iptables -t nat -D PREROUTING -p udp --dport "$port" \
                -j DNAT --to-destination "$R_INT:$port" 2>/dev/null
            iptables -t nat -A PREROUTING -p tcp --dport "$port" \
                -j DNAT --to-destination "$R_INT:$port"
            iptables -t nat -A PREROUTING -p udp --dport "$port" \
                -j DNAT --to-destination "$R_INT:$port"
        done
    fi
}

_write_conf() {
    local pswd_safe="${PSWD//\'/\'\\\'\'}"
    {
        printf '# Narnia Tunnel Config\n'
        printf 'TYPE=%s\n'            "$TYPE"
        printf 'IFACE=%s\n'           "${IFACE:-nvpn}"
        printf 'R_IP=%s\n'            "$R_IP"
        printf "PSWD='%s'\n"          "$pswd_safe"
        printf 'L_IP=%s\n'            "$L_IP"
        printf 'R_INT=%s\n'           "$R_INT"
        printf 'PORT_LIST=%s\n'       "$PORT_LIST"
        printf 'DEFAULT_IF=%s\n'      "$DEFAULT_IF"
        printf 'SERVER_LISTEN=%s\n'   "${SERVER_LISTEN:-0.0.0.0}"
        printf 'MAC_ADDR=%s\n'        "$MAC_ADDR"
        printf 'KEEPALIVE=%s\n'       "$KEEPALIVE"
        printf 'LINK_QUALITY=%s\n'    "$LINK_QUALITY"
        printf 'BAN_QUALITY=%s\n'     "$BAN_QUALITY"
        printf 'OPERATING_MODE=%s\n'  "$OPERATING_MODE"
        printf 'BANDWIDTH_LIMIT=%s\n' "$BANDWIDTH_LIMIT"
        printf 'TUNNEL_MTU=%s\n'      "$TUNNEL_MTU"
        printf 'DSCP_MARK=%s\n'       "$DSCP_MARK"
    } > "$CONF_FILE"
    chmod 600 "$CONF_FILE"
}

start_logic() {
    if [ ! -f "$CONF_FILE" ]; then
        echo -e "${R}  [ERROR] Config file missing: $CONF_FILE${NC}"; exit 1
    fi
    source "$CONF_FILE"
    if [ "$(docker ps -aq -f name=narnia_tunnel)" ]; then
        docker rm -f narnia_tunnel >> "$LOG_FILE" 2>&1
    fi
    local -a dcmd=(
        docker run
        --cap-add=NET_ADMIN
        --device /dev/net/tun:/dev/net/tun
        --net=host
        -e "INTERFACE=${IFACE}"
        -e "PASSWORD=${PSWD}"
    )
    if [ "$TYPE" == "1" ]; then
        dcmd+=(-e "REMOTE_IP=${R_IP}")
        [ -n "$DSCP_MARK" ] && dcmd+=(-e "DSCP_MARK=${DSCP_MARK}")
    else
        dcmd+=(-e "SERVER=${SERVER_LISTEN:-0.0.0.0}")
        [ -n "$OPERATING_MODE" ] && dcmd+=(-e "OPERATING_MODE=${OPERATING_MODE}")
        [ -n "$BANDWIDTH_LIMIT" ] && dcmd+=(-e "BANDWIDTH_LIMIT=${BANDWIDTH_LIMIT}")
    fi
    [ -n "$MAC_ADDR" ]     && dcmd+=(-e "MAC=${MAC_ADDR}")
    [ -n "$KEEPALIVE" ]    && dcmd+=(-e "KEEPALIVE=${KEEPALIVE}")
    [ -n "$LINK_QUALITY" ] && dcmd+=(-e "LINK_QUALITY=${LINK_QUALITY}")
    [ -n "$BAN_QUALITY" ]  && dcmd+=(-e "BAN_QUALITY=${BAN_QUALITY}")
    [ -n "$TUNNEL_MTU" ]   && dcmd+=(-e "MTU=${TUNNEL_MTU}")
    dcmd+=(--restart unless-stopped --name narnia_tunnel -d "$IMG")
    "${dcmd[@]}" >> "$LOG_FILE" 2>&1
    sleep 3
    if [[ ! "$OPERATING_MODE" =~ ^ip: ]]; then
        ip addr add "$L_IP/24" dev "$IFACE" 2>/dev/null
    fi
    ip link set "$IFACE" mtu "${TUNNEL_MTU:-1500}"
    ip link set "$IFACE" up
    apply_firewall
}

stop_logic() {
    docker stop narnia_tunnel 2>/dev/null
    ip link set "$IFACE" down 2>/dev/null
    ip addr flush dev "$IFACE" 2>/dev/null
    if [ -f "$CONF_FILE" ]; then
        source "$CONF_FILE" 2>/dev/null
        iptables -t nat -D POSTROUTING -o "$DEFAULT_IF" -j MASQUERADE 2>/dev/null
        if [ "$TYPE" == "1" ]; then
            iptables -t nat -D POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null
            iptables -D FORWARD -i "$DEFAULT_IF" -o "$IFACE" -j ACCEPT 2>/dev/null
            iptables -D FORWARD -i "$IFACE" -o "$DEFAULT_IF" -j ACCEPT 2>/dev/null
            if [ -n "$PORT_LIST" ]; then
                IFS=',' read -ra ADDR <<< "$PORT_LIST"
                for port in "${ADDR[@]}"; do
                    port=$(echo "$port" | xargs)
                    iptables -t nat -D PREROUTING -p tcp --dport "$port" \
                        -j DNAT --to-destination "$R_INT:$port" 2>/dev/null
                    iptables -t nat -D PREROUTING -p udp --dport "$port" \
                        -j DNAT --to-destination "$R_INT:$port" 2>/dev/null
                done
            fi
        fi
    fi
}

install_core() {
    install_deps
    echo -e "  ${Y}Pulling image ${IMG}...${NC}"
    if ! docker pull "$IMG" >> "$LOG_FILE" 2>&1; then
        echo -e "  ${R}[ERROR] Failed to pull image.${NC}"
        echo -e "  ${DIM}Log: $LOG_FILE${NC}"
        read -p "  Press Enter..."
        return 1
    fi
    echo -e "  ${G}[OK] Core image ready.${NC}"
    sleep 1
}

create_tunnel() {
    if [ ! -f "$CONF_FILE" ]; then
        if ! docker image inspect "$IMG" &>/dev/null; then
            echo -e "  ${R}[ERROR] Run 'Install Core' first.${NC}"
            sleep 2; return
        fi
    fi

    banner
    echo -e "${BOLD}${C}  ⚙️  Create Tunnel${NC}"
    echo -e "${LINE}"

    DEFAULT_IF=$(ip -4 route show default | awk '{print $5}' | head -n1)
    echo -e "  ${W}Detected main interface:${NC} ${G}${DEFAULT_IF}${NC}"
    echo -e "${LINE}"
    echo -e "   ${W}1)${NC}  IRAN Server    ${DIM}(client mode — connects to FOREIGN server)${NC}"
    echo -e "   ${W}2)${NC}  FOREIGN Server ${DIM}(server mode — listens for IRAN client)${NC}"
    echo -e "${LINE}"
    while true; do
        read -p "  Select role [1/2]: " TYPE
        [[ "$TYPE" == "1" || "$TYPE" == "2" ]] && break
        echo -e "  ${R}Invalid. Enter 1 or 2.${NC}"
    done

    if [ "$TYPE" == "1" ]; then
        L_IP="10.200.200.2"; R_INT="10.200.200.1"; SERVER_LISTEN=""
        while true; do
            read -p "  FOREIGN server IP (remote): " R_IP
            [ -n "$R_IP" ] && break
            echo -e "  ${R}Remote IP cannot be empty.${NC}"
        done
    else
        L_IP="10.200.200.1"; R_INT="10.200.200.2"; R_IP=""
        SERVER_LISTEN="0.0.0.0"
        read -p "  Listen IP [0.0.0.0]: " _v
        [ -n "$_v" ] && SERVER_LISTEN="$_v"
    fi

    while true; do
        read -p "  Tunnel password: " PSWD
        [ -n "$PSWD" ] && break
        echo -e "  ${R}Password cannot be empty.${NC}"
    done
    echo ""

    echo -e "${LINE}"
    echo -e "  ${BOLD}${W}Advanced Options${NC} ${DIM}(press Enter to use defaults)${NC}"
    echo -e "${LINE}"

    read -p "  Custom MAC address for TAP [random]: " MAC_ADDR
    read -p "  Keepalive interval, seconds [5]: " KEEPALIVE
    echo -e "\n  ${W}MTU${NC} ${DIM}(empty = auto; both sides negotiate, smaller wins)${NC}"
    read -p "  MTU in bytes [auto]: " TUNNEL_MTU
    echo -e "\n  ${W}Link Quality${NC}"
    read -p "  Link quality threshold, 0-100 [none]: " LINK_QUALITY
    read -p "  Ban quality threshold,  0-100 [none]: " BAN_QUALITY

    if [ "$TYPE" == "1" ]; then
        BANDWIDTH_LIMIT=""; OPERATING_MODE=""
        echo -e "\n  ${W}DSCP Mark${NC} ${DIM}(client only)${NC}"
        read -p "  DSCP mark [none]: " DSCP_MARK
    else
        DSCP_MARK=""
        echo -e "\n  ${W}Bandwidth Limit${NC} ${DIM}(server side only, Mbps)${NC}"
        read -p "  Bandwidth limit [none]: " BANDWIDTH_LIMIT
        echo -e "\n  ${W}Operating Mode${NC} ${DIM}(server defines mode for both sides)${NC}"
        echo -e "  ${DIM}bridge:br0:br1  |  ip:mask:srv_ip:cli_ip:dynamic:metric  |  none${NC}"
        read -p "  Operating mode [none]: " OPERATING_MODE
    fi

    PORT_LIST=""
    if [ "$TYPE" == "1" ]; then
        echo ""
        echo -e "${LINE}"
        echo -e "  ${W}Port Forwarding${NC} ${DIM}(comma-separated, e.g. 443,2053,8080)${NC}"
        read -p "  Ports to forward [none]: " PORT_LIST
    fi

    _write_conf
    create_service
    show_progress 0.04 "Configuring     "
    start_logic

    echo -e "\n  ${G}[OK] Tunnel is up and running!${NC}"
    echo -e "  ${DIM}Run 'narnia' anytime to manage.${NC}"
    echo -e "${LINE}"
    read -p "  Press Enter..."
}

edit_config() {
    if [ ! -f "$CONF_FILE" ]; then
        echo -e "  ${R}[ERROR] No config found.${NC}"; sleep 2; return
    fi
    banner
    echo -e "${BOLD}${C}  ✏️  Edit Configuration${NC}"
    echo -e "${LINE}"
    source "$CONF_FILE" 2>/dev/null
    echo -e "  ${W}Current values in brackets — press Enter to keep.${NC}"
    echo -e "${LINE}"
    local _v
    read -p "  Password          [hidden]: "               _v; [ -n "$_v" ] && PSWD="$_v"
    read -p "  Keepalive sec     [${KEEPALIVE:-5}]: "      _v; [ -n "$_v" ] && KEEPALIVE="$_v"
    read -p "  MAC address       [${MAC_ADDR:-random}]: "  _v; [ -n "$_v" ] && MAC_ADDR="$_v"
    read -p "  MTU               [${TUNNEL_MTU:-auto}]: "  _v; [ -n "$_v" ] && TUNNEL_MTU="$_v"
    read -p "  Link quality      [${LINK_QUALITY:-none}]: " _v; [ -n "$_v" ] && LINK_QUALITY="$_v"
    read -p "  Ban quality       [${BAN_QUALITY:-none}]: "  _v; [ -n "$_v" ] && BAN_QUALITY="$_v"
    if [ "$TYPE" == "1" ]; then
        read -p "  Remote IP        [${R_IP}]: "               _v; [ -n "$_v" ] && R_IP="$_v"
        read -p "  DSCP mark        [${DSCP_MARK:-none}]: "    _v; [ -n "$_v" ] && DSCP_MARK="$_v"
        read -p "  Port forwarding  [${PORT_LIST:-none}]: "    _v; [ -n "$_v" ] && PORT_LIST="$_v"
    else
        read -p "  Listen IP        [${SERVER_LISTEN:-0.0.0.0}]: " _v; [ -n "$_v" ] && SERVER_LISTEN="$_v"
        read -p "  Bandwidth limit  [${BANDWIDTH_LIMIT:-none}]: "   _v; [ -n "$_v" ] && BANDWIDTH_LIMIT="$_v"
        read -p "  Operating mode   [${OPERATING_MODE:-none}]: "    _v; [ -n "$_v" ] && OPERATING_MODE="$_v"
    fi
    DEFAULT_IF=$(ip -4 route show default | awk '{print $5}' | head -n1)
    _write_conf
    echo -e "\n  ${G}[OK] Config saved.${NC}"
    read -p "  Restart tunnel now? [y/N]: " do_restart
    if [[ "$do_restart" =~ ^[yY]$ ]]; then
        systemctl restart narnia.service
        echo -e "  ${G}[OK] Service restarted.${NC}"
    fi
    sleep 1
}

tunnel_dashboard() {
    if [ ! -f "$CONF_FILE" ]; then
        echo -e "  ${R}[ERROR] No config found.${NC}"; sleep 2; return
    fi
    source "$CONF_FILE" 2>/dev/null
    while true; do
        banner
        echo -e "${BOLD}${C}  📊 Tunnel Dashboard${NC}"
        echo -e "${LINE}"

        local svc_state
        svc_state=$(systemctl is-active narnia.service 2>/dev/null || echo "not-found")

        echo -e "${BOLD}  Container:${NC}"
        docker ps -f name=narnia_tunnel \
            --format "  {{.Names}}  |  {{.Status}}  |  {{.Image}}" 2>/dev/null || \
            echo -e "  ${R}No container running.${NC}"

        local svc_clr
        [ "$svc_state" == "active" ] && svc_clr="${G}" || svc_clr="${R}"
        echo -e "  Service : ${svc_clr}${svc_state^^}${NC}"

        echo -e "\n${BOLD}  Interface (${IFACE}):${NC}"
        ip addr show "$IFACE" 2>/dev/null | grep inet || \
            echo -e "  ${R}Interface not found.${NC}"

        echo -e "\n${BOLD}  Routes:${NC}"
        ip route show dev "$IFACE" 2>/dev/null || echo -e "  ${DIM}none${NC}"

        echo -e "${LINE}"
        echo -e "   ${W}1)${NC} 📈  Statistics (live)"
        echo -e "   ${W}2)${NC} 🔗  Peer Connectivity Test"
        echo -e "   ${W}0)${NC} ← Back"
        echo -e "${LINE}"
        read -p "  Select: " d_opt
        case $d_opt in
            1) tunnel_statistics ;;
            2) _peer_test ;;
            0) return ;;
        esac
    done
}

_peer_test() {
    source "$CONF_FILE" 2>/dev/null
    banner
    echo -e "${BOLD}${C}  🔗 Peer Connectivity Test${NC}"
    echo -e "${LINE}"
    echo -e "\n${BOLD}  Peer Ping (${R_INT}):${NC}"
    ping -c 3 -W 2 "$R_INT" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "  ${G}[OK] Tunnel peer reachable.${NC}"
    else
        echo -e "  ${R}[FAIL] Peer unreachable.${NC}"
    fi
    echo -e "${LINE}"
    read -p "  Press Enter..."
}

tunnel_statistics() {
    if [ ! -f "$CONF_FILE" ]; then
        echo -e "  ${R}[ERROR] No config found.${NC}"; sleep 2; return
    fi
    source "$CONF_FILE" 2>/dev/null

    local container_id
    container_id=$(docker ps -q -f name=narnia_tunnel 2>/dev/null)

    _srow() {
        local label="$1" value="$2" info="$3"
        printf "  %-22s  %-18s  %s\n" "$label" "$value" "$info"
    }

    _collect_and_draw() {
        local ping_val rx_bytes tx_bytes rx_h tx_h total_h cpu_pct mem_pct mtu_val state_val stats

        ping_val=$(ping -c1 -W1 "$R_INT" 2>/dev/null | grep -oP 'time=\K[\d.]+')
        if [ -z "$ping_val" ]; then
            ping_val="timeout"
        else
            ping_val="${ping_val} ms"
        fi

        if ip link show "$IFACE" &>/dev/null; then
            rx_bytes=$(cat /sys/class/net/"$IFACE"/statistics/rx_bytes 2>/dev/null || echo 0)
            tx_bytes=$(cat /sys/class/net/"$IFACE"/statistics/tx_bytes 2>/dev/null || echo 0)
            rx_h=$(numfmt --to=iec --suffix=B "$rx_bytes" 2>/dev/null || echo "${rx_bytes}B")
            tx_h=$(numfmt --to=iec --suffix=B "$tx_bytes" 2>/dev/null || echo "${tx_bytes}B")
            total_h=$(numfmt --to=iec --suffix=B "$(( rx_bytes + tx_bytes ))" 2>/dev/null || echo "$(( rx_bytes + tx_bytes ))B")
        else
            rx_h="N/A"; tx_h="N/A"; total_h="N/A"
        fi

        if [ -n "$container_id" ]; then
            stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemPerc}}" "$container_id" 2>/dev/null)
            cpu_pct=$(echo "$stats" | cut -d'|' -f1)
            mem_pct=$(echo "$stats" | cut -d'|' -f2)
        else
            cpu_pct="N/A"; mem_pct="N/A"
        fi

        mtu_val=$(ip link show "$IFACE" 2>/dev/null | grep -oP 'mtu \K\d+')
        [ -z "$mtu_val" ] && mtu_val="N/A"

        if docker ps -q -f name=narnia_tunnel 2>/dev/null | grep -q .; then
            state_val="RUNNING"
        else
            state_val="OFFLINE"
        fi

        clear
        banner
        echo -e "  ${BOLD}${C}📈 Live Statistics${NC}  ${DIM}· refresh 5s · q = exit${NC}"
        echo -e "${LINE}"
        printf "  ${DIM}%-22s  %-18s  %s${NC}\n" "METRIC" "VALUE" "INFO"
        echo -e "${LINE}"
        _srow "Tunnel State"   "$state_val"   "docker container"
        _srow "Peer Latency"   "$ping_val"    "→ ${R_INT}"
        echo -e "${LINE}"
        _srow "Download (RX)"  "$rx_h"        "since last start"
        _srow "Upload   (TX)"  "$tx_h"        "since last start"
        _srow "Total Traffic"  "$total_h"     "RX + TX"
        echo -e "${LINE}"
        _srow "CPU Usage"      "$cpu_pct"     "narnia container"
        _srow "Memory Usage"   "$mem_pct"     "narnia container"
        echo -e "${LINE}"
        _srow "Active MTU"     "$mtu_val"     "${IFACE} interface"
        echo -e "${LINE}"
        printf "  ${DIM}Last update: %s${NC}\n" "$(date '+%H:%M:%S')"
    }

    _collect_and_draw

    trap 'tput cnorm; return' INT
    tput civis

    while true; do
        if read -r -s -n1 -t5 _key 2>/dev/null; then
            if [[ "$_key" == "q" || "$_key" == "Q" ]]; then
                tput cnorm
                return
            fi
        fi
        _collect_and_draw
    done

    tput cnorm
}


mtu_optimizer() {
    if [ ! -f "$CONF_FILE" ]; then
        echo -e "  ${R}[ERROR] No config found. Create tunnel first.${NC}"; sleep 2; return
    fi
    source "$CONF_FILE" 2>/dev/null

    banner
    echo -e "${BOLD}${C}  🔬 Tunnel Optimizer${NC}"
    echo -e "${LINE}"

    local target
    if [ "$TYPE" == "1" ]; then
        target="$R_IP"
    else
        target="$R_INT"
    fi

    echo -e "  ${W}Target :${NC} ${Y}${target}${NC}"
    echo -e "  ${W}Current MTU :${NC} ${DIM}${TUNNEL_MTU:-auto}${NC}"
    echo -e "${LINE}"

    echo -e "  ${Y}[1/4] Testing peer connectivity...${NC}"
    if ! ping -c2 -W2 "$target" &>/dev/null; then
        echo -e "  ${R}[ERROR] Cannot reach ${target}. Is the tunnel up?${NC}"
        read -p "  Press Enter..."; return
    fi
    echo -e "  ${G}      Peer reachable.${NC}"

    echo -e "\n  ${Y}[2/4] Detecting optimal MTU via binary search...${NC}"
    echo -e "  ${DIM}      Testing range 576 – 1500 bytes (ICMP overhead = 28b)${NC}"
    echo ""

    local low=576 high=1500 best=1400
    while [ $(( high - low )) -gt 1 ]; do
        local mid=$(( (low + high) / 2 ))
        printf "  Testing %d bytes ...\r" "$mid"
        if ping -c2 -W2 -M do -s $(( mid - 28 )) "$target" &>/dev/null 2>&1; then
            best=$mid; low=$mid
        else
            high=$mid
        fi
    done

    local narnia_overhead=28
    local suggested=$(( best - narnia_overhead ))
    [ "$suggested" -lt 576 ] && suggested=576

    echo -e "\n  ${G}[OK] Max path MTU : ${BOLD}${best}${NC}"
    echo -e "  ${G}[OK] Suggested tunnel MTU (−${narnia_overhead}b overhead) : ${BOLD}${suggested}${NC}"

    echo -e "\n  ${Y}[3/4] Measuring round-trip latency to peer...${NC}"
    local ping_result avg_rtt
    ping_result=$(ping -c5 -W2 "$R_INT" 2>/dev/null | tail -1)
    avg_rtt=$(echo "$ping_result" | grep -oP 'avg\K[^/]*' | tr -d '/' | awk -F'/' '{print $1}')
    [ -z "$avg_rtt" ] && avg_rtt="N/A"
    echo -e "  ${G}[OK] Average RTT to tunnel peer : ${BOLD}${avg_rtt} ms${NC}"

    echo -e "\n  ${Y}[4/4] Checking keepalive alignment...${NC}"
    local ka="${KEEPALIVE:-5}"
    local ka_ok="${G}OK${NC}"
    local ka_hint=""
    if [ "$ka" -lt 10 ] 2>/dev/null; then
        ka_ok="${Y}LOW${NC}"; ka_hint="  ${DIM}Consider 15-20s to reduce DPD false positives.${NC}"
    fi
    echo -e "  Keepalive : ${ka}s  ${ka_ok}${ka_hint}"

    echo -e "\n${LINE}"
    echo -e "  ${BOLD}${W}Optimization Summary${NC}"
    echo -e "${LINE}"
    printf "  %-24s : %s\n" "Max path MTU"     "${best} bytes"
    printf "  %-24s : %s\n" "Suggested MTU"    "${suggested} bytes"
    printf "  %-24s : %s\n" "Current MTU"      "${TUNNEL_MTU:-auto}"
    printf "  %-24s : %s\n" "Avg RTT"          "${avg_rtt} ms"
    printf "  %-24s : %s\n" "Keepalive"        "${ka}s"
    echo -e "${LINE}"

    echo -e "\n  ${W}Apply keepalive optimization?${NC} ${DIM}(set to 20s if currently < 10s)${NC}"
    read -p "  [y/N]: " apply_ka
    if [[ "$apply_ka" =~ ^[yY]$ ]]; then
        KEEPALIVE=20
        echo -e "  ${G}[OK] Keepalive set to 20s.${NC}"
    fi

    echo -e "\n  ${W}MTU selection:${NC}"
    echo -e "   ${W}1)${NC}  Apply suggested MTU  ${DIM}(${suggested})${NC}"
    echo -e "   ${W}2)${NC}  Keep current MTU     ${DIM}(${TUNNEL_MTU:-auto})${NC}"
    echo -e "   ${W}3)${NC}  Enter manually"
    read -p "  Select [1/2/3]: " mtu_choice

    case $mtu_choice in
        1)
            TUNNEL_MTU="$suggested"
            echo -e "  ${G}[OK] MTU set to ${suggested}.${NC}"
            ;;
        3)
            while true; do
                read -p "  Enter MTU (576-9000): " mtu_input
                if [[ "$mtu_input" =~ ^[0-9]+$ ]] && \
                   [ "$mtu_input" -ge 576 ] && [ "$mtu_input" -le 9000 ]; then
                    TUNNEL_MTU="$mtu_input"
                    echo -e "  ${G}[OK] MTU set to ${mtu_input}.${NC}"
                    break
                fi
                echo -e "  ${R}Invalid. Enter a number between 576 and 9000.${NC}"
            done
            ;;
        *)
            echo -e "  ${DIM}MTU unchanged.${NC}"
            ;;
    esac

    DEFAULT_IF=$(ip -4 route show default | awk '{print $5}' | head -n1)
    _write_conf

    echo -e "\n  ${G}[OK] Settings saved.${NC}"
    read -p "  Restart tunnel to apply changes? [y/N]: " do_restart
    if [[ "$do_restart" =~ ^[yY]$ ]]; then
        systemctl restart narnia.service
        echo -e "  ${G}[OK] Tunnel restarted with new settings.${NC}"
    fi
    read -p "  Press Enter..."
}

tunnel_control() {
    while true; do
        banner
        echo -e "${BOLD}${C}  🎮 Tunnel Control${NC}"
        echo -e "${LINE}"
        echo -e "   ${W}1)${NC} 📋  View Logs (live)"
        echo -e "   ${W}2)${NC} 🔄  Restart"
        echo -e "   ${W}3)${NC} ⏹   Stop"
        echo -e "   ${W}4)${NC} ▶   Start"
        echo -e "${LINE}"
        echo -e "   ${W}0)${NC} ← Back"
        echo -e "${LINE}"
        local tc_opt
        read -p "  Select: " tc_opt
        case $tc_opt in
            1)
                echo -e "  ${C}Press Ctrl+C to exit logs.${NC}"; sleep 1
                docker logs -f narnia_tunnel
                ;;
            2)
                systemctl restart narnia.service
                echo -e "  ${G}[OK] Restarted.${NC}"; sleep 2
                ;;
            3)
                systemctl stop narnia.service
                echo -e "  ${R}[OK] Stopped.${NC}"; sleep 2
                ;;
            4)
                systemctl start narnia.service
                echo -e "  ${G}[OK] Started.${NC}"; sleep 2
                ;;
            0) return ;;
            *) echo -e "  ${R}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

tunnel_manager() {
    while true; do
        banner
        echo -e "${BOLD}${C}  🔧 Tunnel Manager${NC}"
        echo -e "${LINE}"
        echo -e "   ${W}1)${NC} ✏️   Edit Configuration"
        echo -e "   ${W}2)${NC} 🔬  Tunnel Optimizer"
        echo -e "   ${W}3)${NC} 🎮  Tunnel Control"
        echo -e "${LINE}"
        echo -e "   ${W}0)${NC} ← Back"
        echo -e "${LINE}"
        local s_opt
        read -p "  Select: " s_opt
        case $s_opt in
            1) edit_config ;;
            2) mtu_optimizer ;;
            3) tunnel_control ;;
            0) return ;;
            *) echo -e "  ${R}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

clean_all() {
    banner
    echo -e "${BOLD}${R}  🗑️  Uninstall & Remove${NC}"
    echo -e "${LINE}"
    echo -e "  ${R}This will remove the tunnel, NAT rules, service and config.${NC}"
    echo -e "${LINE}"
    read -p "  Are you sure? [yes/N]: " confirm
    [ "$confirm" != "yes" ] && return
    echo -e "${Y}  Stopping service...${NC}"
    systemctl stop narnia.service 2>/dev/null
    systemctl disable narnia.service 2>/dev/null
    echo -e "${Y}  Removing container...${NC}"
    docker stop narnia_tunnel 2>/dev/null
    docker rm narnia_tunnel 2>/dev/null
    if [ -f "$CONF_FILE" ]; then
        source "$CONF_FILE" 2>/dev/null
        echo -e "${Y}  Cleaning firewall rules...${NC}"
        iptables -t nat -D POSTROUTING -o "$DEFAULT_IF" -j MASQUERADE 2>/dev/null
        if [ "$TYPE" == "1" ]; then
            iptables -t nat -D POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null
            iptables -D FORWARD -i "$DEFAULT_IF" -o "$IFACE" -j ACCEPT 2>/dev/null
            iptables -D FORWARD -i "$IFACE" -o "$DEFAULT_IF" -j ACCEPT 2>/dev/null
            if [ -n "$PORT_LIST" ]; then
                IFS=',' read -ra ADDR <<< "$PORT_LIST"
                for port in "${ADDR[@]}"; do
                    port=$(echo "$port" | xargs)
                    iptables -t nat -D PREROUTING -p tcp --dport "$port" \
                        -j DNAT --to-destination "$R_INT:$port" 2>/dev/null
                    iptables -t nat -D PREROUTING -p udp --dport "$port" \
                        -j DNAT --to-destination "$R_INT:$port" 2>/dev/null
                done
            fi
        fi
    fi
    ip link delete "$IFACE" 2>/dev/null
    rm -f "$CONF_FILE" "$SERVICE_FILE" "$INSTALL_DIR/$SCRIPT_NAME"
    systemctl daemon-reload 2>/dev/null
    echo -e "  ${G}[OK] Narnia removed successfully.${NC}"
    read -p "  Press Enter..."
    exit 0
}

menu() {
    while true; do
        banner
        echo -e "${BOLD}${W}  Main Menu${NC}"
        echo -e "${LINE}"
        echo -e "   ${W}1)${NC} 📦  Install Core & Prerequisites"
        echo -e "   ${W}2)${NC} ⚙️   Create Tunnel"
        echo -e "${LINE}"
        echo -e "   ${W}3)${NC} 🔧  Tunnel Manager"
        echo -e "   ${W}4)${NC} 📊  Tunnel Dashboard"
        echo -e "${LINE}"
        echo -e "   ${W}5)${NC} 🗑️   Uninstall & Remove"
        echo -e "${LINE}"
        echo -e "   ${W}0)${NC} 🚪  Exit"
        echo -e "${LINE}"
        local opt
        read -p "  Select: " opt
        case $opt in
            1) install_core ;;
            2) create_tunnel ;;
            3) tunnel_manager ;;
            4) tunnel_dashboard ;;
            5) clean_all ;;
            0) echo -e "  ${G}Goodbye.${NC}"; exit 0 ;;
            *) echo -e "  ${R}Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

case "$1" in
    start) start_logic ;;
    stop)  stop_logic  ;;
    *)     menu        ;;
esac
