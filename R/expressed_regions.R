#' Identify expressed regions from the mean coverage for a given SRA project
#'
#' This function uses the pre-computed mean coverage for a given SRA project to
#' identify the expressed regions (ERs) for a given chromosome. It returns a
#' [GRanges-class][GenomicRanges::GRanges-class] object with the expressed regions as
#' defined by [findRegions][derfinder::findRegions].
#'
#' @param project A character vector with one SRA study id.
#' @param chr A character vector with the name of the chromosome.
#' @param cutoff The base-pair level cutoff to use.
#' @param outdir The destination directory for the downloaded file(s) that were
#' previously downloaded with [download_study]. If the files are missing,
#' but `outdir` is specified, they will get downloaded first. By default
#' `outdir` is set to `NULL` which will use the data from the web.
#' We only recommend downloading the full data if you will use it several times.
#' @param maxClusterGap This determines the maximum gap between candidate ERs.
#' @param chrlen The chromosome length in base pairs. If it's `NULL`, the
#' chromosome length is extracted from the Rail-RNA runs GitHub repository.
#' Alternatively check the `SciServer` section on the vignette to see
#' how to access all the recount data via a R Jupyter Notebook.
#' @param verbose If `TRUE` basic status updates will be printed along the
#' way.
#' @param ... Additional arguments passed to [download_study] when
#' `outdir` is specified but the required files are missing.
#'
#' @return A [GRanges-class][GenomicRanges::GRanges-class] object as created by
#' [findRegions][derfinder::findRegions].
#'
#' @author Leonardo Collado-Torres
#' @export
#'
#' @import derfinder GenomicRanges RCurl S4Vectors GenomeInfoDb
#' @importMethodsFrom rtracklayer import import.bw
#' @importFrom RCurl url.exists
#'
#' @seealso [download_study], [findRegions][derfinder::findRegions],
#' [railMatrix][derfinder::railMatrix]
#'
#' @examples
#' ## Define expressed regions for study SRP002001, chrY
#'
#' ## Workaround for https://github.com/lawremi/rtracklayer/issues/83
#' download_study("SRP002001", type = "mean")
#'
#' regions <- expressed_regions("SRP002001", "chrY",
#'     cutoff = 5L,
#'     maxClusterGap = 3000L,
#'     outdir = "SRP002001"
#' )
#'
#' \dontrun{
#' ## Define the regions for multiple chrs
#' regs <- sapply(chrs, expressed_regions, project = "SRP002001", cutoff = 5L)
#'
#' ## You can then combine them into a single GRanges object if you want to
#' library("GenomicRanges")
#' single <- unlist(GRangesList(regs))
#' }
#'
expressed_regions <- function(
        project, chr, cutoff, outdir = NULL,
        maxClusterGap = 300L, chrlen = NULL, verbose = TRUE, ...) {
    ## Check inputs
    stopifnot(is.character(project) & length(project) == 1)
    stopifnot(is.character(chr) & length(chr) == 1)

    ## Use table from the package
    url_table <- recount::recount_url

    ## Subset url data
    url_table <- url_table[url_table$project == project, ]
    if (nrow(url_table) == 0) {
        stop("Invalid 'project' argument. There's no such 'project' in the recount_url data.frame.")
    }

    ## Find chromosome length if absent
    if (is.null(chrlen)) {
        chrinfo <- read.table("https://raw.githubusercontent.com/nellore/runs/master/gtex/hg38.sizes",
            col.names = c("chr", "size"), colClasses = c(
                "character",
                "integer"
            )
        )
        chrlen <- chrinfo$size[chrinfo$chr == chr]
        stopifnot(length(chrlen) == 1)
    }

    ## Check if data is present, otherwise download it
    if (!is.null(outdir)) {
        ## Check mean file
        meanFile <- file.path(outdir, "bw", url_table$file_name[grep(
            "mean",
            url_table$file_name
        )])
        if (!file.exists(meanFile)) {
            download_study(
                project = project, type = "mean", outdir = outdir,
                download = TRUE, ...
            )
        }
    } else {
        meanFile <- download_study(
            project = project, type = "mean",
            download = FALSE
        )
    }

    ## Load coverage
    meanCov <- derfinder::loadCoverage(
        files = meanFile, chr = chr,
        chrlen = chrlen
    )

    ## Find regions
    regs <- derfinder::findRegions(
        position = S4Vectors::Rle(TRUE, length(meanCov$coverage[[1]])),
        fstats = meanCov$coverage[[1]], chr = chr,
        maxClusterGap = maxClusterGap, cutoff = cutoff, verbose = verbose
    )

    ## If there are no regions, return NULL
    if (is.null(regs)) regs <- GenomicRanges::GRanges()

    ## Format appropriately
    names(regs) <- seq_len(length(regs))

    ## Set the length
    GenomeInfoDb::seqlengths(regs) <- length(meanCov$coverage[[1]])

    ## Finish
    return(regs)
}
