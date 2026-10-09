# -----------------------------------------------------------------------------
# Copyright (c) 2026, Oracle and/or its affiliates.
#
# This software is dual-licensed to you under the Universal Permissive License
# (UPL) 1.0 as shown at https://oss.oracle.com/licenses/upl and Apache License
# 2.0 as shown at http://www.apache.org/licenses/LICENSE-2.0. You may choose
# either license.
#
# If you elect to accept the software under the Apache License, Version 2.0,
# the following applies:
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# -----------------------------------------------------------------------------

"""
E3500 - Module for testing AWS config cache notifications with real resources.

These tests require run_long_tests and the AWS notifier settings in
sample_config.ini. EventBridge must send the matching S3 and Secrets Manager
events to the configured SQS queue.
E3504 also requires sqs:CreateQueue, sqs:DeleteQueue and sqs:SendMessage.
"""

import json
import os
import threading
import time
import uuid
from urllib.parse import quote

import oracledb
import pytest

plugin = pytest.importorskip("oracledb.plugins.aws_config_provider")
boto3 = pytest.importorskip("boto3")


class AwsNotifierConfig:
    """
    Manages real AWS resources required by the notifier test.
    """

    def __init__(self, test_env, extended_config):
        self.bucket_name = extended_config.get_str_value("aws_bucket_name")
        self.aws_region = extended_config.get_str_value("aws_region")
        self.aws_profile = extended_config.get_str_value(
            "aws_profile"
        ) or os.environ.get("AWS_PROFILE")
        self.object_key = "aws notifier config.json"
        self.queue_url = extended_config.get_str_value("aws_sqs_queue_url")
        self.secret_names = []
        self.connect_descriptor = test_env.connect_string
        self.db_user = test_env.main_user
        self.db_password = test_env.main_password
        if not self.bucket_name:
            pytest.skip("AWS S3 bucket name is not configured")
        if not self.aws_region:
            pytest.skip("AWS region is not configured")
        if not self.queue_url:
            pytest.skip("AWS SQS queue URL is not configured")

    def _build_config_text(self, config_key, stmtcachesize):
        return json.dumps(
            {
                config_key: dict(
                    connect_descriptor=self.connect_descriptor,
                    config_time_to_live=3600,
                    pyo=dict(stmtcachesize=stmtcachesize),
                )
            },
            separators=(",", ":"),
        )

    def build_dsn(self, config_key, object_key=None):
        if object_key is None:
            object_key = self.object_key
        query_args = dict(
            aws_region=self.aws_region,
            key=config_key,
            queueurl=self.queue_url,
        )
        if self.aws_profile is not None:
            query_args["authentication"] = "aws_profile"
            query_args["aws_profile"] = self.aws_profile
        query = "&".join(
            f"{key}={quote(str(value), safe='')}"
            for key, value in query_args.items()
        )
        quoted_object_key = quote(object_key, safe="/")
        dsn = f"config-awss3://{self.bucket_name}/{quoted_object_key}?{query}"
        if object_key == self.object_key:
            self.dsn = dsn
        return dsn

    def build_secret_dsn(self, secret_name, config_key):
        query_args = dict(
            aws_region=self.aws_region,
            key=config_key,
            queueurl=self.queue_url,
        )
        if self.aws_profile is not None:
            query_args["authentication"] = "aws_profile"
            query_args["aws_profile"] = self.aws_profile
        query = "&".join(
            f"{key}={quote(str(value), safe='')}"
            for key, value in query_args.items()
        )
        secret_name = quote(secret_name, safe="/")
        return f"config-awssecretsmanager://{secret_name}?{query}"

    def cleanup_secrets(self):
        for secret_name in self.secret_names:
            try:
                self.secrets_client.delete_secret(
                    SecretId=secret_name, ForceDeleteWithoutRecovery=True
                )
            except Exception as exc:
                error = getattr(exc, "response", {}).get("Error", {})
                if error.get("Code") != "ResourceNotFoundException":
                    raise
        self.secret_names.clear()

    def create_secret_config(self, secret_name, config_key, stmtcachesize):
        self.secrets_client.create_secret(
            Name=secret_name,
            SecretString=self._build_config_text(config_key, stmtcachesize),
        )
        self.secret_names.append(secret_name)

    def drain_queue(self):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            response = self.sqs_client.receive_message(
                QueueUrl=self.queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=1,
            )
            messages = response.get("Messages", [])
            if not messages:
                return
            for message in messages:
                self.sqs_client.delete_message(
                    QueueUrl=self.queue_url,
                    ReceiptHandle=message["ReceiptHandle"],
                )

    def get_object_text(self, object_key=None):
        if object_key is None:
            object_key = self.object_key
        try:
            response = self.s3_client.get_object(
                Bucket=self.bucket_name, Key=object_key
            )
        except Exception as exc:
            error = getattr(exc, "response", {}).get("Error", {})
            if error.get("Code") in ("NoSuchKey", "404"):
                return None
            raise
        return response["Body"].read().decode()

    def get_stmtcachesize(self, dsn=None):
        params = oracledb.ConnectParams()
        params.parse_connect_string(dsn or self.dsn)
        return params.stmtcachesize

    def put_config(self, config_key, stmtcachesize, object_key=None):
        if object_key is None:
            object_key = self.object_key
        self.s3_client.put_object(
            Bucket=self.bucket_name,
            Key=object_key,
            Body=self._build_config_text(config_key, stmtcachesize),
        )

    def put_secret_config(self, secret_name, config_key, stmtcachesize):
        self.secrets_client.put_secret_value(
            SecretId=secret_name,
            SecretString=self._build_config_text(config_key, stmtcachesize),
        )

    def remove_secret_config(self, secret_name):
        self.secrets_client.delete_secret(
            SecretId=secret_name, ForceDeleteWithoutRecovery=True
        )
        self.secret_names.remove(secret_name)

    def restore_object(self, original_text, object_key=None):
        if object_key is None:
            object_key = self.object_key
        if original_text is None:
            self.s3_client.delete_object(
                Bucket=self.bucket_name, Key=object_key
            )
        else:
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=object_key,
                Body=original_text,
            )

    def wait_for_removed_config(self, dsn=None):
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                self.get_stmtcachesize(dsn)
            except oracledb.Error as exc:
                error = exc.args[0]
                if error.full_code == "DPY-2056":
                    return
                raise
            time.sleep(2)
        pytest.fail("Timed out waiting for removed AWS config")

    def wait_for_updated_config(self, expected_value, dsn=None):
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            if self.get_stmtcachesize(dsn) == expected_value:
                return
            time.sleep(2)
        pytest.fail(
            "Timed out waiting for refreshed AWS config with "
            f"stmtcachesize={expected_value}"
        )


