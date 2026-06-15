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
all: init process tex report compile-report

help:
	@echo "========================================================================"
	@echo "                SpectralBL-Analytics Pipeline Engine                    "
	@echo "========================================================================"
	@echo "  make init              - Instantiate Julia project environment and precompile"
	@echo "  make process           - Run attractor diagnostics (set CAMPAIGN=CASES-99|GABLS3|ALL)"
	@echo "  make tex               - Regenerate LaTeX macros and data tables"
	@echo "  make report            - Build Mustache templates and JSON report manifest"
	@echo "  make compile-report    - Compile TeX document to repo root as $(OUTPUT_PDF)"
	@echo "  make cases99-report    - Full CASES-99 flow (outputs root CASES-99.pdf)"
	@echo "  make gabls3-report     - Full GABLS3 flow (outputs root GABLS3.pdf)"
	@echo "  make cabauw-report     - Canonical Cabauw-only flow (forces CAMPAIGN=GABLS3)"
	@echo "  make test              - Run repository test suites (20 invariants expected)"
	@echo "  make clean             - Remove localized runtime temporary logs"
	@echo "  make purge             - Evict deep build caches, TikZ externalizations, and PDFs"
	@echo "------------------------------------------------------------------------"
	@echo " Current Runtime State:"
	@echo "   Active Campaign ID : $(CAMPAIGN)"
	@echo "   Target Report Path : $(REPORT_DIR)/main.tex"
	@echo "   Output PDF Landing : $(WORKSPACE_ROOT)/$(OUTPUT_PDF)"
	@echo "========================================================================"

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
	@echo "Compiling report PDF via latexmk in $(REPORT_DIR)..."
	cd $(REPORT_DIR) && latexmk -lualatex -shell-escape -interaction=nonstopmode main.tex
	cp -f $(REPORT_DIR)/main.pdf $(WORKSPACE_ROOT)/$(OUTPUT_PDF)
	@echo "Success: Compiled artifact relocated to $(WORKSPACE_ROOT)/$(OUTPUT_PDF)"

cases99-report:
	$(MAKE) process tex report compile-report CAMPAIGN=CASES-99
	@echo "CASES-99 report pipeline complete."

gabls3-report: cabauw-report

cabauw-report:
	$(MAKE) process tex report compile-report CAMPAIGN=GABLS3
	@echo "Cabauw/GABLS3 report pipeline complete."

purge: clean
	@echo "Invoking LaTeX engine cleanup..."
	@if [ -d reports/cases99_run ]; then cd reports/cases99_run && latexmk -C; fi
	@if [ -d reports/gabls3_run ]; then cd reports/gabls3_run && latexmk -C; fi
	@if [ -d reports/all_run ]; then cd reports/all_run && latexmk -C; fi
	@echo "Evicting deep externalized graphic caches and root binaries..."
	rm -rf reports/cases99_run/tikz-cache/*
	rm -rf reports/gabls3_run/tikz-cache/*
	rm -rf reports/all_run/tikz-cache/*
	rm -f $(WORKSPACE_ROOT)/*.pdf
	rm -rf data/outputs/*
	@echo "Purge complete. Repository is completely structural."