-- macaddr check

CREATE TABLE macaddrtmp (a macaddr);

\copy macaddrtmp from 'data/macaddr.data'

SET enable_seqscan=on;

SELECT count(*) FROM macaddrtmp WHERE a <  '22:00:5c:e5:9b:0d';

SELECT count(*) FROM macaddrtmp WHERE a <= '22:00:5c:e5:9b:0d';

SELECT count(*) FROM macaddrtmp WHERE a  = '22:00:5c:e5:9b:0d';

SELECT count(*) FROM macaddrtmp WHERE a >= '22:00:5c:e5:9b:0d';

SELECT count(*) FROM macaddrtmp WHERE a >  '22:00:5c:e5:9b:0d';

CREATE INDEX macaddridx ON macaddrtmp USING gist ( a );

SET enable_seqscan=off;

SELECT count(*) FROM macaddrtmp WHERE a <  '22:00:5c:e5:9b:0d'::macaddr;

SELECT count(*) FROM macaddrtmp WHERE a <= '22:00:5c:e5:9b:0d'::macaddr;

SELECT count(*) FROM macaddrtmp WHERE a  = '22:00:5c:e5:9b:0d'::macaddr;

SELECT count(*) FROM macaddrtmp WHERE a >= '22:00:5c:e5:9b:0d'::macaddr;

SELECT count(*) FROM macaddrtmp WHERE a >  '22:00:5c:e5:9b:0d'::macaddr;

-- Test index-only scans
SET enable_bitmapscan=off;
EXPLAIN (COSTS OFF)
SELECT * FROM macaddrtmp WHERE a < '02:03:04:05:06:07'::macaddr;
SELECT * FROM macaddrtmp WHERE a < '02:03:04:05:06:07'::macaddr;
