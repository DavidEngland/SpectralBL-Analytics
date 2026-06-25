# src/GeometricPrecursors.jl
module GeometricPrecursors

using LinearAlgebra
using Statistics
using StatsBase: percentile
using DataFrames
using CSV

export compute_multi_scale_variance,
       compute_multi_scale_autocorrelation,
       compute_trajectory_speed,
       compute_acceleration_magnitude,
       compute_trajectory_curvature,
       compute_richardson_gradient,
       PrecursorResults,
       analyze_precursors

"""
    PrecursorResults

Container for all precursor indicator time series.
"""
struct PrecursorResults
    time::Vector{Float64}
    
    # Category A: Critical-Transition Indicators (Scheffer/Held theory)
    var_5::Vector{Float64}      # 5-min variance
    var_15::Vector{Float64}     # 15-min variance
    var_30::Vector{Float64}     # 30-min variance
    var_60::Vector{Float64}     # 60-min variance
    ac1_5::Vector{Float64}      # 5-min lag-1 autocorrelation
    ac1_15::Vector{Float64}     # 15-min lag-1 autocorrelation
    ac1_30::Vector{Float64}     # 30-min lag-1 autocorrelation
    ac1_60::Vector{Float64}     # 60-min lag-1 autocorrelation
    
    # Category B: Geometric Indicators (novel in SBL context)
    speed::Vector{Float64}      # ||dη/dt||
    acceleration::Vector{Float64}  # ||d²η/dt²||
    curvature::Vector{Float64}  # ||η' × η''|| / ||η'||³ (regularized)
    
    # Classical metrics for comparison
    ri_mean::Vector{Float64}    # Mean Richardson number
    tke::Vector{Union{Missing,Float64}}  # TKE if available
end

"""
    compute_multi_scale_variance(signal::Vector{Float64}, times::Vector{Float64}, tau_minutes::Vector{Int})

Computes variance of signal over multiple time windows.

# Arguments
- `signal`: Time series of η₃ or other quantity
- `times`: Corresponding timestamps (seconds)
- `tau_minutes`: Vector of window sizes in minutes [5, 15, 30, 60]

# Returns
- Matrix where each column is variance time series for that τ
"""
function compute_multi_scale_variance(signal::Vector{Float64}, times::Vector{Float64}, tau_minutes::Vector{Int})
    n = length(signal)
    n_tau = length(tau_minutes)
    result = Matrix{Float64}(undef, n, n_tau)
    
    for (j, tau) in enumerate(tau_minutes)
        tau_sec = tau * 60.0
        
        for i in 1:n
            # Find indices within time window centered at i
            t_center = times[i]
            window_mask = (times .>= t_center - tau_sec/2) .& (times .<= t_center + tau_sec/2)
            window_data = signal[window_mask]
            
            if length(window_data) >= 3
                result[i, j] = var(window_data)
            else
                result[i, j] = NaN
            end
        end
    end
    
    return result
end

"""
    compute_multi_scale_autocorrelation(signal::Vector{Float64}, times::Vector{Float64}, tau_minutes::Vector{Int})

Computes lag-1 autocorrelation over multiple time windows.
Critical slowing down predicts AC₁ → 1 near bifurcations.

# Arguments
- `signal`: Time series of η₃ or other quantity
- `times`: Corresponding timestamps (seconds)
- `tau_minutes`: Vector of window sizes in minutes [5, 15, 30, 60]

# Returns
- Matrix where each column is AC₁ time series for that τ
"""
function compute_multi_scale_autocorrelation(signal::Vector{Float64}, times::Vector{Float64}, tau_minutes::Vector{Int})
    n = length(signal)
    n_tau = length(tau_minutes)
    result = Matrix{Float64}(undef, n, n_tau)
    
    for (j, tau) in enumerate(tau_minutes)
        tau_sec = tau * 60.0
        
        for i in 1:n
            # Find indices within time window centered at i
            t_center = times[i]
            window_mask = (times .>= t_center - tau_sec/2) .& (times .<= t_center + tau_sec/2)
            window_data = signal[window_mask]
            
            if length(window_data) >= 4  # Need at least 4 points for lag-1
                x = window_data[1:end-1]
                y = window_data[2:end]
                
                # Pearson correlation coefficient
                if std(x) > 0 && std(y) > 0
                    result[i, j] = cor(x, y)
                else
                    result[i, j] = NaN
                end
            else
                result[i, j] = NaN
            end
        end
    end
    
    return result
end

