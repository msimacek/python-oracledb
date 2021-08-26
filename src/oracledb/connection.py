#------------------------------------------------------------------------------
# Copyright (c) 2020, 2021, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from typing import Callable, Type, Union
from . import constants, errors, exceptions, utils
from . import thick_impl, thin_impl
from . import pool as pool_module
from .defaults import defaults
from .cursor import Cursor
from .lob import LOB
from .subscr import Subscription
from .aq import Queue, MessageProperties
from .soda import SodaDatabase
from .dbobject import DbObjectType, DbObject
from .base_impl import DB_TYPE_BLOB, DB_TYPE_CLOB, DB_TYPE_NCLOB, DbType

class Connection:
    _impl = None

    def __init__(self,
                 dsn: str=None, *,
                 user: str=None,
                 password: str=None,
                 host: str=None,
                 port: int=None,
                 service_name: str=None,
                 thin: bool=None,
                 mode: int=constants.AUTH_MODE_DEFAULT,
                 handle: int=0,
                 pool: Type["pool_module.Pool"]=None,
                 threaded: bool=None,
                 events: bool=None,
                 cclass: str=None,
                 purity: int=constants.PURITY_DEFAULT,
                 newpassword: str=None,
                 edition: str=None,
                 appcontext: list=[],
                 tag: str=None,
                 matchanytag: bool=False,
                 shardingkey: list=[],
                 supershardingkey: list=[],
                 stmtcachesize: int=None,
                 secure_transport: bool=False,
                 config_dir: str=None,
                 enable_drcp: bool=False) -> None:
        """
        Constructor for creating a connection to the database. All parameters
        are optional.

        The dsn (data source name) can be a string in the format
        user/password@connect_string or can simply be the connect string (in
        which case the user and password need to be specified separately). See
        the documentation on connection strings for more information.

        If the mode is specified, it must be one of the connection
        authorization modes which are defined at the module level.

        If the handle is specified, it must be of type OCISvcCtx* and is only
        of use when embedding Python in an application (like PowerBuilder)
        which has already made the connection. The connection thus created
        should never be used after the source handle has been closed or
        destroyed. This parameter is only useful when creating a thick
        connection.

        The pool parameter is expected to be a pool object and the use of this
        parameter is the equivalent of calling acquire() on the pool.
        Parameters not accepted by that method are ignored.

        The threaded parameter is expected to be a boolean expression which
        indicates whether or not Oracle should wrap accesses to connections
        with a mutex. Doing so in single threaded applications imposes a
        performance penalty of about 10-15% which is why the default is False.

        The events parameter is expected to be a boolean expression which
        indicates whether or not to initialize Oracle in events mode. This is
        required for continuous query notification and high availability event
        notifications.

        The cclass parameter is expected to be a string and defines the
        connection class for database resident connection pooling (DRCP).

        The purity parameter is expected to be one of PURITY_DEFAULT,
        PURITY_NEW, or PURITY_ANY.

        The newpassword parameter is expected to be a string if specified and
        sets the password for the logon during the connection process.

        The edition parameter is expected to be a string if specified and sets
        the edition to use for the session. It is only relevant if both the
        client and the database are at least Oracle Database 11.2. If this
        parameter is used with the cclass parameter the exception "DPI-1058:
        edition not supported with connection class" will be raised.

        The appcontext parameter is expected to be a list of 3-tuples, if
        specified, and sets the application context for the connection.
        Application context is available in the database by using the
        sys_context() PL/SQL method and can be used within a logon trigger as
        well as any other PL/SQL procedures. Each entry in the list is expected
        to contain three strings: the namespace, the name and the value.

        The tag parameter, if specified, is expected to be a string and will
        limit the sessions that can be returned from a session pool unless the
        matchanytag parameter is set to True. In that case sessions with the
        specified tag will be preferred over others, but if no such sessions
        are available a session with a different tag may be returned instead.
        In any case, untagged sessions will always be returned if no sessions
        with the specified tag are available. Sessions are tagged when they are
        released back to the pool.

        The shardingkey and supershardingkey parameters, if specified, are
        expected to be a sequence of values which will be used to identify the
        database shard to connect to. The key values can be strings, numbers,
        bytes or dates.

        The stmtcachesize parameter, if specified, is expected to be an integer
        which specifies the initial value of Connection.stmtcachesize.
        """
        self._impl = None
        if thin is None:
            thin = defaults.thin
        if stmtcachesize is None:
            stmtcachesize = defaults.stmtcachesize
        if threaded is None:
            threaded = defaults.threaded
        if events is None:
            events = defaults.events
        if config_dir is None:
            config_dir = defaults.config_dir
        if pool is None:
            pool_impl = None
        elif not isinstance(pool, pool_module.Pool):
            message = "pool must be an instance of oracledb.Pool"
            raise TypeError(message)
        else:
            pool._verify_open()
            pool_impl = pool._impl
            if isinstance(pool_impl, thick_impl.ThickPoolImpl):
                thin = False
        params = utils.ConnectParams(user=user, password=password, host=host,
                                     port=port, service_name=service_name,
                                     secure_transport=secure_transport,
                                     config_dir=config_dir,
                                     enable_drcp=enable_drcp)
        if dsn is not None:
            params.parse_dsn(dsn, thin=thin)
        user = params.user
        dsn = params.get_dsn()
        if thin:
            if pool is not None:
                impl = pool_impl.acquire(user=user, password=password,
                                         cclass=cclass, purity=purity,
                                         tag=tag, matchanytag=matchanytag,
                                         shardingkey=shardingkey,
                                         supershardingkey=supershardingkey)
            else:
                impl = thin_impl.ThinConnImpl(user, dsn)
                while True:
                    redirect_data = impl.connect(params,
                                                 stmtcachesize=stmtcachesize,
                                                 newpassword=newpassword,
                                                 auth_mode=mode, cclass=cclass,
                                                 purity=purity)
                    if redirect_data is None:
                        break
                    params.parse_redirect_data(redirect_data)
        else:
            impl = thick_impl.ThickConnImpl(user, dsn)
            impl.connect(password=params.password, mode=mode, handle=handle,
                         pool_impl=pool_impl, threaded=threaded,
                         events=events, cclass=cclass, purity=purity,
                         newpassword=newpassword, edition=edition,
                         appcontext=appcontext, tag=tag,
                         matchanytag=matchanytag, shardingkey=shardingkey,
                         supershardingkey=supershardingkey,
                         stmtcachesize=stmtcachesize)
        self._impl = impl
        self._version = None
        if impl.invoke_session_callback and pool is not None \
                and pool.session_callback is not None \
                and callable(pool.session_callback):
            pool.session_callback(self, tag)
            impl.invoke_session_callback = False

    def __del__(self):
        if self._impl is not None:
            self._impl.close(in_del=True)
            self._impl = None

    def __enter__(self):
        self._verify_connected()
        return self

    def __exit__(self, exc_type, exc_value, exc_tb):
        self.close()

    def __repr__(self):
        cls_name = f"oracledb.{type(self).__name__}"
        if self.username is None:
            return f"<{cls_name} to externally identified user>"
        return f"<{cls_name} to {self.username}@{self.dsn}>"

    def _verify_connected(self):
        """
        Verifies that the connection is connected to the database. If it is
        not, an exception is raised.
        """
        if self._impl is None:
            errors._raise_err(errors.ERR_NOT_CONNECTED)

    @property
    def action(self) -> None:
        raise AttributeError("action is not readable")

    @action.setter
    def action(self, value: str) -> None:
        """
        Specifies the action column in the v$session table. It is a string
        attribute and cannot be set to None -- use the empty string instead.
        """
        self._verify_connected()
        self._impl.set_action(value)

    @property
    def autocommit(self) -> bool:
        """
        Specifies whether autocommit mode is on or off. When autocommit mode is
        on, all statements are committed as soon as they have completed
        executing successfully.
        """
        self._verify_connected()
        return self._impl.autocommit

    @autocommit.setter
    def autocommit(self, value: bool) -> None:
        self._verify_connected()
        self._impl.autocommit = value

    def begin(self, format_id: int=-1, transaction_id: str="",
              branch_id: str="") -> None:
        """
        Explicitly begin a new transaction. Without parameters, this explicitly
        begins a local transaction; otherwise, this explicitly begins a
        distributed (global) transaction with the given parameters. See the
        Oracle documentation for more details.

        Note that in order to make use of global (distributed) transactions,
        the internal_name and external_name attributes must be set to
        appropriate values.
        """
        self._verify_connected()
        self._impl.begin(format_id, transaction_id, branch_id)

    @property
    def call_timeout(self) -> int:
        """
        Specifies the amount of time (in milliseconds) that a single round-trip
        to the database may take before a timeout will occur. A value of 0
        means that no timeout will take place.
        """
        self._verify_connected()
        return self._impl.get_call_timeout()

    @call_timeout.setter
    def call_timeout(self, value: int) -> None:
        self._verify_connected()
        self._impl.set_call_timeout(value)

    @property
    def callTimeout(self) -> int:
        """
        Deprecated. Use property call_timeout instead.
        """
        return self.call_timeout

    @callTimeout.setter
    def callTimeout(self, value: int) -> None:
        self._verify_connected()
        self._impl.set_call_timeout(value)

    def cancel(self) -> None:
        """
        Break a long-running transaction.
        """
        self._verify_connected()
        self._impl.cancel()

    def changepassword(self, old_password: str, new_password: str) -> None:
        """
        Changes the password for the user to which the connection is connected.
        """
        self._verify_connected()
        self._impl.change_password(old_password, new_password)

    @property
    def client_identifier(self) -> None:
        raise AttributeError("client_identifier is not readable")

    @client_identifier.setter
    def client_identifier(self, value: str) -> None:
        """
        Specifies the client_identifier column in the v$session table.
        """
        self._verify_connected()
        self._impl.set_client_identifier(value)

    @property
    def clientinfo(self) -> None:
        raise AttributeError("clientinfo is not readable")

    @clientinfo.setter
    def clientinfo(self, value: str) -> None:
        """
        Specifies the client_info column in the v$session table.
        """
        self._verify_connected()
        self._impl.set_client_info(value)

    def close(self) -> None:
        """
        Closes the connection and makes it unusable for further operations. An
        Error exception will be raised if any operation is attempted with this
        connection after this method completes successfully.
        """
        self._verify_connected()
        self._impl.close()
        self._impl = None

    def commit(self) -> None:
        """
        Commits any pending transactions to the database.
        """
        self._verify_connected()
        self._impl.commit()

    def createlob(self, lob_type: DbType) -> LOB:
        """
        Create and return a new temporary LOB of the specified type.
        """
        self._verify_connected()
        if lob_type not in (DB_TYPE_CLOB, DB_TYPE_NCLOB, DB_TYPE_BLOB):
            message = "parameter should be one of oracledb.DB_TYPE_CLOB, " \
                      "oracledb.DB_TYPE_BLOB or oracledb.DB_TYPE_NCLOB"
            raise TypeError(message)
        impl = self._impl.create_temp_lob_impl(lob_type)
        return LOB._from_impl(impl)

    @property
    def current_schema(self) -> str:
        """
        Specifies the current schema for the session. Setting this value is the
        same as executing the SQL statement "ALTER SESSION SET CURRENT_SCHEMA".
        The attribute is set (and verified) on the next call that does a round
        trip to the server. The value is placed before unqualified database
        objects in SQL statements you then execute.
        """
        self._verify_connected()
        return self._impl.get_current_schema()

    @current_schema.setter
    def current_schema(self, value: str) -> None:
        self._verify_connected()
        self._impl.set_current_schema(value)

    def cursor(self, scrollable: bool=False) -> Cursor:
        """
        Returns a cursor associated with the connection.
        """
        self._verify_connected()
        return Cursor(self, scrollable)

    @property
    def dbop(self) -> None:
        raise AttributeError("dbop is not readable")

    @dbop.setter
    def dbop(self, value: str) -> None:
        """
        Specifies the database operation that is to be monitored. This can be
        viewed in the DBOP_NAME column of the V$SQL_MONITOR table.
        """
        self._verify_connected()
        self._impl.set_dbop(value)

    @property
    def dsn(self) -> str:
        """
        Specifies the connection string (TNS entry) of the database to which a
        connection has been established.
        """
        self._verify_connected()
        return self._impl.dsn

    @property
    def edition(self) -> str:
        """
        Specifies the session edition.
        """
        self._verify_connected()
        return self._impl.get_edition()

    @property
    def encoding(self) -> str:
        """
        Specifies the IANA character set name of the character set in use. This
        is always the value "UTF-8".
        """
        return "UTF-8"

    @property
    def external_name(self) -> str:
        """
        Specifies the external name that is used by the connection when logging
        distributed transactions.
        """
        self._verify_connected()
        return self._impl.get_external_name()

    @external_name.setter
    def external_name(self, value: str) -> None:
        self._verify_connected()
        self._impl.set_external_name(value)

    def getSodaDatabase(self) -> SodaDatabase:
        """
        Return a SODA database object for performing all operations on Simple
        Oracle Document Access (SODA).
        """
        self._verify_connected()
        db_impl = self._impl.create_soda_database_impl(self)
        return SodaDatabase._from_impl(self, db_impl)

    def gettype(self, name: str) -> DbObjectType:
        """
        Return a type object given its name. This can then be used to create
        objects which can be bound to cursors created by this connection.
        """
        self._verify_connected()
        obj_type_impl = self._impl.get_type(name)
        return DbObjectType._from_impl(obj_type_impl)

    @property
    def handle(self) -> int:
        """
        Returns the OCI service context handle for the connection. It is
        primarily provided to facilitate testing the creation of a connection
        using the OCI service context handle.

        This property is only relevant for the thick driver.
        """
        self._verify_connected()
        return self._impl.get_handle()

    @property
    def inputtypehandler(self) -> Callable:
        """
        Specifies a method called for each value that is bound to a statement
        executed on any cursor associated with this connection. The method
        signature is handler(cursor, value, arraysize) and the return value is
        expected to be a variable object or None in which case a default
        variable object will be created. If this attribute is None, the default
        behavior will take place for all values bound to statements.
        """
        self._verify_connected()
        return self._impl.inputtypehandler

    @inputtypehandler.setter
    def inputtypehandler(self, value: Callable) -> None:
        self._verify_connected()
        self._impl.inputtypehandler = value

    @property
    def internal_name(self) -> str:
        """
        Specifies the internal name that is used by the connection when logging
        distributed transactions.
        """
        self._verify_connected()
        return self._impl.get_internal_name()

    @internal_name.setter
    def internal_name(self, value: str) -> None:
        self._verify_connected()
        self._impl.set_internal_name(value)

    @property
    def ltxid(self) -> bytes:
        """
        Returns the logical transaction id for the connection. It is used
        within Oracle Transaction Guard as a means of ensuring that
        transactions are not duplicated. See the Oracle documentation and the
        provided sample for more information.
        """
        self._verify_connected()
        return self._impl.get_ltxid()

    @property
    def maxBytesPerCharacter(self) -> int:
        """
        Deprecated. Use the constant value 4 instead.
        """
        return 4

    @property
    def module(self) -> None:
        raise AttributeError("module is not readable")

    @module.setter
    def module(self, value: str) -> None:
        """
        Specifies the module column in the v$session table. The maximum length
        for this string is 48 and if you exceed this length you will get
        ORA-24960.
        """
        self._verify_connected()
        self._impl.set_module(value)

    def msgproperties(self, payload: Union[bytes, DbObject]=None,
                      correlation: str=None, delay: int=None,
                      exceptionq: str=None, expiration: int=None,
                      priority: int=None) -> MessageProperties:
        """
        Create and return a message properties object. If the parameters are
        not None, they act as a shortcut for setting each of the equivalently
        named properties.
        """
        impl = self._impl.create_msg_props_impl()
        props = MessageProperties._from_impl(impl)
        if payload is not None:
            props.payload = payload
        if correlation is not None:
            props.correlation = correlation
        if delay is not None:
            props.delay = delay
        if exceptionq is not None:
            props.exceptionq = exceptionq
        if expiration is not None:
            props.expiration = expiration
        if priority is not None:
            props.priority = priority
        return props

    @property
    def nencoding(self) -> str:
        """
        Specifies the IANA character set name of the national character set in
        use. This is always the value "UTF-8".
        """
        return "UTF-8"

    @property
    def outputtypehandler(self) -> Callable:
        """
        Specifies a method called for each column that is going to be fetched
        from any cursor associated with this connection. The method signature
        is handler(cursor, name, defaultType, length, precision, scale) and the
        return value is expected to be a variable object or None in which case
        a default variable object will be created. If this attribute is None,
        the default behavior will take place for all columns fetched from
        cursors associated with this connection.
        """
        self._verify_connected()
        return self._impl.outputtypehandler

    @outputtypehandler.setter
    def outputtypehandler(self, value: Callable) -> None:
        self._verify_connected()
        self._impl.outputtypehandler = value

    def ping(self) -> None:
        """
        Pings the database to verify the connection is valid.
        """
        self._verify_connected()
        self._impl.ping()

    def prepare(self) -> bool:
        """
        Prepare the distributed (global) transaction for commit. Return a
        boolean indicating if a transaction was actually prepared in order to
        avoid the error ORA-24756 (transaction does not exist).
        """
        self._verify_connected()
        return self._impl.prepare()

    def queue(self, name: str, payload_type: DbObjectType=None, *,
              payloadType: DbObjectType=None) -> Queue:
        """
        Creates and returns a queue which is used to enqueue and dequeue
        messages in Advanced Queueing (AQ).

        The name parameter is expected to be a string identifying the queue in
        which messages are to be enqueued or dequeued.

        The payload_type parameter, if specified, is expected to be an object
        type that identifies the type of payload the queue expects. If not
        specified, RAW data is enqueued and dequeued.
        """
        self._verify_connected()
        payload_type_impl = None
        if payloadType is not None:
            if payload_type is not None:
                errors._raise_err(errors.ERR_DUPLICATED_PARAMETER,
                                  deprecated_name="payloadType",
                                  new_name="payload_type")
            payload_type = payloadType
        if payload_type is not None:
            if not isinstance(payload_type, DbObjectType):
                raise TypeError("expecting DbObjectType")
            payload_type_impl = payload_type._impl
        impl = self._impl.create_queue_impl()
        impl.initialize(self._impl, name, payload_type_impl)
        return Queue._from_impl(self, impl)

    def rollback(self) -> None:
        """
        Rolls back any pending transactions.
        """
        self._verify_connected()
        self._impl.rollback()

    def shutdown(self, mode: int=0) -> None:
        """
        Shutdown the database. In order to do this the connection must be
        connected as SYSDBA or SYSOPER. Two calls must be made unless the mode
        specified is DBSHUTDOWN_ABORT.
        """
        self._verify_connected()
        self._impl.shutdown(mode)

    def startup(self, force: bool=False, restrict: bool=False,
                pfile: str=None) -> None:
        """
        Startup the database. This is equivalent to the SQL*Plus command
        “startup nomount”. The connection must be connected as SYSDBA or
        SYSOPER with the PRELIM_AUTH option specified for this to work.

        The pfile parameter, if specified, is expected to be a string
        identifying the location of the parameter file (PFILE) which will be
        used instead of the stored parameter file (SPFILE).
        """
        self._verify_connected()
        self._impl.startup(force, restrict, pfile)

    @property
    def stmtcachesize(self) -> int:
        """
        Specifies the size of the statement cache. This value can make a
        significant difference in performance (up to 100x) if you have a small
        number of statements that you execute repeatedly.
        """
        self._verify_connected()
        return self._impl.get_stmt_cache_size()

    @stmtcachesize.setter
    def stmtcachesize(self, value: int) -> None:
        self._verify_connected()
        self._impl.set_stmt_cache_size(value)

    def subscribe(self,
                  namespace: int=constants.SUBSCR_NAMESPACE_DBCHANGE,
                  protocol: int=constants.SUBSCR_PROTOCOL_CALLBACK,
                  callback: Callable=None,
                  timeout: int=0,
                  operations: int=constants.OPCODE_ALLOPS,
                  port: int=0,
                  qos: int=constants.SUBSCR_QOS_DEFAULT,
                  ip_address: str=None,
                  grouping_class: int=constants.SUBSCR_GROUPING_CLASS_NONE,
                  grouping_value: int=0,
                  grouping_type: int=constants.SUBSCR_GROUPING_TYPE_SUMMARY,
                  name: str=None,
                  client_initiated: bool=False,
                  *,
                  ipAddress: str=None,
                  groupingClass: int=constants.SUBSCR_GROUPING_CLASS_NONE,
                  groupingValue: int=0,
                  groupingType: int=constants.SUBSCR_GROUPING_TYPE_SUMMARY,
                  clientInitiated: bool=False) -> Subscription:
        """
        Return a new subscription object that receives notification for events
        that take place in the database that match the given parameters.

        The namespace parameter specifies the namespace the subscription uses.
        It can be one of SUBSCR_NAMESPACE_DBCHANGE or SUBSCR_NAMESPACE_AQ.

        The protocol parameter specifies the protocol to use when notifications
        are sent. Currently the only valid value is SUBSCR_PROTOCOL_CALLBACK.

        The callback is expected to be a callable that accepts a single
        parameter. A message object is passed to this callback whenever a
        notification is received.

        The timeout value specifies that the subscription expires after the
        given time in seconds. The default value of 0 indicates that the
        subscription never expires.

        The operations parameter enables filtering of the messages that are
        sent (insert, update, delete). The default value will send
        notifications for all operations. This parameter is only used when the
        namespace is set to SUBSCR_NAMESPACE_DBCHANGE.

        The port parameter specifies the listening port for callback
        notifications from the database server. If not specified, an unused
        port will be selected by the Oracle Client libraries.

        The qos parameter specifies quality of service options. It should be
        one or more of the following flags, OR'ed together:
        SUBSCR_QOS_RELIABLE,
        SUBSCR_QOS_DEREG_NFY,
        SUBSCR_QOS_ROWIDS,
        SUBSCR_QOS_QUERY,
        SUBSCR_QOS_BEST_EFFORT.

        The ip_address parameter specifies the IP address (IPv4 or IPv6) in
        standard string notation to bind for callback notifications from the
        database server. If not specified, the client IP address will be
        determined by the Oracle Client libraries.

        The grouping_class parameter specifies what type of grouping of
        notifications should take place. Currently, if set, this value can
        only be set to the value SUBSCR_GROUPING_CLASS_TIME, which will group
        notifications by the number of seconds specified in the grouping_value
        parameter. The grouping_type parameter should be one of the values
        SUBSCR_GROUPING_TYPE_SUMMARY (the default) or
        SUBSCR_GROUPING_TYPE_LAST.

        The name parameter is used to identify the subscription and is specific
        to the selected namespace. If the namespace parameter is
        SUBSCR_NAMESPACE_DBCHANGE then the name is optional and can be any
        value. If the namespace parameter is SUBSCR_NAMESPACE_AQ, however, the
        name must be in the format '<QUEUE_NAME>' for single consumer queues
        and '<QUEUE_NAME>:<CONSUMER_NAME>' for multiple consumer queues, and
        identifies the queue that will be monitored for messages. The queue
        name may include the schema, if needed.

        The client_initiated parameter is used to determine if client initiated
        connections or server initiated connections (the default) will be
        established. Client initiated connections are only available in Oracle
        Client 19.4 and Oracle Database 19.4 and higher.
        """
        self._verify_connected()
        if ipAddress is not None:
            if ip_address is not None:
                errors._raise_err(errors.ERR_DUPLICATED_PARAMETER,
                                  deprecated_name="ipAddress",
                                  new_name="ip_address")
            ip_address = ipAddress
        if groupingClass != constants.SUBSCR_GROUPING_CLASS_NONE:
            if grouping_class != constants.SUBSCR_GROUPING_CLASS_NONE:
                errors._raise_err(errors.ERR_DUPLICATED_PARAMETER,
                                  deprecated_name="groupingClass",
                                  new_name="grouping_class")
            grouping_class = groupingClass
        if groupingValue != 0:
            if grouping_value != 0:
                errors._raise_err(errors.ERR_DUPLICATED_PARAMETER,
                                  deprecated_name="groupingValue",
                                  new_name="grouping_value")
            grouping_value = groupingValue
        if groupingType != constants.SUBSCR_GROUPING_TYPE_SUMMARY:
            if grouping_type != constants.SUBSCR_GROUPING_TYPE_SUMMARY:
                errors._raise_err(errors.ERR_DUPLICATED_PARAMETER,
                                  deprecated_name="groupingType",
                                  new_name="grouping_type")
            grouping_type = groupingType
        if clientInitiated:
            if client_initiated:
                errors._raise_err(errors.ERR_DUPLICATED_PARAMETER,
                                  deprecated_name="clientInitiated",
                                  new_name="client_initiated")
            client_initiated = clientInitiated
        impl = self._impl.create_subscr_impl(self, callback, namespace, name,
                                             protocol, ip_address, port,
                                             timeout, operations, qos,
                                             grouping_class, grouping_value,
                                             grouping_type, client_initiated)
        subscr = Subscription._from_impl(impl)
        impl.subscribe(subscr, self._impl)
        return subscr

    @property
    def tag(self) -> str:
        """
        This property initially contains the actual tag of the session that was
        acquired from a pool. If the connection was not acquired from a pool or
        no tagging parameters were specified (tag and matchanytag) when the
        connection was acquired from the pool, this value will be None. If the
        value is changed, it must be a string containing name=value pairs like
        “k1=v1;k2=v2”.

        If this value is not None when the connection is released back to the
        pool it will be used to retag the session. This value can be overridden
        in the call to SessionPool.release().
        """
        self._verify_connected()
        return self._impl.tag

    @tag.setter
    def tag(self, value: str) -> None:
        self._verify_connected()
        self._impl.tag = value

    @property
    def thin(self) -> bool:
        """
        Returns a boolean indicating if the connection was established with the
        thin driver (True) or thick driver (False).
        """
        self._verify_connected()
        return isinstance(self._impl, thin_impl.ThinConnImpl)

    @property
    def tnsentry(self) -> str:
        """
        Deprecated. Use dsn property instead.
        """
        return self.dsn

    def unsubscribe(self, subscr: Subscription) -> None:
        """
        Unsubscribe from events in the database that were originally subscribed
        to using subscribe(). The connection used to unsubscribe should be the
        same one used to create the subscription, or should access the same
        database and be connected as the same user name.
        """
        self._verify_connected()
        if not isinstance(subscr, Subscription):
            raise TypeError("expecting subscription")
        subscr._impl.unsubscribe(self._impl)

    @property
    def username(self) -> str:
        """
        Returns the name of the user which established the connection to the
        database.
        """
        self._verify_connected()
        return self._impl.username

    @property
    def version(self) -> str:
        """
        Returns the version of the database to which the connection has been
        established.
        """
        if self._version is None:
            self._verify_connected()
            self._version = self._impl.get_version()
        return self._version

# alias required by the DB API
connect = Connection
