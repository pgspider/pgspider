--
-- VERSION
--

-- ===================================================================
-- test --version option
-- ===================================================================

\! clusterdb \-\-version
\! createdb \-\-version
\! createuser \-\-version
\! dropdb \-\-version
\! dropuser \-\-version
\! ecpg \-\-version
\! initdb \-\-version
\! pg_archivecleanup \-\-version
\! pg_basebackup \-\-version
\! pgbench \-\-version
\! pg_checksums \-\-version
\! pg_config \-\-version
\! pg_controldata \-\-version
\! pg_ctl \-\-version
\! pg_dump \-\-version
\! pg_dumpall \-\-version
\! pg_isready \-\-version
\! pg_receivewal \-\-version
\! pg_recvlogical \-\-version
\! pg_resetwal \-\-version
\! pg_restore \-\-version
\! pg_rewind \-\-version
\! pgspider \-\-version
\! pg_test_fsync \-\-version
\! pg_test_timing \-\-version
\! pg_upgrade \-\-version
\! pg_verifybackup \-\-version
\! pg_waldump \-\-version
\! postmaster \-\-version
\! psql \-\-version
\! reindexdb \-\-version
\! vacuumdb \-\-version
\! $PWD/../../../contrib/oid2name/oid2name \-\-version
\! $PWD/../../../contrib/vacuumlo/vacuumlo \-\-version
\! ./pg_regress \-\-version
-- src/test/isolation/isolationtester not support --version option
-- \! $PWD/../isolation/isolationtester \-\-version
\! $PWD/../isolation/pg_isolation_regress \-\-version

-- ===================================================================
-- test --V option
-- ===================================================================

\! clusterdb \-V
\! createdb \-V
\! createuser \-V
\! dropdb \-V
\! dropuser \-V
\! ecpg \-V
\! initdb \-V
\! pg_archivecleanup \-V
\! pg_basebackup \-V
\! pgbench \-V
\! pg_checksums \-V
-- pg_config have no -V option
-- \! pg_config \-V
\! pg_controldata \-V
\! pg_ctl \-V
\! pg_dump \-V
\! pg_dumpall \-V
\! pg_isready \-V
\! pg_receivewal \-V
\! pg_recvlogical \-V
\! pg_resetwal \-V
\! pg_restore \-V
\! pg_rewind \-V
\! pgspider \-V
\! pg_test_fsync \-V
\! pg_test_timing \-V
\! pg_upgrade \-V
\! pg_verifybackup \-V
\! pg_waldump \-V
\! postmaster \-V
\! psql \-V
\! reindexdb \-V
\! vacuumdb \-V
\! $PWD/../../../contrib/oid2name/oid2name \-V
\! $PWD/../../../contrib/vacuumlo/vacuumlo \-V
\! ./pg_regress \-V
\! $PWD/../isolation/isolationtester \-V
\! $PWD/../isolation/pg_isolation_regress \-V

-- ===================================================================
-- test function version()
-- ===================================================================
SELECT substring(version(), 1, 13) AS version;
SELECT * FROM substring(version(),1,13);
