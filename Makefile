.SUFFIXES:

PDF2TXT := $(shell which pdftotext)
FILTER  := $(shell which report)
REPORT	:= report.csv
MERGE	:= cat

ifeq ($(PDF2TXT),)
$(error pdftotext not found.)
endif

ifeq ($(FILTER),)
FILTER := $(wildcard ./annual_report.sh)
$(warning $(FILTER) is used.)
endif

pdfs := $(wildcard *.pdf)
text := $(pdfs:%.pdf=.%.txt)
csvs := $(pdfs:%.pdf=.%.csv)

text_exist := $(wildcard .*.txt)
csvs_exist := $(wildcard .*.csv)

all: $(REPORT)

$(REPORT): $(csvs)
	@printf "%6s, %7s, %20s, %20s\n" code unit 2019 2018 > $@
	@$(MERGE) $^ >> $@

%.csv: %.txt $(MAKEFILE_LIST)
	@$(FILTER) $< > $@

%.txt: PDF_FLAGS := -raw
#%.txt: PDF_FLAGS := -layout
.%.txt: %.pdf
	@echo "Converting $< ... "
	@$(PDF2TXT) $(PDF_FLAGS) $< $@

%.pdf:
	@echo "No command to download $@"
	@false

clean:
	@rm -rf .*.csv .*.txt

miss:
	@echo "Missed txt files: $(filter-out $(text_exist), $(text))"
	@echo "Missed csv files: $(filter-out $(csvs_exist), $(csvs))"

.SECONDARY: $(text)
