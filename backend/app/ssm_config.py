"""
AWS SSM Parameter Store Configuration Loader
Loads Azure OpenAI keys and configs from SSM Parameter Store
"""
import os
import logging
from typing import Dict, Optional, List
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class AzureOpenAIConfig:
    """Azure OpenAI configuration from SSM"""
    name: str
    endpoint: str
    api_key: str
    deployment: str
    region: str
    config_type: str  # 'chat' or 'embedding'
    priority: int


class SSMConfigLoader:
    """Load Azure OpenAI configurations from AWS SSM Parameter Store"""

    def __init__(self, app_name: str = "rag-demo", aws_region: str = None):
        self.app_name = app_name
        self.aws_region = aws_region or os.environ.get("AWS_REGION", "us-east-1")
        self._ssm_client = None

    @property
    def ssm_client(self):
        """Lazy load SSM client"""
        if self._ssm_client is None:
            import boto3
            self._ssm_client = boto3.client('ssm', region_name=self.aws_region)
        return self._ssm_client

    def get_parameter(self, name: str, decrypt: bool = True) -> Optional[str]:
        """Get a single parameter from SSM"""
        try:
            response = self.ssm_client.get_parameter(
                Name=name,
                WithDecryption=decrypt
            )
            return response['Parameter']['Value']
        except Exception as e:
            logger.error(f"Error getting SSM parameter {name}: {e}")
            return None

    def get_parameters_by_path(self, path: str, decrypt: bool = True) -> Dict[str, str]:
        """Get all parameters under a path"""
        try:
            params = {}
            paginator = self.ssm_client.get_paginator('get_parameters_by_path')

            for page in paginator.paginate(
                Path=path,
                Recursive=True,
                WithDecryption=decrypt
            ):
                for param in page['Parameters']:
                    # Extract the key name from the full path
                    key = param['Name'].replace(path, '').strip('/')
                    params[key] = param['Value']

            return params
        except Exception as e:
            logger.error(f"Error getting SSM parameters by path {path}: {e}")
            return {}

    def load_chat_configs(self) -> List[AzureOpenAIConfig]:
        """Load all chat model configurations from SSM"""
        configs = []

        # Load US East config (priority 1)
        us_east_params = self.get_parameters_by_path(f"/{self.app_name}/azure-openai/us-east")
        if us_east_params.get('endpoint') and us_east_params.get('api-key'):
            configs.append(AzureOpenAIConfig(
                name="azure-us-east",
                endpoint=us_east_params.get('endpoint', ''),
                api_key=us_east_params.get('api-key', ''),
                deployment=us_east_params.get('deployment', 'gpt-4o-mini'),
                region="us-east",
                config_type="chat",
                priority=1
            ))

        # Load EU West config (priority 2 - failover)
        eu_west_params = self.get_parameters_by_path(f"/{self.app_name}/azure-openai/eu-west")
        if eu_west_params.get('endpoint') and eu_west_params.get('api-key'):
            configs.append(AzureOpenAIConfig(
                name="azure-eu-west",
                endpoint=eu_west_params.get('endpoint', ''),
                api_key=eu_west_params.get('api-key', ''),
                deployment=eu_west_params.get('deployment', 'gpt-4o-mini'),
                region="eu-west",
                config_type="chat",
                priority=2
            ))

        logger.info(f"Loaded {len(configs)} chat configs from SSM")
        return configs

    def load_embedding_configs(self) -> List[AzureOpenAIConfig]:
        """Load all embedding model configurations from SSM"""
        configs = []

        # Load US East embedding config
        us_east_params = self.get_parameters_by_path(f"/{self.app_name}/azure-openai/us-east")
        if us_east_params.get('embedding-endpoint') and us_east_params.get('embedding-key'):
            configs.append(AzureOpenAIConfig(
                name="azure-embedding-us-east",
                endpoint=us_east_params.get('embedding-endpoint', ''),
                api_key=us_east_params.get('embedding-key', ''),
                deployment=us_east_params.get('embedding-deployment', 'text-embedding-3-small'),
                region="us-east",
                config_type="embedding",
                priority=1
            ))

        # Load EU West embedding config (failover)
        eu_west_params = self.get_parameters_by_path(f"/{self.app_name}/azure-openai/eu-west")
        if eu_west_params.get('embedding-endpoint') and eu_west_params.get('embedding-key'):
            configs.append(AzureOpenAIConfig(
                name="azure-embedding-eu-west",
                endpoint=eu_west_params.get('embedding-endpoint', ''),
                api_key=eu_west_params.get('embedding-key', ''),
                deployment=eu_west_params.get('embedding-deployment', 'text-embedding-3-small'),
                region="eu-west",
                config_type="embedding",
                priority=2
            ))

        logger.info(f"Loaded {len(configs)} embedding configs from SSM")
        return configs

    def load_all_configs(self) -> Dict[str, List[AzureOpenAIConfig]]:
        """Load all configurations"""
        return {
            'chat': self.load_chat_configs(),
            'embedding': self.load_embedding_configs()
        }


def get_ssm_config_loader() -> SSMConfigLoader:
    """Factory function to get SSM config loader"""
    app_name = os.environ.get('APP_NAME', 'rag-demo')
    aws_region = os.environ.get('AWS_REGION', 'us-east-1')
    return SSMConfigLoader(app_name=app_name, aws_region=aws_region)


# Convenience functions
def load_azure_configs_from_ssm() -> Dict[str, List[AzureOpenAIConfig]]:
    """Load all Azure OpenAI configs from SSM"""
    loader = get_ssm_config_loader()
    return loader.load_all_configs()
