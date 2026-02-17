"""
Azure OpenAI Client with Multi-Subscription Failover
Supports loading configs from: Environment Variables, DynamoDB, or AWS SSM
"""
import os
import time
import logging
from typing import Optional, Tuple, List, Dict, Any
from dataclasses import dataclass
from openai import AzureOpenAI

logger = logging.getLogger(__name__)


@dataclass
class AzureConfig:
    """Configuration for an Azure OpenAI endpoint"""
    endpoint: str
    api_key: str
    deployment: str
    embedding_deployment: str
    name: str


class AzureOpenAIFailover:
    """
    Azure OpenAI client with automatic failover between multiple subscriptions.

    Features:
    - Automatic failover on errors (429, 500, timeout)
    - Health tracking for each endpoint
    - Recovery after cooldown period
    - Manual failover trigger for demos
    - Separate embedding endpoint support
    - DynamoDB config storage support
    - AWS SSM Parameter Store support
    """

    def __init__(self, use_dynamodb: bool = None, use_ssm: bool = None):
        # Check config source: SSM > DynamoDB > Environment
        self.use_ssm = use_ssm if use_ssm is not None else os.getenv("USE_SSM_CONFIG", "false").lower() == "true"
        self.use_dynamodb = use_dynamodb if use_dynamodb is not None else os.getenv("USE_DYNAMODB_CONFIG", "false").lower() == "true"

        if self.use_ssm:
            self._init_from_ssm()
        elif self.use_dynamodb:
            self._init_from_dynamodb()
        else:
            self._init_from_env()

        self.current_index = 0
        self.health_status: Dict[int, bool] = {i: True for i in range(len(self.configs))}
        self.last_failure_time: Dict[int, float] = {}
        self.recovery_time = 60  # seconds before retrying failed endpoint

        logger.info(f"Initialized Azure OpenAI Failover with {len(self.configs)} chat endpoints and {len(self.embedding_clients)} embedding endpoints")

    def _init_from_ssm(self):
        """Initialize configurations from AWS SSM Parameter Store"""
        from .ssm_config import SSMConfigLoader

        loader = SSMConfigLoader()

        # Load chat configs
        chat_configs = loader.load_chat_configs()
        self.configs = []
        self.clients = []

        for config in chat_configs:
            azure_config = AzureConfig(
                endpoint=config.endpoint,
                api_key=config.api_key,
                deployment=config.deployment,
                embedding_deployment="",
                name=f"Chat ({config.region})"
            )
            self.configs.append(azure_config)
            self.clients.append(self._create_client(azure_config))

        # Load embedding configs
        embedding_configs = loader.load_embedding_configs()
        self.embedding_clients = []

        for config in embedding_configs:
            client = AzureOpenAI(
                azure_endpoint=config.endpoint,
                api_key=config.api_key,
                api_version="2024-02-01"
            )
            self.embedding_clients.append({
                'client': client,
                'deployment': config.deployment,
                'name': f"Embedding ({config.region})"
            })

        logger.info(f"Loaded configs from SSM: {len(self.configs)} chat, {len(self.embedding_clients)} embedding")

    def _init_from_dynamodb(self):
        """Initialize configurations from DynamoDB"""
        from .dynamodb_config import DynamoDBConfigStore

        store = DynamoDBConfigStore()

        # Load chat configs
        chat_configs = store.get_chat_configs()
        self.configs = []
        self.clients = []

        for config in chat_configs:
            azure_config = AzureConfig(
                endpoint=config.endpoint,
                api_key=config.api_key,
                deployment=config.deployment,
                embedding_deployment="",  # Not used for chat
                name=f"Chat ({config.region})"
            )
            self.configs.append(azure_config)
            self.clients.append(self._create_client(azure_config))

        # Load embedding configs
        embedding_configs = store.get_embedding_configs()
        self.embedding_clients = []

        for config in embedding_configs:
            client = AzureOpenAI(
                azure_endpoint=config.endpoint,
                api_key=config.api_key,
                api_version="2024-02-01"
            )
            self.embedding_clients.append((client, config.deployment, f"Embedding ({config.region})"))

        self.embedding_deployment_1 = embedding_configs[0].deployment if embedding_configs else "text-embedding-3-small"
        self.embedding_deployment_2 = embedding_configs[1].deployment if len(embedding_configs) > 1 else self.embedding_deployment_1

        if not self.configs:
            raise ValueError("No Azure OpenAI chat endpoints configured in DynamoDB.")

        logger.info(f"Loaded {len(self.configs)} chat configs and {len(self.embedding_clients)} embedding configs from DynamoDB")

    def _init_from_env(self):
        """Initialize configurations from environment variables"""
        self.configs = self._load_configs()
        self.clients = [self._create_client(c) for c in self.configs]

        # Separate embedding clients (with failover support)
        self.embedding_clients = self._create_embedding_clients()
        self.embedding_deployment_1 = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT_1", "text-embedding-3-small")
        self.embedding_deployment_2 = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT_2", "text-embedding-3-small")

    def _create_embedding_clients(self) -> List[Tuple[AzureOpenAI, str, str]]:
        """Create embedding clients with failover support"""
        clients = []

        # Primary embedding endpoint
        endpoint_1 = os.getenv("AZURE_OPENAI_EMBEDDING_ENDPOINT_1")
        key_1 = os.getenv("AZURE_OPENAI_EMBEDDING_KEY_1")
        deployment_1 = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT_1", "text-embedding-3-small")

        if endpoint_1 and key_1:
            client = AzureOpenAI(
                azure_endpoint=endpoint_1,
                api_key=key_1,
                api_version="2024-02-01"
            )
            clients.append((client, deployment_1, "Embedding (US East)"))
            logger.info("Configured embedding endpoint: US East")

        # Failover embedding endpoint
        endpoint_2 = os.getenv("AZURE_OPENAI_EMBEDDING_ENDPOINT_2")
        key_2 = os.getenv("AZURE_OPENAI_EMBEDDING_KEY_2")
        deployment_2 = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT_2", "text-embedding-3-small")

        if endpoint_2 and key_2:
            client = AzureOpenAI(
                azure_endpoint=endpoint_2,
                api_key=key_2,
                api_version="2024-02-01"
            )
            clients.append((client, deployment_2, "Embedding (EU West)"))
            logger.info("Configured embedding endpoint: EU West")

        return clients

    def _load_configs(self) -> List[AzureConfig]:
        """Load Azure configurations from environment variables"""
        configs = []

        # Primary endpoint
        if os.getenv("AZURE_OPENAI_ENDPOINT_1"):
            configs.append(AzureConfig(
                endpoint=os.getenv("AZURE_OPENAI_ENDPOINT_1", ""),
                api_key=os.getenv("AZURE_OPENAI_KEY_1", ""),
                deployment=os.getenv("AZURE_OPENAI_DEPLOYMENT_1", "gpt-4"),
                embedding_deployment=os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-ada-002"),
                name="Primary (Subscription 1)"
            ))

        # Secondary endpoint
        if os.getenv("AZURE_OPENAI_ENDPOINT_2"):
            configs.append(AzureConfig(
                endpoint=os.getenv("AZURE_OPENAI_ENDPOINT_2", ""),
                api_key=os.getenv("AZURE_OPENAI_KEY_2", ""),
                deployment=os.getenv("AZURE_OPENAI_DEPLOYMENT_2", "gpt-4"),
                embedding_deployment=os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT", "text-embedding-ada-002"),
                name="Secondary (Subscription 2)"
            ))

        if not configs:
            raise ValueError("No Azure OpenAI endpoints configured. Set AZURE_OPENAI_ENDPOINT_1 environment variable.")

        return configs

    def _create_client(self, config: AzureConfig) -> AzureOpenAI:
        """Create an Azure OpenAI client from config"""
        return AzureOpenAI(
            azure_endpoint=config.endpoint,
            api_key=config.api_key,
            api_version="2024-02-01"
        )

    def _should_retry_endpoint(self, index: int) -> bool:
        """Check if enough time has passed to retry a failed endpoint"""
        if index not in self.last_failure_time:
            return True
        return time.time() - self.last_failure_time[index] > self.recovery_time

    def _mark_unhealthy(self, index: int):
        """Mark an endpoint as unhealthy"""
        self.health_status[index] = False
        self.last_failure_time[index] = time.time()
        logger.warning(f"Marked {self.configs[index].name} as unhealthy")

    def _mark_healthy(self, index: int):
        """Mark an endpoint as healthy"""
        self.health_status[index] = True
        if index in self.last_failure_time:
            del self.last_failure_time[index]
        logger.info(f"Marked {self.configs[index].name} as healthy")

    def get_current_provider(self) -> str:
        """Get the name of the current active provider"""
        return self.configs[self.current_index].name

    def get_status(self) -> Dict[str, Any]:
        """Get detailed status of all endpoints"""
        return {
            "current_provider": self.get_current_provider(),
            "current_index": self.current_index,
            "endpoints": [
                {
                    "name": config.name,
                    "healthy": self.health_status[i],
                    "is_current": i == self.current_index,
                    "last_failure": self.last_failure_time.get(i)
                }
                for i, config in enumerate(self.configs)
            ]
        }

    def chat_completion(
        self,
        messages: List[Dict[str, str]],
        **kwargs
    ) -> Tuple[str, str]:
        """
        Execute a chat completion with automatic failover.

        Args:
            messages: List of message dictionaries
            **kwargs: Additional arguments for the API call

        Returns:
            Tuple of (response_text, provider_name)
        """
        errors = []

        for attempt in range(len(self.configs)):
            index = (self.current_index + attempt) % len(self.configs)

            # Skip unhealthy endpoints unless recovery time has passed
            if not self.health_status[index] and not self._should_retry_endpoint(index):
                logger.debug(f"Skipping unhealthy endpoint: {self.configs[index].name}")
                continue

            config = self.configs[index]
            client = self.clients[index]

            try:
                logger.info(f"Attempting chat completion with {config.name}")

                response = client.chat.completions.create(
                    model=config.deployment,
                    messages=messages,
                    timeout=30,
                    **kwargs
                )

                # Success - mark healthy and update current
                self._mark_healthy(index)
                self.current_index = index

                content = response.choices[0].message.content or ""
                return content, config.name

            except Exception as e:
                error_msg = str(e)
                logger.error(f"Error with {config.name}: {error_msg}")
                errors.append(f"{config.name}: {error_msg}")
                self._mark_unhealthy(index)
                continue

        raise Exception(f"All Azure OpenAI endpoints failed: {'; '.join(errors)}")

    def generate_embeddings(self, texts: List[str]) -> Tuple[List[List[float]], str]:
        """
        Generate embeddings with failover between embedding endpoints.

        Args:
            texts: List of texts to embed

        Returns:
            Tuple of (embeddings_list, provider_name)
        """
        errors = []

        # Try dedicated embedding endpoints first
        for client, deployment, name in self.embedding_clients:
            try:
                logger.info(f"Generating embeddings with {name}")
                response = client.embeddings.create(
                    input=texts,
                    model=deployment,
                    timeout=30
                )
                embeddings = [item.embedding for item in response.data]
                return embeddings, name
            except Exception as e:
                logger.error(f"Embedding error with {name}: {e}")
                errors.append(f"{name}: {e}")
                continue

        # Fallback to chat endpoints for embeddings if no dedicated endpoints
        if not self.embedding_clients:
            for attempt in range(len(self.configs)):
                index = (self.current_index + attempt) % len(self.configs)

                if not self.health_status[index] and not self._should_retry_endpoint(index):
                    continue

                config = self.configs[index]
                client = self.clients[index]

                try:
                    logger.info(f"Generating embeddings with {config.name}")

                    response = client.embeddings.create(
                        input=texts,
                        model=self.embedding_deployment_1,
                        timeout=30
                    )

                    self._mark_healthy(index)
                    embeddings = [item.embedding for item in response.data]
                    return embeddings, config.name

                except Exception as e:
                    error_msg = str(e)
                    logger.error(f"Embedding error with {config.name}: {error_msg}")
                    errors.append(f"{config.name}: {error_msg}")
                    self._mark_unhealthy(index)
                    continue

        raise Exception(f"All embedding endpoints failed: {'; '.join(errors)}")

    def trigger_failover(self) -> Dict[str, str]:
        """
        Manually trigger a failover (for demo purposes).

        Returns:
            Dictionary with old and new provider names
        """
        old_provider = self.get_current_provider()
        old_index = self.current_index

        # Mark current as unhealthy
        self._mark_unhealthy(old_index)

        # Move to next available endpoint
        for i in range(1, len(self.configs)):
            next_index = (old_index + i) % len(self.configs)
            if self.health_status.get(next_index, True) or self._should_retry_endpoint(next_index):
                self.current_index = next_index
                break

        new_provider = self.get_current_provider()

        logger.warning(f"Manual failover triggered: {old_provider} -> {new_provider}")

        return {
            "message": "Failover triggered",
            "from": old_provider,
            "to": new_provider
        }

    def health_check(self) -> Dict[str, Any]:
        """
        Perform health check on all endpoints.

        Returns:
            Dictionary with health status of each endpoint
        """
        results = {}

        for i, config in enumerate(self.configs):
            try:
                self.clients[i].chat.completions.create(
                    model=config.deployment,
                    messages=[{"role": "user", "content": "test"}],
                    max_tokens=5,
                    timeout=10
                )
                results[config.name] = {
                    "status": "healthy",
                    "is_current": i == self.current_index
                }
                self._mark_healthy(i)

            except Exception as e:
                results[config.name] = {
                    "status": "unhealthy",
                    "error": str(e),
                    "is_current": i == self.current_index
                }
                self._mark_unhealthy(i)

        return results


# Singleton instance
_failover_client: Optional[AzureOpenAIFailover] = None


def get_azure_client() -> AzureOpenAIFailover:
    """Get or create the singleton Azure OpenAI client"""
    global _failover_client
    if _failover_client is None:
        _failover_client = AzureOpenAIFailover()
    return _failover_client
