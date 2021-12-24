#-------------------------------------------------------------------------
#
# Makefile--
#    Makefile for utils/hash
#
# IDENTIFICATION
#    src/backend/utils/hash/Makefile
#
#-------------------------------------------------------------------------

subdir = src/backend/utils/hash
top_builddir = ../../../..
include $(top_builddir)/src/Makefile.global

OBJS = \
	dynahash.o \
	pg_crc.o

dynahash.o : dynahash.c dynahash_thread.c

include $(top_srcdir)/src/backend/common.mk
