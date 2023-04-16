# TransmissionControlPower
TransmissionControlPower is a shell script that optimizes your TCP stack so you squeeze the best performance out of your connection.

## How it works
It adjusts a few settings within the linux network stack.

## Can it brick my system
If you have an old kernel or a kernel without BBR support, then maybe. It will mess with your current kernel if it fails to detect bbr as being a valid tcp congestion control algorithm. If you have a kernel that supports BBR, then it will not mess with your current kernel.

This script is only tested on Debian KVM machines. It is **not** designed to work with other OSes. Use at your own risk.

## How to use
```bash
bash <(curl -s https://raw.githubusercontent.com/lolnbalok233/TransmissionControlPower/main/optimise.sh)
```

## How well does it works
Tested over a 1Gbps connection using Iperf3, using a server in China and a server in the USA.

![Optimisations compared over 10 times of the day](https://cdn.jsdelivr.net/gh/daycat/blogimages@main/uPic/20230321ATIRqs.png)

It increased the throughput by 300% on average. Your mileage may vary depending on the server hardware and the network connection between servers.

# References used in this script:
- [Linux Kernel](https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt)
- [Cyberciti](http://www.cyberciti.biz/faq/linux-tcp-tuning/)
- [IBM high performance computing](https://www.ibm.com/docs/en/aix/7.1?topic=performance-tcp-udp-tuning)
- [Nkeonkeo's optimizations](https://github.com/nkeonkeo/shs)
- [Bob Cromwell](https://cromwell-intl.com/open-source/performance-tuning/tcp.html)
