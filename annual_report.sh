#!/bin/sh

debug=${2:-/dev/null}

[[ "`uname -s`" = "Darwin" ]] && SED=`which gsed` || SED=`which sed`

JOIN_LINE_FOR_NDIGIT='/[^0-9]$/{N;s/\n *(（)/\1/;s/\n//}'
JOIN_LINES_BY_DIGITS='/[0-9]$/{N;s/\n[^0-9].*//;s/\n/ /}'
RM_LABEL_DIGIT='s/([^0-9 ]) [0-9]([^0-9])/\1  \2/'
TRIM_BLANKS='s/^ *//;s/ +/ /g'
val={}
idx=0
loc1='主要(会计|财务|會計|財務)(数据|數據)[和与](会计|财务|會計|財務)(指标|指標)'
profit_items=('扣除非(经|經)常性(损|損)益(后|後)(的)?基本每股收益' '稀(释|釋)每股收益')
ac_need=(17 7)
ac_done=(21 11)
suffix='(\(|（)元(／|\/)股(）|\))'
s=$($SED -nE '/'"$loc1"'$/{=;q}' "$1")
s=${s:=200}

function parser1()
{
	log=$1.1.sed

	loc2='(营业|營業)[总]?收入'
	th1='主要会计$|[本报告期比上年同期增减（%）]{4,}$|主要会计数据 *[0-9]{4} *年'
	th2='([ 本期比上年同期增减]*[0-9]{4}){2,}'
	th3='[0-9]{4} *年末? *本期'
	th4='(.+ 调整[前后]){2,}'
#	year=$($SED -nE "/$loc1/,\${/[0-9]{4} *年/{s/([0-9]{4} *年).*/\1/;p;q}}" $1)

	p=${profit_items[0]}
	loc=$p${suffix}
	ac_min=${ac_need[0]}		# suffix is partial
	ac_max=${ac_done[0]}		# suffix is completed

	d=($($SED -nE ''$s',+200{
		:r0
		/[单單位：人民币:百千万]+ *元/{
			x
			/^$/!{x;br1};g			# skip when hold space is not empty
			/：\$/{N;s/\n//}		# append next line
			s/ +//g				# strip blanks
#			w '$log'
			s/.*[单單位：人民币:]+(.*元).*/\1/
			s/^.{6,}$//			# wrong data
			/^$/!w '$log'
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
		/^[ ]*'${loc2}'/{
			x				# exchange origin in current and unit in hold space
			/^:r3$/{x;br3}			# goto next field
			/^$/{
				g
				w '$log'
				s/.*[\(（](.+)[）\)].*/\1/;
				/.+/tr2b		# unit is here
				/^$/s/.*/未知/		# unit is not found
				:r2b
			}
			=				# print line number
			w '$log'
			p;x				# print unit and retrieve origin line
			/\.\$/N;s/\n//			# append one more line when end with "."
			'"$JOIN_LINES_BY_DIGITS"'	# append one more line when end with number
			'"$TRIM_BLANKS"'		# strip useless blanks
			w '$log'
			s/（.*）//g			# strip comments
			/[^ ]+ ([^ ]{8,} ){3}/!s/([^ ]+ ?)/\? &/4
			s/(([^ ]+ ){5}).*/\1/
			w '$log'
			p				# print current contents
			s/^.*$/:r3/			# mark flag to next step
			x				# save flag to hold space
			b				# branch to end of script to continue
		}
		:r3
		/^ *'"${loc:0:10}"'/{
			'"${RM_LABEL_DIGIT}"'
			'"${JOIN_LINE_FOR_NDIGIT}"'
			s/^ +//
			x
			:r3a;n
			/^[0-9\. 不适用]+$/{H;x;s/\n/ /g;x;br3a}
			w '${log}'
			/^[ ]*['"${loc}"']+ *$/{
				s/[ ]+//g
				H
				w '${log}'
				x
				s/^([^ ]+) ([^\n]+)\n([^ ]+)$/\1\3 \2/
				x
			}
			x
			/^'"$p"'/!{s/^.*$/:r3/;x;br3}
			w '${log}'
			s/(收益)\(?[0-9]+\)? /\1 /	# remove comments
			/^[^ ]{'$ac_min'}/{		# complete perfect but unnecessary
				/^[^ ]{'$ac_max'}/!{
					N
					s/^([^ ]+) ([^\n]+)\n *([^ ]+) *$/\1\3 \2/
					s/\n.*//	# remove addition line if mismatch
				}
			}
			'"${TRIM_BLANKS}"'
			=
			w '$log'
			y/\(\/\)/（／）/
			p
			q
		}
	}' $1))

	[[ ${#d[@]} -lt 5 ]] && return 255

	#[[ ${#d[@]} -gt 5 ]] && [[ "${d[5]/,/}" = "${d[5]}" ]] && d=("${d[@]:0:5}" "-" "${d[@]:5}")
	FORMAT="%-25s +%.8d: %*s %*s %20s %20s %20s %8s"
	w1=${d[1]//\w/}
	w2=${d[2]//\w/}
	d=(${d[0]} $((6 + ${#w1})) ${d[1]} $((10 + ${#w2})) ${d[@]:2})
	[[ $# -gt 1 ]] && printf "${FORMAT}\n" $1 ${d[@]:0:9} >> $2

	case ${d[2]} in
		元)	unit=1 ;;
		千元)	unit=1000 ;;
		万元)	unit=10000 ;;
		百万元) unit=1000000 ;;
		*)	printf "\e[0;31m[Warning] unrecongnized unit\e[m (assume as 1): %s in file %s\n" \
				${d[2]} "$1" > /dev/stderr
			unit=? && d[2]=元;;
	esac
	val[$idx]=${unit} && idx=$(expr $idx + 1)

	for o in 5 6; do
		v=${d[$o]:-?}
		val[$idx]=${v//,/} && idx=$(expr $idx + 1)
	done

	[[ ${#d[@]} -lt 12 ]] && return 0

	# parse profit
	d=(${d[@]:9})
	FORMAT="%-25s +%.8d: %-*s"
	for ((i=2; i<${#d[@]}; i++)) do
		FORMAT="${FORMAT} %10s"
	done
	d[1]=${d[1]/╱/／}
	d=(${d[0]} $((42 + ${#d[1]})) ${d[@]:1})
	[[ $# -gt 1 ]] && printf "${FORMAT}\n" $1 ${d[@]} >> $2

	for o in 3 4; do
		v=${d[$o]:-?}
		val[$idx]=${v//,/} && idx=$(expr $idx + 1)
	done

	return 0
}

function parser2()
{
	log=$1.2.sed

	for ((j=1; j<${#profit_items[@]}; j++))
	do
		p=${profit_items[$j]}
		loc=$p${suffix}
		ac_min=${ac_need[$j]}		# suffix is partial
		ac_max=${ac_done[$j]}		# suffix is completed
		#echo "Searching $loc" > /dev/stderr
		d=($($SED -nE ''$s',+200{
			:r3
			/'"${loc:0:10}"'/!b
			s/.*('"${loc:0:10}"')/\1/
			'"${RM_LABEL_DIGIT}"'
			'"$JOIN_LINE_FOR_NDIGIT"'
			s/^ +//
			w '${log}'
			x
			:r3a;n
			/^[0-9\. 不适用]+$/{H;x;s/\n/ /g;x;br3a}
#			w '${log}'
			/^ *['"${loc}"']+ *$/{
				s/ +//g
				H
#				w '${log}'
				x
				s/^([^ ]+) ([^\n]+)\n([^ ]+)$/\1\3 \2/
				x
			}
			x
			/^'"$p"'/!{x;br3}
			w '${log}'
			s/(收益) *\([0-9]+\) /\1 /	# remove possible numberic label?
			/^[^ ]{'$ac_min'}/{		# complete perfect but unnecessary
				/^[^ ]{'$ac_max'}/!{
					N
					s/^([^ ]+) ([^\n]+)\n *([^ ]+) *$/\1\3 \2/
					s/\n.*//	# remove addition line if mismatch
				}
			}
			'"$TRIM_BLANKS"'
			w '${log}'
			=
			y/\(\/\)/（／）/
			p;q;};$=
		' $1))

		FORMAT="%-25s +%.8d: %-*s"
		for ((i=2; i<${#d[@]}; i++)) do
			FORMAT="${FORMAT} %10s"
		done
		d[1]=${d[1]/╱/／}
		d=(${d[0]} $((42 + ${#d[1]})) ${d[@]:1})
		[[ $# -gt 1 ]] && printf "${FORMAT}\n" $1 ${d[@]} >> $2

		[[ ${#d[@]} -gt 3 ]] && val[$idx]=${d[3]} && idx=$(expr $idx + 1)
		[[ ${#d[@]} -gt 4 ]] && val[$idx]=${d[4]} && idx=$(expr $idx + 1) && return 0
	done

	return 255
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
	log=$1.4.sed
	p="[派发送發現现金分配红为股利息含税不低于人民币约]"
	d=($($SED -nE '/主要(会计|财务)数据/q		# searching till here
		/^/b					# ignore line if footer (begin with ^L ?)
		H;x					# append and exchange staging with current line
		s/[ \n]*//g				# delete all blanks and line break
		/每.{0,2}股'$p'*[0-9\.]+元/!t		# mismatch searching pattern
		w '${log}'
		s/.*(每.{0,2}股'$p'*)([0-9\.]+)(元).*/\1 \2 \3/ 	# transform
		=					# print line number
		p					# print searching result
		w '${log}'
		q					# quit
	' $1))

	FORMAT="%-25s +%.8d:"
	if [ ${#d[@]} -gt 1 ]; then
		w=${d[1]//[0-9]/}
		w=$((${#w} + 24))		# plus max len of UTF-8 Characters
		d=(${d[0]} $w ${d[@]:1})
		FORMAT="${FORMAT} %-*s %6s %s"
	fi
	[[ $# -gt 1 ]] && printf "${FORMAT}\n" $1 ${d[@]} >> $2
	[[ ${#d[@]} -gt 3 ]] && v=${d[3]} && \
	case ${d[2]:1:2} in
		10|十股) ;;
		*) v=$v*10;;
	esac || v=0

	val[$idx]=$v && idx=$(expr $idx + 1)

	return 0
}

f=${1##*/}
code=${f%%_*}
dt=${f#*_}
dt=${dt%.*}
val[$idx]=${code#.} 		&& idx=$(expr $idx + 1)
val[$idx]=${dt%%_*} 		&& idx=$(expr $idx + 1)

parser1 $1 $debug
while [ $idx -lt 5 ]; do val[$idx]='\?' && idx=$(expr $idx + 1); done
[[ $idx -lt 7 ]] && parser2 $1 $debug
while [ $idx -lt 7 ]; do val[$idx]='\?' && idx=$(expr $idx + 1); done
parser4 $1 $debug
parser3 $1 $debug

echo ${val[@]} | xargs printf "${LINE_FORMAT}\n"