"""
    compute_trajectory_speed(eta::Matrix{Float64}, times::Vector{Float64})

Computes trajectory speed v(t) = ||dη/dt|| in manifold space.

# Arguments
- `eta`: n × 3 matrix of (η₁, η₂, η₃) coordinates
- `times`: n-vector of timestamps (seconds)

# Returns
- Vector of trajectory speeds
"""
function compute_trajectory_speed(eta::Matrix{Float64}, times::Vector{Float64})
    n = size(eta, 1)
    speed = Vector{Float64}(undef, n)
    
    # Use central differences for interior points
    for i in 2:n-1
        dt = times[i+1] - times[i-1]
        if dt > 0
            deta = (eta[i+1, :] .- eta[i-1, :]) ./ dt
            speed[i] = norm(deta)
        else
            speed[i] = NaN
        end
    end
    
    # Forward difference for first point
    if n >= 2
        dt = times[2] - times[1]
        if dt > 0
            deta = (eta[2, :] .- eta[1, :]) ./ dt
            speed[1] = norm(deta)
        else
            speed[1] = NaN
        end
    end
    
    # Backward difference for last point
    if n >= 2
        dt = times[n] - times[n-1]
        if dt > 0
            deta = (eta[n, :] .- eta[n-1, :]) ./ dt
            speed[n] = norm(deta)
        else
            speed[n] = NaN
        end
    end
    
    return speed
end

"""
    compute_acceleration_magnitude(eta::Matrix{Float64}, times::Vector{Float64})

Computes acceleration magnitude a(t) = ||d²η/dt²||.

Distinguishes:
- Low speed + high curvature → creeping along fold
- High speed + low curvature → rapid excursion along straight manifold

# Arguments
- `eta`: n × 3 matrix of (η₁, η₂, η₃) coordinates
- `times`: n-vector of timestamps (seconds)

# Returns
- Vector of acceleration magnitudes
"""
function compute_acceleration_magnitude(eta::Matrix{Float64}, times::Vector{Float64})
    n = size(eta, 1)
    accel = Vector{Float64}(undef, n)
    
    # Use central differences for second derivative
    for i in 2:n-1
        dt_back = times[i] - times[i-1]
        dt_forward = times[i+1] - times[i]
        
        if dt_back > 0 && dt_forward > 0
            # First derivative at i-1/2 and i+1/2
            deta_back = (eta[i, :] .- eta[i-1, :]) ./ dt_back
            deta_forward = (eta[i+1, :] .- eta[i, :]) ./ dt_forward
            
            # Second derivative at i
            dt_avg = (dt_back + dt_forward) / 2
            d2eta = (deta_forward .- deta_back) ./ dt_avg
            accel[i] = norm(d2eta)
        else
            accel[i] = NaN
        end
    end
    
    # Boundary points set to NaN (need neighbors for second derivative)
    accel[1] = NaN
    accel[n] = NaN
    
    return accel
end

"""
    compute_trajectory_curvature(eta::Matrix{Float64}, times::Vector{Float64}; epsilon_percentile::Float64=1.0)

Computes trajectory curvature κ(t) = ||η' × η''|| / ||η'||³.

This is a coordinate-independent geometric measure of how sharply the trajectory
is turning in manifold space.

# Regularization
Only computed where speed v(t) > ε to avoid ||η'|| → 0 singularities.
Default: ε = 1st percentile of speed distribution (filters near-stationary points).

# Arguments
- `eta`: n × 3 matrix of (η₁, η₂, η₃) coordinates
- `times`: n-vector of timestamps (seconds)
- `epsilon_percentile`: Percentile of speed for regularization threshold (default: 1.0)

# Returns
- Vector of curvature values (NaN where speed < ε or at boundaries)
"""
function compute_trajectory_curvature(eta::Matrix{Float64}, times::Vector{Float64}; epsilon_percentile::Float64=1.0)
    n = size(eta, 1)
    curvature = Vector{Float64}(undef, n)
    
    # Compute velocity and acceleration
    velocity = Matrix{Float64}(undef, n, 3)
    acceleration = Matrix{Float64}(undef, n, 3)
    
    # Central differences for velocity
    for i in 2:n-1
        dt = times[i+1] - times[i-1]
        if dt > 0
            velocity[i, :] = (eta[i+1, :] .- eta[i-1, :]) ./ dt
        else
            velocity[i, :] .= NaN
        end
    end
    
    # Boundary velocities
    if n >= 2
        dt = times[2] - times[1]
        velocity[1, :] = dt > 0 ? (eta[2, :] .- eta[1, :]) ./ dt : [NaN, NaN, NaN]
        
        dt = times[n] - times[n-1]
        velocity[n, :] = dt > 0 ? (eta[n, :] .- eta[n-1, :]) ./ dt : [NaN, NaN, NaN]
    end
    
    # Central differences for acceleration
    for i in 2:n-1
        dt_back = times[i] - times[i-1]
        dt_forward = times[i+1] - times[i]
        
        if dt_back > 0 && dt_forward > 0
            deta_back = (eta[i, :] .- eta[i-1, :]) ./ dt_back
            deta_forward = (eta[i+1, :] .- eta[i, :]) ./ dt_forward
            dt_avg = (dt_back + dt_forward) / 2
            acceleration[i, :] = (deta_forward .- deta_back) ./ dt_avg
        else
            acceleration[i, :] .= NaN
        end
    end
    
    # Boundaries for acceleration
    acceleration[1, :] .= NaN
    acceleration[n, :] .= NaN
    
    # Compute speed for regularization
    speed = [norm(velocity[i, :]) for i in 1:n]
    valid_speeds = speed[.!isnan.(speed)]
    
    if isempty(valid_speeds)
        fill!(curvature, NaN)
        return curvature
    end
    
    # Regularization threshold: epsilon_percentile of speed distribution
    epsilon = length(valid_speeds) > 0 ? percentile(valid_speeds, epsilon_percentile) : 0.0
    
    # Compute curvature with regularization
    for i in 1:n
        v = velocity[i, :]
        a = acceleration[i, :]
        v_norm = norm(v)
        
        # Only compute where speed > epsilon (avoid singularities)
        if !any(isnan.(v)) && !any(isnan.(a)) && v_norm > epsilon
            # Cross product in 3D
            cross_prod = [
                v[2] * a[3] - v[3] * a[2],
                v[3] * a[1] - v[1] * a[3],
                v[1] * a[2] - v[2] * a[1]
            ]
            
            curvature[i] = norm(cross_prod) / (v_norm^3)
        else
            curvature[i] = NaN
        end
    end
    
    return curvature
