"""
DynamoDB Configuration Store for Azure OpenAI Endpoints
"""
import os
import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


@dataclass
class AzureOpenAIConfig:
    """Configuration for an Azure OpenAI endpoint stored in DynamoDB"""
    config_id: str  # Primary key (e.g., "chat-us-east-1", "embedding-eu-west-1")
    config_type: str  # "chat" or "embedding"
    endpoint: str
    api_key: str
    deployment: str
    region: str
    priority: int  # Lower = higher priority (1 = primary, 2 = failover)
    enabled: bool = True

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dynamo_item(cls, item: Dict[str, Any]) -> 'AzureOpenAIConfig':
        return cls(
            config_id=item['config_id']['S'],
            config_type=item['config_type']['S'],
            endpoint=item['endpoint']['S'],
            api_key=item['api_key']['S'],
            deployment=item['deployment']['S'],
            region=item['region']['S'],
            priority=int(item['priority']['N']),
            enabled=item.get('enabled', {}).get('BOOL', True)
        )


class DynamoDBConfigStore:
    """
    Store and retrieve Azure OpenAI configurations from DynamoDB.

    Table Schema:
    - config_id (String, Primary Key): Unique identifier for the config
    - config_type (String): "chat" or "embedding"
    - endpoint (String): Azure OpenAI endpoint URL
    - api_key (String): API key (consider using AWS Secrets Manager for production)
    - deployment (String): Model deployment name
    - region (String): Azure region (e.g., "us-east-1", "eu-west-1")
    - priority (Number): Priority order for failover (1 = primary)
    - enabled (Boolean): Whether this endpoint is active
    """

    def __init__(
        self,
        table_name: str = None,
        region: str = None
    ):
        self.table_name = table_name or os.getenv("DYNAMODB_CONFIG_TABLE", "rag-demo-config")
        self.region = region or os.getenv("AWS_REGION", "us-east-1")

        self.dynamodb = boto3.client('dynamodb', region_name=self.region)
        self.table_resource = boto3.resource('dynamodb', region_name=self.region).Table(self.table_name)

        logger.info(f"Initialized DynamoDB config store: {self.table_name}")

    def create_table_if_not_exists(self) -> bool:
        """Create the DynamoDB table if it doesn't exist"""
        try:
            self.dynamodb.describe_table(TableName=self.table_name)
            logger.info(f"Table {self.table_name} already exists")
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                logger.info(f"Creating table {self.table_name}")
                self.dynamodb.create_table(
                    TableName=self.table_name,
                    KeySchema=[
                        {'AttributeName': 'config_id', 'KeyType': 'HASH'}
                    ],
                    AttributeDefinitions=[
                        {'AttributeName': 'config_id', 'AttributeType': 'S'}
                    ],
                    BillingMode='PAY_PER_REQUEST'
                )
                # Wait for table to be created
                waiter = self.dynamodb.get_waiter('table_exists')
                waiter.wait(TableName=self.table_name)
                logger.info(f"Table {self.table_name} created successfully")
                return True
            raise

    def put_config(self, config: AzureOpenAIConfig) -> bool:
        """Store a configuration in DynamoDB"""
        try:
            self.table_resource.put_item(Item={
                'config_id': config.config_id,
                'config_type': config.config_type,
                'endpoint': config.endpoint,
                'api_key': config.api_key,
                'deployment': config.deployment,
                'region': config.region,
                'priority': config.priority,
                'enabled': config.enabled
            })
            logger.info(f"Stored config: {config.config_id}")
            return True
        except Exception as e:
            logger.error(f"Error storing config: {e}")
            return False

    def get_config(self, config_id: str) -> Optional[AzureOpenAIConfig]:
        """Get a specific configuration by ID"""
        try:
            response = self.table_resource.get_item(Key={'config_id': config_id})
            if 'Item' in response:
                item = response['Item']
                return AzureOpenAIConfig(
                    config_id=item['config_id'],
                    config_type=item['config_type'],
                    endpoint=item['endpoint'],
                    api_key=item['api_key'],
                    deployment=item['deployment'],
                    region=item['region'],
                    priority=item['priority'],
                    enabled=item.get('enabled', True)
                )
            return None
        except Exception as e:
            logger.error(f"Error getting config: {e}")
            return None

    def get_configs_by_type(self, config_type: str) -> List[AzureOpenAIConfig]:
        """Get all configurations of a specific type (chat or embedding), sorted by priority"""
        try:
            response = self.table_resource.scan(
                FilterExpression='config_type = :type AND enabled = :enabled',
                ExpressionAttributeValues={
                    ':type': config_type,
                    ':enabled': True
                }
            )

            configs = [
                AzureOpenAIConfig(
                    config_id=item['config_id'],
                    config_type=item['config_type'],
                    endpoint=item['endpoint'],
                    api_key=item['api_key'],
                    deployment=item['deployment'],
                    region=item['region'],
                    priority=item['priority'],
                    enabled=item.get('enabled', True)
                )
                for item in response.get('Items', [])
            ]

            # Sort by priority (lower = higher priority)
            configs.sort(key=lambda x: x.priority)
            return configs

        except Exception as e:
            logger.error(f"Error scanning configs: {e}")
            return []

    def get_chat_configs(self) -> List[AzureOpenAIConfig]:
        """Get all enabled chat endpoint configurations"""
        return self.get_configs_by_type('chat')

    def get_embedding_configs(self) -> List[AzureOpenAIConfig]:
        """Get all enabled embedding endpoint configurations"""
        return self.get_configs_by_type('embedding')

    def disable_config(self, config_id: str) -> bool:
        """Disable a configuration (for failover)"""
        try:
            self.table_resource.update_item(
                Key={'config_id': config_id},
                UpdateExpression='SET enabled = :enabled',
                ExpressionAttributeValues={':enabled': False}
            )
            logger.info(f"Disabled config: {config_id}")
            return True
        except Exception as e:
            logger.error(f"Error disabling config: {e}")
            return False

    def enable_config(self, config_id: str) -> bool:
        """Enable a configuration"""
        try:
            self.table_resource.update_item(
                Key={'config_id': config_id},
                UpdateExpression='SET enabled = :enabled',
                ExpressionAttributeValues={':enabled': True}
            )
            logger.info(f"Enabled config: {config_id}")
            return True
        except Exception as e:
            logger.error(f"Error enabling config: {e}")
            return False

    def delete_config(self, config_id: str) -> bool:
        """Delete a configuration"""
        try:
            self.table_resource.delete_item(Key={'config_id': config_id})
            logger.info(f"Deleted config: {config_id}")
            return True
        except Exception as e:
            logger.error(f"Error deleting config: {e}")
            return False


