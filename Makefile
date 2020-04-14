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

all: $(REPORT)

$(REPORT): $(csvs)
	@$(MERGE) $^ > $@

%.csv: %.txt $(MAKEFILE_LIST)
	@$(FILTER) $< > $@

%.txt: PDF_FLAGS := -raw
#%.txt: PDF_FLAGS := -layout
.%.txt: %.pdf
	@$(PDF2TXT) $(PDF_FLAGS) $< $@

%.pdf:
	@echo "No command to download $@"
	@false

clean:
	@rm -rf .*.csv .*.txt

.SECONDARY: $(text)
