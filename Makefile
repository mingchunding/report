.SUFFIXES:

PDF2TXT := $(shell which pdftotext)
FILTER  := $(shell which report 2>/dev/null)
REPORT	:= report.csv
MERGE	:= cat

ifeq ($(shell uname -s),Darwin)
SED	:= $(shell which gsed)
else
SED	:= $(shell which sed)
endif

REPORT_HEADER	:= code date unit 2019  2018  rate2019  rate2018 profit name
LINE_FORMAT 	:= %6s, %8s, %7s, %20s, %20s, %10s, %10s, %8s,   %s
export LINE_FORMAT

LOG_HEADER_FORMAT:= %-25s  %8s  %6s %-8s %20s %20s %20s  %7s %20s
LOG_HEADER_ITEM  := File  Line Unit Item 2019 2018 2018 Rate 2017

ifneq ($(words $(LINE_FORMAT)),$(words $(REPORT_HEADER)))
$(error REPORT_HEADER format and NAME string mismatch.)
endif

ifeq ($(PDF2TXT),)
$(error pdftotext not found.)
endif

ifeq ($(FILTER),)
FILTER := $(wildcard ./annual_report.sh)
ifeq ($(MAKELEVEL),0)
$(warning $(FILTER) is used.)
endif
endif

#$(printf "\e[1;32m$(LOG_HEADER_FORMAT)\e[0m\n" $(LOG_HEADER_ITEM))

pdfs := $(sort $(wildcard *.[Pp][Dd][Ff]))
text := $(pdfs:%.pdf=.%.txt)
csvs := $(pdfs:%.pdf=.%.csv)

text_exist := $(wildcard .*.txt)
csvs_exist := $(wildcard .*.csv)

nfiles  ?= $(words $(pdfs))
tmpfile	:= $(shell mktemp -u)
VERBOSE_LOG ?= $(tmpfile).annual_report

define CREATE_PDF2TXT_CFG
	echo "%.txt: PDF_FLAGS := -q -layout -nopgbrk" && \
	echo "PDF2TEXT_POST_SED:='/^ {10,}|^[ 0-9\/]*\$$\$$/d'"
endef
$(shell test -f .pdf2txt.cfg || ($(call CREATE_PDF2TXT_CFG) > .pdf2txt.cfg))
include .pdf2txt.cfg

define PRINT_TIPS
	ITEM="$(1)" && w=$${#ITEM} &&\
	printf "To run \'\e[0;32mmake %s\e[0m'%*s view %-*s data in last build.\n" \
	$1 $$((15 - $$w)) 'to' 12 "$(patsubst last%,% contents,$(1:raw_%=raw %))"

endef

all: $(REPORT) FORCE
	@$(MAKE) hint

%.csv: %.utf8.csv
	@iconv -f UTF-8 -t GB2312 $< | unix2dos > $@

report.utf8.csv: $(csvs)
	@echo $(REPORT_HEADER) | xargs printf "$(LINE_FORMAT)\n"  > $@
	@$(MERGE) $^ >> $@
	@printf "Detail Log is saved in \e[0;32m'%s'\e[0m\n" "$(VERBOSE_LOG)"

%.csv: %.txt $(firstword $(MAKEFILE_LIST)) $(FILTER)
	@$(FILTER) $< $(VERBOSE_LOG) > $@

.%.txt: %.pdf .pdf2txt.cfg
	@printf "[%3d%%] \e[0;32mConverting %s\e[m\n" $$((($$(ls -1 .*.txt 2>/dev/null | wc -l) + 1) *100 / $(nfiles))) $<
	@$(PDF2TXT) $(PDF_FLAGS) $< $@
	@$(SED) -Ei $(PDF2TEXT_POST_SED) $@

%.pdf:
	@echo "No command to download $@"
	@true

define DEBUG_PARSER
.%.txt.$(1).sed: .%.csv FORCE
	@cat $$@
	@echo
endef
$(foreach i,1 2 3 4,$(eval $(call DEBUG_PARSER,$(i))))

clean:
	@rm -rf .*.csv .*.txt.*.sed

distclean: clean
	@rm -rf .*.txt

lastlog:
	@less `ls -1rt $(dir $(tmpfile))tmp.*.annual_report | tail -1`

raw_profit:   KEYS := '稀释|扣除'
raw_incoming: KEYS := '营业[总]?收入'
raw_bonus:    KEYS := '每.*股.*元$$'
raw_name:     KEYS := '股票名称'
raw_%:
	@grep -E ${KEYS} `ls -1rt $(dir $(tmpfile))tmp.*.annual_report | tail -1` | sort | less

listlog:
	@ls -Glrt $(dir $(tmpfile))tmp.*.annual_report

cleanlog:
	@rm $(dir $(tmpfile))tmp.*.annual_report

HINT_GOALS := lastlog raw_incoming raw_profit raw_bonus raw_name
hint:
	@$(foreach p,$(HINT_GOALS),$(call PRINT_TIPS,$(p)))

-include helper.mk

.PHONY: clean distclean hint FORCE
.SECONDARY: $(text)
