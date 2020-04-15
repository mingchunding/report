#!/bin/sh

debug=/dev/stderr

SED=`which sed`
JOIN_LINE_FOR_NDIGIT='/[^0-9]$/{N;s/\n//};'
JOIN_LINES_BY_DIGITS='/[0-9]\$/{N;s/\n[^0-9].*//;s/\n/ /}'
TRIM_BLANKS='s/^ *//;s/ +/ /g;'
val={}
idx=0

function parser1()
{
	loc1="主要(会计数据和财务指标|會計數據和財務指標|财务数据)"
	loc2="(营业|營業)收入"
	year=$($SED -nE "/$loc1/,\${/[0-9]{4} *年/{s/([0-9]{4} *年).*/\1/;p;q}}" $1)
	unit=$($SED -nE "/$loc1/,\${/.*([单單]位：|人民币[百千万]*元)/{/：\$/{N;s/\n//};s/.*([单單]位： *|人民币)(\w*元).*/\2/;p;q}}" $1)

	case ${unit/人民币/} in
		元) unit=1 ;;
		千元) unit=1000 ;;
		万元) unit=10000 ;;
		百万元) unit=1000000 ;;
		*) echo "unrecongnized unit: $unit in file $1" > $2
		unit=1 ;;
	esac
	val[$idx]=${unit} && idx=$(expr $idx + 1)

	line=$($SED -nE "/$loc1/,\${/$loc2/{=;q}};\$=" $1)
	cmd="$line{{/\.\$/N;s/\n//};"$JION_LINES_BY_DIGITS\;$TRIM_BLANKS'p;q;}'
	d=$(${SED} -nE "$cmd" $1)
	printf "%-25s +%.8d: %s\n" $1 $line "$d" > $2
	incoming1=$(echo "$d" | cut -d' ' -f2)
	incoming2=$(echo "$d" | cut -d' ' -f3)
	incoming_incr_rate=$(echo "$d" | cut -d' ' -f4)
	val[$idx]=${incoming1//,/} && idx=$(expr $idx + 1)
	val[$idx]=${incoming2//,/} && idx=$(expr $idx + 1)
}

function parser2()
{
	for loc in "扣除非(经|經)常性(损益后|損益後)的" "稀(释|釋)每股收益"
	do
		line=$($SED -nE "/$loc/{=;q};\$=" $1)
		cmd="$line{"$JOIN_LINE_FOR_NDIGIT$TRIM_BLANKS'p;q}'
		d=$(${SED} -nE "$cmd" $1)
		printf "%-25s +%.8d: %s\n" $1 $line "$d" > $2
		incpp=$(echo "$d" | cut -d' ' -f2)
		val[$idx]=${incpp} && idx=$(expr $idx + 1)
		[[ "x$incpp" != "x" ]] && return || idx=$(expr $idx - 1)
	done
}

code=${1%%_*}
dt=${1#*_}
dt=${dt%.*}
val[$idx]=${code#.} 		&& idx=$(expr $idx + 1)
val[$idx]=${dt%%_*} 		&& idx=$(expr $idx + 1)

parser1 $1 /dev/null #$debug #
parser2 $1 /dev/null #$debug #

echo ${val[@]} | xargs printf "${LINE_FORMAT}\n"
