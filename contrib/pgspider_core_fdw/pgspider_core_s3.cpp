#include <aws/core/Aws.h>
#include <aws/core/auth/AWSCredentialsProvider.h>
#include <aws/core/auth/AWSAuthSigner.h>
#include <aws/s3/S3Client.h>
#include <aws/s3/model/ListObjectsRequest.h>

extern "C"
{
#include "postgres.h"
#include "commands/defrem.h"
#include "foreign/foreign.h"
#include "foreign/fdwapi.h"
#include "miscadmin.h"
#include "parquet_fdw_s3.h"
}

static Aws::SDKOptions *aws_sdk_options;

static void check_conn_params(const char **keywords, const char **values, UserMapping *user);

static Aws::S3::S3Client *s3_client_open(const char *user, const char *password, bool use_minio);
static void s3_client_close(Aws::S3::S3Client *s3_client);

extern "C" void
parquet_s3_init()
{
	aws_sdk_options = new Aws::SDKOptions();
	Aws::InitAPI(*aws_sdk_options);
}

extern "C" void
parquet_s3_shutdown()
{
	Aws::ShutdownAPI(*aws_sdk_options);
    aws_sdk_options = NULL;
}

/*
 * Generate key-value arrays from the given list. Caller must have
 * allocated large-enough arrays.  Returns number of options found.
 */
static int
ExtractConnectionOptions(List *defelems, const char **keywords,
						 const char **values)
{
	ListCell   *lc;
	int			i;

	i = 0;
	foreach(lc, defelems)
	{
		DefElem    *d = (DefElem *) lfirst(lc);

		keywords[i] = d->defname;
		values[i] = defGetString(d);
		i++;
	}
	return i;
}

/*
 * Connect to remote server using specified server and user mapping properties.
 */
static Aws::S3::S3Client *
create_s3_connection(ForeignServer *server, UserMapping *user, bool use_minio)
{
	Aws::S3::S3Client	   *volatile conn = NULL;

	/*
	 * Use PG_TRY block to ensure closing connection on error.
	 */
	PG_TRY();
	{
		const char **keywords;
		const char **values;
		int			n;
		char *id = NULL;
		char *password = NULL;
		ListCell   *lc;

		n = list_length(user->options) + 1;
		keywords = (const char **) palloc(n * sizeof(char *));
		values = (const char **) palloc(n * sizeof(char *));

		n = ExtractConnectionOptions(user->options,
									  keywords, values);
		keywords[n] = values[n] = NULL;

		/* verify connection parameters and make connection */
		check_conn_params(keywords, values, user);

		/* get id and password from user option */
		foreach(lc, user->options)
		{
			DefElem    *def = (DefElem *) lfirst(lc);

			if (strcmp(def->defname, "user") == 0)
				id = defGetString(def);

			if (strcmp(def->defname, "password") == 0)
				password = defGetString(def);
		}

		conn = s3_client_open(id, password, use_minio);
		if (!conn)
			ereport(ERROR,
					(errcode(ERRCODE_SQLCLIENT_UNABLE_TO_ESTABLISH_SQLCONNECTION),
					 errmsg("could not connect to S3 \"%s\"",
							server->servername)));

		pfree(keywords);
		pfree(values);
	}
	PG_CATCH();
	{
		/* Close S3 handle if we managed to create one */
		if (conn)
			s3_client_close(conn);
		PG_RE_THROW();
	}
	PG_END_TRY();

	return conn;
}

/*
 * Password is required to connect to S3.
 */
static void
check_conn_params(const char **keywords, const char **values, UserMapping *user)
{
	int			i;

	/* ok if params contain a non-empty password */
	for (i = 0; keywords[i] != NULL; i++)
	{
		if (strcmp(keywords[i], "password") == 0 && values[i][0] != '\0')
			return;
	}

	ereport(ERROR,
			(errcode(ERRCODE_S_R_E_PROHIBITED_SQL_STATEMENT_ATTEMPTED),
			 errmsg("password is required"),
			 errdetail("Non-superusers must provide a password in the user mapping.")));
}

