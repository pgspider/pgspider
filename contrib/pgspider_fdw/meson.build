# Copyright (c) 2022-2023, PostgreSQL Global Development Group

pgspider_fdw_sources = files(
  'connection.c',
  'deparse.c',
  'option.c',
  'pgspider_fdw.c',
  'shippable.c',
  'pgspider_data_compression_transfer.c',
)

if host_system == 'windows'
  pgspider_fdw_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'pgspider_fdw',
    '--FILEDESC', 'pgspider_fdw - foreign data wrapper for PGSpider',])
endif

pgspider_fdw = shared_module('pgspider_fdw',
  pgspider_fdw_sources,
  kwargs: contrib_mod_args + {
    'dependencies': contrib_mod_args['dependencies'] + [libpq],
  },
)
contrib_targets += pgspider_fdw

install_data(
  'pgspider_fdw.control',
  'pgspider_fdw--1.0.sql',
  'pgspider_fdw--1.1.sql',
  'pgspider_fdw--1.2.sql',
  'pgspider_fdw--1.3.sql',
  'pgspider_fdw--1.4.sql',
  kwargs: contrib_data_args,
)

tests += {
  'name': 'pgspider_fdw',
  'sd': meson.current_source_dir(),
  'bd': meson.current_build_dir(),
  'regress': {
    'sql': [
      'pgspider_fdw',
    ],
    'regress_args': ['--dlpath', meson.build_root() / 'src/test/regress'],
  },
}
