#' multi_res_baps
#'
#' Function to perform Bayesian hierarchical clustering of population structure successively at multiple resolutions, choosing the best partition at each level.
#'
#' @import Matrix
#'
#' @param sparse.data a sparse SNP data object returned from import_fasta_sparse_nt
#' @param levels the number of levels to investigate (default=2)
#' @param k.init the initial number of clusters for the top level (default=n.isolates/4)
#' @param hc.method the type of initial hierarchical clustering to use. Can be with 'ward' or 'genie' (default='ward')
#' @param n.cores the number of cores to use in clustering
#' @param quiet whether to print additional information or not (default=TRUE)
#'
#' @return a data.frame representing the final clustering at multiple resolutions
#'
#' @examples
#'
#' fasta.file.name <- system.file("extdata", "seqs.fa", package = "fastbaps")
#' sparse.data <- import_fasta_sparse_nt(fasta.file.name)
#' multi.res.df <- multi_res_baps(sparse.data, levels=2)
#'
#' @export
multi_res_baps <- function(sparse.data, levels=2, k.init=NULL, hc.method='ward',
                           n.cores=1, quiet=TRUE){

  # Check inputs
  if(!is.list(sparse.data)) stop("Invalid value for sparse.data! Did you use the import_fasta_sparse_nt function?")
  if(!(class(sparse.data$snp.matrix)=="dgCMatrix")) stop("Invalid value for sparse.data! Did you use the import_fasta_sparse_nt function?")
  if(!is.numeric(sparse.data$consensus)) stop("Invalid value for sparse.data! Did you use the import_fasta_sparse_nt function?")
  if(!is.matrix(sparse.data$prior)) stop("Invalid value for sparse.data! Did you use the import_fasta_sparse_nt function?")
  if(!is.numeric(n.cores) || n.cores<1) stop("Invalid value for n.cores!")
  if(!is.numeric(levels) | levels < 0) stop("Invalid value for levels!")
  if(!(hc.method %in% c("ward", "genie"))) stop("Invalid hc.method!")

  n.isolates <- ncol(sparse.data$snp.matrix)
  n.snps <- nrow(sparse.data$snp.matrix)

  cluster.results <- matrix(1, nrow = n.isolates, ncol = levels+1)

  for (l in seq_len(levels)){
    if(!quiet) print(paste("Clustering at level", l))

    prev.partition <- split(1:n.isolates, cluster.results[,l])

    new.partitions <- rep(NA, n.isolates)
    for (p in seq_along(prev.partition)){
      part <- prev.partition[[p]]
      if (length(part)>4){
        temp.data <- sparse.data
        temp.data$snp.matrix <- temp.data$snp.matrix[,part,drop=FALSE]
        rs <- rowSums(temp.data$snp.matrix>0)
        keep <- rs>0
        keep <- keep & (rs<length(part))
        if(sum(keep)<=1){
          new.partitions[part] <- n.isolates*p*2
          next
        }
        temp.data$snp.matrix <- temp.data$snp.matrix[keep, , drop=FALSE]
        temp.data$prior <- temp.data$prior[, keep, drop=FALSE]
        temp.data$consensus <- temp.data$consensus[keep]
        temp.data$hclust <- NULL

        if((l==1) && !is.null(k.init)){
          fb <- fastbaps::fast_baps(temp.data, n.cores = n.cores, k.init = k.init,
                                    hc.method=hc.method, quiet = quiet)
        } else {
          fb <- fastbaps::fast_baps(temp.data, hc.method=hc.method, n.cores = n.cores,
                                    quiet = quiet)
        }

        new.partitions[part] <- n.isolates*p*2 + fastbaps::best_baps_partition(temp.data, fb, quiet = quiet)
      } else {
        new.partitions[part] <- n.isolates*p*2
      }
    }
    #relabel 1:n.clusters
    cluster.results[,l+1] <- as.numeric(factor(new.partitions))

  }

  df <- data.frame(Isolates=colnames(sparse.data$snp.matrix), cluster.results[,2:ncol(cluster.results)],
                  stringsAsFactors = FALSE)
  colnames(df)[2:ncol(df)] <- paste("Level", 1:levels)

  return(df)
}
