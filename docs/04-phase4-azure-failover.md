# Phase 4: Azure OpenAI Failover Implementation

## 🎯 Goal
Implement multi-subscription Azure OpenAI with automatic failover for high availability.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Failover Manager                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌──────────────┐         ┌──────────────┐                 │
│   │  Primary      │  FAIL   │  Secondary   │                │
│   │  Azure OpenAI │ ──────▶ │  Azure OpenAI│                │
│   │  (East US)    │         │  (West US)   │                │
│   └──────────────┘         └──────────────┘                 │
│         │                         │                          │
│         ▼                         ▼                          │
│   Subscription 1            Subscription 2                   │
│   (Primary)                 (Backup)                         │
└─────────────────────────────────────────────────────────────┘
```

## Failover Triggers

1. **HTTP 429** - Rate limit exceeded
2. **HTTP 500-503** - Service unavailable
3. **Timeout** - Request takes > 30 seconds
4. **Connection Error** - Network issues

## Implementation

```python
# backend/app/azure_openai.py
import os
import time
from typing import Optional
from openai import AzureOpenAI
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)

@dataclass
class AzureConfig:
    endpoint: str
    api_key: str
    deployment: str
    name: str

class AzureOpenAIFailover:
    def __init__(self):
        self.configs = [
            AzureConfig(
                endpoint=os.getenv("AZURE_OPENAI_ENDPOINT_1"),
                api_key=os.getenv("AZURE_OPENAI_KEY_1"),
                deployment=os.getenv("AZURE_OPENAI_DEPLOYMENT_1", "gpt-4"),
                name="Primary (East US)"
            ),
            AzureConfig(
                endpoint=os.getenv("AZURE_OPENAI_ENDPOINT_2"),
                api_key=os.getenv("AZURE_OPENAI_KEY_2"),
                deployment=os.getenv("AZURE_OPENAI_DEPLOYMENT_2", "gpt-4"),
                name="Secondary (West US)"
            )
        ]
        
        self.clients = [self._create_client(c) for c in self.configs]
        self.current_index = 0
        self.health_status = {i: True for i in range(len(self.configs))}
        self.last_failure_time = {}
        self.recovery_time = 60  # seconds before retry failed endpoint
    
    def _create_client(self, config: AzureConfig) -> AzureOpenAI:
        return AzureOpenAI(
            azure_endpoint=config.endpoint,
            api_key=config.api_key,
            api_version="2024-02-01"
        )
    
    def _should_retry_endpoint(self, index: int) -> bool:
        if index not in self.last_failure_time:
            return True
        return time.time() - self.last_failure_time[index] > self.recovery_time
    
    def _mark_unhealthy(self, index: int):
        self.health_status[index] = False
        self.last_failure_time[index] = time.time()
        logger.warning(f"Marked {self.configs[index].name} as unhealthy")
    
    def _mark_healthy(self, index: int):
        self.health_status[index] = True
        if index in self.last_failure_time:
            del self.last_failure_time[index]
    
    def get_current_provider(self) -> str:
        return self.configs[self.current_index].name
    
    def chat_completion(self, messages: list, **kwargs) -> tuple[str, str]:
        """
        Returns: (response_text, provider_name)
        """
        errors = []
        
        for attempt in range(len(self.configs)):
            index = (self.current_index + attempt) % len(self.configs)
            
            # Skip if unhealthy and not ready for retry
            if not self.health_status[index] and not self._should_retry_endpoint(index):
                continue
            
            config = self.configs[index]
            client = self.clients[index]
            
            try:
                logger.info(f"Attempting request with {config.name}")
                
                response = client.chat.completions.create(
                    model=config.deployment,
                    messages=messages,
                    timeout=30,
                    **kwargs
                )
                
                # Success - mark healthy and update current
                self._mark_healthy(index)
                self.current_index = index
                
                return response.choices[0].message.content, config.name
                
            except Exception as e:
                error_msg = str(e)
                logger.error(f"Error with {config.name}: {error_msg}")
                errors.append(f"{config.name}: {error_msg}")
                self._mark_unhealthy(index)
                continue
        
        raise Exception(f"All Azure OpenAI endpoints failed: {errors}")
    
    def health_check(self) -> dict:
        """Check health of all endpoints"""
        results = {}
        for i, config in enumerate(self.configs):
            try:
                response = self.clients[i].chat.completions.create(
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
    global _failover_client
    if _failover_client is None:
        _failover_client = AzureOpenAIFailover()
    return _failover_client
```

## Demo Failover Trigger

For demo purposes, add a manual failover trigger:

```python
# backend/app/main.py
from fastapi import APIRouter
from .azure_openai import get_azure_client

router = APIRouter()

@router.post("/demo/trigger-failover")
async def trigger_failover():
    """Manually trigger failover for demo purposes"""
    client = get_azure_client()
    old_provider = client.get_current_provider()
    
    # Mark current as unhealthy
    client._mark_unhealthy(client.current_index)
    
    # Move to next
    client.current_index = (client.current_index + 1) % len(client.configs)
    new_provider = client.get_current_provider()
    
    return {
        "message": "Failover triggered",
        "from": old_provider,
        "to": new_provider
    }

@router.get("/demo/health-status")
async def get_health_status():
    """Get health status of all Azure OpenAI endpoints"""
    client = get_azure_client()
    return {
        "current_provider": client.get_current_provider(),
        "health": client.health_check()
    }
```

## UI Integration

Show failover status in Electron UI:
- 🟢 Green indicator for healthy primary
- 🟡 Yellow indicator when using failover
- 🔴 Red indicator when all endpoints down

## ✅ Phase 4 Checklist

- [ ] Two Azure OpenAI subscriptions configured
- [ ] Failover logic implemented
- [ ] Manual failover trigger for demo
- [ ] Health check endpoint working
- [ ] UI shows current provider status
- [ ] Tested failover scenario
