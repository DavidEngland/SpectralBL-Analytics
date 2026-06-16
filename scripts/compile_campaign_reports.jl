#!/usr/bin/env julia
# scripts/compile_campaign_reports.jl

println("Compiling reporting summaries and visual sheets...")

using DataFrames
using CSV
using Dates
using Statistics
using LinearAlgebra
using Printf

const ARCTIC_TOKEN_SET = Set([
	"arctic_hlbl",
	"ARCTIC_HLBL",
	"ARCTIC-AMPLIFICATION",
	"arctic-amplification",
	"ARCTIC",
	"arctic",
])

function normalize_campaign(flag::String)
	stripped = strip(flag)
	isempty(stripped) && return "cases99"
	return String(stripped)
end

function resolve_routes(campaign_flag::String)
	output_root = "reports"
	is_arctic = campaign_flag in ARCTIC_TOKEN_SET

	if is_arctic
		return (
			report_dir = joinpath(output_root, "arctic_amplification_run"),
			data_file = joinpath("data", "outputs", "regime_trajectories_arctic_amplification.csv"),
			campaign_label = "ARCTIC-AMPLIFICATION",
			is_arctic = true,
		)
	elseif lowercase(campaign_flag) in ("gabls3", "cabauw")
		return (
			report_dir = joinpath(output_root, "gabls3_run"),
			data_file = joinpath("data", "outputs", "regime_trajectories_gabls3.csv"),
			campaign_label = "GABLS3",
			is_arctic = false,
		)
	else
		return (
			report_dir = joinpath(output_root, "cases99_run"),
			data_file = joinpath("data", "outputs", "regime_trajectories_cases_99.csv"),
			campaign_label = "CASES-99",
			is_arctic = false,
		)
	end
end

function safe_mean(df::DataFrame, col::Symbol)
	if !(col in names(df))
		return nothing
	end
	vals = Float64[]
	for v in df[!, col]
		if !ismissing(v)
			f = Float64(v)
			if isfinite(f)
				push!(vals, f)
			end
		end
	end
	isempty(vals) && return nothing
	return mean(vals)
end

function estimate_d_eff(df::DataFrame)
	if :D_eff in names(df)
		return safe_mean(df, :D_eff)
	end

	eta_cols = filter(c -> startswith(String(c), "eta_"), names(df))
	if isempty(eta_cols)
		return nothing
	end

	X = Matrix{Float64}(df[:, eta_cols])
	if size(X, 1) == 0 || size(X, 2) == 0
		return nothing
	end

	centered = X .- mean(X; dims=1)
	svals = svd(centered; full=false).S
	if isempty(svals) || sum(svals) <= eps(Float64)
		return nothing
	end

	p = svals ./ sum(svals)
	h = -sum(pi > 0.0 ? pi * log(pi) : 0.0 for pi in p)
	return exp(h)
end

function extract_synthetic_guard_deff(path::String)
	if !isfile(path)
		return nothing
	end

	content = read(path, String)
	# Row shape from TexExporter: AA Core Plateau & <D_eff_Mean> & ...
	m = match(r"AA Core Plateau\s*&\s*([0-9]+(?:\.[0-9]+)?)", content)
	if m === nothing
		return nothing
	end

	return tryparse(Float64, m.captures[1])
end

function evaluate_arctic_acceptance_guard_native(df::DataFrame)
	if nrow(df) == 0
		return (status = "SKIPPED", message = "No rows available; AA window guard not evaluated.")
	end

	aa_df = DataFrame()
	if :time_value in names(df)
		tmin = minimum(df.time_value)
		tmax = maximum(df.time_value)
		if !(isfinite(tmin) && isfinite(tmax)) || tmax <= tmin
			return (status = "SKIPPED", message = "Invalid time bounds; AA window guard not evaluated.")
		end

		start_t = tmin + 0.45 * (tmax - tmin)
		end_t = tmin + 0.75 * (tmax - tmin)
		aa_df = filter(row -> start_t <= row.time_value <= end_t, df)
	else
		# Fallback for trajectory files lacking explicit time_value; use middle-late row window.
		n = nrow(df)
		start_i = max(1, floor(Int, 0.45 * n))
		end_i = min(n, ceil(Int, 0.75 * n))
		aa_df = df[start_i:end_i, :]
	end

	if nrow(aa_df) == 0
		return (status = "SKIPPED", message = "No samples in AA core window; guard not evaluated.")
	end

	d_eff_val = estimate_d_eff(aa_df)
	if d_eff_val === nothing
		return (status = "SKIPPED", message = "Could not estimate D_eff for AA core window.")
	end

	if 3.5 <= d_eff_val <= 4.3
		return (
			status = "PASS",
			message = @sprintf("AA guard passed (D_eff=%.3f in [3.5, 4.3]).", d_eff_val),
		)
	end

	return (
		status = "FAIL",
		message = @sprintf("AA guard failed (D_eff=%.3f outside [3.5, 4.3]).", d_eff_val),
	)
