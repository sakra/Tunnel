#!/bin/bash
# tunnel script for launching remote Mathematica controller kernels.
# See https://github.com/sakra/Tunnel/blob/master/MANUAL.md for usage hints.
# Copyright 2015 Sascha Kratky, see accompanying license file.

cd "`dirname \"$0\"`"

if [ -z "$LOGFILE" ]
then
	# log file with unique name for each invocation
	mkdir -p "Logs/`date \"+%Y-%m-%d\"`"
	LOGFILE="Logs/`date \"+%Y-%m-%d\"`/`basename \"$0\" .sh`_`date \"+%Y-%m-%d-%H%M%S\"`_$$.log"
	# single logfile
	# LOGFILE="`basename \"$0\" .sh`.log"
fi

echo `hostname` `date` >> $LOGFILE
echo $0 $@ >> $LOGFILE

# check if we are being called as SSH_ASKPASS helper script
if [ -n "$REMOTE_KERNEL_PASSWORD" -a "$0" == "$SSH_ASKPASS" ]
then
	# just output the password that has been passed as an environment variable
	echo $REMOTE_KERNEL_PASSWORD
	exit 0
fi

# check arguments
if [ "$#" -ne "3" ]
then
	echo "Usage: $0 [user[:password]@]host[:port] path_to_mathematica_kernel linkname" >> $LOGFILE
	exit 1
fi

REMOTE_KERNEL_ADDRESS=$1
REMOTE_KERNEL_PATH=$2
LINK_NAME=$3

SSH_PATH=/usr/bin/ssh

if [ ! -x "$SSH_PATH" ]
then
	echo "Error: OpenSSH client $SSH_PATH does not exist or is not executable." >> $LOGFILE
	exit 1
fi

# parse port link name port numbers, e.g., 53994@127.0.0.1,39359@127.0.0.1
MAIN_LINK_DATA_PORT=`echo $LINK_NAME | awk -F "[,@]" '{print $1}'`
MAIN_LINK_HOST=`echo $LINK_NAME | awk -F "[,@]" '{print $2}'`
MAIN_LINK_MESSAGE_PORT=`echo $LINK_NAME | awk -F "[,@]" '{print $3}'`

if [ -z "$MAIN_LINK_DATA_PORT" -o -z "$MAIN_LINK_MESSAGE_PORT" ]
then
	echo "Error: $LINK_NAME is not a properly formatted MathLink TCPIP protocol link name!" >> $LOGFILE
	exit 1
fi

# test if MAIN_LINK_HOST is an IPv6 address
if echo $MAIN_LINK_HOST | grep -q ":"
then
	# SSH requires IPv6 address to be enclosed in square brackets
	MAIN_LINK_HOST="[$MAIN_LINK_HOST]"
fi

LOOPBACK_IP_ADDR="127.0.0.1"
MAIN_LINK_LOOPBACK="$MAIN_LINK_DATA_PORT@$LOOPBACK_IP_ADDR,$MAIN_LINK_MESSAGE_PORT@$LOOPBACK_IP_ADDR"

if [ "$MAIN_LINK_HOST" != "$LOOPBACK_IP_ADDR" ]
then
	echo "Warning: $LINK_NAME does not use the loopback IP address $LOOPBACK_IP_ADDR!" >> $LOGFILE
fi

# SSH options
# -C enable compression
# -v verbose mode
# -x disable X11 forwarding
# -n prevent reading from stdin
# -T disable pseudo-tty allocation
SSH_OPTS="-C -v -x -n -T -o CheckHostIP=no -o StrictHostKeyChecking=no -o ControlMaster=no"

# parse user credentials from host name
REMOTE_KERNEL_USER=`echo $REMOTE_KERNEL_ADDRESS | awk -F "[@]" '{print $1}'`
REMOTE_KERNEL_HOST=`echo $REMOTE_KERNEL_ADDRESS | awk -F "[@]" '{print $2}'`
if [ -z "$REMOTE_KERNEL_HOST" ]
then
	REMOTE_KERNEL_HOST=$REMOTE_KERNEL_USER
	REMOTE_KERNEL_USER=""
fi

# parse password from user credentials
if [ -n "$REMOTE_KERNEL_USER" ]
then
	REMOTE_KERNEL_PASSWORD=`echo $REMOTE_KERNEL_USER | awk -F "[:]" '{print $2}'`
	REMOTE_KERNEL_USER=`echo $REMOTE_KERNEL_USER | awk -F "[:]" '{print $1}'`
fi

# parse SSH port number from host name
REMOTE_KERNEL_PORT=`echo $REMOTE_KERNEL_HOST | awk -F "[:]" '{print $2}'`
REMOTE_KERNEL_HOST=`echo $REMOTE_KERNEL_HOST | awk -F "[:]" '{print $1}'`

# test if REMOTE_KERNEL_PORT is a positive integer
if echo $REMOTE_KERNEL_PORT | grep -v -q "^[0-9]*$"
then
	echo "Error: $REMOTE_KERNEL_PORT is not a properly formatted TCP port number!" >> $LOGFILE
	exit 1
fi

# add optional command line options
if [ -n "$REMOTE_KERNEL_USER" ]
then
	SSH_OPTS="$SSH_OPTS -l $REMOTE_KERNEL_USER"
fi
if [ -n "$REMOTE_KERNEL_PASSWORD" ]
then
	# login password cannot be specified as a command line option to SSH, use SSH_ASKPASS trick
	export DISPLAY=none:0.0
	export SSH_ASKPASS=$0
	export REMOTE_KERNEL_PASSWORD
	export LOGFILE
