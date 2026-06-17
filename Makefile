.PHONY: init test process tex stage2-pipeline stage3-assemble stage4-calibrate stage4-discover report compile-report compile-cards cabauw-report cases99-report gabls3-report arctic-report arctic-hlbl-synthetic arctic-finalize clean purge help all

# Configuration parameters
TRAJECTORY_CSV ?= data/drafts/trajectories/trajectory_master.csv
CAMPAIGN ?= ALL
WORKSPACE_ROOT := $(shell pwd)
OUTPUT_PDF = $(if $(filter CASES-99,$(CAMPAIGN)),CASES-99.pdf,$(if $(filter GABLS3,$(CAMPAIGN)),GABLS3.pdf,$(if $(filter ARCTIC-AMPLIFICATION,$(CAMPAIGN)),ARCTIC-AMPLIFICATION.pdf,main.pdf)))
REPORT_RUN_DIR = $(if $(filter CASES-99,$(CAMPAIGN)),cases99_run,$(if $(filter GABLS3,$(CAMPAIGN)),gabls3_run,$(if $(filter ARCTIC-AMPLIFICATION,$(CAMPAIGN)),arctic_amplification_run,all_run)))
CAMPAIGN_SLUG = $(shell echo "$(CAMPAIGN)" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$$//')

# Default target
all: init process tex report

help:
	@echo "Available commands:"
	@echo "  make init              - Instantiate the Julia environment"
	@echo "  make process           - Run attractor diagnostics on campaign data"
	@echo "  make stage2-pipeline   - Run Stage 2 routing + operator diagnostics on trajectory CSV"
	@echo "  make stage3-assemble   - Assemble Stage 3 global closure matrices from Stage 2 packets"
	@echo "  make stage4-calibrate  - Run Stage 4 Pareto lambda sweep + select sparse model"
	@echo "  make stage4-discover   - Run Stage 4 production STLS with fixed lambda"
	@echo "  make tex               - Regenerate LaTeX macros and tables for the draft"
	@echo "  make report            - Build Mustache templates + JSON manifest (set CAMPAIGN=GABLS3|CASES-99|ALL)"
	@echo "  make compile-report    - Compile TeX document to PDF (campaign-scoped filename)"
	@echo "  make cases99-report    - Full CASES-99 flow (outputs CASES-99.pdf)"
	@echo "  make gabls3-report     - Full GABLS3 flow (outputs GABLS3.pdf)"
	@echo "  make arctic-report     - Full ARCTIC-AMPLIFICATION flow"
	@echo "  make arctic-hlbl-synthetic - Run synthetic Arctic HLBL suite + TeX snippets"
	@echo "  make arctic-finalize   - Synthetic + native Arctic report + monitoring cards"
	@echo "  make compile-cards     - Build campaign summary markdown card (set CAMPAIGN flag)"
	@echo "  make cabauw-report     - Canonical Cabauw-only flow (forces CAMPAIGN=GABLS3)"
	@echo "  make test              - Run repository test suites"
	@echo "  make clean             - Remove compiled logs and temporary runtime artifacts"
	@echo "  make purge             - Clean + remove deep build caches and PDFs"

init:
	julia --project="." -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

process:
	@echo "Running attractor pipeline (campaign=$(CAMPAIGN))..."
	julia --project="." scripts/extract_attractor_diagnostics.jl $(CAMPAIGN)

stage2-pipeline:
	@echo "Running Stage 2 pipeline (campaign=$(CAMPAIGN))..."
	julia --project="." scripts/stage2_pipeline.jl $(TRAJECTORY_CSV) $(CAMPAIGN)

stage3-assemble:
	@echo "Assembling Stage 3 global closure matrices (campaign=$(CAMPAIGN), slug=$(CAMPAIGN_SLUG))..."
	julia --project="." scripts/stage3_matrix_assembler.jl \
		--packet data/outputs/stage2_packets_$(CAMPAIGN_SLUG).csv \
		--trajectory $(TRAJECTORY_CSV) \
		--campaign $(CAMPAIGN) \
		--emit-csv true

stage4-calibrate:
	@echo "Running Stage 4 calibration sweep (campaign=$(CAMPAIGN), slug=$(CAMPAIGN_SLUG))..."
	julia --project="." scripts/stage4_sparse_regression.jl \
		--stage3-bin data/outputs/stage3_closure_$(CAMPAIGN_SLUG).bin \
		--output-json data/outputs/stage4_discovered_equations_$(CAMPAIGN_SLUG).json \
		--mode calibrate \
		--library-mode contract90

stage4-discover:
	@echo "Running Stage 4 production discovery (campaign=$(CAMPAIGN), slug=$(CAMPAIGN_SLUG))..."
	julia --project="." scripts/stage4_sparse_regression.jl \
		--stage3-bin data/outputs/stage3_closure_$(CAMPAIGN_SLUG).bin \
		--output-json data/outputs/stage4_discovered_equations_$(CAMPAIGN_SLUG).json \
		--mode production \
		--lambda 1e-3 \
		--library-mode contract90

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
	cd reports/$(REPORT_RUN_DIR) && latexmk -lualatex -shell-escape -interaction=nonstopmode main.tex
	cd reports/$(REPORT_RUN_DIR) && cp -f main.pdf $(OUTPUT_PDF)

compile-cards:
	@echo "Compiling campaign monitoring card (campaign=$(CAMPAIGN))..."
	julia --project="." scripts/compile_campaign_reports.jl $(CAMPAIGN)

cases99-report: CAMPAIGN=CASES-99
cases99-report: process tex report compile-report
	@echo "CASES-99 report pipeline complete."

gabls3-report: cabauw-report

cabauw-report: CAMPAIGN=GABLS3
cabauw-report: process tex report compile-report
	@echo "Cabauw/GABLS3 report pipeline complete."

arctic-report: CAMPAIGN=ARCTIC-AMPLIFICATION
arctic-report: process tex report compile-report
	@echo "Arctic amplification report pipeline complete."

arctic-hlbl-synthetic:
	@echo "Running synthetic Arctic HLBL suite..."
	julia --project="." scripts/RunArcticAmplificationSuite.jl
	@echo "Synthetic Arctic HLBL suite complete."

arctic-finalize: arctic-hlbl-synthetic arctic-report
	@echo "Executing master compiler sequence for high-latitude domains..."
	$(MAKE) compile-cards CAMPAIGN=arctic_hlbl
	@echo "Finalization complete. Tables, parameter macros, and markdown cards are synchronized."

purge: clean
	@echo "Removing deep build caches and generated PDFs..."
	rm -rf reports/cases99_run/tikz-cache/*
	rm -f reports/cases99_run/main.pdf reports/cases99_run/CASES-99.pdf reports/cases99_run/CASES_99.pdf reports/cases99_run/GABLS3.pdf
	rm -f reports/cases99_run/CASES_99.aux reports/cases99_run/CASES_99.fdb_latexmk reports/cases99_run/CASES_99.fls reports/cases99_run/CASES_99.log reports/cases99_run/CASES_99.out reports/cases99_run/CASES_99.toc
	rm -rf data/outputs/*
	cd reports/cases99_run && latexmk -C