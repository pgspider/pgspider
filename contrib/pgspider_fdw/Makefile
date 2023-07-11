# contrib/pgspider_fdw/Makefile

MODULE_big = pgspider_fdw
OBJS = \
	$(WIN32RES) \
	connection.o \
	deparse.o \
	option.o \
	pgspider_fdw.o \
	pgspider_data_compression_transfer.o \
	shippable.o
PGFILEDESC = "pgspider_fdw - foreign data wrapper for PGSpider"

PG_CPPFLAGS = -I$(libpq_srcdir)
SHLIB_LINK_INTERNAL = $(libpq) -llz4 -lcurl

EXTENSION = pgspider_fdw
DATA = pgspider_fdw--1.0.sql pgspider_fdw--1.0--1.1.sql pgspider_fdw--1.1.sql pgspider_fdw--1.2.sql pgspider_fdw--1.3.sql pgspider_fdw--1.4.sql

REGRESS = pgspider_fdw

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
SHLIB_PREREQS = submake-libpq
subdir = contrib/pgspider_fdw
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
