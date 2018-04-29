#!/bin/bash

# 3proxy server installer for Debian GNU/Linux (7-9)
# need root user
# sed -i "/$STR/d" "/etc/3proxy/.proxyauth" - remove user $STR

clear
if [[ -e /etc/3proxy/3proxy.cfg ]]; then
	echo "3proxy-install (github.com/ibrmn/3proxy-install)"
	echo ""
	echo "Hello! You have already installed 3proxy."
	echo ""
	read -p "Do you want to remove 3proxy? [y/n]: " -e -i n REMOVE
	if [[ "$REMOVE" = 'y' ]]; then
		/etc/init.d/3proxyinit stop
		rm -rf /etc/3proxy
		rm /etc/rc0.d/*proxyinit
		rm /etc/rc1.d/*proxyinit 
		rm /etc/rc6.d/*proxyinit
		rm /etc/rc2.d/*proxyinit
		rm /etc/rc3.d/*proxyinit 
		rm /etc/rc4.d/*proxyinit
		rm /etc/rc5.d/*proxyinit
		rm /etc/init.d/3proxyinit
		rm -rf /var/log/3proxy
		rm /usr/bin/3proxy

		echo "Wait 5 seconds to close 3proxy."
		sleep 5s
		deluser proxy3
		
		iptables -D INPUT -p tcp -m tcp --dport 1080 -j ACCEPT
		iptables -D INPUT -p udp -m udp --dport 1080 -j ACCEPT
		iptables -D INPUT -p tcp -m tcp --dport 3128 -j ACCEPT

		echo ""
		echo "3Proxy removed!"
	else
		echo ""
		echo "Removal aborted!"
	fi
	exit


else
	# Устанавливаем необходимые пакеты
	apt-get update && apt-get install -y build-essential wget tar gzip psmisc

	# Какую версию ставим?
	ver=0.8.12

	wget --no-check-certificate ~/$ver.tar.gz https://github.com/z3APA3A/3proxy/archive/$ver.tar.gz
	tar xzf ~/$ver.tar.gz
	cd ~/3proxy-$ver
	make -f Makefile.Linux

	mkdir /etc/3proxy
	cp ~/3proxy-$ver/src/3proxy /usr/bin/
	adduser --system --no-create-home --disabled-login --group proxy3

	user_id=$(grep proxy3 /etc/passwd | sed 's/:/ /g' | awk '{print $3}')
	group_id=$(grep proxy3 /etc/passwd | sed 's/:/ /g' | awk '{print $4}')

echo "setgid $group_id
setuid $user_id" >> /etc/3proxy/3proxy.cfg

# Прописываем NS сервера из /etc/resolv.conf
cat /etc/resolv.conf | sed 's/nameserver/nserver/' >> /etc/3proxy/3proxy.cfg
	
echo 'nscache 65536
timeouts 1 5 30 60 180 1800 15 60
users $/etc/3proxy/.proxyauth
daemon
log /var/log/3proxy/3proxy.log D
logformat "- +_L%t.%. %N.%p %E %U %C:%c %R:%r %O %I %h %T"
archiver gz /usr/bin/gzip %F
rotate 5

auth cache strong
proxy -n -p3128 -a

auth strong
flush
maxconn 64
socks -p1080' >> /etc/3proxy/3proxy.cfg

	# Создаём файл с пользователями и паролями

echo ""
echo "Tell me username and password for your proxy"
read -p "Proxy user: " -e -i proxy PROXY_USER
read -p "Password: " -e -i $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-8};echo;) PROXY_PASS

echo "## addusers in this format:
#user:CL:password
##see for documentation: http://www.3proxy.ru/howtoe.asp#USERS
$PROXY_USER:CL:$PROXY_PASS" >> /etc/3proxy/.proxyauth

	# Выставляем права доступа к файлам прокси-сервера

	chown proxy3:proxy3 -R /etc/3proxy
	chown proxy3:proxy3 /usr/bin/3proxy
	chmod 444 /etc/3proxy/3proxy.cfg
	chmod 400 /etc/3proxy/.proxyauth

	# Создаём папку для ведения логов и назначаем права на неё
	mkdir /var/log/3proxy
	chown proxy3:proxy3 /var/log/3proxy

	# Создаём файл-инициализации
echo '
#!/bin/sh
#
### BEGIN INIT INFO
# Provides: 3Proxy
# Required-Start: $remote_fs $syslog
# Required-Stop: $remote_fs $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Initialize 3proxy server
# Description: starts 3proxy
### END INIT INFO

case "$1" in
 start)

 echo Starting 3Proxy
 /usr/bin/3proxy /etc/3proxy/3proxy.cfg
 ;;

 stop)
 echo Stopping 3Proxy
 /usr/bin/killall 3proxy
 ;;

 restart|reload)
 echo Reloading 3Proxy
 /usr/bin/killall -s USR1 3proxy
 ;;
 *)
 echo Usage: \$0 "{start|stop|restart}"
 exit 1
esac
exit 0' >> /etc/init.d/3proxyinit

	# Делаем файл исполняемым и добавляем в автозагрузку
	chmod +x /etc/init.d/3proxyinit
	update-rc.d 3proxyinit defaults
	/etc/init.d/3proxyinit start

	# Необходимо открыть порты в iptables
	echo ""
	echo "We need add rules to iptables"
	iptables -I INPUT -p tcp -m tcp --dport 1080 -j ACCEPT
	iptables -I INPUT -p udp -m udp --dport 1080 -j ACCEPT
	iptables -I INPUT -p tcp -m tcp --dport 3128 -j ACCEPT
	
	# Удаляем мусор после установки
	rm ~/$ver.tar.gz
	rm -r ~/3proxy-$ver

fi
exit 0;