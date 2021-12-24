/* contrib/pgspider_fdw/pgspider_fdw--1.3.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pgspider_fdw" to load this file. \quit

CREATE FUNCTION pgspider_fdw_handler()
RETURNS fdw_handler
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FUNCTION pgspider_fdw_validator(text[], oid)
RETURNS void
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FOREIGN DATA WRAPPER pgspider_fdw
  HANDLER pgspider_fdw_handler
  VALIDATOR pgspider_fdw_validator;

CREATE FUNCTION pgspider_fdw_get_connections (OUT server_name text,
    OUT valid boolean)
RETURNS SETOF record
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT PARALLEL RESTRICTED;

CREATE FUNCTION pgspider_fdw_disconnect (text)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT PARALLEL RESTRICTED;

CREATE FUNCTION pgspider_fdw_disconnect_all ()
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT PARALLEL RESTRICTED;

CREATE PROCEDURE pgspider_create_or_replace_stub(func_type text, name_arg text, return_type regtype) AS $$
DECLARE
  proname_raw text := split_part(name_arg, '(', 1);
  proname text := ltrim(rtrim(proname_raw));
BEGIN
  IF lower(func_type) = 'aggregation' OR lower(func_type) = 'aggregate' OR lower(func_type) = 'agg' OR lower(func_type) = 'a' THEN
    DECLARE
      proargs_raw text := right(name_arg, length(name_arg) - length(proname_raw));
      proargs text := ltrim(rtrim(proargs_raw));
      proargs_types text := right(left(proargs, length(proargs) - 1), length(proargs) - 2);
      aggproargs text;
    BEGIN
      IF lower(proargs_types) = '*' THEN
        aggproargs := '(text)';
      ELSE
        aggproargs := format('(%s, %s)', return_type, proargs_types);
      END IF;
      BEGIN
        EXECUTE format('
          CREATE OR REPLACE FUNCTION %s_sfunc%s RETURNS %s IMMUTABLE AS $inner$
          BEGIN
            RAISE EXCEPTION ''stub %s_sfunc%s is called'';
            RETURN NULL;
          END $inner$ LANGUAGE plpgsql;',
	      proname, aggproargs, return_type, proname, aggproargs);
      EXCEPTION
        WHEN duplicate_function THEN
          RAISE DEBUG 'stub function for aggregation already exists (ignored)';
      END;
      BEGIN
        IF lower(proargs_types) = '*' THEN
          name_arg := format('%s(*)', proname);
        END IF;
        EXECUTE format('
          CREATE OR REPLACE AGGREGATE %s
          (
            sfunc = %s_sfunc,
            stype = %s
          );', name_arg, proname, return_type);
      EXCEPTION
        WHEN duplicate_function THEN
          RAISE DEBUG 'stub aggregation already exists (ignored)';
        WHEN others THEN
          RAISE EXCEPTION 'stub aggregation % exception', name_arg;
      END;
    END;
  ELSEIF lower(func_type) = 'function' OR lower(func_type) = 'func' OR lower(func_type) = 'f' THEN
    BEGIN
      EXECUTE format('
        CREATE OR REPLACE FUNCTION %s RETURNS %s IMMUTABLE AS $inner$
        BEGIN
          RAISE EXCEPTION ''stub %s is called'';
          RETURN NULL;
        END $inner$ LANGUAGE plpgsql;',
        name_arg, return_type, name_arg);
    EXCEPTION
      WHEN duplicate_function THEN
        RAISE DEBUG 'stub already exists (ignored)';
    END;
  ELSEIF lower(func_type) = 'stable function' OR lower(func_type) = 'sfunc' OR lower(func_type) = 'sf' THEN
    BEGIN
      EXECUTE format('
        CREATE OR REPLACE FUNCTION %s RETURNS %s STABLE AS $inner$
        BEGIN
          RAISE EXCEPTION ''stub %s is called'';
          RETURN NULL;
        END $inner$ LANGUAGE plpgsql;',
        name_arg, return_type, name_arg);
    EXCEPTION
      WHEN duplicate_function THEN
        RAISE DEBUG 'stub already exists (ignored)';
    END;
  ELSEIF lower(func_type) = 'volatile function' OR lower(func_type) = 'vfunc' OR lower(func_type) = 'vf' THEN
    BEGIN
      EXECUTE format('
        CREATE OR REPLACE FUNCTION %s RETURNS %s VOLATILE AS $inner$
        BEGIN
          RAISE EXCEPTION ''stub %s is called'';
          RETURN NULL;
        END $inner$ LANGUAGE plpgsql;',
        name_arg, return_type, name_arg);
    EXCEPTION
      WHEN duplicate_function THEN
        RAISE DEBUG 'stub already exists (ignored)';
    END;
  ELSE
    RAISE EXCEPTION 'not supported function type %', func_type;
    BEGIN
      EXECUTE format('
        CREATE OR REPLACE FUNCTION %s_sfunc RETURNS %s AS $inner$
        BEGIN
          RAISE EXCEPTION ''stub %s is called'';
          RETURN NULL;
        END $inner$ LANGUAGE plpgsql;',
        name_arg, return_type, name_arg);
    EXCEPTION
      WHEN duplicate_function THEN
        RAISE DEBUG 'stub already exists (ignored)';
    END;
  END IF;
END
$$ LANGUAGE plpgsql;

-- Create type
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'mysql_string_type') THEN
      CREATE TYPE mysql_string_type as enum ('CHAR', 'BINARY');
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'time_unit') THEN
      CREATE TYPE time_unit as enum ('YEAR', 'QUARTER', 'MONTH', 'WEEK', 'DAY', 'HOUR', 'MINUTE', 'SECOND', 'MILLISECOND', 'MICROSECOND');
    END IF;
END$$;


-- ===============================================================================
-- FDW common functions
-- ===============================================================================
CALL pgspider_create_or_replace_stub('vf', 'atan(float8, float8)', 'float8');
CALL pgspider_create_or_replace_stub('vf', 'log2(float8)', 'float8');
CALL pgspider_create_or_replace_stub('vf', 'log10(float8)', 'float8');
CALL pgspider_create_or_replace_stub('vf', 'timestampdiff(time_unit, timestamp, timestamp)', 'double precision');


-- ===============================================================================
-- INFLUXDB stub functions
-- ===============================================================================
-- Aggregations
CALL pgspider_create_or_replace_stub('a', 'influx_count_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'influx_count(text)', 'text');
CALL pgspider_create_or_replace_stub('a', 'influx_distinct(anyelement)', 'anyelement');
CALL pgspider_create_or_replace_stub('a', 'integral(bigint)', 'bigint');
CALL pgspider_create_or_replace_stub('a', 'integral(float8)', 'float8');
CALL pgspider_create_or_replace_stub('a', 'integral(bigint, interval)', 'bigint');
CALL pgspider_create_or_replace_stub('a', 'integral(float8, interval)', 'float8');
CALL pgspider_create_or_replace_stub('a', 'integral_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'integral(text)', 'text');
CALL pgspider_create_or_replace_stub('a', 'mean(bigint)', 'bigint');
CALL pgspider_create_or_replace_stub('a', 'mean(float8)', 'float8');
CALL pgspider_create_or_replace_stub('a', 'mean_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'mean(text)', 'text');
CALL pgspider_create_or_replace_stub('a', 'median(bigint)', 'bigint');
CALL pgspider_create_or_replace_stub('a', 'median(float8)', 'float8');
CALL pgspider_create_or_replace_stub('a', 'median_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'median(text)', 'text');
CALL pgspider_create_or_replace_stub('a', 'influx_mode(anyelement)', 'anyelement');
CALL pgspider_create_or_replace_stub('a', 'influx_mode_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'influx_mode(text)', 'text');
CALL pgspider_create_or_replace_stub('a', 'spread(bigint)', 'bigint');
CALL pgspider_create_or_replace_stub('a', 'spread(float8)', 'float8');
CALL pgspider_create_or_replace_stub('a', 'spread_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'spread(text)', 'text');
CALL pgspider_create_or_replace_stub('a', 'stddev_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'stddev(text)', 'text');
CALL pgspider_create_or_replace_stub('a', 'influx_sum_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'influx_sum(text)', 'text');

-- Selectors
CALL pgspider_create_or_replace_stub('f', 'bottom(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'bottom(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'bottom(bigint, text, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'bottom(float8, text, int)', 'float8');
CALL pgspider_create_or_replace_stub('a', 'first(timestamp with time zone, anyelement)', 'anyelement');
CALL pgspider_create_or_replace_stub('a', 'first_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'first(text)', 'text');
CALL pgspider_create_or_replace_stub('a', 'last(timestamp with time zone, anyelement)', 'anyelement');
CALL pgspider_create_or_replace_stub('a', 'last_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'last(text)', 'text');
CALL pgspider_create_or_replace_stub('a', 'influx_max_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'influx_max(text)', 'text');
CALL pgspider_create_or_replace_stub('a', 'influx_min_all(*)', 'text');
CALL pgspider_create_or_replace_stub('a', 'influx_min(text)', 'text');
CALL pgspider_create_or_replace_stub('f', 'percentile(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'percentile(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'percentile(bigint, float8)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'percentile(float8, float8)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'percentile_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'percentile_all(float8)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'percentile(text, int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'percentile(text, float8)', 'text');
CALL pgspider_create_or_replace_stub('a', 'sample(anyelement, int)', 'anyelement');
CALL pgspider_create_or_replace_stub('sf', 'sample_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'sample(text, int)', 'text');
CALL pgspider_create_or_replace_stub('f', 'top(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'top(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'top(bigint, text, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'top(float8, text, int)', 'float8');

-- Transformations
CALL pgspider_create_or_replace_stub('sf', 'abs_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'acos_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'asin_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'atan_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'atan2_all(bigint)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'atan2_all(float8)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'ceil_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'cos_all()', 'text');
CALL pgspider_create_or_replace_stub('f', 'cumulative_sum(bigint)', 'bigint');
CALL pgspider_create_or_replace_stub('f', 'cumulative_sum(float8)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'cumulative_sum_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'cumulative_sum(text)', 'text');
CALL pgspider_create_or_replace_stub('f', 'derivative(anyelement)', 'anyelement');
CALL pgspider_create_or_replace_stub('f', 'derivative(anyelement, interval)', 'anyelement');
CALL pgspider_create_or_replace_stub('sf', 'derivative_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'derivative(text)', 'text');
CALL pgspider_create_or_replace_stub('f', 'difference(bigint)', 'bigint');
CALL pgspider_create_or_replace_stub('f', 'difference(float8)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'difference_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'difference(text)', 'text');
CALL pgspider_create_or_replace_stub('f', 'elapsed(anyelement)', 'bigint');
CALL pgspider_create_or_replace_stub('sf', 'elapsed_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'elapsed(text)', 'text');
CALL pgspider_create_or_replace_stub('f', 'elapsed(anyelement, interval)', 'bigint');
CALL pgspider_create_or_replace_stub('sf', 'exp_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'floor_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'ln_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'log_all(bigint)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'log_all(float8)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'log2_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'log10_all()', 'text');
CALL pgspider_create_or_replace_stub('f', 'moving_average(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'moving_average(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'moving_average_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'moving_average(text, int)', 'text');
CALL pgspider_create_or_replace_stub('f', 'non_negative_derivative(anyelement)', 'anyelement');
CALL pgspider_create_or_replace_stub('f', 'non_negative_derivative(anyelement, interval)', 'anyelement');
CALL pgspider_create_or_replace_stub('sf', 'non_negative_derivative_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'non_negative_derivative(text)', 'text');
CALL pgspider_create_or_replace_stub('f', 'non_negative_difference(bigint)', 'bigint');
CALL pgspider_create_or_replace_stub('f', 'non_negative_difference(float8)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'non_negative_difference_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'non_negative_difference(text)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'pow_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'round_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'sin_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'sqrt_all()', 'text');
CALL pgspider_create_or_replace_stub('sf', 'tan_all()', 'text');

-- Predictors
CALL pgspider_create_or_replace_stub('f', 'holt_winters(anyelement, int, int)', 'anyelement');
CALL pgspider_create_or_replace_stub('f', 'holt_winters_with_fit(anyelement, int, int)', 'anyelement');

-- Technical Analysis
CALL pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(bigint, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(float8, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(double precision, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(double precision, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'chande_momentum_oscillator_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'chande_momentum_oscillator(text, int)', 'text');
CALL pgspider_create_or_replace_stub('f', 'exponential_moving_average(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'exponential_moving_average(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'exponential_moving_average(bigint, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'exponential_moving_average(float8, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'exponential_moving_average_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'exponential_moving_average(text, int)', 'text');
CALL pgspider_create_or_replace_stub('f', 'double_exponential_moving_average(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'double_exponential_moving_average(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'double_exponential_moving_average(bigint, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'double_exponential_moving_average(float8, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'double_exponential_moving_average_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'double_exponential_moving_average(text, int)', 'text');
CALL pgspider_create_or_replace_stub('f', 'kaufmans_efficiency_ratio(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'kaufmans_efficiency_ratio(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'kaufmans_efficiency_ratio(bigint, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'kaufmans_efficiency_ratio(float8, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'kaufmans_efficiency_ratio_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'kaufmans_efficiency_ratio(text, int)', 'text');
CALL pgspider_create_or_replace_stub('f', 'kaufmans_adaptive_moving_average(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'kaufmans_adaptive_moving_average(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'kaufmans_adaptive_moving_average(bigint, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'kaufmans_adaptive_moving_average(float8, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'kaufmans_adaptive_moving_average_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'kaufmans_adaptive_moving_average(text, int)', 'text');
CALL pgspider_create_or_replace_stub('f', 'triple_exponential_moving_average(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'triple_exponential_moving_average(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'triple_exponential_moving_average(bigint, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'triple_exponential_moving_average(float8, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'triple_exponential_moving_average_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'triple_exponential_moving_average(text, int)', 'text');
CALL pgspider_create_or_replace_stub('f', 'triple_exponential_derivative(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'triple_exponential_derivative(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'triple_exponential_derivative(bigint, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'triple_exponential_derivative(float8, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'triple_exponential_derivative_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'triple_exponential_derivative(text, int)', 'text');
CALL pgspider_create_or_replace_stub('f', 'relative_strength_index(bigint, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'relative_strength_index(float8, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'relative_strength_index(bigint, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('f', 'relative_strength_index(float8, int, int)', 'float8');
CALL pgspider_create_or_replace_stub('sf', 'relative_strength_index_all(int)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'relative_strength_index(text, int)', 'text');

-- Time
CALL pgspider_create_or_replace_stub('f', 'influx_time(timestamp with time zone, interval, interval)', 'timestamp with time zone');
CALL pgspider_create_or_replace_stub('f', 'influx_time(timestamp with time zone, interval)', 'timestamp with time zone');


-- ===============================================================================
-- MySQL stub functions
-- ===============================================================================
CALL pgspider_create_or_replace_stub('f', 'match_against(variadic text[])', 'float');

-- Numeric functions
CALL pgspider_create_or_replace_stub('vf', 'conv(anyelement, int, int)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'conv(text, int, int)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'crc32(anyelement)', 'bigint');
CALL pgspider_create_or_replace_stub('vf', 'crc32(text)', 'bigint');
CALL pgspider_create_or_replace_stub('vf', 'mysql_pi()', 'float8');
CALL pgspider_create_or_replace_stub('vf', 'rand(float8)', 'float8');
CALL pgspider_create_or_replace_stub('vf', 'rand()', 'float8');
CALL pgspider_create_or_replace_stub('vf', 'truncate(float8, int)', 'float8');

-- String functions
CALL pgspider_create_or_replace_stub('vf', 'bin(numeric)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'mysql_char(bigint)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'elt(int, variadic text[])', 'text');
CALL pgspider_create_or_replace_stub('vf', 'export_set(int, text, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'export_set(int, text, text, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'export_set(int, text, text, text, int)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'field(text, variadic text[])', 'int');
CALL pgspider_create_or_replace_stub('vf', 'find_in_set(text, text)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'format(double precision, int)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'format(double precision, int, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'from_base64(text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'hex(text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'hex(bigint)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'insert(text, int, int, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'instr(text, text)', 'bigint');
CALL pgspider_create_or_replace_stub('vf', 'lcase(text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'locate(text, text)', 'bigint');
CALL pgspider_create_or_replace_stub('vf', 'locate(text, text, bigint)', 'bigint');
CALL pgspider_create_or_replace_stub('vf', 'make_set(bigint, variadic text[])', 'text');
CALL pgspider_create_or_replace_stub('vf', 'mid(text, bigint, bigint)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'oct(bigint)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'ord(anyelement)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'quote(text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'regexp_instr(text, text)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'regexp_instr(text, text, int)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'regexp_instr(text, text, int, int)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'regexp_instr(text, text, int, int, int)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'regexp_instr(text, text, int, int, int, text)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'regexp_like(text, text)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'regexp_like(text, text, text)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'regexp_replace(text, text, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'regexp_replace(text, text, text, int)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'regexp_replace(text, text, text, int, int)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'regexp_replace(text, text, text, int, int, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'regexp_substr(text, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'regexp_substr(text, text, int)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'regexp_substr(text, text, int, int)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'regexp_substr(text, text, int, int, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'space(bigint)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'strcmp(text, text)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'substring_index(text, text, bigint)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'to_base64(text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'ucase(text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'unhex(text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'weight_string(text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'weight_string(text, mysql_string_type, int)', 'text');

-- Date and Time Functions
CALL pgspider_create_or_replace_stub('vf', 'adddate(timestamp, int)', 'date');
CALL pgspider_create_or_replace_stub('vf', 'adddate(timestamp, interval)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'addtime(timestamp, interval)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'addtime(interval, interval)', 'interval');
CALL pgspider_create_or_replace_stub('vf', 'convert_tz(timestamp, text, text)', 'timestamp'); -- need load timezone table
CALL pgspider_create_or_replace_stub('vf', 'curdate()', 'date');
CALL pgspider_create_or_replace_stub('vf', 'mysql_current_date()', 'date');
CALL pgspider_create_or_replace_stub('vf', 'curtime()', 'time');
CALL pgspider_create_or_replace_stub('vf', 'mysql_current_time()', 'time');
CALL pgspider_create_or_replace_stub('vf', 'mysql_current_timestamp()', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'date_add(timestamp, interval)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'date_format(timestamp, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'date_sub(date, interval)', 'date');
CALL pgspider_create_or_replace_stub('vf', 'date_sub(timestamp, interval)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'datediff(timestamp, timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'day(timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'dayname(date)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'dayofmonth(date)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'dayofweek(date)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'dayofyear(date)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'mysql_extract(text, timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'from_days(integer)', 'date');
CALL pgspider_create_or_replace_stub('vf', 'from_unixtime(bigint)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'from_unixtime(bigint, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'get_format(text, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'hour(time without time zone)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'last_day(timestamp)', 'date');
CALL pgspider_create_or_replace_stub('vf', 'mysql_localtime()', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'mysql_localtimestamp()', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'makedate(integer, integer)', 'date');
CALL pgspider_create_or_replace_stub('vf', 'maketime(integer, integer, integer)', 'time');
CALL pgspider_create_or_replace_stub('vf', 'microsecond(time)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'microsecond(timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'minute(time)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'minute(timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'month(timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'monthname(timestamp)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'mysql_now()', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'period_add(integer, integer)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'period_diff(integer, integer)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'quarter(timestamp)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'sec_to_time(int)', 'time');
CALL pgspider_create_or_replace_stub('vf', 'second(time)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'second(timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'str_to_date(text, text)', 'date');
CALL pgspider_create_or_replace_stub('vf', 'str_to_date(time, text)', 'time');
CALL pgspider_create_or_replace_stub('vf', 'str_to_date(timestamp, text)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'subdate(timestamp, interval)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'subtime(timestamp, interval)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'subtime(time, time)', 'interval');
CALL pgspider_create_or_replace_stub('vf', 'subtime(interval, interval)', 'interval');
CALL pgspider_create_or_replace_stub('vf', 'sysdate()', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'mysql_time(timestamp)', 'time');
CALL pgspider_create_or_replace_stub('vf', 'time_format(time, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'time_to_sec(time)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'timediff(time, time)', 'interval');
CALL pgspider_create_or_replace_stub('vf', 'timediff(timestamp, timestamp)', 'interval');
CALL pgspider_create_or_replace_stub('vf', 'mysql_timestamp(timestamp)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'mysql_timestamp(timestamp, time)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'timestampadd(time_unit, integer, timestamp)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'to_days(date)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'to_days(integer)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'to_seconds(integer)', 'bigint');
CALL pgspider_create_or_replace_stub('vf', 'to_seconds(timestamp)', 'bigint');
CALL pgspider_create_or_replace_stub('vf', 'unix_timestamp()', 'numeric');
CALL pgspider_create_or_replace_stub('vf', 'unix_timestamp(timestamp)', 'numeric');
CALL pgspider_create_or_replace_stub('vf', 'utc_date()', 'date');
CALL pgspider_create_or_replace_stub('vf', 'utc_time()', 'time');
CALL pgspider_create_or_replace_stub('vf', 'utc_timestamp()', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'week(timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'week(timestamp, integer)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'weekday(timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'weekofyear(timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'year(timestamp)', 'integer');
CALL pgspider_create_or_replace_stub('vf', 'yearweek(timestamp)', 'integer');
-- ===============================================================================
-- MySQL unique stub aggregate functions
-- ===============================================================================
CALL pgspider_create_or_replace_stub('a', 'bit_xor(anyelement)', 'numeric');
CALL pgspider_create_or_replace_stub('a', 'group_concat(anyelement)', 'text');
CALL pgspider_create_or_replace_stub('a', 'std(anyelement)', 'double precision');

-- MySQL special aggregation function
-- JSON functions
-- custom type for [path, value]
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'path_value') THEN
      CREATE TYPE path_value;

      CREATE FUNCTION path_value_in(cstring)
        RETURNS path_value
        AS 'MODULE_PATHNAME'
        LANGUAGE C IMMUTABLE STRICT;

      CREATE FUNCTION path_value_out(path_value)
        RETURNS cstring
        AS 'MODULE_PATHNAME'
        LANGUAGE C IMMUTABLE STRICT;

      CREATE TYPE path_value (
        internallength = VARIABLE,
        input = path_value_in,
        output = path_value_out
      );
    END IF;
END$$;


CALL pgspider_create_or_replace_stub('vf', 'json_array_append(json, variadic path_value[])', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_array_insert(json, variadic path_value[])', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_contains(json, json)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_contains(json, text)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_contains(json, json, text)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_contains_path(json, variadic text[])', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_depth(json)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_extract(json, variadic text[])', 'text');
CALL pgspider_create_or_replace_stub('vf', 'json_insert(json, variadic path_value[])', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_keys(json)', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_keys(json, text)', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_length(json)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_length(json, text)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_merge(variadic json[])', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_merge_patch(variadic json[])', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_merge_preserve(variadic json[])', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_overlaps(json, json)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_pretty(json)', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_quote(text)', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_remove(json, variadic text[])', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_replace(json, variadic path_value[])', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_schema_valid(json, json)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_schema_validation_report(json, json)', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_search(json, text, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'json_search(json, text, text, text, variadic text[])', 'text');
CALL pgspider_create_or_replace_stub('vf', 'json_set(json, variadic path_value[])', 'json');
CALL pgspider_create_or_replace_stub('vf', 'json_storage_free(json)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_storage_size(json)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'mysql_json_table(json, text, text[], text[])', 'text');
CALL pgspider_create_or_replace_stub('vf', 'json_type(json)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'json_unquote(text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'json_valid(text)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_valid(json)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'json_value(json, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'json_value(json, text, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'json_value(json, text, text, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'json_value(json, text, text, text, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'member_of(anyelement, json)', 'int');
CALL pgspider_create_or_replace_stub('vf', 'member_of(text, json)', 'int');

-- cast functions
CALL pgspider_create_or_replace_stub('vf', 'convert(text, text)', 'text');
CALL pgspider_create_or_replace_stub('vf', 'convert(anyelement, text)', 'text');

-- ===============================================================================
-- GridDB stub functions
-- ===============================================================================

-- Time Operations
CALL pgspider_create_or_replace_stub('f', 'to_timestamp_ms(bigint)', 'timestamp');
CALL pgspider_create_or_replace_stub('f', 'to_epoch_ms(timestamp)', 'bigint');
CALL pgspider_create_or_replace_stub('f', 'griddb_timestamp(text)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'timestampadd(time_unit, timestamp, integer)', 'timestamp');
CALL pgspider_create_or_replace_stub('vf', 'griddb_now()', 'timestamp');

-- Array Operations
CALL pgspider_create_or_replace_stub('f', 'array_length(anyarray)', 'integer');
CALL pgspider_create_or_replace_stub('f', 'element(integer, anyarray)', 'anyelement');

-- Time-series functions
CALL pgspider_create_or_replace_stub('sf', 'time_next(timestamp)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'time_next_only(timestamp)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'time_prev(timestamp)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'time_prev_only(timestamp)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'time_interpolated(anyelement, timestamp)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'max_rows(anyelement)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'min_rows(anyelement)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'time_sampling(timestamp,timestamp,integer,time_unit)', 'text');
CALL pgspider_create_or_replace_stub('sf', 'time_sampling(anyelement,timestamp,timestamp,integer,time_unit)', 'text');

-- Aggregate function
CALL pgspider_create_or_replace_stub('a', 'time_avg(anyelement)', 'double precision');
