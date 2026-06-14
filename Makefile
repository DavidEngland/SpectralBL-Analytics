.PHONY: init test process tex report compile-report clean purge help

# Configuration parameters
TRAJECTORY_CSV ?= data/drafts/trajectories/trajectory_master.csv
WORKSPACE_ROOT := $(shell pwd)

# Default target
all: init process tex report

help:
	@echo "Available commands:"
	@echo "  make init              - Instantiate the Julia environment"
	@echo "  make process           - Run attractor diagnostics on campaign data"
	@echo "  make tex               - Regenerate LaTeX macros and tables for the draft"
	@echo "  make report            - Build Mustache templates + JSON manifest from trajectory CSV"
	@echo "  make compile-report    - Compile TeX document to PDF (requires latexmk, lualatex)"
	@echo "  make test              - Run repository test suites"
	@echo "  make clean             - Remove compiled logs and temporary runtime artifacts"
	@echo "  make purge             - Clean + remove deep build caches and PDFs"

init:
	julia --project="." -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

process:
	@echo "Running attractor pipeline on CASES-99..."
	julia --project="." scripts/extract_attractor_diagnostics.jl

tex:
	@echo "Regenerating LaTeX exports..."
	julia --project="." scripts/regenerate_tex_exports.jl

report:
	@echo "Building Mustache templates and JSON manifest..."
	julia --project="." scripts/build_campaign_report.jl $(TRAJECTORY_CSV)

compile-report:
	@echo "Compiling TeX document to PDF..."
	cd reports/cases99_run && latexmk -lualatex -shell-escape -interaction=nonstopmode main.tex
	@echo "PDF generated at: reports/cases99_run/main.pdf"

test:
	julia --project="." test/runtests.jl

clean:
	find . -name "*.log" -type f -delete
	find . -name ".DS_Store" -type f -delete
	rm -rf .julia/

purge: clean
	@echo "Removing deep build caches and generated PDFs..."
	rm -rf reports/cases99_run/tikz-cache/*
	rm -f reports/cases99_run/main.pdf
	rm -rf data/outputs/*
	cd reports/cases99_run && latexmk -C