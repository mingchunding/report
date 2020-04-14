#!/bin/sh

debug=/dev/stderr

SED=`which sed`

code=${1%%_*}

function parser1()
{
	loc1="主要会计数据和财务指标|主要會計數據和財務指標|主要财务数据"
	loc2="营业收入|營業收入|营业收入"
	year=$($SED -nE "/$loc1/,\${/[0-9]{4} *年/{s/([0-9]{4} *年).*/\1/;p;q}}" $1)
	unit=$($SED -nE "/$loc1/,\${/.*([单單]位：|人民币[百千万]*元)/{/：\$/{N;s/\n//};s/.*([单單]位： *|人民币)(\w*元).*/\2/;p;q}}" $1)

	case ${unit/人民币/} in
		元)
		unit=1
		;;
		千元)
		unit=1000
		;;
		万元)
		unit=10000
		;;
		百万元)
		unit=1000000
		;;
		*)
		echo "unrecongnized unit: $unit in file $1" > $2
		unit=1
		;;
	esac

	line=$($SED -nE "/$loc1/,\${/$loc2/{=;q}}" $1)
	echo "Line #$line in file $1" > $2
	cmd="$line{{/\.\$/N;s/\n//};/[0-9]\$/{N;s/\n[^0-9].*//;s/\n/ /};s/^ *//;s/ +/ /g;p;q;}"
	d=$(${SED} -nE "$cmd" $1)
	echo $d > $2
	incoming1=$(echo "$d" | cut -d' ' -f2)
	incoming2=$(echo "$d" | cut -d' ' -f3)
	incoming_incr_rate=$(echo "$d" | cut -d' ' -f4)
}

function parser2()
{
	loc1="扣除非(经常性损益后|經常性損益後)的"
	cmd="/$loc1/{/[^0-9]\$/{N;s/\n//};s/^ *//;s/ +/ /g;p;q}"
	d=$(${SED} -nE "$cmd" $1)
	printf "%-25s 0: %s\n" $1 "$d" > $2
	incpp=$(echo "$d" | cut -d' ' -f2)
	[[ "x$incpp" != "x" ]] && return

	loc1="(稀释|稀釋)每股收益"
	cmd="/$loc1/{s/^ *//;s/ +/ /g;p;q}"
	d=$(${SED} -nE "$cmd" $1)
	printf "%-25s 1: %s\n" $1 "$d" > $2
	incpp=$(echo "$d" | cut -d' ' -f2)
}

parser1 $1 /dev/null
parser2 $1 $debug

dt=${1#*_}
dt=${dt%.*}
printf "%s, %8s, %7s, %20s, %20s, %10s\n" ${code/\./} ${dt%%_*} $unit ${incoming1//,/} ${incoming2//,/} $incpp
