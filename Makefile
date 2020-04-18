.SUFFIXES:

PDF2TXT := $(shell which pdftotext)
FILTER  := $(shell which report 2>/dev/null)
REPORT	:= report.csv
MERGE	:= cat

REPORT_HEADER		:= code date unit 2019  2018  rate  profit name
LINE_FORMAT 	:= %6s, %8s, %7s, %20s, %20s, %10s, %8s,   %-20s
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

all: $(REPORT)

$(REPORT): $(csvs)
	@echo $(REPORT_HEADER) | xargs printf "$(LINE_FORMAT)\n"  > $@
	@$(MERGE) $^ >> $@

%.csv: %.txt $(MAKEFILE_LIST) $(FILTER)
	@$(FILTER) $< $(VERBOSE_LOG) > $@

#@printf "[%3d%%] \e[0;32mAnalysing %s\e[m\n" $$((($$(ls -1 .*.csv 2>/dev/null | wc -l) + 1) * 100 / $(nfiles))) $<
#%.txt: PDF_FLAGS := -raw
%.txt: PDF_FLAGS := -q -layout
.%.txt: %.pdf
	@printf "[%3d%%] \e[0;32mConverting %s\e[m\n" $$((($$(ls -1 .*.txt 2>/dev/null | wc -l) + 1) *100 / $(nfiles))) $<
	@$(PDF2TXT) $(PDF_FLAGS) $< $@
	@sed -Ei '/ {10,}|^[ 0-9\/]*$$/d' $@

%.pdf:
	@echo "No command to download $@"
	@true

clean:
	@rm -rf .*.csv .*.txt.sed

distclean: clean
	@rm -rf .*.txt

-include helper.mk

.PHONY: clean distclean
.SECONDARY: $(text)
