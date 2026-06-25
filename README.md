<div align="center">

# 🔀 Narnia 
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

# iperf -c 10.200.200.1
------------------------------------------------------------
Client connecting to 10.200.200.1, TCP port 5001
TCP window size: 16.0 KByte (default)
------------------------------------------------------------
[  1] local 10.200.200.2 port 54852 connected with 10.200.200.1 port 5001 (icwnd/mss/irtt=14/1448/1727)
[ ID] Interval       Transfer     Bandwidth
[  1] 0.0000-10.0985 sec  65.4 MBytes  54.3 Mbits/sec

# iperf -c 10.200.200.1 -R
------------------------------------------------------------
Client connecting to 10.200.200.2, TCP port 5001
TCP window size: 16.0 KByte (default)
------------------------------------------------------------
[  1] local 10.200.200.2 port 52778 connected with 10.200.200.1 port 5001 (reverse) (icwnd/mss/irtt=14/1448/1623)
[ ID] Interval       Transfer     Bandwidth
[ *1] 0.0000-10.0884 sec  75.8 MBytes  63.0 Mbits/sec

```
<div align="center">

---

این پروژه با الگو برداری از پروژه سازنده اصلی توسعه داده شده

**پروژه اصلی:** [Stormotron/Narnia](https://github.com/Stormotron/Narnia)

برای حمایت لطفا به پروژه استار دهید و در [✈️ کانال تلگرام](https://t.me/Dnt3e) عضو بشید.

---

</div>
<div align="center">
  
### ساخته شده برای شما ❤️
  
</div>

