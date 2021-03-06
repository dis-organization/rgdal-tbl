require(methods, quietly = TRUE, warn.conflicts = FALSE)

.setCollectorFun <- function(object, fun)
  .Call('R_RegisterFinalizerEx', object, fun, TRUE, PACKAGE="rgdal")

.assertClass <- function(object, class) {
  
  if (class %in% is(object))
    invisible(object)
  else
    stop(paste('Object is not a member of class', class))

}

.GDALDataTypes <- c('Unknown', 'Byte', 'UInt16', 'Int16', 'UInt32',
                    'Int32', 'Float32', 'Float64', 'CInt16', 'CInt32',
                    'CFloat32', 'CFloat64')

setClass('GDALMajorObject',
         representation(handle = 'externalptr'))
 
getDescription <- function(object) {

  .assertClass(object, 'GDALMajorObject')

  .Call('RGDAL_GetDescription', object, PACKAGE="rgdal")

}

getMetadata <- function(object, domain = "") {

  .assertClass(object, 'GDALMajorObject')

  metadata <- .Call('RGDAL_GetMetadata', object,
                    as.character(domain), PACKAGE="rgdal")

  if (is.null(metadata))
    metadata
  else
    noquote(metadata)

}

setMetadata <- function(object, metadata) {

  .assertClass(object, 'GDALMajorObject')

  metadata <- lapply(as.list(metadata), as.character)

  .Call('RGDAL_SetMetadata', object, metadata, PACKAGE="rgdal")

  invisible(object)
  
}

appendMetadata <- function(object, metadata) {

  .assertClass(object, 'GDALMajorObject')

  setMetadata(object, append(getMetadata(object), metadata))

}

setClass('GDALDriver', 'GDALMajorObject')

setClass('GDALReadOnlyDataset', 'GDALMajorObject')

setClass('GDALDataset', 'GDALMajorObject')

setClass('GDALTransientDataset', 'GDALMajorObject')
         
setClass('GDALRasterBand', 'GDALMajorObject')

getGDALDriverNames <- function() .Call('RGDAL_GetDriverNames')

setMethod('initialize', 'GDALDriver',
          def = function(.Object, name, handle = NULL) {
            if (is.null(handle)) {
              slot(.Object, 'handle') <- {
                .Call('RGDAL_GetDriver', as.character(name), PACKAGE="rgdal")
              }
            } else {
              slot(.Object, 'handle') <- handle
            }
            .Object
          })

getDriverName <- function(driver) {

  .assertClass(driver, 'GDALDriver')

  .Call('RGDAL_GetDriverShortName', driver, PACKAGE="rgdal")

}

getDriverLongName <- function(driver) {

  .assertClass(driver, 'GDALDriver')

  .Call('RGDAL_GetDriverLongName', driver, PACKAGE="rgdal")

}

setMethod('initialize', 'GDALReadOnlyDataset',
          def = function(.Object, filename, handle = NULL) {
            if (is.null(handle)) {
              slot(.Object, 'handle') <- {
                .Call('RGDAL_OpenDataset', as.character(filename), 
			TRUE, PACKAGE="rgdal")
              }
            } else {
              slot(.Object, 'handle') <- handle
            }
            cfn <- function(handle) .Call('RGDAL_CloseHandle', 
		handle, PACKAGE="rgdal")
            .setCollectorFun(slot(.Object, 'handle'), cfn)
            .Object
          })

setMethod('initialize', 'GDALDataset',
          def = function(.Object, filename, handle = NULL) {
            if (is.null(handle)) {
              slot(.Object, 'handle') <- {
                .Call('RGDAL_OpenDataset', as.character(filename), 
			FALSE, PACKAGE="rgdal")
              }
            } else {
              slot(.Object, 'handle') <- handle
            }
            cfn <- function(handle) .Call('RGDAL_CloseHandle', 
		handle, PACKAGE="rgdal")
            .setCollectorFun(slot(.Object, 'handle'), cfn)
            .Object
          })

setMethod('initialize', 'GDALTransientDataset',
          def = function(.Object, driver, rows, cols, bands = 1,
            type = 'Byte', options = '', handle = NULL) {
            if (is.null(handle)) {
              typeNum <- match(type, .GDALDataTypes, 1) - 1
              slot(.Object, 'handle') <- .Call('RGDAL_CreateDataset', driver,
                                              as.integer(c(cols, rows, bands)),
                                              as.integer(typeNum),
                                              as.character(options),
                                              tempfile(), PACKAGE="rgdal")
            } else {
              slot(.Object, 'handle') <- handle
            }
            cfn <- function(handle) .Call('RGDAL_DeleteHandle', 
		handle, PACKAGE="rgdal")
            .setCollectorFun(slot(.Object, 'handle'), cfn)
            .Object
          })

