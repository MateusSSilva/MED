# main_upper.R
# ------------
# Applies the MED algorithm to the Complex Upper Limb Movements dataset
# (3-D marker positions).
#
# Dataset
#   Folder:    data/complex-upper-limb-movements-1.0.0/ (all *.csv therein)
#   Structure: each subfolder is named after the subject; filenames encode
#              task and trial (e.g., reach0a.csv → task "reach", trial "a");
#              first column is time [s], remaining columns are positions in
#              meters; CSV fields are semicolon-separated.
#
# Requirements
#   pkg/MED_pkg.R (profile_MED, rescaling_MED, cost_e, and dbscan_MED removed).
#   Run from the repository root: setwd("path/to/MED_pkg")
#
# Parameters
#   unit  m  |  min_D 0.003 m  |  min_T 0.1 s  |  min_V 0.01 m/s
#   filter  lp 10 Hz, 4th-order Butterworth
#
# Output
#   output/upper/output_upper_R.csv — one row per trial, columns: file, ind,
#   task, trial, then D/V/T/N/Nt/W/R2/P and alpha/K/R2_alpha for each
#   dimension (suffix _all, _x, _y, _z).

library(here)

source(here("pkg", "MED_pkg.R"))

data_dir <- here("data", "complex-upper-limb-movements-1.0.0")
output_dir <- here("output", "upper")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

output_list <- list()

files <- list.files(path = data_dir, pattern = "\\.csv$",
                    recursive = TRUE, full.names = TRUE)

for (i in seq_along(files)) {
    file_path <- files[i]
    file_name <- basename(file_path)
    name_parts <- strsplit(file_name, "0")[[1]]
    task <- name_parts[1]
    trial <- if (length(name_parts) >= 2) substr(name_parts[2], 1, 1) else NA
    subject <- basename(dirname(file_path))

    raw_data <- read.csv(file_path, header = TRUE, sep = ";")
    movementData <- as.matrix(raw_data[, 2:ncol(raw_data)])
    time_diffs <- diff(raw_data[, 1])
    FPS <- if (length(time_diffs) > 0 && mean(time_diffs) != 0) 1 / mean(time_diffs) else NA

    cat(sprintf("Processing: %s | Subject: %s | Task: %s | Trial: %s | FPS: %.2f\n",
                file_name, subject, task, trial, FPS))

    output <- MED(movementData, FPS,
                  unit = "m",
                  limits = c(0.003, 0.1, 0.01),
                  filter = c(10, 4))

    dims <- c("all", "x", "y", "z")
    suffixes <- c("_all", "_x", "_y", "_z")
    direct_vars <- c("D", "V", "T", "N", "Nt", "W", "R2", "P")
    scale_vars <- c("alpha" = "alpha", "K" = "K", "R2" = "R2_alpha")

    row_list <- list(file = i, ind = subject, task = task, trial = trial)

    for (k in seq_along(dims)) {
        d <- dims[k]
        sfx <- suffixes[k]
        for (var in direct_vars) {
            val <- output[[var]][[d]]
            row_list[[paste0(var, sfx)]] <- if (!is.null(val)) val else NA
        }
        for (src in names(scale_vars)) {
            val <- output$scaling[[src]][[d]]
            row_list[[paste0(scale_vars[[src]], sfx)]] <- if (!is.null(val)) val else NA
        }
    }

    output_list[[i]] <- as.data.frame(row_list, stringsAsFactors = FALSE)
}

output_MED <- as.data.frame(do.call(rbind, output_list))
write.csv(output_MED, file.path(output_dir, "output_upper_R.csv"), row.names = FALSE)
