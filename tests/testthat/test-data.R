context("Download data, scale, ER-level")

library("SummarizedExperiment")

## Download the example data included in the package
url <- download_study("SRP009615", outdir = file.path(tempdir(), "SRP009615"))

## Load the data
load(file.path(tempdir(), "SRP009615", "rse_gene.Rdata"))

## Check size once:
# > file.path(tempdir(), 'SRP009615', 'rse_gene.Rdata')
# [1] "/var/folders/cx/n9s558kx6fb7jf5z_pgszgb80000gn/T//Rtmptm6u0K/SRP009615/rse_gene.Rdata"
# >
# > system('ls -lh /var/folders/cx/n9s558kx6fb7jf5z_pgszgb80000gn/T//Rtmptm6u0K/SRP009615/rse_gene.Rdata')
# -rw-r--r--  1 lcollado  staff   3.0M Apr 27 16:35 /var/folders/cx/n9s558kx6fb7jf5z_pgszgb80000gn/T//Rtmptm6u0K/SRP009615/rse_gene.Rdata
unlink(file.path(tempdir(), "SRP009615", "rse_gene.Rdata"))

## Compare the data
test_that("Example RSE", {
    expect_equivalent(rse_gene, rse_gene_SRP009615)
})

## Temporary download URLs
test_that("Download URLs", {
    expect_equal(
        download_study("DRP000366", type = "mean", download = FALSE),
        "http://duffel.rail.bio/recount/DRP000366/bw/mean_DRP000366.bw"
    )
    expect_equal(
        download_study("DRP000366",
            type = "samples",
            download = FALSE
        ),
        "http://duffel.rail.bio/recount/DRP000366/bw/DRR000897.bw"
    )
    expect_equal(
        download_study("DRP000366", type = "rse-fc", download = FALSE),
        "http://duffel.rail.bio/recount/fc_rc/rse_fc_DRP000366.Rdata"
    )
})

## Test downloading a small project entirely
tmpdir <- file.path(tempdir(), "SRP002001")
urls <- download_study("SRP002001", type = "all", outdir = tmpdir)
expected_urls <- paste0(
    "http://duffel.rail.bio/recount/",
    rep(rep(c("v2/", ""), 3), c(2, 1, 3, 2, 1, 2)), "SRP002001/",
    c(
        "rse_gene.Rdata", "rse_exon.Rdata", "rse_jx.Rdata",
        "rse_tx.RData", "counts_gene.tsv.gz",
        "counts_exon.tsv.gz", "counts_jx.tsv.gz",
        "SRP002001.tsv", "files_info.tsv",
        "bw/SRR036661.bw", "bw/mean_SRP002001.bw"
    )
)
names(expected_urls) <- c(
    "rse-gene", "rse-exon", "rse-jx", "rse-tx",
    "counts-gene", "counts-exon", "counts-jx",
    "phenotype", "files-info", "samples", "mean"
)

## Compute md5sum locally
localfiles <- c(
    list.files(tmpdir, "[.]", full.names = TRUE),
    dir(file.path(tmpdir, "bw"), full.names = TRUE)
)
names(localfiles) <- c(list.files(tmpdir, "[.]"), dir(file.path(tmpdir, "bw")))

library("tools")
md5 <- sapply(localfiles, md5sum)
names(md5) <- names(localfiles)
## md5sum doesn't match for jx files?
md5 <- md5[-which(names(md5) %in% c(
    "files_info.tsv", "counts_jx.tsv.gz",
    "rse_jx.Rdata"
))]

## Get original md5sum
fileinfo <- read.table(file.path(tmpdir, "files_info.tsv"),
    header = TRUE,
    stringsAsFactors = FALSE
)

test_that("Project SRP002001", {
    expect_equal(urls, expected_urls)
    expect_equivalent(fileinfo$md5sum[match(names(md5), fileinfo$file)], md5)
})