static Aws::S3::S3Client*
s3_client_open(const char *user, const char *password, bool use_minio)
{
    const Aws::String access_key_id = user;
    const Aws::String secret_access_key = password;
	Aws::Auth::AWSCredentials cred = Aws::Auth::AWSCredentials(access_key_id, secret_access_key);
	Aws::Client::ClientConfiguration clientConfig;
	Aws::S3::S3Client *s3_client;

	if (use_minio)
	{
		const Aws::String endpoint = "127.0.0.1:9000";
		clientConfig.scheme = Aws::Http::Scheme::HTTP;
		clientConfig.endpointOverride = endpoint;
		s3_client = new Aws::S3::S3Client(cred, clientConfig,
				Aws::Client::AWSAuthV4Signer::PayloadSigningPolicy::Never, false);
	}
	else
	{
		clientConfig.scheme = Aws::Http::Scheme::HTTPS;
		clientConfig.region = Aws::Region::AP_NORTHEAST_1;
		s3_client = new Aws::S3::S3Client(cred, clientConfig);
	}

	return s3_client;
}

static void
s3_client_close(Aws::S3::S3Client *s3_client)
{
	delete s3_client;
}

/*
 * Get S3 handle by foreign table id.
 */
static Aws::S3::S3Client*
parquetGetConnectionByTableid(Oid foreigntableid)
{
    Aws::S3::S3Client *s3client = NULL;

    if (foreigntableid != 0)
    {
        ForeignTable  *ftable = GetForeignTable(foreigntableid);
        ForeignServer *fserver = GetForeignServer(ftable->serverid);
        UserMapping   *user = GetUserMapping(GetUserId(), fserver->serverid);
        parquet_s3_server_opt *options = parquet_s3_get_options(foreigntableid);

        s3client = create_s3_connection(fserver, user, options->use_minio);
    }
    return s3client;
}

/*
 * Get file names in S3 directory.
 */
static List*
parquetGetS3ObjectList(Aws::S3::S3Client *s3_cli, const char *s3path)
{
    List *objectlist = NIL;
	Aws::S3::S3Client s3_client = *s3_cli;
	Aws::S3::Model::ListObjectsRequest request;

    if (s3path == NULL)
        return NIL;

    /* Calculate bucket name and directory name from S3 path. */
    const char *bucket = s3path + 5; /* Remove "s3://" */
    const char *dir = strchr(bucket, '/'); /* Search the 1st '/' after "s3://". */
    const Aws::String& bucketName = bucket;
    size_t len;
    if (dir)
    {
        len = dir - bucket;
        dir++; /* Remove '/' */
    }
    else
    {
        len = bucketName.length();
    }
    
	request.WithBucket(bucketName.substr(0, len));
	auto outcome = s3_client.ListObjects(request);

	if (!outcome.IsSuccess())
		elog(ERROR, "pgspider_core_fdw: failed to get object list on %s. %s", bucketName.substr(0, len).c_str(), outcome.GetError().GetMessage().c_str());

	Aws::Vector<Aws::S3::Model::Object> objects =
		outcome.GetResult().GetContents();
	for (Aws::S3::Model::Object& object : objects)
	{
        Aws::String key = object.GetKey();
        if (!dir)
        {
			char *fullpath = psprintf("s3://%s/%s", bucketName.substr(0, len).c_str(), key.c_str());
		    objectlist = lappend(objectlist, makeString(fullpath));
            elog(DEBUG1, "pgspider_core_fdw: accessing %s", fullpath);
        }
        else if (strncmp(key.c_str(), dir, strlen(dir)) == 0)
        {
            char *file = pstrdup((char*) key.substr(strlen(dir)).c_str());
            /* Don't register if the object is directory. */
            if (strcmp(file, "/") != 0)
            {
                char *fullpath = psprintf("%s%s", s3path, file);
		        objectlist = lappend(objectlist, makeString(fullpath));
                elog(DEBUG1, "pgspider_core_fdw: accessing %s", fullpath);
            }
            else
				pfree(file);
        }
        else
            elog(DEBUG1, "pgspider_core_fdw: skipping s3://%s/%s", bucketName.substr(0, len).c_str(), key.c_str());
	}

	return objectlist;
}

static char*
get_s3_path_from_options(Oid foreigntableid)
{
	ForeignTable *table;
    ListCell     *lc;

    table = GetForeignTable(foreigntableid);

    foreach(lc, table->options)
    {
		DefElem    *def = (DefElem *) lfirst(lc);

        if (strcmp(def->defname, "dirname") == 0)
            return defGetString(def);
    }
    return NULL;
}

extern "C"  List *
getS3FileList(Oid foreigntableid)
{
    Aws::S3::S3Client *s3client = parquetGetConnectionByTableid(foreigntableid);
    char *s3path = get_s3_path_from_options(foreigntableid);
    List *s3filelist = parquetGetS3ObjectList(s3client, s3path);
	s3_client_close(s3client);
    return s3filelist;
}
