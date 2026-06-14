.PHONY: init test process tex clean help

# Default target
all: init process tex

help:
	@echo "Available commands:"
	@echo "  make init      - Instantiate the Julia environment"
	@echo "  make process   - Run attractor diagnostics on campaign data"
	@echo "  make tex       - Regenerate LaTeX macros and tables for the draft"
	@echo "  make test      - Run repository test suites"
	@echo "  make clean     - Remove compiled logs and temporary runtime artifacts"

init:
	julia --project="." -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

process:
	@echo "Running attractor pipeline on CASES-99..."
	julia --project="." scripts/extract_attractor_diagnostics.jl

tex:
	@echo "Regenerating LaTeX exports..."
	julia --project="." scripts/regenerate_tex_exports.jl

test:
	julia --project="." test/runtests.jl

clean:
	find . -name "*.log" -type f -delete
	find . -name ".DS_Store" -type f -delete
	rm -rf .julia/