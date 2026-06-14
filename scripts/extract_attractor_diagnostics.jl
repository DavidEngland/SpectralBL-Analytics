using Pkg
Pkg.activate(".")
# append src directory to load path natively
push!(LOAD_PATH, joinpath(pwd(), "src"))

using AttractorDiagnostics
using IngestionFormatters
import ArgParse

println("Attractor pipeline initialized.")
# Add ingestion loop, SVD computation, and CSV dump execution layers here.