getDriver <- function(dataset) {

  .assertClass(dataset, 'GDALReadOnlyDataset')

  new('GDALDriver',
      handle = .Call('RGDAL_GetDatasetDriver', dataset, PACKAGE="rgdal"))

}

copyDataset <- function(dataset, driver, strict = FALSE, options = '') {

  .assertClass(dataset, 'GDALReadOnlyDataset')
  
  if (missing(driver)) driver <- getDriver(dataset)
  
  new.obj <- new('GDALTransientDataset',
                 handle = .Call('RGDAL_CopyDataset',
                   dataset, driver,
                   as.integer(strict),
                   as.character(options),
                   tempfile(), PACKAGE="rgdal"))

  new.obj
  
}

saveDataset <- function(dataset, filename) {

  .assertClass(dataset, 'GDALReadOnlyDataset')
  
  new.class <- ifelse(class(dataset) == 'GDALTransientDataset',
                      'GDALDataset', class(dataset))
  
  new.obj <- new(new.class,
                 handle = .Call('RGDAL_CopyDataset',
                   dataset, getDriver(dataset),
                   FALSE, NULL, filename, PACKAGE="rgdal"))

  invisible(new.obj)
  
}

saveDatasetAs <- function(dataset, filename, driver = NULL) {

  .assertClass(dataset, 'GDALReadOnlyDataset')
  
  if (is.null(driver)) driver <- getDriver(dataset)
  
  new.obj <- new('GDALReadOnlyDataset',
                 handle = .Call('RGDAL_CopyDataset',
                   dataset, driver, FALSE, NULL, filename, PACKAGE="rgdal"))
  
  closeDataset(new.obj)
  
  err.opt <- getOption('show.error.messages')

  options(show.error.messages = FALSE)

  new.obj <- try(new('GDALDataset', filename))

  options(show.error.messages = err.opt)

  if (inherits(new.obj, 'try-error'))
    new.obj <- new('GDALReadOnlyDataset', filename)

  closeDataset(dataset)

  eval.parent(dataset <- new.obj)

  invisible(new.obj)
  
}

setGeneric('closeDataset',
           def = function(dataset) standardGeneric('closeDataset'),
           where = 2, valueClass = 'NULL')

setMethod('closeDataset', 'GDALReadOnlyDataset',
          def = function(dataset) {
            .setCollectorFun(slot(dataset, 'handle'), NULL)
            .Call('RGDAL_CloseDataset', dataset, PACKAGE="rgdal")
            invisible()
          })

setMethod('closeDataset', 'GDALTransientDataset',
          def = function(dataset) {
            driver <- getDriver(dataset)
            filename <- getDescription(dataset)
            .Call('RGDAL_DeleteFile', driver, filename, PACKAGE="rgdal")
            callNextMethod()
          })

deleteDataset <- function(dataset) {

  .assertClass(dataset, 'GDALDataset')
  
  driver <- getDriver(dataset)
  
  filename <- getDescription(dataset)
  
  .Call('RGDAL_DeleteFile', driver, filename, PACKAGE="rgdal")
  
  closeDataset(dataset)

}

GDAL.open <- function(filename) {
	res <- new("GDALReadOnlyDataset", filename)
	res
}

GDAL.close <- function(dataset) {
            .setCollectorFun(slot(dataset, 'handle'), NULL)
            .Call('RGDAL_CloseDataset', dataset, PACKAGE="rgdal")
            invisible()
}

#if (!isGeneric('dim')) setGeneric('dim')

setMethod('dim', 'GDALReadOnlyDataset',
          def = function(x) {
            nrows <- .Call('RGDAL_GetRasterYSize', x, PACKAGE="rgdal")
            ncols <- .Call('RGDAL_GetRasterXSize', x, PACKAGE="rgdal")
            nbands <- .Call('RGDAL_GetRasterCount', x, PACKAGE="rgdal")
            if (nbands > 1)
              c(nrows, ncols, nbands)
            else
              c(nrows, ncols)
          })

getProjectionRef <- function(dataset) {

  .assertClass(dataset, 'GDALReadOnlyDataset')

  noquote(.Call('RGDAL_GetProjectionRef', dataset, PACKAGE="rgdal"))

}

