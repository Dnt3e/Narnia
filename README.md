# Narnia Multi-Port Tunnel

**Tunnel with Multi-Port Support**  
**Author: Dnt3e**

Check out the original project: [Stormotron/Narnia](https://github.com/stormotron/narnia)  

---

## ⚡ توضیحات فارسی

برای **فارسی**, زبانان [لینک توضیحات فارسی](READMEFA.md)  

---

## 📝 What is this?

Narnia Tunnel is a **simple, secure tunnel over ICMP (ping)** that runs in Docker.  
It supports **multi-port forwarding**, ChaCha20 encryption, and high MTU up to 9000.  

Think of it as a **lightweight stealth VPN**—easy to setup, no complicated configs.

---

## 🚀 Features

- **Multi-port forwarding:** Forward multiple services simultaneously  
- **Encrypted tunnel (ChaCha20):** Keep traffic secure  
- **Docker-based:** Full isolation from host system  
- **Interactive setup menu:** Easy configuration  
- **Systemd service:** Start tunnel automatically on boot  
- **Status & ping check:** Monitor connectivity easily  
- **Safe uninstall:** Removes Docker container, firewall rules, and configs  

---

## ⚙️ Requirements

- Linux (Debian / Ubuntu / RedHat / CentOS)  
- Root privileges  
- Docker (script installs automatically if missing)  

---

## 📦 Quick Start (Installation)

1. **Download the script:**

```bash
curl -O https://raw.githubusercontent.com/Dnt3e/Narnia/main/Narnia.sh
chmod +x Narnia.sh
sudo ./Narnia.sh
```
## ✅ Tested Performance

Stormotron tested the tunnel with `iperf` on TCP:  

```text
# iperf -c 192.168.0.1
------------------------------------------------------------
Client connecting to 192.168.0.1, TCP port 5001
TCP window size: 16.0 KByte (default)
------------------------------------------------------------
[  1] local 192.168.0.2 port 36270 connected with 192.168.0.1 port 5001
[ ID] Interval       Transfer     Bandwidth
[  1] 0.00-10.16 sec  45.1 MBytes  37.3 Mbits/sec

# iperf -c 192.168.0.1 -R
------------------------------------------------------------
Client connecting to 192.168.0.1, TCP port 5001
TCP window size: 16.0 KByte (default)
------------------------------------------------------------
[  1] local 192.168.0.2 port 49500 connected with 192.168.0.1 port 5001 (reverse)
[ ID] Interval       Transfer     Bandwidth
[ *1] 0.00-10.13 sec  45.5 MBytes  37.7 Mbits/sec
```
### Made for you ❤️

