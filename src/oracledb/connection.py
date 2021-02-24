#------------------------------------------------------------------------------
# Copyright (c) 2020, Oracle and/or its affiliates. All rights reserved.
#------------------------------------------------------------------------------

from . import constants, errors, exceptions, utils
from . import thick_impl, thin_impl
from .cursor import Cursor
from .base_impl import DB_TYPE_BLOB, DB_TYPE_CLOB, DB_TYPE_NCLOB

class Connection:

    def __init__(self, dsn=None, *, user=None, password=None, host=None,
                 port=None, service_name=None, thin=True,
                 mode=constants.DEFAULT_AUTH, handle=0, pool=None,
                 threaded=False, events=False, cclass=None,
                 purity=constants.ATTR_PURITY_DEFAULT, newpassword=None,
                 edition=None, appcontext=[], tag=None, matchanytag=False,
                 shardingkey=[], supershardingkey=[]):
        self._impl = None
        result = utils.parse_connect_params(dsn, user, password, host, port,
                                            service_name, thin)
        dsn, user, password, host, port, connect_data = result
        if thin:
            impl = thin_impl.ThinConnImpl(user, dsn)
            impl._connect(host, port, connect_data, password)
        else:
            impl = thick_impl.ThickConnImpl(user, dsn)
            impl._connect(password=password, mode=mode, handle=handle,
                          pool=pool, threaded=threaded, events=events,
                          cclass=cclass, purity=purity,
                          newpassword=newpassword, edition=edition,
                          appcontext=appcontext, tag=tag,
                          matchanytag=matchanytag, shardingkey=shardingkey,
                          supershardingkey=supershardingkey)
        self._impl = impl
        self._dsn = dsn
        self._username = user
        self._version = None

    @staticmethod
    def _from_impl(impl, dsn, username):
        conn = Connection.__new__(Connection)
        conn._impl = impl
        conn._dsn = dsn
        conn._username = username
        conn._version = None
        return conn

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
            errors._raise_from_string(exceptions.InterfaceError,
                                      "not connected")

    @property
    def action(self):
        raise AttributeError("action is not readable")

    @action.setter
    def action(self, value):
        """
        Specifies the action column in the v$session table. It is a string
        attribute and cannot be set to None -- use the empty string instead.
        """
        self._verify_connected()
        self._impl.action = value

    @property
    def autocommit(self):
        """
        Specifies whether autocommit mode is on or off. When autocommit mode is
        on, all statements are committed as soon as they have completed
        executing successfully.
        """
        self._verify_connected()
        return self._impl.autocommit

    @autocommit.setter
    def autocommit(self, value):
        self._verify_connected()
        self._impl.autocommit = value

    def begin(self, format_id=-1, transaction_id="", branch_id=""):
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
    def callTimeout(self):
        """
        Specifies the amount of time (in milliseconds) that a single round-trip
        to the database may take before a timeout will occur. A value of 0
        means that no timeout will take place.
        """
        self._verify_connected()
        return self._impl.calltimeout

    @callTimeout.setter
    def callTimeout(self, value):
        self._verify_connected()
        self._impl.calltimeout = value

    def cancel(self):
        """
        Break a long-running transaction.
        """
        self._verify_connected()
        self._impl.cancel()

    def changepassword(self, old_password, new_password):
        """
        Changes the password for the user to which the connection is connected.
        """
        self._verify_connected()
        self._impl.changepassword(old_password, new_password)

    @property
    def client_identifier(self):
        raise AttributeError("client_identifier is not readable")

    @client_identifier.setter
    def client_identifier(self, value):
        """
        Specifies the client_identifier column in the v$session table.
        """
        self._verify_connected()
        self._impl.client_identifier = value

    @property
    def clientinfo(self):
        raise AttributeError("clientinfo is not readable")

    @clientinfo.setter
    def clientinfo(self, value):
        """
        Specifies the client_info column in the v$session table.
        """
        self._verify_connected()
        self._impl.clientinfo = value

    def close(self):
        """
        Closes the connection and makes it unusable for further operations. An
        Error exception will be raised if any operation is attempted with this
        connection after this method completes successfully.
        """
        self._verify_connected()
        self._impl.close()
        self._impl = None

    def commit(self):
        """
        Commits any pending transactions to the database.
        """
        self._verify_connected()
        self._impl.commit()

    def createlob(self, lob_type):
        """
        Create and return a new temporary LOB of the specified type.
        """
        self._verify_connected()
        if lob_type not in (DB_TYPE_CLOB, DB_TYPE_NCLOB, DB_TYPE_BLOB):
            message = "parameter should be one of oracledb.DB_TYPE_CLOB, " \
                      "oracledb.DB_TYPE_BLOB or oracledb.DB_TYPE_NCLOB"
            raise TypeError(message)
        return self._impl.createlob(lob_type)

    @property
    def current_schema(self):
        self._verify_connected()
        return self._impl.current_schema

    @current_schema.setter
    def current_schema(self, value):
        self._verify_connected()
        self._impl.current_schema = value

    def cursor(self, scrollable=False):
        """
        Returns a cursor associated with the connection.
        """
        self._verify_connected()
        return Cursor(self, scrollable)

    @property
    def dbop(self):
        raise AttributeError("dbop is not readable")

    @dbop.setter
    def dbop(self, value):
        """
        Specifies the database operation that is to be monitored. This can be
        viewed in the DBOP_NAME column of the V$SQL_MONITOR table.
        """
        self._verify_connected()
        self._impl.dbop = value

    @property
    def dsn(self):
        """
        Specifies the connection string (TNS entry) of the database to which a
        connection has been established.
        """
        return self._dsn

    @property
    def edition(self):
        """
        Specifies the session edition.
        """
        self._verify_connected()
        return self._impl.edition

    @property
    def encoding(self):
        """
        Specifies the IANA character set name of the character set in use. This
        is always the value "UTF-8".
        """
        return "UTF-8"

    @property
    def external_name(self):
        """
        Specifies the external name that is used by the connection when logging
        distributed transactions.
        """
        self._verify_connected()
        return self._impl.external_name

    @external_name.setter
    def external_name(self, value):
        self._verify_connected()
        self._impl.external_name = value

    def getSodaDatabase(self):
        """
        Return a SODA database object for performing all operations on Simple
        Oracle Document Access (SODA).
        """
        self._verify_connected()
        return self._impl.getSodaDatabase(self)

    def gettype(self, name):
        """
        Return a type object given its name. This can then be used to create
        objects which can be bound to cursors created by this connection.
        """
        self._verify_connected()
        return self._impl.gettype(name)

    @property
    def handle(self):
        """
        Returns the OCI service context handle for the connection. It is
        primarily provided to facilitate testing the creation of a connection
        using the OCI service context handle.

        This property is only relevant for the thick driver.
        """
        self._verify_connected()
        return self._impl.get_handle()

    @property
    def inputtypehandler(self):
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
    def inputtypehandler(self, value):
        self._verify_connected()
        self._impl.inputtypehandler = value

    @property
    def internal_name(self):
        """
        Specifies the internal name that is used by the connection when logging
        distributed transactions.
        """
        self._verify_connected()
        return self._impl.internal_name

    @internal_name.setter
    def internal_name(self, value):
        self._verify_connected()
        self._impl.internal_name = value

    @property
    def ltxid(self):
        """
        Returns the logical transaction id for the connection. It is used
        within Oracle Transaction Guard as a means of ensuring that
        transactions are not duplicated. See the Oracle documentation and the
        provided sample for more information.
        """
        self._verify_connected()
        return self._impl.ltxid

    @property
    def module(self):
        raise AttributeError("module is not readable")

    @module.setter
    def module(self, value):
        """
        Specifies the module column in the v$session table. The maximum length
        for this string is 48 and if you exceed this length you will get
        ORA-24960.
        """
        self._verify_connected()
        self._impl.module = value

    def msgproperties(self, payload=None, correlation=None, delay=None,
                      exceptionq=None, expiration=None, priority=None):
        """
        Create and return a message properties object. If the parameters are
        not None, they act as a shortcut for setting each of the equivalently
        named properties.
        """
        props = self._impl.create_msg_props()
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
    def nencoding(self):
        """
        Specifies the IANA character set name of the national character set in
        use. This is always the value "UTF-8".
        """
        return "UTF-8"

    @property
    def outputtypehandler(self):
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
    def outputtypehandler(self, value):
        self._verify_connected()
        self._impl.outputtypehandler = value

    def ping(self):
        """
        Pings the database to verify the connection is valid.
        """
        self._verify_connected()
        self._impl.ping()

    def prepare(self):
        """
        Prepare the distributed (global) transaction for commit. Return a
        boolean indicating if a transaction was actually prepared in order to
        avoid the error ORA-24756 (transaction does not exist).
        """
        self._verify_connected()
        return self._impl.prepare()

    def queue(self, name, payloadType=None):
        """
        Creates and returns a queue which is used to enqueue and dequeue
        messages in Advanced Queueing (AQ).

        The name parameter is expected to be a string identifying the queue in
        which messages are to be enqueued or dequeued.

        The payloadType parameter, if specified, is expected to be an object
        type that identifies the type of payload the queue expects. If not
        specified, RAW data is enqueued and dequeued.
        """
        self._verify_connected()
        return self._impl.queue(name, payloadType)

    def rollback(self):
        """
        Rolls back any pending transactions.
        """
        self._verify_connected()
        self._impl.rollback()

    def shutdown(self, mode=0):
        """
        Shutdown the database. In order to do this the connection must be
        connected as SYSDBA or SYSOPER. Two calls must be made unless the mode
        specified is DBSHUTDOWN_ABORT.
        """
        self._verify_connected()
        self._impl.shutdown(mode)

    def startup(self, force=False, restrict=False, pfile=None):
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
    def stmtcachesize(self):
        """
        Specifies the size of the statement cache. This value can make a
        significant difference in performance (up to 100x) if you have a small
        number of statements that you execute repeatedly.
        """
        self._verify_connected()
        return self._impl.stmtcachesize

    @stmtcachesize.setter
    def stmtcachesize(self, value):
        self._verify_connected()
        self._impl.stmtcachesize = value

    def subscribe(self, namespace=constants.SUBSCR_NAMESPACE_DBCHANGE,
                  protocol=constants.SUBSCR_PROTOCOL_CALLBACK, callback=None,
                  timeout=0, operations=constants.OPCODE_ALLOPS, port=0,
                  qos=constants.SUBSCR_QOS_DEFAULT, ipAddress=None,
                  groupingClass=constants.SUBSCR_GROUPING_CLASS_NONE,
                  groupingValue=0,
                  groupingType=constants.SUBSCR_GROUPING_TYPE_SUMMARY,
                  name=None, clientInitiated=False):
        """
        Return a new subscription object that receives notification for events
        that take place in the database that match the given parameters.
        """
        self._verify_connected()
        subscr = self._impl.create_subscription(self, callback, namespace,
                                                name, protocol, ipAddress,
                                                port, timeout, operations,
                                                qos, groupingClass,
                                                groupingValue, groupingType,
                                                clientInitiated)
        subscr.subscribe()
        return subscr

    @property
    def tag(self):
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
    def tag(self, value):
        self._verify_connected()
        self._impl.tag = value

    @property
    def tnsentry(self):
        """
        Deprecated. Use dsn property instead.
        """
        return self.dsn

    def unsubscribe(self, subscr):
        """
        Unsubscribe from events in the database that were originally subscribed
        to using subscribe(). The connection used to unsubscribe should be the
        same one used to create the subscription, or should access the same
        database and be connected as the same user name.
        """
        self._verify_connected()
        subscr.unsubscribe(self._impl)

    @property
    def username(self):
        """
        Returns the name of the user which established the connection to the
        database.
        """
        return self._username

    @property
    def version(self):
        """
        Returns the version of the database to which the connection has been
        established.
        """
        if self._version is None:
            self._verify_connected()
            self._version = self._impl.version
        return self._version

# alias required by the DB API
connect = Connection