putRasterData <- function(dataset,
                          rasterData,
                          band = 1,
                          offset = c(0, 0)) {

  .assertClass(dataset, 'GDALDataset')

  offset <- rep(offset, length.out = 2)
  
  rasterBand <- new('GDALRasterBand', dataset, band)
  
  .Call('RGDAL_PutRasterData', rasterBand, rasterData, 
	as.integer(offset), PACKAGE="rgdal")

}

getRasterTable <- function(dataset,
                           band = NULL,
                           offset = c(0, 0),
                           region.dim = dim(dataset)) {

  .assertClass(dataset, 'GDALReadOnlyDataset')

  offset <- rep(offset, length.out = 2)
  region.dim <- rep(region.dim, length.out = 2)

  rasterData <- getRasterData(dataset, band,
                              offset = offset,
                              region = region.dim)

  nbands <- .Call('RGDAL_GetRasterCount', dataset, PACKAGE="rgdal")

  if (is.null(band)) band <- 1:nbands

  dim(rasterData) <- c(region.dim, nbands)

  geoTrans <- getGeoTransFunc(dataset)

  x.i <- 1:region.dim[1] + offset[1]
  y.i <- 1:region.dim[2] + offset[2]

  y.i <- rep(y.i, each = length(x.i))
  x.i <- rep(x.i, len = prod(region.dim))

  out <- geoTrans(x.i, y.i)

  for (b in band) out <- cbind(out, as.vector(rasterData[,,b]))

  out <- as.data.frame(out)
    
  names(out) <- c('row', 'column', paste('band', 1:nbands, sep = ''))

  out

}

                           
getRasterData <- function(dataset,
                          band = NULL,
                          offset = c(0, 0),
                          region.dim = dim(dataset),
                          output.dim = region.dim,
                          interleave = c(0, 0),
                          set.dimnames = FALSE,
                          as.is = FALSE) {

  .assertClass(dataset, 'GDALReadOnlyDataset')

  offset <- rep(offset, length.out = 2)
  region.dim <- rep(region.dim, length.out = 2)
  output.dim <- rep(output.dim, length.out = 2)
  interleave <- rep(interleave, length.out = 2)

  nbands <- .Call('RGDAL_GetRasterCount', dataset, PACKAGE="rgdal")

  if (is.null(band)) band <- 1:nbands
  
  x <- array(dim = as.integer(c(rev(output.dim), length(band))))

  for (i in seq(along=band)) {
  
    rasterBand <- new('GDALRasterBand', dataset, band[i])

    x[,,i] <- .Call('RGDAL_GetRasterData', rasterBand,
                      as.integer(c(offset, region.dim)),
                      as.integer(output.dim),
                      as.integer(interleave), PACKAGE="rgdal")
  
  }

  if (set.dimnames) {

    geoTrans <- getGeoTransFunc(dataset)

    x.i <- 1:output.dim[1] + offset[1]
    y.i <- 1:output.dim[2] + offset[2]

    xy <- geoTrans(x.i, y.i)

    dimnames(x) <- list(xy[,1], xy[,2], band)

  }

  x <- drop(x)

  if (!as.is) {
  
    scale <- .Call('RGDAL_GetScale', rasterBand, PACKAGE="rgdal")
    offset <- .Call('RGDAL_GetOffset', rasterBand, PACKAGE="rgdal")

    if (scale != 1) x <- x * scale
    if (offset != 0) x <- x + offset
    
    catNames <- .Call('RGDAL_GetCategoryNames', rasterBand, PACKAGE="rgdal")
  
    if (!is.null(catNames)) {
      levels <- rep(min(x):max(x), len = length(catNames))
      x <- array(factor(x, levels, catNames), dim = dim(x),
                 dimnames = dimnames(x))
    }

  }

  x

}

getColorTable <- function(dataset, band = NULL) {

  .assertClass(dataset, 'GDALReadOnlyDataset')

  nbands <- .Call('RGDAL_GetRasterCount', dataset, PACKAGE="rgdal")
  
  if (nbands > 1) warning('RGB imaging not yet supported')

  if (is.null(band)) band <- 1
  
  rasterBand <- new('GDALRasterBand', dataset, band)
  
  ctab <- .Call('RGDAL_GetColorTable', rasterBand, PACKAGE="rgdal") / 255

  if (length(ctab) == 0) return(NULL)

  if (.Call('RGDAL_GetColorInterp', rasterBand, PACKAGE="rgdal") == 'Palette')
    switch(.Call('RGDAL_GetPaletteInterp', rasterBand, PACKAGE="rgdal"),  
           RGB = rgb(ctab[,1], ctab[,2], ctab[,3]),
           HSV = hsv(ctab[,1], ctab[,2], ctab[,3]), # Doesn't actually exist
           Gray = gray(ctab[,1]),
           gray(apply(ctab, 2, mean)))
  else
    gray(ctab[,1])

}

