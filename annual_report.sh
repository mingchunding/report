#!/bin/sh

debug=${2:-/dev/null}

[[ "`uname -s`" = "Darwin" ]] && SED=`which gsed` || SED=`which sed`

JOIN_LINE_FOR_NDIGIT='/[^0-9]$/{N;s/\n//}'
JOIN_LINES_BY_DIGITS='/[0-9]$/{N;s/\n[^0-9].*//;s/\n/ /}'
RM_LABEL_DIGIT='s/([^0-9 ]) [0-9]([^0-9])/\1  \2/'
TRIM_BLANKS='s/^ *//;s/ +/ /g'
val={}
idx=0

function parser1()
{
	log=$1.sed

	loc1='主要(会计数据和财务指标|會計數據和財務指標|财务数据)'
	loc2='(营业|營業)收入'
	th1='主要会计$|[本报告期比上年同期增减（%）]{4,}$|主要会计数据 *[0-9]{4} *年'
	th2='([ 本期比上年同期增减]*[0-9]{4}){2,}'
	th3='[0-9]{4} *年末? *本期'
	th4='(.+ 调整[前后]){2,}'
	inps0='扣除非(经|經)常性(损益后|損益後)[的基]'
	inps1='扣除非经經常性损益后損益後的基本每股收益\(（元／\/股）\)'
	inps2='稀(释|釋)每股收益'
#	year=$($SED -nE "/$loc1/,\${/[0-9]{4} *年/{s/([0-9]{4} *年).*/\1/;p;q}}" $1)

	d=($($SED -nE '/'$loc1'/,${
		:r0
		/[单單位：人民币:百千万]+ *元/{
			x
			/^$/!{x;br1};g			# skip when hold space is not empty
			/：\$/{N;s/\n//}		# append next line
			s/ +//g				# strip blanks
#			w '$log'
			s/.*[单單位：人民币:]+(.*元).*/\1/
			x				# retrieve origin and continue others
		}
		:r1
		/'"$th1"'|'"$th2"'|'"$th3"'|'"$th4"'/{
#			x;/^:r3$/{x;br3};x
			:r1a
## workaround to parse unit inside table header
			/[单單位：人民币:]+.*元/{
				x
				/^$/{
					g
					/：\$/{N;s/\n//}
					s/ *//g
#					w '$log'
					s/.*[单單位：人民币:]+(.*元).*/\1/
				}
				x
			}
			w '$log'
			n
			/ +[本期比上年同期增减\(（%）\)]+$/br1a
			br0
		}
		/'${loc2}'/{
			x				# exchange origin in current and unit in hold space
			/^:r3$/{x;br3}			# goto next field
			/^$/s/.*/未知/			# unit is not found
			=				# print line number
			w '$log'
			p;x				# print unit and retrieve origin line
			/\.\$/N;s/\n//			# append one more line when end with "."
			'"$JOIN_LINES_BY_DIGITS"'	# append one more line when end with number
			'"$TRIM_BLANKS"'		# strip useless blanks
			s/（.*）//g			# strip comments
			w '$log'
			p				# print current contents
			s/^.*$/:r3/			# mark flag to next step
			x				# save flag to hold space
			b				# branch to end of script to continue
		}
		:r3
		/'"${inps0}"'/{
			'"${RM_LABEL_DIGIT}"'
			'"${JOIN_LINE_FOR_NDIGIT}"'
			s/^ +//
			x
			:r3a;n
			/^[0-9\. 不适用]+$/{H;x;s/\n/ /g;x;br3a}
			/^ *['"${inps1}"']+ *$/{
				s/ +//g
				H
				x
				s/^([^0-9\. ]+) ([^\n]+)\n(['"${inps1}"']+)$/\1\3 \2/
				x
			}
			x
			w '$log'
			y/\(\/\)/（／）/
			'"${TRIM_BLANKS}"'
			q
		}
	}' $1))

	[[ ${#d[@]} -gt 5 ]] && [[ "${d[5]/,/}" = "${d[5]}" ]] && d=("${d[@]:0:5}" "-" "${d[@]:5}")
	FORMAT="%-25s +%.8d: %*s %5s %20s %20s %20s"
	[[ ${#d[@]} -gt 5 ]] && FORMAT="${FORMAT} %8s"
	for ((i=7; i<${#d[@]}; i++)) do
		FORMAT="${FORMAT} %20s"
	done
	[[ $# -gt 1 ]] && printf "${FORMAT}\n" $1 ${d[0]} $((6 + ${#d[1]})) ${d[@]:1} >> $2

	case ${d[1]} in
		元)	unit=1 ;;
		千元)	unit=1000 ;;
		万元)	unit=10000 ;;
		百万元) unit=1000000 ;;
		*)	printf "\e[0;31m[Warning] unrecongnized unit\e[m (assume as 1): %s in file %s\n" \
				${d[1]} "$1" > /dev/stderr
			unit=1 && d[1]=元;;
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
		[[ $# -gt 1 ]] && printf "%-25s +%.8d: %s\n" $1 ${d[0]} "`echo ${d[@]:1}`" >> $2
		[[ ${#d[@]} -gt 2 ]] && val[$idx]=${d[2]} && idx=$(expr $idx + 1) && return
	done
}

function parser3()
{
	d=$($SED -nE '/公司简称：/{=;s/.*公司简称： *(.+)$/\1/;p;q}' $1)
	line=$(echo "$d" | $SED -n '1p')
	[[ -z $line ]] && line=0
	[[ $line -gt 0 ]] && d=$(echo "$d" | $SED -n '$p') || d="N/A"
	[[ $# -gt 1 ]] && printf "%-25s +%.8d: %s\n" $1 $line "$d" >> $2
	val[$idx]=\"$d\" && idx=$(expr $idx + 1)
}

function parser4()
{
	[[ $# -gt 2 ]] && log=$3 || log=$(mktemp -u)
	p="[派发送發現现金分配红为股利息含税不低于人民币约]"
	d=($($SED -nE '/主要(会计|财务)数据/q		# searching till here
		/^/b					# ignore line if footer (begin with ^L ?)
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

	[[ $# -gt 1 ]] && printf "%-25s +%.8d: %s\n" $1 ${d[0]:-0} "`echo ${d[@]:1}`" >> $2
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

parser1 $1 $debug
parser2 $1 $debug
parser4 $1 $debug
parser3 $1 $debug

echo ${val[@]} | xargs printf "${LINE_FORMAT}\n"
