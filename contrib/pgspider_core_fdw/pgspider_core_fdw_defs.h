#ifndef SPD_FDW_DEFS
#define SPD_FDW_DEFS

/*Following are global defs for SPD FDW -- factor to spd_defs.h */
#define SPDURL "__spd_url"
#define SPD_CONF_PATH "/usr/local/pgspider/share/extension/spd_server_nodes.conf"
#define NODE_NAME_LEN (1024)
#define NODES_MAX (100)
#define SRVOPT_QRY "select srvoptions from information_schema._pg_foreign_servers where foreign_server_name = '%s'"
#define UMOPT_QRY "select umoptions from information_schema._pg_user_mappings where foreign_server_name = '%s'"
#define UDTNAME_QRY "select udt_name from information_schema.columns where table_name='%s' and column_name='%s'"
#define ENUMOID_QRY "select oid from pg_type where typname='%s'"
/*End defs*/


#endif							/* SPD_FDW_DEFS */
