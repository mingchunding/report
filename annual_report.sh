#!/bin/sh

debug=/dev/stderr

SED=`which sed`

code=${1%%_*}

function parser1()
{
	loc1="近三年主要会计数据和财务指标"
	loc2="营业收入|资产总额"
	year=$($SED -nE "/$loc1/,\${/[0-9]{4} *年/{s/([0-9]{4} *年).*/\1/;p;q}}" $1)
	unit=$($SED -nE "/$loc1/,\${/.*单位：/{s/.*单位： *(\w*元).*/\1/;p;q}}" $1)

	case ${unit/人民币/} in
		元)
		unit=1
		;;
		万元)
		unit=10000
		;;
		百万元)
		unit=1000000
		;;
		*)
		echo "unrecongnized unit: $unit in file $1" > $debug
		unit=1
		;;
	esac

	line=$($SED -nE "/$loc1/,\${/$loc2/{=;q}}" $1)
	echo "Line #$line in file $1" > $debug
	cmd="$line{{/\.\$/N;s/\n//};/[0-9]\$/{N;s/\n[^0-9].*//;s/\n/ /};s/^ *//;s/ +/ /g;p;q;}"
	d=$(${SED} -nE "$cmd" $1)
	echo $d > $debug
	incoming1=$(echo "$d" | cut -d' ' -f2)
	incoming2=$(echo "$d" | cut -d' ' -f3)
	incoming_incr_rate=$(echo "$d" | cut -d' ' -f4)
}

parser1 $1

printf "%s, %7s, %20s, %20s\n" ${code/\./} $unit ${incoming1//,/} ${incoming2//,/} 
