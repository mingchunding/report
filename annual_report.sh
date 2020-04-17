#!/bin/sh

debug=/dev/stderr

SED=`which sed`
JOIN_LINE_FOR_NDIGIT='/[^0-9]$/{N;s/\n//}'
JOIN_LINES_BY_DIGITS='/[0-9]$/{N;s/\n[^0-9].*//;s/\n/ /}'
TRIM_BLANKS='s/^ *//;s/ +/ /g'
val={}
idx=0

function parser1()
{
	[[ $# -gt 2 ]] && log=$3 || log=$(mktemp -u)

	loc1="主要(会计数据和财务指标|會計數據和財務指標|财务数据)"
	loc2="(营业|營業)收入"
#	year=$($SED -nE "/$loc1/,\${/[0-9]{4} *年/{s/([0-9]{4} *年).*/\1/;p;q}}" $1)

	d=($($SED -nE '/'$loc1'/,${
		/[单單位：人民币:百千万]+ *元/{
			x;/^$/!{x;t};x;h
			/：\$/{N;s/\n//}
			s/ *//g
			s/.*[单單位：人民币:]+(\w*元).*/\1/
			x
		}
		/'${loc2}'/{
			#w '$log$1'
			=				# print line number
			x;/^$/{s/.*/NA/};p;x		# check unit
			/\.\$/N;s/\n//
			'"$JOIN_LINES_BY_DIGITS"'
			'"$TRIM_BLANKS"'
			p
			q
		}
	}' $1))

	printf "%-25s +%.8d: %-4s %s\n" $1 ${d[0]} ${d[1]} "`echo ${d[@]:2}`" > $2

	case ${d[1]} in
		元)	unit=1 ;;
		千元)	unit=1000 ;;
		万元)	unit=10000 ;;
		百万元) unit=1000000 ;;
		*)	printf "\e[0;31m[Warning] unrecongnized unit\e[m (assume as 1): %s in file %s\n" \
				${d[1]} "$1" > /dev/stderr
			unit=1 ;;
	esac
	val[$idx]=${unit} && idx=$(expr $idx + 1)

	for o in 3 4; do
		val[$idx]=${d[$o]//,/} && idx=$(expr $idx + 1)
	done
}

function parser2()
{
	for loc in "扣除非(经|經)常性(损益后|損益後)的" "稀(释|釋)每股收益"
	do
		d=($(${SED} -nE '/'$loc'/{=
			'"$JOIN_LINE_FOR_NDIGIT"';'"$TRIM_BLANKS"';p;q};$=
		' $1))
		printf "%-25s +%.8d: %s\n" $1 ${d[0]} "`echo ${d[@]:1}`" > $2
		[[ ${#d[@]} -gt 2 ]] && val[$idx]=${d[2]} && idx=$(expr $idx + 1) && return
	done
}

function parser3()
{
	d=$($SED -nE '/公司简称：/{=;s/.*公司简称： *(.+)$/\1/;p;q}' $1)
	line=$(echo "$d" | $SED -n '1p')
	[[ -z $line ]] && line=0
	[[ $line -gt 0 ]] && d=$(echo "$d" | $SED -n '$p') || d="N/A"
	printf "%-25s +%.8d: %s\n" $1 $line "$d" > $2
	val[$idx]=\"$d\" && idx=$(expr $idx + 1)
}

function parser4()
{
	[[ $# -gt 2 ]] && log=$3 || log=$(mktemp -u)
	p="[派发送發現现金分配红为股利息含税不低于人民币约]"
	d=($($SED -nE '/主要(会计|财务)数据/q		# searching till here
		/^/t					# ignore line if footer (begin with ^L ?)
		H;x					# append and exchange staging with current line
		s/[ \n]*//g				# delete all blanks and line break
		/每.{0,2}股'$p'*[0-9\.]+元/!t		# mismatch searching pattern
		#w '${log}2${1##*/}'
		s/.*(每.{0,2}股'$p'*)([0-9\.]+)(元).*/\1 \2 \3/ 	# transform
		=					# print line number
		p					# print searching result
		#w '${log}${1##*/}'
		q					# quit
	' $1))

	printf "%-25s +%.8d: %s\n" $1 ${d[0]:-0} "`echo ${d[@]:1}`" > $2
	[[ ${#d[@]} -gt 2 ]] && v=${d[2]} && \
	case ${d[1]:1:2} in
		10|十股) ;;
		*) v=$v*10;;
	esac || v=0

	val[$idx]=$v && idx=$(expr $idx + 1)
}

code=${1%%_*}
dt=${1#*_}
dt=${dt%.*}
val[$idx]=${code#.} 		&& idx=$(expr $idx + 1)
val[$idx]=${dt%%_*} 		&& idx=$(expr $idx + 1)

parser1 $1 /dev/null #$debug #
parser2 $1 /dev/null #$debug #
parser4 $1 /dev/null #$debug    #sedlog #
parser3 $1 /dev/null #$debug #

echo ${val[@]} | xargs printf "${LINE_FORMAT}\n"
