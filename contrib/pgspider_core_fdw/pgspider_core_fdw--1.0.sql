/* contrib/pgspider_core_fdw/pgspider_core_fdw--1.0.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pgspider_core_fdw" to load this file. \quit

				CREATE FUNCTION pgspider_core_fdw_handler()
			RETURNS fdw_handler
			AS 'MODULE_PATHNAME'
			LANGUAGE C STRICT;

CREATE		FUNCTION
pgspider_core_fdw_validator(text[], oid)
RETURNS void
			AS 'MODULE_PATHNAME'
			LANGUAGE C STRICT;

CREATE		FOREIGN DATA WRAPPER pgspider_core_fdw
			HANDLER pgspider_core_fdw_handler
			VALIDATOR pgspider_core_fdw_validator;

CREATE OR REPLACE FUNCTION pgspider_core_fdw_version()
  RETURNS pg_catalog.int4 STRICT
  AS 'MODULE_PATHNAME' LANGUAGE C;