end

function evaluate_arctic_acceptance_guard(df::DataFrame)
	synthetic_summary_path = joinpath("drafts", "sections", "generated", "table_arctic_synoptic.tex")

	synthetic_d_eff = extract_synthetic_guard_deff(synthetic_summary_path)
	if synthetic_d_eff !== nothing
		if 3.5 <= synthetic_d_eff <= 4.3
			return (
				status = "PASS",
				message = @sprintf(
					"AA guard passed via synthetic source %s (D_eff=%.3f in [3.5, 4.3]).",
					synthetic_summary_path,
					synthetic_d_eff,
				),
			)
		end

		return (
			status = "FAIL",
			message = @sprintf(
				"AA guard failed via synthetic source %s (D_eff=%.3f outside [3.5, 4.3]).",
				synthetic_summary_path,
				synthetic_d_eff,
			),
		)
	end

	native_result = evaluate_arctic_acceptance_guard_native(df)
	if native_result.status == "SKIPPED"
		return (
			status = "SKIPPED",
			message = "Synthetic summary not found and native guard skipped: " * native_result.message,
		)
	end

	return (
		status = native_result.status,
		message = "Synthetic summary unavailable; native evaluation used. " * native_result.message,
	)
end

function sync_generated_assets(report_dir::String)
	src_dir = joinpath("drafts", "sections", "generated")
	dst_dir = joinpath(report_dir, "generated")

	if !isdir(src_dir)
		return "Generated assets directory not found: $(src_dir)"
	end

	mkpath(dst_dir)
	copied = 0
	for name in readdir(src_dir)
		src = joinpath(src_dir, name)
		if isfile(src) && (endswith(name, ".tex") || endswith(name, ".md"))
			cp(src, joinpath(dst_dir, name); force=true)
			copied += 1
		end
	end

	return "Copied $(copied) generated assets into $(dst_dir)."
end

function write_summary_card(report_dir::String, campaign_label::String, df::DataFrame, guard_result)
	card_path = joinpath(report_dir, "campaign_summary_card.md")

	mean_eta_1 = safe_mean(df, :eta_1)
	mean_eta_2 = safe_mean(df, :eta_2)
	mean_eta_3 = safe_mean(df, :eta_3)
	mean_sv_entropy = safe_mean(df, :sv_entropy)
	d_eff_est = estimate_d_eff(df)

	open(card_path, "w") do io
		println(io, "# Synoptic Performance Monitoring Card")
		println(io)
		println(io, "- Campaign: ", campaign_label)
		println(io, "- Generated: ", Dates.now(Dates.UTC))
		println(io, "- Total Processed Profiles: ", nrow(df))
		if mean_eta_1 !== nothing
			println(io, "- Mean eta_1: ", @sprintf("%.4f", mean_eta_1))
		end
		if mean_eta_2 !== nothing
			println(io, "- Mean eta_2: ", @sprintf("%.4f", mean_eta_2))
		end
		if mean_eta_3 !== nothing
			println(io, "- Mean eta_3: ", @sprintf("%.4f", mean_eta_3))
		end
		if mean_sv_entropy !== nothing
			println(io, "- Mean sv_entropy: ", @sprintf("%.4f", mean_sv_entropy))
		end
		if d_eff_est !== nothing
			println(io, "- Mean Campaign Modal Dimension (D_eff estimate): ", @sprintf("%.4f", d_eff_est))
		end
		println(io, "- Arctic Acceptance Guard: ", guard_result.status)
		println(io, "- Guard Detail: ", guard_result.message)
	end

	return card_path
end

function main()
	campaign_flag = normalize_campaign(length(ARGS) >= 1 ? ARGS[1] : "cases99")
	println("Active compiler sweep targeted at: ", campaign_flag)

	routes = resolve_routes(campaign_flag)
	mkpath(routes.report_dir)

	if !isfile(routes.data_file)
		println("Warning: Campaign data file not found: ", routes.data_file)
		println("Skipping card generation. Run extraction/report pipeline first.")
		println(sync_generated_assets(routes.report_dir))
		return
	end

	println("Ingesting telemetry data for card generation: ", routes.data_file)
	df = CSV.read(routes.data_file, DataFrame)

	if nrow(df) == 0
		println("Warning: Telemetry table is empty; skipping summary card generation.")
		println(sync_generated_assets(routes.report_dir))
		return
	end

	guard_result = routes.is_arctic ? evaluate_arctic_acceptance_guard(df) : (status = "N/A", message = "Guard only evaluated for Arctic campaigns.")
	card_path = write_summary_card(routes.report_dir, routes.campaign_label, df, guard_result)

	println(sync_generated_assets(routes.report_dir))
	println("Markdown summary card assembled at: ", card_path)

	if guard_result.status == "FAIL"
		println("Warning: Arctic Acceptance Guard FAILED. Review diagnostics before manuscript export.")
	else
		println("Compiler sweep complete.")
	end
end

main()
