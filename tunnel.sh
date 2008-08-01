#!/bin/bash

DIR=`/usr/bin/dirname $0`
PATH='/usr/bin:/bin'
PID=''
PID_FILE="${DIR}/.tunnel"
RM='/bin/rm'
PS='/bin/ps'
LN='/bin/ln'
AWK='/usr/bin/awk'
SSH='/usr/bin/ssh'
TR='/usr/bin/tr'
KILL='/bin/kill'

pidof() {
	PID=`$PS axc | $AWK "{if (\\\$5==\"$1\") print \\\$1}" | $TR "\n" " "`
	echo $PID
}

tunnel_status() {
	STATUS='stopped'
	if [ -e ${PID_FILE} ]; then
		RUNNING_PID=$( pidof 'tunnel' )
		if [ -n "$RUNNING_PID" ]; then
			$PS -p $RUNNING_PID > /dev/null
			if [ $? != 0 ]; then
				STATUS='stopped'
			else
				STATUS='running'
			fi
		fi
	else
		RUNNING_PID=$( pidof 'tunnel' )
		if [ -n "$RUNNING_PID" ]; then
			$PS -p $RUNNING_PID > /dev/null
			if [ $? != 0 ]; then
				STATUS='stopped'
			else
				STATUS='running'
			fi
		fi
	fi

	echo $STATUS
}

stop_tunnel() {
	STATUS=$(tunnel_status)
	if [ $STATUS == "running" ]; then
		RUNNING_PID=$( pidof 'tunnel' )
		$KILL -INT $RUNNING_PID
		if [ $(pidof tunnel) ]; then
			echo "tunnel did not exit on sigint; sending sigkill"
			$KILL -KILL $RUNNING_PID
			if [ $(pidof tunnel) ]; then
				echo "tunnel still failed to exit"
				exit 1
			fi
		fi

		$RM $PID_FILE

		echo "tunnel stopped"
	else
		echo "tunnel is already $STATUS"
	fi
}

start_tunnel() {
	STATUS=$(tunnel_status)
	TUNNEL="${DIR}/tunnel"

	if [ ! -e "${TUNNEL}" ]; then
		echo "creating symbolic from $TUNNEL to $SSH"
		$LN -s $SSH $TUNNEL
	fi

	if [ $STATUS == "stopped" ]; then
		TARGET=''
		case $1 in
			remote)
				if [ -z "$TUNNEL_HOST" ]; then
					echo "Please set TUNNEL_HOST for remote tunnel"
					exit 1
				fi

				TARGET=$TUNNEL_HOST
				;;
			localhost)
				TARGET='localhost'
				;;
			*)
				echo "${TARGET}: unknown target"
				exit 1
				;;
		esac

		$TUNNEL -N -D 50022 $TARGET 2>/dev/null &

		RUNNING_PID=$( pidof 'tunnel' )
		echo $RUNNING_PID > $PID_FILE

		echo "tunnel started"
	else
		echo "tunnel is already $STATUS"
	fi
}

usage() {
	echo "$0 [ start | stop | restart | status ]"
}

case $1 in
	start)
		start_tunnel $2
	;;
	stop)
		stop_tunnel
	;;
	restart)
		stop_tunnel
		start_tunnel $2
	;;
	status)
		tunnel_status 1
	;;
	*)
		usage
		exit 1
esac

