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
$(warning $(FILTER) is used.)
endif

#$(printf "\e[1;32m$(LOG_HEADER_FORMAT)\e[0m\n" $(LOG_HEADER_ITEM))

pdfs := $(sort $(wildcard *.pdf))
text := $(pdfs:%.pdf=.%.txt)
csvs := $(pdfs:%.pdf=.%.csv)

text_exist := $(wildcard .*.txt)
csvs_exist := $(wildcard .*.csv)

nfiles  ?= $(words $(pdfs))
tmpfile	:= $(shell mktemp -u)
VERBOSE_LOG ?= $(tmpfile).annual_report

all: $(REPORT) FORCE
	@printf "To run '\e[0;32mmake lastlog\e[0m' to view log contents of last build.\n"

$(REPORT): $(csvs)
	@echo $(REPORT_HEADER) | xargs printf "$(LINE_FORMAT)\n"  > $@
	@$(MERGE) $^ >> $@
	@printf "Detail Log is saved in \e[0;32m'%s'\e[0m\n" "$(VERBOSE_LOG)"

%.csv: %.txt $(MAKEFILE_LIST) $(FILTER)
	@$(FILTER) $< $(VERBOSE_LOG) > $@

#@printf "[%3d%%] \e[0;32mAnalysing %s\e[m\n" $$((($$(ls -1 .*.csv 2>/dev/null | wc -l) + 1) * 100 / $(nfiles))) $<
#%.txt: PDF_FLAGS := -raw
%.txt: PDF_FLAGS := -q -layout
.%.txt: %.pdf
	@printf "[%3d%%] \e[0;32mConverting %s\e[m\n" $$((($$(ls -1 .*.txt 2>/dev/null | wc -l) + 1) *100 / $(nfiles))) $<
	@$(PDF2TXT) $(PDF_FLAGS) $< $@
	@$(SED) -Ei '/ {10,}|^[ 0-9\/]*$$/d' $@

%.pdf:
	@echo "No command to download $@"
	@true

%.txt.1.sed: %.csv FORCE
	cat $@

%.txt.4.sed: %.csv FORCE
	cat $@

clean:
	@rm -rf .*.csv .*.txt.sed

distclean: clean
	@rm -rf .*.txt

lastlog:
	@less `ls -1rt $(dir $(tmpfile))tmp.*.annual_report | tail -1`

listlog:
	@ls -Glrt $(dir $(tmpfile))tmp.*.annual_report

cleanlog:
	@rm $(dir $(tmpfile))tmp.*.annual_report

-include helper.mk

.PHONY: clean distclean FORCE
.SECONDARY: $(text)
