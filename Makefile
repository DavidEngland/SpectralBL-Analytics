.PHONY: init test process tex report compile-report cabauw-report cases99-report gabls3-report clean purge help all

# Configuration parameters
TRAJECTORY_CSV ?= data/drafts/trajectories/trajectory_master.csv
CAMPAIGN ?= ALL
# Valid CAMPAIGN values: CASES-99, GABLS3, ALL (default ALL runs both production campaigns)
# Unknown campaign values will be sanitized to {campaign}_run directory path
WORKSPACE_ROOT := $(shell pwd)
OUTPUT_PDF = $(if $(filter CASES-99,$(CAMPAIGN)),CASES-99.pdf,$(if $(filter GABLS3,$(CAMPAIGN)),GABLS3.pdf,main.pdf))
# REPORT_DIR routes campaign output: CASES-99 → cases99_run, GABLS3 → gabls3_run, ALL/unknown → all_run
REPORT_DIR = $(if $(filter CASES-99,$(CAMPAIGN)),reports/cases99_run,$(if $(filter GABLS3,$(CAMPAIGN)),reports/gabls3_run,reports/all_run))

# Default target
all: init process tex report

	@echo "  make process           - Run attractor diagnostics on campaign data (set CAMPAIGN=CASES-99|GABLS3|ALL, default ALL)"
	@echo "  make tex               - Regenerate LaTeX macros and tables for the draft"
	@echo "  make report            - Build Mustache templates + JSON manifest (set CAMPAIGN=GABLS3|CASES-99|ALL)"
	@echo "  make compile-report    - Compile TeX document to PDF (campaign-scoped filename)"
	@echo "  make cases99-report    - Full CASES-99 flow (outputs CASES-99.pdf)"
	@echo "  make gabls3-report     - Full GABLS3 flow (outputs GABLS3.pdf)"
	@echo "  make cabauw-report     - Canonical Cabauw-only flow (forces CAMPAIGN=GABLS3)"
	@echo "  make test              - Run repository test suites (20 tests expected to pass)"
	@echo "  make clean             - Remove compiled logs and temporary runtime artifacts"
	@echo "  make purge             - Clean + remove deep build caches and PDFs"
	@echo ""
	@echo "Campaign parameter: CAMPAIGN=CASES-99|GABLS3|ALL (default ALL)"
	@echo "Mixed-campaign output: CAMPAIGN=ALL writes to reports/all_run/main.pdf (experimental)"N=GABLS3)"
	@echo "  make test              - Run repository test suites"
	@echo "  make clean             - Remove compiled logs and temporary runtime artifacts"
	@echo "  make purge             - Clean + remove deep build caches and PDFs"

init:
	julia --project="." -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

process:
	@echo "Running attractor pipeline (campaign=$(CAMPAIGN))..."
	julia --project="." scripts/extract_attractor_diagnostics.jl $(CAMPAIGN)

tex:
	@echo "Regenerating LaTeX exports..."
	julia --project="." scripts/regenerate_tex_exports.jl

test:
	julia --project="." test/runtests.jl

clean:
	find . -name "*.log" -type f -delete
	find . -name ".DS_Store" -type f -delete
	rm -rf .julia/logs

report:
	@echo "Building Mustache templates and JSON manifest (campaign=$(CAMPAIGN))..."
	julia --project="." scripts/build_campaign_report.jl $(TRAJECTORY_CSV) $(CAMPAIGN)

compile-report:
	@echo "Compiling report PDF via latexmk as $(OUTPUT_PDF)..."
	cd $(REPORT_DIR) && latexmk -lualatex -shell-escape -interaction=nonstopmode main.tex
	cd $(REPORT_DIR) && cp -f main.pdf $(OUTPUT_PDF)

cases99-report: CAMPAIGN=CASES-99
cases99-report: process tex report compile-report
	@echo "CASES-99 report pipeline complete."

gabls3-report: cabauw-report

cabauw-report: CAMPAIGN=GABLS3
cabauw-report: process tex report compile-report
	@echo "Cabauw/GABLS3 report pipeline complete."

purge: clean
	@echo "Removing deep build caches and generated PDFs..."
	rm -rf reports/cases99_run/tikz-cache/*
	rm -rf reports/gabls3_run/tikz-cache/*
	rm -rf reports/all_run/tikz-cache/*
	rm -f reports/cases99_run/main.pdf reports/cases99_run/CASES-99.pdf reports/cases99_run/CASES_99.pdf reports/cases99_run/GABLS3.pdf
	rm -f reports/cases99_run/CASES_99.aux reports/cases99_run/CASES_99.fdb_latexmk reports/cases99_run/CASES_99.fls reports/cases99_run/CASES_99.log reports/cases99_run/CASES_99.out reports/cases99_run/CASES_99.toc
	rm -f reports/gabls3_run/main.pdf reports/gabls3_run/CASES-99.pdf reports/gabls3_run/GABLS3.pdf
	rm -f reports/all_run/main.pdf reports/all_run/CASES-99.pdf reports/all_run/GABLS3.pdf
	rm -rf data/outputs/*
	@if [ -d reports/cases99_run ]; then cd reports/cases99_run && latexmk -C; fi
	@if [ -d reports/gabls3_run ]; then cd reports/gabls3_run && latexmk -C; fi
	@if [ -d reports/all_run ]; then cd reports/all_run && latexmk -C; fi