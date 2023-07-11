# contrib/pgspider_core_fdw/Makefile

MODULE_big = pgspider_core_fdw
OBJS = deparse.o pgspider_core_fdw.o pgspider_core_option.o pgspider_core_routing.o pgspider_core_timemeasure.o pgspider_core_remoteproc.o pgspider_core_compression_transfer.o $(WIN32RES)
PGFILEDESC = "pgspider_core_fdw - PGSpider core module"

PG_CPPFLAGS = -I$(libpq_srcdir) -I../ -lpthread -lpq -lm -lpgspider_keepalive -z defs
SHLIB_LINK = $(libpq)

# Add files and flags for Parquet S3 FDW
ifdef ENABLE_PARALLEL_S3
OBJS += pgspider_core_s3.o parquet_s3_fdw_server_option.o
SHLIB_LINK += -laws-cpp-sdk-core -laws-cpp-sdk-s3
PG_CPPFLAGS += -std=c++11 -DENABLE_PARALLEL_S3
endif

EXTENSION = pgspider_core_fdw
DATA = pgspider_core_fdw--1.0.sql

REGRESS = ported_postgres_fdw pd_stored

EXTRA_INSTALL = contrib/pgspider_keepalive

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
SHLIB_PREREQS = submake-libpq
subdir = contrib/pgspider_core_fdw/
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
VPATH = fdws
FILES = file_fdw.so
DSTDIR=outdir

OUTFILES=$(FILES:%=$(DSTDIR)/%)

check: temp-install

temp-install: EXTRA_INSTALL+=contrib/postgres_fdw contrib/pgspider_core_fdw contrib/pgspider_keepalive contrib/pgspider_fdw

checkprep: EXTRA_INSTALL+=contrib/postgres_fdw contrib/pgspider_core_fdw contrib/pgspider_keepalive contrib/pgspider_fdw contrib/dblink

#check: copyfdw
copyfdw:
	$(OUTFILES):: $(FILES)
	cp $? $(DSTDIR)/

