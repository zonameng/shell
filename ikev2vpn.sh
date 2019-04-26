#!/bin/bash
#===============================================================================================
#   System Required:  CentOS6.x/7 (32bit/64bit) or Ubuntu
#   Description:  Install IKEV2 VPN for CentOS and Ubuntu
#   Author: quericy
#   Intro:  https://quericy.me/blog/699
#===============================================================================================

clear
VER=5.7.0
echo "#==================================================================================="
echo "# Install IKEV2 VPN for CentOS6.x/7 (32bit/64bit) or Ubuntu or Debian7/8.*"
echo "# Intro: https://quericy.me/blog/699"
echo "#"
echo "# Author:quericy"
echo "#"
echo "# Version:$VER"
echo "#==================================================================================="
echo ""

__INTERACTIVE=""
if [ -t 1 ] ; then
    __INTERACTIVE="1"
fi
#color
__green(){
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[1;31;32m'
    fi
    printf -- "$1"
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[0m'
    fi
}

__red(){
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[1;31;40m'
    fi
    printf -- "$1"
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[0m'
    fi
}

__yellow(){
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[1;31;33m'
    fi
    printf -- "$1"
    if [ "$__INTERACTIVE" ] ; then
        printf '\033[0m'
    fi
}


#install strongswan
function install_ikev2(){
    disable_selinux
    get_system
    yum_install
    get_my_ip
    pre_install
}



# Disable selinux
function disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# Ubuntu or CentOS
function get_system(){
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        system_str="0"
    elif  grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        system_str="1"
    elif  grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        system_str="1"
    elif  grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        system_str="1"
    else
        echo "This Script must be running at the CentOS or Ubuntu or Debian!"
        exit 1
    fi
}

#install strongswan
function yum_install(){
    if [ "$system_str" = "0" ]; then
    yum -y install epel-release &>/dev/null
    yum -y install strongswan &>/dev/null
    else
    apt-get -y install strongswan &>/dev/null
    fi
}
# Get IP address of the server
function get_my_ip(){
    echo "Preparing, Please wait a moment..."
    IP=`curl -s checkip.dyndns.com | cut -d' ' -f 6  | cut -d'<' -f 1`
    if [ -z $IP ]; then
        IP=`curl -s ifconfig.me/ip`
    fi
}

#Pre_install settings
function pre_install(){
    read -e -t 60 -p "Please input the IP or Domain(default_value:${IP}):" host_ip
    if [ "$host_ip" = "" ]; then
        host_ip=$IP
    fi
    read -e -t 60 -p "Would you want to import existing cert (yes or no)?(default_value:no):" have_cert
    if [ "$have_cert" = "yes" ]; then
        have_cert="1"
    else
        have_cert="0"
        read -e -t 60 -p "Please input the cert country(default value:CN):" my_cert_c
        if [ "$my_cert_c" = "" ]; then
            my_cert_c="CN"
        fi
        read -e -t 60 -p "Please input the cert organization(default value:myvpn):" my_cert_o
        if [ "$my_cert_o" = "" ]; then
            my_cert_o="myvpn"
        fi
        read -e -t 60 -p "Please input the cert common name(default value:VPN CA):" my_cert_cn
        if [ "$my_cert_cn" = "" ]; then
            my_cert_cn="VPN CA"
        fi
    fi
    echo "####################################"
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo "Please confirm the information:"
    echo ""
    echo -e "The ip(or domain) of your server: [$(__green $host_ip)]"
    if [ "$have_cert" = "1" ]; then
        echo -e "$(__yellow "These are the certificate you MUST be prepared:")"
        echo -e "[$(__green "ca.cert.pem")]:The CA cert or the chain cert."
        echo -e "[$(__green "server.cert.pem")]:Your server cert."
        echo -e "[$(__green "server.pem")]:Your  key of the server cert."
        echo -e "[$(__yellow "Please copy these file to the same directory of this script before start!")]"
    else
        echo -e "the cert_info:[$(__green "C=${my_cert_c}, O=${my_cert_o}")]"
    fi
    echo ""
    echo "Press any key to start...or Press Ctrl+C to cancel"
    char=`get_char`
    #Current folder
    cur_dir=`pwd`
    cd $cur_dir

}

function get_key(){
    cd $cur_dir
    if [ ! -d my_key ];then
        mkdir my_key
    fi
    if [ "$have_cert" = "1" ]; then
        import_cert
    else
        create_cert
    fi

    echo "####################################"
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    cp -r ca.key.pem /etc/strongswan/ipsec.d/private/
    cp -r ca.cert.pem /etc/strongswan/ipsec.d/cacerts/
    cp -r server.cert.pem /etc/strongswan/ipsec.d/certs/
    cp -r server.pub.pem /etc/strongswan/ipsec.d/certs/
    cp -r server.key.pem /etc/strongswan/ipsec.d/private/
    cp -r client.cert.pem /etc/strongswan/ipsec.d/certs/
    cp -r client.key.pem /etc/strongswan/ipsec.d/private/
    echo "Cert copy completed"
}

# import cert if user has ssl certificate
function import_cert(){
   cd $cur_dir
   if [ -f ca.cert.pem ];then
        cp -f ca.cert.pem my_key/ca.cert.pem
        echo -e "ca.cert.pem [$(__green "found")]"
    else
        echo -e "ca.cert.pem [$(__red "Not found!")]"
        exit
    fi
    if [ -f server.cert.pem ];then
        cp -f server.cert.pem my_key/server.cert.pem
        cp -f server.cert.pem my_key/client.cert.pem
        echo -e "server.cert.pem [$(__green "found")]"
        echo -e "client.cert.pem [$(__green "auto create")]"
    else
        echo -e "server.cert.pem [$(__red "Not found!")]"
        exit
    fi
    if [ -f server.pem ];then
        cp -f server.pem my_key/server.pem
        cp -f server.pem my_key/client.pem
        echo -e "server.pem [$(__green "found")]"
        echo -e "client.pem [$(__green "auto create")]"
    else
        echo -e "server.pem [$(__red "Not found!")]"
        exit
    fi
    cd my_key
}

# auto create certificate
function create_cert(){
    cd $cur_dir
    cd my_key
    strongswan pki --gen --outform pem > ca.key.pem
    strongswan pki --self --in ca.key.pem --dn "C=${my_cert_c}, O=${my_cert_o}, CN=${my_cert_cn}" --ca --lifetime 3650 --outform pem > ca.cert.pem
    strongswan pki --gen --outform pem > server.key.pem
    strongswan pki --pub --in server.key.pem --outform pem > server.pub.pem
    strongswan pki --issue --lifetime 3600 --cacert ca.cert.pem --cakey ca.key.pem --in server.pub.pem --dn "C=${my_cert_c}, O=${my_cert_o}, CN=${host_ip}" --san="${host_ip}" --flag serverAuth --flag ikeIntermediate --outform pem > server.cert.pem
    strongswan pki --gen --outform pem > client.key.pem
    strongswan pki --pub --in client.key.pem --outform pem > client.pub.pem
    strongswan pki --issue --lifetime 1200 --cacert ca.cert.pem --cakey ca.key.pem --in client.pub.pem --dn "C=${my_cert_c}, O=${my_cert_o}, CN=${host_ip}" --outform pem > client.cert.pem
    openssl pkcs12 -export -inkey client.key.pem -in client.cert.pem -name "${my_cert_cn}" -certfile ca.cert.pem -caname "${my_cert_cn}" -out client.cert.p12
}

# configure the ipsec.conf
function configure_ipsec(){
    cp -f /etc/strongswan/ipsec.conf  /etc/strongswan/ipsec.conf_`date +%Y-%m-%d-%R`_bak
    cat > /usr/local/etc/ipsec.conf<<-EOF
config setup
    uniqueids=no
 
conn %default
    compress = yes
    esp = aes256-sha256,aes256-sha1,3des-sha1!
    ike = aes256-sha256-modp2048,aes256-sha1-modp2048,aes128-sha1-modp2048,3des-sha1-modp2048,aes256-sha256-modp1024,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024!
    keyexchange = ike
    keyingtries = 1

conn  IKEv2-EAP
    leftca = "C=${my_cert_c}, O=${my_cert_o}, CN=${my_cert_cn}"
    leftcert = server.cert.pem
    leftsendcert = always
    rightsendcert = never
    leftid = ${host_ip}
    left = %any
    right = %any
    leftauth = pubkey
    rightauth = eap-mschapv2
    leftfirewall = yes
    leftsubnet = 0.0.0.0/0
    rightsourceip = 10.1.0.0/16
    fragmentation = yes
    rekey = no
    eap_identity=%any
    auto = add
EOF
}

# configure the strongswan.conf
function configure_strongswan(){
    read -e -p "Please input DNS1:" DNS1
    read -e -p "Please input DNS2:" DNS2
    cp -f /etc/strongswan/strongswan.d/charon.conf /etc/strongswan/strongswan.d/charon.conf_`date +%Y-%m-%d-%R`_bak
    cat > /etc/strongswan/strongswan.d/charon.conf <<-EOF
charon{ 
    compress = yes
    load_modular = yes
    dns1 = ${DNS1}
    dns2 = ${DNS1}
}
EOF
}


# configure the ipsec.secrets
function configure_secrets(){
    read -e -p "Please input your username:" username
    read -e -p "Please input your password:" password
    cp -f /etc/strongswan/ipsec.secrets /etc/strongswan/ipsec.secrets_`date +%Y-%m-%d-%R`_bak
    cat > /etc/strongswan/ipsec.secrets <<-EOF
# 使用证书验证时的服务器端私钥
# 格式 : RSA <private key file> [ <passphrase> | %prompt ]
: RSA server.key.pem
    
# 使用预设加密密钥, 越长越好
# 格式 [ <id selectors> ] : PSK <secret>
: PSK "${password}"
   
#EAP 方式, 格式同 psk 相同
${username} %any : EAP "${password}"
   
# XAUTH 方式, 只适用于 IKEv1
# 格式 [ <servername> ] <username> : XAUTH "<password>"
${username} %any : XAUTH "${password}"
EOF
}
# Initialization step
install_ikev2