scaleFac <- scale_counts(rse_gene_SRP009615, factor_only = TRUE)
scaleFac_mapped <- scale_counts(rse_gene_SRP009615,
    by = "mapped_reads",
    factor_only = TRUE
)
rse <- scale_counts(rse_gene_SRP009615, round = FALSE)

test_that("Scaling", {
    expect_equal(round(head(scaleFac), 2), c(
        "SRR387777" = 0.04,
        "SRR387778" = 0.03, "SRR387779" = 0.03, "SRR387780" = 0.04,
        "SRR389077" = 0.04, "SRR389078" = 0.04
    ))
    expect_gt(scaleFac_mapped[1], scaleFac[1])
    expect_gt(scaleFac_mapped[2], scaleFac[2])
    expect_gt(scaleFac_mapped[3], scaleFac[3])
    expect_equal(assay(rse, 1) / matrix(rep(scaleFac, each = 58037),
        ncol = 12
    ), assay(rse_gene_SRP009615, 1))
})

regions <- expressed_regions("SRP002001", "chrY", cutoff = 5, outdir = tmpdir)
## Artificially remove the mean coverage file so that the file will have to
## get downloaded on the first test, then it'll be present for the second
## test
unlink(localfiles["mean_SRP002001.bw"])

test_that("Expressed regions", {
    expect_equal(
        regions,
        expressed_regions("SRP002001", "chrY", cutoff = 5, outdir = tmpdir)
    )
})


rse_ER <- coverage_matrix("SRP002001", "chrY", regions, outdir = tmpdir)
## Same for the phenotype data and the sample bigwig file
unlink(localfiles["SRP002001.tsv"])
unlink(localfiles["SRR036661.bw"])

test_that("Coverage matrix", {
    expect_equal(
        rse_ER,
        coverage_matrix("SRP002001", "chrY", regions, outdir = tmpdir)
    )
    expect_equal(
        rse_ER,
        coverage_matrix("SRP002001", "chrY", regions,
                        outdir = tmpdir,
                        chunksize = 500
        )
    )
})

## Check size once:
# > tmpdir
# [1] "/var/folders/9f/82m1lr2n1fv1mk91plf2l_dr0000gn/T//Rtmp8kCCFV/SRP002001"
# > system("du -sh /var/folders/9f/82m1lr2n1fv1mk91plf2l_dr0000gn/T//Rtmp8kCCFV/SRP002001")
#  90M	/var/folders/9f/82m1lr2n1fv1mk91plf2l_dr0000gn/T//Rtmp8kCCFV/SRP002001
unlink(tmpdir, recursive = TRUE)


metadata <- all_metadata()
test_that("All metadata", {
    expect_equal(nrow(metadata), 50099)
})

phenoFile <- download_study(
    project = "SRP012289", type = "phenotype",
    download = FALSE
)
pheno <- read.table(phenoFile,
    header = TRUE, stringsAsFactors = FALSE,
    sep = "\t"
)
test_that("Correct phenotype information", {
    expect_equal(pheno$auc, 159080954)
})


## Test Snaptron
library("GenomicRanges")
junctions <- GRanges(seqnames = "chr2", IRanges(
    start = c(28971710:28971712, 29555081:29555083, 29754982:29754984),
    end = c(29462417:29462419, 29923338:29923340, 29917714:29917716)
))

junctions_v2 <- GRanges(seqnames = "chr2", IRanges(
    start = 29532116:29532118, end = 29694848:29694850
))

snap <- snaptron_query(junctions)
snap_v2 <- snaptron_query(junctions_v2, version = "srav2")
snap_gtex <- snaptron_query(junctions_v2, version = "gtex")
snap_tcga <- snaptron_query(junctions_v2, version = "tcga")

