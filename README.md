# OS Prep

modprobe af_key xfrm_user xfrm_algo esp4

iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    ???

