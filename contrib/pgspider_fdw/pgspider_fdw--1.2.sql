/* contrib/pgspider_fdw/pgspider_fdw--1.2.sql */

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
          CREATE FUNCTION %s_sfunc%s RETURNS %s IMMUTABLE AS $inner$
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
          CREATE AGGREGATE %s
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
        CREATE FUNCTION %s RETURNS %s IMMUTABLE AS $inner$
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
        CREATE FUNCTION %s RETURNS %s STABLE AS $inner$
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
        CREATE FUNCTION %s_sfunc RETURNS %s AS $inner$
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

-- influxdb stubs
--Aggregations
call pgspider_create_or_replace_stub('a', 'influx_count_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'influx_count(text)', 'text');
call pgspider_create_or_replace_stub('a', 'influx_distinct(anyelement)', 'anyelement');
call pgspider_create_or_replace_stub('a', 'integral(bigint)', 'bigint');
call pgspider_create_or_replace_stub('a', 'integral(float8)', 'float8');
call pgspider_create_or_replace_stub('a', 'integral(bigint, interval)', 'bigint');
call pgspider_create_or_replace_stub('a', 'integral(float8, interval)', 'float8');
call pgspider_create_or_replace_stub('a', 'integral_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'integral(text)', 'text');
call pgspider_create_or_replace_stub('a', 'mean(bigint)', 'bigint');
call pgspider_create_or_replace_stub('a', 'mean(float8)', 'float8');
call pgspider_create_or_replace_stub('a', 'mean_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'mean(text)', 'text');
call pgspider_create_or_replace_stub('a', 'median(bigint)', 'bigint');
call pgspider_create_or_replace_stub('a', 'median(float8)', 'float8');
call pgspider_create_or_replace_stub('a', 'median_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'median(text)', 'text');
call pgspider_create_or_replace_stub('a', 'influx_mode(anyelement)', 'anyelement');
call pgspider_create_or_replace_stub('a', 'influx_mode_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'influx_mode(text)', 'text');
call pgspider_create_or_replace_stub('a', 'spread(bigint)', 'bigint');
call pgspider_create_or_replace_stub('a', 'spread(float8)', 'float8');
call pgspider_create_or_replace_stub('a', 'spread_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'spread(text)', 'text');
call pgspider_create_or_replace_stub('a', 'stddev_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'stddev(text)', 'text');
call pgspider_create_or_replace_stub('a', 'influx_sum_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'influx_sum(text)', 'text');

--Selectors
call pgspider_create_or_replace_stub('f', 'bottom(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'bottom(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'bottom(bigint, text, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'bottom(float8, text, int)', 'float8');
call pgspider_create_or_replace_stub('a', 'first(timestamp with time zone, anyelement)', 'anyelement');
call pgspider_create_or_replace_stub('a', 'first_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'first(text)', 'text');
call pgspider_create_or_replace_stub('a', 'last(timestamp with time zone, anyelement)', 'anyelement');
call pgspider_create_or_replace_stub('a', 'last_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'last(text)', 'text');
call pgspider_create_or_replace_stub('a', 'influx_max_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'influx_max(text)', 'text');
call pgspider_create_or_replace_stub('a', 'influx_min_all(*)', 'text');
call pgspider_create_or_replace_stub('a', 'influx_min(text)', 'text');
call pgspider_create_or_replace_stub('f', 'percentile(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'percentile(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'percentile(bigint, float8)', 'float8');
call pgspider_create_or_replace_stub('f', 'percentile(float8, float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'percentile_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'percentile_all(float8)', 'text');
call pgspider_create_or_replace_stub('sf', 'percentile(text, int)', 'text');
call pgspider_create_or_replace_stub('sf', 'percentile(text, float8)', 'text');
call pgspider_create_or_replace_stub('a', 'sample(anyelement, int)', 'anyelement');
call pgspider_create_or_replace_stub('sf', 'sample_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'sample(text, int)', 'text');
call pgspider_create_or_replace_stub('f', 'top(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'top(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'top(bigint, text, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'top(float8, text, int)', 'float8');

--Transformations
call pgspider_create_or_replace_stub('sf', 'abs_all()', 'text');
call pgspider_create_or_replace_stub('f', 'acos(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'acos(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'acos_all()', 'text');
call pgspider_create_or_replace_stub('f', 'asin(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'asin(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'asin_all()', 'text');
call pgspider_create_or_replace_stub('f', 'atan(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'atan(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'atan_all()', 'text');
call pgspider_create_or_replace_stub('f', 'atan2(bigint, bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'atan2(bigint, float8)', 'float8');
call pgspider_create_or_replace_stub('f', 'atan2(float8, bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'atan2(float8, float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'atan2_all(bigint)', 'text');
call pgspider_create_or_replace_stub('sf', 'atan2_all(float8)', 'text');
call pgspider_create_or_replace_stub('f', 'ceil(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'ceil(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'ceil_all()', 'text');
call pgspider_create_or_replace_stub('f', 'cos(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'cos(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'cos_all()', 'text');
call pgspider_create_or_replace_stub('f', 'cumulative_sum(bigint)', 'bigint');
call pgspider_create_or_replace_stub('f', 'cumulative_sum(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'cumulative_sum_all()', 'text');
call pgspider_create_or_replace_stub('sf', 'cumulative_sum(text)', 'text');
call pgspider_create_or_replace_stub('f', 'derivative(anyelement)', 'anyelement');
call pgspider_create_or_replace_stub('f', 'derivative(anyelement, interval)', 'anyelement');
call pgspider_create_or_replace_stub('sf', 'derivative_all()', 'text');
call pgspider_create_or_replace_stub('sf', 'derivative(text)', 'text');
call pgspider_create_or_replace_stub('f', 'difference(bigint)', 'bigint');
call pgspider_create_or_replace_stub('f', 'difference(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'difference_all()', 'text');
call pgspider_create_or_replace_stub('sf', 'difference(text)', 'text');
call pgspider_create_or_replace_stub('f', 'elapsed(anyelement)', 'bigint');
call pgspider_create_or_replace_stub('sf', 'elapsed_all()', 'text');
call pgspider_create_or_replace_stub('sf', 'elapsed(text)', 'text');
call pgspider_create_or_replace_stub('f', 'elapsed(anyelement, interval)', 'bigint');
call pgspider_create_or_replace_stub('f', 'exp(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'exp(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'exp_all()', 'text');
call pgspider_create_or_replace_stub('f', 'floor(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'floor(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'floor_all()', 'text');
call pgspider_create_or_replace_stub('f', 'ln(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'ln(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'ln_all()', 'text');
call pgspider_create_or_replace_stub('f', 'log(bigint, bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'log(float8, float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'log_all(bigint)', 'text');
call pgspider_create_or_replace_stub('sf', 'log_all(float8)', 'text');
call pgspider_create_or_replace_stub('f', 'log2(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'log2(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'log2_all()', 'text');
call pgspider_create_or_replace_stub('f', 'log10(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'log10(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'log10_all()', 'text');
call pgspider_create_or_replace_stub('f', 'moving_average(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'moving_average(float8, int)', 'float8');
call pgspider_create_or_replace_stub('sf', 'moving_average_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'moving_average(text, int)', 'text');
call pgspider_create_or_replace_stub('f', 'non_negative_derivative(anyelement)', 'anyelement');
call pgspider_create_or_replace_stub('f', 'non_negative_derivative(anyelement, interval)', 'anyelement');
call pgspider_create_or_replace_stub('sf', 'non_negative_derivative_all()', 'text');
call pgspider_create_or_replace_stub('sf', 'non_negative_derivative(text)', 'text');
call pgspider_create_or_replace_stub('f', 'non_negative_difference(bigint)', 'bigint');
call pgspider_create_or_replace_stub('f', 'non_negative_difference(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'non_negative_difference_all()', 'text');
call pgspider_create_or_replace_stub('sf', 'non_negative_difference(text)', 'text');
call pgspider_create_or_replace_stub('f', 'pow(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'pow(float8, int)', 'float8');
call pgspider_create_or_replace_stub('sf', 'pow_all(int)', 'text');
call pgspider_create_or_replace_stub('f', 'round(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'round(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'round_all()', 'text');
call pgspider_create_or_replace_stub('f', 'sin(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'sin(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'sin_all()', 'text');
call pgspider_create_or_replace_stub('sf', 'sqrt_all()', 'text');
call pgspider_create_or_replace_stub('f', 'tan(bigint)', 'float8');
call pgspider_create_or_replace_stub('f', 'tan(float8)', 'float8');
call pgspider_create_or_replace_stub('sf', 'tan_all()', 'text');

--Predictors
call pgspider_create_or_replace_stub('f', 'holt_winters(anyelement, int, int)', 'anyelement');
call pgspider_create_or_replace_stub('f', 'holt_winters_with_fit(anyelement, int, int)', 'anyelement');

--Technical Analysis
call pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(bigint, int, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(float8, int, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(double precision, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'chande_momentum_oscillator(double precision, int, int)', 'float8');
call pgspider_create_or_replace_stub('sf', 'chande_momentum_oscillator_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'chande_momentum_oscillator(text, int)', 'text');
call pgspider_create_or_replace_stub('f', 'exponential_moving_average(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'exponential_moving_average(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'exponential_moving_average(bigint, int, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'exponential_moving_average(float8, int, int)', 'float8');
call pgspider_create_or_replace_stub('sf', 'exponential_moving_average_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'exponential_moving_average(text, int)', 'text');
call pgspider_create_or_replace_stub('f', 'double_exponential_moving_average(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'double_exponential_moving_average(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'double_exponential_moving_average(bigint, int, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'double_exponential_moving_average(float8, int, int)', 'float8');
call pgspider_create_or_replace_stub('sf', 'double_exponential_moving_average_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'double_exponential_moving_average(text, int)', 'text');
call pgspider_create_or_replace_stub('f', 'kaufmans_efficiency_ratio(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'kaufmans_efficiency_ratio(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'kaufmans_efficiency_ratio(bigint, int, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'kaufmans_efficiency_ratio(float8, int, int)', 'float8');
call pgspider_create_or_replace_stub('sf', 'kaufmans_efficiency_ratio_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'kaufmans_efficiency_ratio(text, int)', 'text');
call pgspider_create_or_replace_stub('f', 'kaufmans_adaptive_moving_average(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'kaufmans_adaptive_moving_average(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'kaufmans_adaptive_moving_average(bigint, int, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'kaufmans_adaptive_moving_average(float8, int, int)', 'float8');
call pgspider_create_or_replace_stub('sf', 'kaufmans_adaptive_moving_average_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'kaufmans_adaptive_moving_average(text, int)', 'text');
call pgspider_create_or_replace_stub('f', 'triple_exponential_moving_average(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'triple_exponential_moving_average(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'triple_exponential_moving_average(bigint, int, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'triple_exponential_moving_average(float8, int, int)', 'float8');
call pgspider_create_or_replace_stub('sf', 'triple_exponential_moving_average_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'triple_exponential_moving_average(text, int)', 'text');
call pgspider_create_or_replace_stub('f', 'triple_exponential_derivative(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'triple_exponential_derivative(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'triple_exponential_derivative(bigint, int, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'triple_exponential_derivative(float8, int, int)', 'float8');
call pgspider_create_or_replace_stub('sf', 'triple_exponential_derivative_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'triple_exponential_derivative(text, int)', 'text');
call pgspider_create_or_replace_stub('f', 'relative_strength_index(bigint, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'relative_strength_index(float8, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'relative_strength_index(bigint, int, int)', 'float8');
call pgspider_create_or_replace_stub('f', 'relative_strength_index(float8, int, int)', 'float8');
call pgspider_create_or_replace_stub('sf', 'relative_strength_index_all(int)', 'text');
call pgspider_create_or_replace_stub('sf', 'relative_strength_index(text, int)', 'text');

--time
call pgspider_create_or_replace_stub('f', 'influx_time(timestamp with time zone, interval, interval)', 'timestamp with time zone');
call pgspider_create_or_replace_stub('f', 'influx_time(timestamp with time zone, interval)', 'timestamp with time zone');

-- mysql stubs
call pgspider_create_or_replace_stub('f', 'match_against(varidiadic text[])', 'float');
-- griddb stubs
--- create type
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'griddb_time_unit') THEN
      CREATE TYPE griddb_time_unit as enum ('YEAR', 'MONTH', 'DAY', 'HOUR', 'MINUTE', 'SECOND', 'MILLISECOND');
    END IF;
END$$;
--- Time Operations
call pgspider_create_or_replace_stub('f', 'to_timestamp_ms(bigint)', 'timestamp');
call pgspider_create_or_replace_stub('f', 'to_epoch_ms(timestamp)', 'bigint');
call pgspider_create_or_replace_stub('f', 'griddb_timestamp(text)', 'timestamp');
call pgspider_create_or_replace_stub('f', 'timestampadd(griddb_time_unit, timestamp, integer)', 'timestamp');
call pgspider_create_or_replace_stub('f', 'timestampdiff(griddb_time_unit, timestamp, timestamp)', 'double precision');
--- Array Operations
call pgspider_create_or_replace_stub('f', 'array_length(anyarray)', 'integer');
call pgspider_create_or_replace_stub('f', 'element(integer, anyarray)', 'anyelement');
--- Time-series functions
call pgspider_create_or_replace_stub('sf', 'time_next(timestamp)', 'text');
call pgspider_create_or_replace_stub('sf', 'time_next_only(timestamp)', 'text');
call pgspider_create_or_replace_stub('sf', 'time_prev(timestamp)', 'text');
call pgspider_create_or_replace_stub('sf', 'time_prev_only(timestamp)', 'text');
call pgspider_create_or_replace_stub('sf', 'time_interpolated(anyelement, timestamp)', 'text');
call pgspider_create_or_replace_stub('sf', 'max_rows(anyelement)', 'text');
call pgspider_create_or_replace_stub('sf', 'min_rows(anyelement)', 'text');
call pgspider_create_or_replace_stub('sf', 'time_sampling(timestamp,timestamp,integer,griddb_time_unit)', 'text');
call pgspider_create_or_replace_stub('sf', 'time_sampling(anyelement,timestamp,timestamp,integer,griddb_time_unit)', 'text');
--- Aggregate function
call pgspider_create_or_replace_stub('a', 'time_avg(anyelement)', 'double precision');
