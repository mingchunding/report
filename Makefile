.SUFFIXES:

PDF2TXT := $(shell which pdftotext)
FILTER  := $(shell which report)
REPORT	:= report.csv
MERGE	:= cat

HEADER		:= code date unit 2019  2018  rate  profit name
LINE_FORMAT 	:= %6s, %8s, %7s, %20s, %20s, %10s, %8s,   %-20s
export LINE_FORMAT

ifneq ($(words $(LINE_FORMAT)),$(words $(HEADER)))
$(error HEADER format and NAME string mismatch.)
endif

ifeq ($(PDF2TXT),)
$(error pdftotext not found.)
endif

ifeq ($(FILTER),)
FILTER := $(wildcard ./annual_report.sh)
$(warning $(FILTER) is used.)
endif

pdfs := $(sort $(wildcard *.pdf))
text := $(pdfs:%.pdf=.%.txt)
csvs := $(pdfs:%.pdf=.%.csv)

text_exist := $(wildcard .*.txt)
csvs_exist := $(wildcard .*.csv)

nfiles := $(words $(pdfs))

all: $(REPORT)

$(REPORT): $(csvs)
	@echo $(HEADER) | xargs printf "$(LINE_FORMAT)\n"  > $@
	@$(MERGE) $^ >> $@

%.csv: %.txt $(MAKEFILE_LIST) $(FILTER)
	@$(FILTER) $< $(VERBOSE) > $@

#%.txt: PDF_FLAGS := -raw
%.txt: PDF_FLAGS := -q -layout
.%.txt: %.pdf
	@echo "[$$(($$(ls -1 .*.txt | wc -l) + 1))/$(nfiles)] Converting $< ... "
	@$(PDF2TXT) $(PDF_FLAGS) $< $@
	@sed -iE '/ *$$\|^[ 0-9\/]*$$/d' $@

%.pdf:
	@echo "No command to download $@"
	@false

clean:
	@rm -rf .*.csv .*.txt

miss:
	@echo "Missed txt files: $(filter-out $(text_exist), $(text))"
	@echo "Missed csv files: $(filter-out $(csvs_exist), $(csvs))"

.SECONDARY: $(text)