fi
if [ -n "$REMOTE_KERNEL_PORT" ]
then
	SSH_OPTS="$SSH_OPTS -p $REMOTE_KERNEL_PORT"
fi

# compute port numbers to be used for preemptive and service links
let "BASE_PORT = MAIN_LINK_DATA_PORT > MAIN_LINK_MESSAGE_PORT ? MAIN_LINK_DATA_PORT : MAIN_LINK_MESSAGE_PORT"
let "PREEMPTIVE_LINK_DATA_PORT = BASE_PORT + 1"
let "PREEMPTIVE_LINK_MESSAGE_PORT = BASE_PORT + 2"
let "SERVICE_LINK_DATA_PORT = BASE_PORT + 3"
let "SERVICE_LINK_MESSAGE_PORT = BASE_PORT + 4"

# set up remote port forwardings for kernel main link
SSH_OPTS="$SSH_OPTS -R $LOOPBACK_IP_ADDR:$MAIN_LINK_DATA_PORT:$MAIN_LINK_HOST:$MAIN_LINK_DATA_PORT"
SSH_OPTS="$SSH_OPTS -R $LOOPBACK_IP_ADDR:$MAIN_LINK_MESSAGE_PORT:$MAIN_LINK_HOST:$MAIN_LINK_MESSAGE_PORT"

# MathLink options
REMOTE_KERNEL_OPTS="-mathlink -LinkMode Connect -LinkProtocol TCPIP -LinkName $MAIN_LINK_LOOPBACK"

# Mathematica kernel options
# force loading of the Tunnel kernel init file
REMOTE_KERNEL_OPTS="$REMOTE_KERNEL_OPTS -initfile tunnel.m"
# -lmverbose print information to stderr on connecting to the license manager
REMOTE_KERNEL_OPTS="$REMOTE_KERNEL_OPTS -lmverbose"

# controller kernel specific options
# the front end requires the launch command to stick around until kernel quits
# thus SSH must not run as a background process (don't use option -f)
# set up local port forwardings for controller kernel preemptive link and service link
SSH_OPTS="$SSH_OPTS -L $LOOPBACK_IP_ADDR:$PREEMPTIVE_LINK_DATA_PORT:$LOOPBACK_IP_ADDR:$PREEMPTIVE_LINK_DATA_PORT"
SSH_OPTS="$SSH_OPTS -L $LOOPBACK_IP_ADDR:$PREEMPTIVE_LINK_MESSAGE_PORT:$LOOPBACK_IP_ADDR:$PREEMPTIVE_LINK_MESSAGE_PORT"
SSH_OPTS="$SSH_OPTS -L $LOOPBACK_IP_ADDR:$SERVICE_LINK_DATA_PORT:$LOOPBACK_IP_ADDR:$SERVICE_LINK_DATA_PORT"
SSH_OPTS="$SSH_OPTS -L $LOOPBACK_IP_ADDR:$SERVICE_LINK_MESSAGE_PORT:$LOOPBACK_IP_ADDR:$SERVICE_LINK_MESSAGE_PORT"

# log everything
echo "REMOTE_KERNEL_ADDRESS=$REMOTE_KERNEL_ADDRESS" >> $LOGFILE
echo "REMOTE_KERNEL_HOST=$REMOTE_KERNEL_HOST" >> $LOGFILE
echo "REMOTE_KERNEL_USER=$REMOTE_KERNEL_USER" >> $LOGFILE
echo "REMOTE_KERNEL_PASSWORD=$REMOTE_KERNEL_PASSWORD" >> $LOGFILE
echo "REMOTE_KERNEL_PORT=$REMOTE_KERNEL_PORT" >> $LOGFILE
echo "REMOTE_KERNEL_PATH=$REMOTE_KERNEL_PATH" >> $LOGFILE
echo "REMOTE_KERNEL_OPTS=$REMOTE_KERNEL_OPTS" >> $LOGFILE
echo "LINK_NAME=$LINK_NAME" >> $LOGFILE
echo "MAIN_LINK_HOST=$MAIN_LINK_HOST" >> $LOGFILE
echo "MAIN_LINK_DATA_PORT=$MAIN_LINK_DATA_PORT" >> $LOGFILE
echo "MAIN_LINK_MESSAGE_PORT=$MAIN_LINK_MESSAGE_PORT" >> $LOGFILE
echo "MAIN_LINK_LOOPBACK=$MAIN_LINK_LOOPBACK" >> $LOGFILE
echo "PREEMPTIVE_LINK_DATA_PORT=$PREEMPTIVE_LINK_DATA_PORT" >> $LOGFILE
echo "PREEMPTIVE_LINK_MESSAGE_PORT=$PREEMPTIVE_LINK_MESSAGE_PORT" >> $LOGFILE
echo "SERVICE_LINK_DATA_PORT=$SERVICE_LINK_DATA_PORT" >> $LOGFILE
echo "SERVICE_LINK_MESSAGE_PORT=$SERVICE_LINK_MESSAGE_PORT" >> $LOGFILE
echo "SSH_PATH=$SSH_PATH" >> $LOGFILE
echo "SSH_OPTS=$SSH_OPTS" >> $LOGFILE

nohup "$SSH_PATH" $SSH_OPTS \
	$REMOTE_KERNEL_HOST \
	"\"$REMOTE_KERNEL_PATH\"" $REMOTE_KERNEL_OPTS \
	>> $LOGFILE 2>&1