@pytest.fixture
def aws_notifier_config(request, test_env, extended_config):

    config = AwsNotifierConfig(test_env, extended_config)
    config.aws_session = boto3.session.Session(
        profile_name=config.aws_profile,
        region_name=config.aws_region,
    )
    if config.aws_session.get_credentials() is None:
        raise RuntimeError("AWS credentials are not configured")
    config.aws_session.client("sts").get_caller_identity()

    config.s3_client = config.aws_session.client("s3")
    config.secrets_client = config.aws_session.client("secretsmanager")
    config.sqs_client = config.aws_session.client("sqs")
    config.config_key = request.node.name
    config.build_dsn(config.config_key)
    return config


def test_ext_3500(aws_notifier_config):
    "E3500 - test real AWS SQS config cache update notification"
    config = aws_notifier_config
    initial_stmtcachesize = 23
    updated_stmtcachesize = 37
    original_text = config.get_object_text()
    try:
        config.put_config(
            config.config_key, stmtcachesize=initial_stmtcachesize
        )
        time.sleep(5)
        config.drain_queue()

        assert config.get_stmtcachesize() == initial_stmtcachesize
        config.put_config(
            config.config_key, stmtcachesize=updated_stmtcachesize
        )
        config.wait_for_updated_config(expected_value=updated_stmtcachesize)
        with oracledb.connect(
            user=config.db_user, password=config.db_password, dsn=config.dsn
        ) as conn:
            assert conn.stmtcachesize == updated_stmtcachesize
    finally:
        config.restore_object(original_text)


def test_ext_3501(aws_notifier_config):
    "E3501 - test real AWS SQS config cache delete notification"
    config = aws_notifier_config
    initial_stmtcachesize = 23
    original_text = config.get_object_text()
    try:
        config.put_config(
            config.config_key, stmtcachesize=initial_stmtcachesize
        )
        time.sleep(5)
        config.drain_queue()

        assert config.get_stmtcachesize() == initial_stmtcachesize
        config.s3_client.delete_object(
            Bucket=config.bucket_name, Key=config.object_key
        )
        config.wait_for_removed_config()
    finally:
        config.restore_object(original_text)


def test_ext_3502(aws_notifier_config):
    "E3502 - test real AWS Secrets Manager config cache notification"
    config = aws_notifier_config
    initial_stmtcachesize = 23
    updated_stmtcachesize = 37
    secret_name = f"python-oracledb-test/aws-notifier-{uuid.uuid4().hex}"
    secret_dsn = config.build_secret_dsn(secret_name, config.config_key)
    try:
        config.create_secret_config(
            secret_name,
            config.config_key,
            stmtcachesize=initial_stmtcachesize,
        )
        time.sleep(5)
        config.drain_queue()

        assert config.get_stmtcachesize(secret_dsn) == initial_stmtcachesize

        config.put_secret_config(
            secret_name,
            config.config_key,
            stmtcachesize=updated_stmtcachesize,
        )
        config.wait_for_updated_config(updated_stmtcachesize, secret_dsn)

        config.remove_secret_config(secret_name)
        config.wait_for_removed_config(secret_dsn)
    finally:
        config.cleanup_secrets()


