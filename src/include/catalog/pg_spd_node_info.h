/*-------------------------------------------------------------------------
 *
 * pg_spd_node_info.h
 *	  definition of the system "shared dependency" relation (pg_spd_node_info)
 *	  along with the relation's initial contents.
 *
 * Portions Copyright (c) 1996-2017, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 * Portions Copyright (c) 2018-2021, TOSHIBA CORPORATION
 *
 * src/include/catalog/pg_spd_node_info.h
 *
 * NOTES
 *	  the genbki.pl script reads this file and generates .bki
 *	  information from the DATA() statements.
 *
 *-------------------------------------------------------------------------
 */

#ifndef PG_SPD_NODE_INFO_H
#define PG_SPD_NODE_INFO_H

#include "catalog/genbki.h"

/* ----------------
 *		pg_spd_node_info definition.  cpp turns this into
 *		typedef struct FormData_pg_spd_node_info
 * ----------------
 */
#define SharedPgspiderNodeInfoRelationId	7001

CATALOG(pg_spd_node_info,7001,SharedPgspiderNodeInfoRelationId) BKI_SHARED_RELATION
{
	/*
	 * Identification of the dependent (referencing) object.
	 *
	 * These fields are all zeroes for a DEPENDENCY_PIN entry.  Also, dbid can
	 * be zero to denote a shared object.
	 */
	Oid			dbid;			/* OID of database containing object */
	text		servername;		/* OID of table containing object */
	text		fdwname;		/* OID of object itself */
	text		ip;				/* column number, or 0 if not used */
} FormData_pg_spd_node_info;

/* ----------------
 *		Form_pg_spd_node_info corresponds to a pointer to a row with
 *		the format of pg_spd_node_info relation.
 * ----------------
 */
typedef FormData_pg_spd_node_info * Form_pg_spd_node_info;

/* ----------------
 *		compiler constants for pg_spd_node_info
 * ----------------
 */
#define Natts_pg_spd_node_info			4
#define Anum_pg_spd_node_info_dbid		1
#define Anum_pg_spd_node_info_servername	2
#define Anum_pg_spd_node_info_fdwname		3
#define Anum_pg_spd_node_info_ip	4


/*
 * pg_spd_node_info has no preloaded contents; system-defined dependencies are
 * loaded into it during a late stage of the initdb process.
 *
 * NOTE: we do not represent all possible dependency pairs in pg_spd_node_info;
 * for example, there's not much value in creating an explicit dependency
 * from a relation to its database.  Currently, only dependencies on roles
 * are explicitly stored in pg_spd_node_info.
 */

#endif							/* PG_SPD_NODE_INFO_H */