def seed_configs_from_env(store: DynamoDBConfigStore) -> None:
    """Seed DynamoDB with configurations from environment variables"""

    # Chat configs
    if os.getenv("AZURE_OPENAI_ENDPOINT_1"):
        store.put_config(AzureOpenAIConfig(
            config_id="chat-us-east-1",
            config_type="chat",
            endpoint=os.getenv("AZURE_OPENAI_ENDPOINT_1"),
            api_key=os.getenv("AZURE_OPENAI_KEY_1"),
            deployment=os.getenv("AZURE_OPENAI_DEPLOYMENT_1", "gpt-4o"),
            region="us-east-1",
            priority=1,
            enabled=True
        ))

    if os.getenv("AZURE_OPENAI_ENDPOINT_2"):
        store.put_config(AzureOpenAIConfig(
            config_id="chat-eu-west-1",
            config_type="chat",
            endpoint=os.getenv("AZURE_OPENAI_ENDPOINT_2"),
            api_key=os.getenv("AZURE_OPENAI_KEY_2"),
            deployment=os.getenv("AZURE_OPENAI_DEPLOYMENT_2", "gpt-4o"),
            region="eu-west-1",
            priority=2,
            enabled=True
        ))

    # Embedding configs
    if os.getenv("AZURE_OPENAI_EMBEDDING_ENDPOINT_1"):
        store.put_config(AzureOpenAIConfig(
            config_id="embedding-us-east-1",
            config_type="embedding",
            endpoint=os.getenv("AZURE_OPENAI_EMBEDDING_ENDPOINT_1"),
            api_key=os.getenv("AZURE_OPENAI_EMBEDDING_KEY_1"),
            deployment=os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT_1", "text-embedding-3-small"),
            region="us-east-1",
            priority=1,
            enabled=True
        ))

    if os.getenv("AZURE_OPENAI_EMBEDDING_ENDPOINT_2"):
        store.put_config(AzureOpenAIConfig(
            config_id="embedding-eu-west-1",
            config_type="embedding",
            endpoint=os.getenv("AZURE_OPENAI_EMBEDDING_ENDPOINT_2"),
            api_key=os.getenv("AZURE_OPENAI_EMBEDDING_KEY_2"),
            deployment=os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT_2", "text-embedding-3-small"),
            region="eu-west-1",
            priority=2,
            enabled=True
        ))

    logger.info("Seeded DynamoDB with configurations from environment variables")