def test_ext_3503(aws_notifier_config):
    "E3503 - test AWS SQS notification only invalidates matching S3 config"
    config = aws_notifier_config
    initial_stmtcachesize = 23
    other_stmtcachesize = 24
    first_updated_stmtcachesize = 37
    second_updated_stmtcachesize = 41
    other_object_key = f"{config.object_key}.other"
    original_text = config.get_object_text()
    other_original_text = config.get_object_text(other_object_key)
    other_config_key = f"{config.config_key}_other"
    other_dsn = config.build_dsn(other_config_key, other_object_key)
    try:
        config.put_config(config.config_key, initial_stmtcachesize)
        config.put_config(
            other_config_key, other_stmtcachesize, other_object_key
        )
        time.sleep(5)
        config.drain_queue()

        assert config.get_stmtcachesize() == initial_stmtcachesize
        assert config.get_stmtcachesize(other_dsn) == other_stmtcachesize

        config.s3_client.delete_object(
            Bucket=config.bucket_name, Key=other_object_key
        )
        config.put_config(config.config_key, first_updated_stmtcachesize)
        config.wait_for_updated_config(first_updated_stmtcachesize)
        assert config.get_stmtcachesize(other_dsn) == other_stmtcachesize

        config.put_config(config.config_key, second_updated_stmtcachesize)
        config.wait_for_updated_config(second_updated_stmtcachesize)
    finally:
        config.restore_object(original_text)
        config.restore_object(other_original_text, other_object_key)


def test_ext_3504(aws_notifier_config):
    "E3504 - test real AWS SQS listener stops after its last DSN is removed"
    config = aws_notifier_config
    # Use separate resources so other tests cannot keep this listener alive.
    suffix = uuid.uuid4().hex
    config.object_key = f"aws-notifier-{suffix}.json"
    other_object_key = f"{config.object_key}.other"
    response = config.sqs_client.create_queue(
        QueueName=f"oracledb-notifier-{suffix}"
    )
    config.queue_url = response["QueueUrl"]
    config.build_dsn(config.config_key)
    other_dsn = config.build_dsn(config.config_key, other_object_key)
    listener_thread = None
    # Deliver notifications directly to isolate this queue from other
    # tests without changing the configured EventBridge routing.
    event = {
        "source": "aws.s3",
        "detail-type": "Object Created",
        "detail": {
            "bucket": {"name": config.bucket_name},
            "object": {"key": config.object_key},
        },
    }
    try:
        # Register two DSNs with the same listener.
        config.put_config(config.config_key, 23)
        config.put_config(config.config_key, 24, other_object_key)
        threads = set(threading.enumerate())
        assert config.get_stmtcachesize() == 23
        (listener_thread,) = (
            thread
            for thread in threading.enumerate()
            if thread not in threads
            and thread.name == "oracledb-aws-config-listener"
        )
        assert config.get_stmtcachesize(other_dsn) == 24

        # Refresh one config and check that the listener is still running.
        config.put_config(config.config_key, 37)
        config.sqs_client.send_message(
            QueueUrl=config.queue_url,
            MessageBody=json.dumps(event),
        )
        config.wait_for_updated_config(37)
        assert listener_thread.is_alive()

        # Delete each config; the first deletion must leave the listener alive.
        event["detail-type"] = "Object Deleted"
        for object_key, dsn in (
            (other_object_key, other_dsn),
            (config.object_key, config.dsn),
        ):
            config.s3_client.delete_object(
                Bucket=config.bucket_name, Key=object_key
            )
            event["detail"]["object"]["key"] = object_key
            config.sqs_client.send_message(
                QueueUrl=config.queue_url,
                MessageBody=json.dumps(event),
            )
            config.wait_for_removed_config(dsn)
            if dsn == other_dsn:
                assert listener_thread.is_alive()

        # The last deletion must stop the listener thread.
        listener_thread.join(timeout=10)
        assert not listener_thread.is_alive()
    finally:
        try:
            event["detail-type"] = "Object Deleted"
            for object_key in (config.object_key, other_object_key):
                config.restore_object(None, object_key)
                event["detail"]["object"]["key"] = object_key
                config.sqs_client.send_message(
                    QueueUrl=config.queue_url,
                    MessageBody=json.dumps(event),
                )
            if listener_thread is not None:
                listener_thread.join(timeout=10)
        finally:
            config.sqs_client.delete_queue(QueueUrl=config.queue_url)