end

"""
    compute_richardson_gradient(ri_columns::Matrix{Float64})

Computes mean Richardson number across available heights.

# Arguments
- `ri_columns`: n × m matrix of Richardson numbers at m different heights

# Returns
- Vector of mean Ri values
"""
function compute_richardson_gradient(ri_columns::Matrix{Float64})
    n = size(ri_columns, 1)
    ri_mean = Vector{Float64}(undef, n)
    
    for i in 1:n
        row = ri_columns[i, :]
        valid = row[.!ismissing.(row)]
        if !isempty(valid)
            ri_mean[i] = mean(skipmissing(valid))
        else
            ri_mean[i] = NaN
        end
    end
    
    return ri_mean
end

"""
    analyze_precursors(trajectory_file::String; tau_minutes::Vector{Int}=[5, 15, 30, 60])

Main analysis function that computes all precursor indicators from a trajectory CSV file.

# Arguments
- `trajectory_file`: Path to regime_trajectories_*.csv file
- `tau_minutes`: Time windows for multi-scale analysis (default: [5, 15, 30, 60])

# Returns
- `PrecursorResults` struct containing all indicator time series
"""
function analyze_precursors(trajectory_file::String; tau_minutes::Vector{Int}=[5, 15, 30, 60])
    # Load trajectory data
    df = CSV.read(trajectory_file, DataFrame)
    
    # Extract key columns
    times = df.time_value
    eta = Matrix{Float64}(hcat(df.eta_1, df.eta_2, df.eta_3))
    eta_3 = df.eta_3  # For variance/AC analysis
    
    # Extract Richardson numbers (all ri_g_* columns)
    ri_cols = [name for name in names(df) if startswith(string(name), "ri_g_")]
    if !isempty(ri_cols)
        # Handle missing values: convert to Matrix, replacing missing with NaN
        ri_data = df[:, ri_cols]
        ri_matrix = Matrix{Float64}(undef, size(ri_data, 1), size(ri_data, 2))
        for i in 1:size(ri_data, 1)
            for j in 1:size(ri_data, 2)
                val = ri_data[i, j]
                ri_matrix[i, j] = ismissing(val) ? NaN : Float64(val)
            end
        end
        ri_mean = compute_richardson_gradient(ri_matrix)
    else
        ri_mean = fill(NaN, length(times))
    end
    
    println("Computing Category A indicators (critical-transition)...")
    
    # Category A: Multi-scale variance and autocorrelation
    var_matrix = compute_multi_scale_variance(eta_3, times, tau_minutes)
    ac1_matrix = compute_multi_scale_autocorrelation(eta_3, times, tau_minutes)
    
    println("Computing Category B indicators (geometric)...")
    
    # Category B: Trajectory geometry
    speed = compute_trajectory_speed(eta, times)
    acceleration = compute_acceleration_magnitude(eta, times)
    curvature = compute_trajectory_curvature(eta, times)
    
    # TKE placeholder (if column exists)
    tke = :tke in names(df) ? df.tke : fill(missing, length(times))
    
    println("Precursor analysis complete.")
    
    return PrecursorResults(
        times,
        var_matrix[:, 1], var_matrix[:, 2], var_matrix[:, 3], var_matrix[:, 4],
        ac1_matrix[:, 1], ac1_matrix[:, 2], ac1_matrix[:, 3], ac1_matrix[:, 4],
        speed,
        acceleration,
        curvature,
        ri_mean,
        tke
    )
end

end # module