displayDataset <- function(x, offset = c(0, 0), region.dim = dim(x),
                           reduction = 1, band = NULL, col = NULL,
                           reset.par = TRUE, max.dim = 500, ...) {

  .assertClass(x, 'GDALReadOnlyDataset')

  offset <- rep(offset, length.out = 2)
  region.dim <- rep(region.dim, length.out = 2)
  reduction <- rep(reduction, length.out = 2)

  if (is.null(band)) band <- 1

  if (length(band) > 1)
    warning('Displaying average of RGB values; ',
            'this may take some time')
  
  offset <- offset %% dim(x)[1:2]
  
  outOfBounds <- (region.dim + offset) > dim(x)[1:2]
  
  if (any(outOfBounds))
    region.dim[outOfBounds]  <- {
      dim(x)[outOfBounds] - offset[outOfBounds]
    }

  if (any(reduction < 1)) reduction[reduction < 1] <- 1

  plot.dim <- region.dim / reduction
            
  if (any(plot.dim > max.dim))
    plot.dim <- max.dim * plot.dim / max(plot.dim)

  if (any(plot.dim < 3))
    plot.dim <- 3 * plot.dim / max(plot.dim)

  image.data <- getRasterData(x, band, offset, region.dim,
                              plot.dim, as.is = TRUE)
  
  if (length(dim(image.data)) > 2)
    image.data <- apply(image.data, 1:2, mean)

  if (is.complex(image.data))
    image.data <- Mod(image.data)
            
  max.val <- max(image.data, na.rm = TRUE)

  if (!is.finite(max.val)) {
    image.data[] <- 2
    max.val <- 2
  }

  if (is.null(col))
    col <- getColorTable(x, band)[1:(max.val + 1)]

  if (is.null(col)) col <- gray(seq(0, 1, len = 64))
  
  par.in <- par(no.readonly = TRUE)

  if (reset.par) on.exit(par(par.in))

  par(pin = max(par.in$pin)
      * par.in$fin / max(par.in$fin)
      * rev(plot.dim) / max(plot.dim))
  
  image.data <- image.data[, ncol(image.data):1]
  
#  geoTrans <- getGeoTransFunc(dataset)

#  x.i <- 1:plot.dim[1] + offset[1]
#  y.i <- 1:plot.dim[2] + offset[2]

#  xy <- getGeoTransFunc(x)(x.i, y.i)

  image.default(image.data + 1, col = col, ...)
            
  invisible(image.data)

}

if (!isGeneric('image')) setGeneric('image', where = 2)

setMethod('image', 'GDALReadOnlyDataset', displayDataset)

setMethod('initialize', 'GDALRasterBand',
          def =  function(.Object, dataset, band = 1) {
            slot(.Object, 'handle') <- .Call('RGDAL_GetRasterBand',
                                            dataset, as.integer(band), 
					    PACKAGE="rgdal")
            .Object
          })

setMethod('dim', 'GDALRasterBand',
          def = function(x) {
            c(.Call('RGDAL_GetYSize', x, PACKAGE="rgdal"),
              .Call('RGDAL_GetXSize', x, PACKAGE="rgdal"))
          })

getGeoTransFunc <- function(dataset) {

  geoTrans <- .Call('RGDAL_GetGeoTransform', dataset, PACKAGE="rgdal")

  rotMat <- matrix(geoTrans[c(6, 5, 3, 2)], 2)

  offset <- geoTrans[c(4, 1)]

  function(x, y = NULL) {

    if (!is.null(y)) x <- cbind(x, y)

    x <- x %*% rotMat

    x[,1] <- x[,1] + offset[1]
    x[,2] <- x[,2] + offset[2]

    x
    
  }

}

.First.lib <- function(lib, pkg) {

  require(methods, quietly = TRUE, warn.conflicts = FALSE)

  library.dynam('rgdal', pkg, lib)

  .Call('RGDAL_Init', PACKAGE="rgdal")

  cat('Geospatial Data Abstraction Library ')
  cat('extensions to R successfully loaded\n')
  
}
