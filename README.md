<div align="center">

# 🛡 Narnia 
**پایدار؛ پنهان در ترافیک Ping!**
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/Dnt3e/Narnia/blob/main/Narnia.png">
  <img width="600" height="900" src="https://github.com/Dnt3e/Narnia/blob/main/Narnia.png">
</picture>
</div>

---

### 🛡 نارنیا چیست؟
**نارنیا** یک ابزار تونل‌سازی پیشرفته و سبک است که ترافیک شما را در دل بسته‌های **ICMP** (همان پکت‌های Ping) پنهان می‌کند.

### 🧩 چرا متفاوت است؟
بیشتر فایروال‌ها به‌دنبال الگوهای VPN، پورت‌های خاص یا پروتکل‌های شناخته‌شده هستند. نارنیا با استفاده از تکنیک **ICMP Tunneling**، تمام ترافیک شما را داخل پکت‌های معمولی Ping بسته‌بندی می‌کند.

* **نامرئی:** چون در دید فایروال، تنها یک "Ping معمولی" بین دو سرور در جریان است. 🕵️
* **رمزنگاری نفوذناپذیر:** تمام داده‌ها با الگوریتم قدرتمند **ChaCha20** کدگذاری می‌شوند؛ یعنی حتی اگر کسی پکت‌ها را بررسی کند، چیزی جز کدهای درهم‌ریخته نخواهد دید. 🔒
* **مدیریت هوشمند:** برخلاف روش‌های سنتی، نارنیا خودش بسته‌ها را بازسازی می‌کند. این یعنی خبری از افت سرعت یا مشکلات ناشی از تکه‌تکه شدن بسته‌ها (Fragmentation) نیست. 🛠

### 🚀 خروجی نهایی:
نارنیا به شما یک **رابط شبکه اختصاصی (Virtual Ethernet)** می‌دهد که عملکردی مشابه اتصال مستقیم کابلی دارد.
* **پشتیبانی از MTU بالا:** تا ۹۰۰۰ بایت (بسیار فراتر از نیاز معمول).
* **پایداری رک‌مانند:** انگار دو سرور، درست کنار هم در یک شبکه محلی قرار دارند.

---

## 📦 شروع سریع (نصب)

1. **دانلود اسکریپت:**

```bash

curl -O https://raw.githubusercontent.com/Dnt3e/Narnia/main/Narnia.sh

chmod +x Narnia.sh

sudo ./Narnia.sh

```


## ✅ تست عملکرد:



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

<div align="center">
  
### ساخته شده برای شما ❤️
  
</div>

