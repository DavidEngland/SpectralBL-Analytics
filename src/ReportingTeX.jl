# src/ReportingTeX.jl
module ReportingTeX
# Layout compilers to target downstream manuscript files
export export_to_tex_table

using DataFrames

function export_to_tex_table(output_path::String, data::DataFrame)
    mkpath(dirname(output_path))
    open(output_path, "w") do io
        cols = String.(names(data))
        write(io, "% AUTO-GENERATED TABLE\n")
        write(io, "\\begin{tabular}{" * join(fill("c", length(cols)), "") * "}\n")
        write(io, join(cols, " & ") * " \\\\ \n")
        write(io, "\\hline\n")
        for row in eachrow(data)
            values = [string(row[c]) for c in cols]
            write(io, join(values, " & ") * " \\\\ \n")
        end
        write(io, "\\end{tabular}\n")
    end
end

end # module