if (!is.null(snap)) {
    test_that("Snaptron", {
        expect_equal(length(snap), 3)
        expect_equal(ncol(mcols(snap)), 14)
        expect_equal(snap$left_annotated[[1]], as.character(NA))
        expect_equal(snaptron_query(junctions[1], verbose = FALSE), NULL)
        expect_equal(is(snap_v2$annotated, "CompressedCharacterList"), TRUE)
        expect_equal(snaptron_query(junctions_v2, verbose = FALSE), NULL)
        expect_equal(snap_gtex$type == "GTEx:I", TRUE)
        expect_equal(snap_tcga$type == "TCGA:I", TRUE)
    })
} else {
    warning("Snaptron_query() is not working! See https://github.com/ChristopherWilks/snaptron/issues/17 for more details.")
}


## Weird pheno files
## First 2 are separate from the rest
projects <- c(
    "SRP036843", "SRP029334", "SRP050563", "SRP055438", "SRP055749",
    "SRP058120", "SRP005342", "SRP007508", "SRP015668"
)
sapply(projects, download_study, type = "phenotype")
phenoFiles <- sapply(projects, function(x) {
    file.path(x, paste0(x, ".tsv"))
})
pheno <- mapply(recount:::.read_pheno, phenoFiles, projects, SIMPLIFY = FALSE)

pheno_tcga <- recount:::.read_pheno("doesntexist", "TCGA")
test_that("Weird pheno files", {
    expect_equivalent(sapply(pheno, nrow), c(3, 5, 4, 33, 16, 30, 12, 5, 33))
    expect_equal(dim(pheno_tcga), c(11284, 864))
})


test_that("RPKM", {
    expect_equal(getRPKM(rse_gene_SRP009615)[1, ], assays(rse_gene_SRP009615)$count[1, ] / (rowData(rse_gene_SRP009615)$bp_length[1] / 1000) / (colSums(assays(rse_gene_SRP009615)$count) / 1e6))
    expect_equal(getRPKM(rse_gene_SRP009615, length_var = NULL)[1, ], assays(rse_gene_SRP009615)$count[1, ] / (width(rowRanges(rse_gene_SRP009615))[1] / 1000) / (colSums(assays(rse_gene_SRP009615)$count) / 1e6))
    expect_equal(getRPKM(rse_gene_SRP009615, mapped_var = "mapped_read_count")[1, ], assays(rse_gene_SRP009615)$count[1, ] / (rowData(rse_gene_SRP009615)$bp_length[1] / 1000) / (colData(rse_gene_SRP009615)$mapped_read_count / 1e6))
    expect_equal(getRPKM(rse_gene_SRP009615, length_var = NULL, mapped_var = "mapped_read_count")[1, ], assays(rse_gene_SRP009615)$count[1, ] / (width(rowRanges(rse_gene_SRP009615))[1] / 1000) / (colData(rse_gene_SRP009615)$mapped_read_count / 1e6))
})

rse_pred <- add_predictions(rse_gene_SRP009615)
test_that("Predictions", {
    expect_equal(all(c("reported_sex", "predicted_sex", "accuracy_sex", "reported_samplesource", "predicted_samplesource", "accuracy_samplesource", "reported_tissue", "predicted_tissue", "accuracy_tissue", "reported_sequencingstrategy", "predicted_sequencingstrategy", "accuracy_sequencingstrategy") %in% colnames(colData(rse_pred))), TRUE)
})

## read_counts
download_study("DRP000499")
load("DRP000499/rse_gene.Rdata")
test_that("read_counts", {
    expect_equal(all(colSums(assays(read_counts(rse_gene, use_paired_end = FALSE))$counts) / colSums(assays(read_counts(rse_gene))$counts) == 2), TRUE)
    expect_equal(all(sign(colSums(assays(read_counts(rse_gene))$counts) / 1e6 - colData(rse_gene)$reads_downloaded / 1e6 / 2) == -1), TRUE)
})

## Clean up
for (p in c(projects, "DRP000499")) unlink(p, recursive = TRUE)
