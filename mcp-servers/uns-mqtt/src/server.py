"""
UNS MQTT MCP Server
====================
Geeft Claude toegang tot de MQTT broker (HiveMQ) van de UNS stack.

Tools:
  - mqtt_publish     Publiceer een bericht naar een topic
  - mqtt_subscribe   Abonneer en ontvang de laatste N berichten
  - mqtt_list_topics Toon actieve topics op de broker

Achtergrond:
  - Heartbeat task publisht elke 10s agent-status naar
    umh/v1/smc/agents/{AGENT_NAME}/_status
  - Scope guard beperkt mqtt_publish tot AGENT_PUBLISH_PREFIX (tenzij
    AGENT_PUBLISH_ALLOW_PRODUCTION=true).
"""

import asyncio
import json
import logging
import os
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone

import aiomqtt
from mcp.server.fastmcp import FastMCP

logger = logging.getLogger("uns-mqtt")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
MQTT_HOST = os.environ.get("UNS_MQTT_HOST", "localhost")
MQTT_PORT = int(os.environ.get("UNS_MQTT_PORT", "1883"))

AGENT_NAME = os.environ.get("AGENT_NAME", "luke-agent")
AGENT_VERSION = "0.1.0"
HEARTBEAT_INTERVAL_S = 10
HEARTBEAT_TOPIC = f"umh/v1/smc/agents/{AGENT_NAME}/_status"

# Scope guard config
AGENT_PUBLISH_PREFIX = os.environ.get(
    "AGENT_PUBLISH_PREFIX", f"umh/v1/smc/agents/{AGENT_NAME}/"
)
AGENT_PUBLISH_ALLOW_PRODUCTION = (
    os.environ.get("AGENT_PUBLISH_ALLOW_PRODUCTION", "false").lower() == "true"
)
PRODUCTION_PREFIX = "umh/v1/smc/"


# ---------------------------------------------------------------------------
# Agent state
# ---------------------------------------------------------------------------
class AgentState:
    """Tracks current agent state for heartbeat publishing."""

    def __init__(self):
        self.state: str = "idle"
        self.started_at: float = time.time()
        self._active_count: int = 0
        self._lock = asyncio.Lock()

    def uptime_s(self) -> int:
        return int(time.time() - self.started_at)

    async def enter_processing(self):
        async with self._lock:
            self._active_count += 1
            self.state = "processing"

    async def exit_processing(self):
        async with self._lock:
            self._active_count = max(0, self._active_count - 1)
            if self._active_count == 0:
                self.state = "idle"


agent_state = AgentState()


@asynccontextmanager
async def processing():
    """Async context manager: marks agent as 'processing' for the duration."""
    await agent_state.enter_processing()
    try:
        yield
    finally:
        await agent_state.exit_processing()


# ---------------------------------------------------------------------------
# Internal publish (bypasses scope guard) — used by heartbeat
# ---------------------------------------------------------------------------
async def _publish_internal(
    topic: str, payload: str, retain: bool = False
) -> None:
    """Publish to MQTT without going through the scope guard.

    Used by heartbeat and other internal agent-status publishes.
    """
    async with aiomqtt.Client(MQTT_HOST, MQTT_PORT) as client:
        await client.publish(topic, payload.encode("utf-8"), retain=retain)


def _build_status_payload(state: str) -> str:
    return json.dumps({
        "agent": AGENT_NAME,
        "state": state,
        "ts": datetime.now(timezone.utc).isoformat(),
        "uptime_s": agent_state.uptime_s(),
        "version": AGENT_VERSION,
    })


# ---------------------------------------------------------------------------
# Heartbeat task
# ---------------------------------------------------------------------------
async def _heartbeat_loop():
    """Publish agent status every HEARTBEAT_INTERVAL_S seconds."""
    retry_delay = 2
    while True:
        try:
            payload = _build_status_payload(agent_state.state)
            await _publish_internal(HEARTBEAT_TOPIC, payload, retain=False)
            logger.debug(
                "heartbeat published: topic=%s state=%s uptime=%ss",
                HEARTBEAT_TOPIC,
                agent_state.state,
                agent_state.uptime_s(),
            )
            retry_delay = 2
            await asyncio.sleep(HEARTBEAT_INTERVAL_S)
        except aiomqtt.MqttError as e:
            logger.debug("heartbeat MQTT error: %s — retry in %ss", e, retry_delay)
            await asyncio.sleep(retry_delay)
            retry_delay = min(retry_delay * 2, 30)
        except asyncio.CancelledError:
            return
        except Exception as e:  # pragma: no cover — defensive
            logger.debug("heartbeat unexpected error: %s", e)
            await asyncio.sleep(retry_delay)


# ---------------------------------------------------------------------------
# Topic cache — collects topics seen via wildcard subscription
# ---------------------------------------------------------------------------
class TopicCache:
    """Maintains a set of recently seen MQTT topics with their last message."""

    def __init__(self):
        self.topics: dict[str, dict] = {}
        self._listener_task: asyncio.Task | None = None

    async def start(self):
        """Start background listener that subscribes to # (all topics)."""
        self._listener_task = asyncio.create_task(self._listen())

    async def stop(self):
        if self._listener_task:
            self._listener_task.cancel()
            try:
                await self._listener_task
            except asyncio.CancelledError:
                pass

    async def _listen(self):
        """Subscribe to all topics and cache what we see."""
        retry_delay = 2
        while True:
            try:
                async with aiomqtt.Client(MQTT_HOST, MQTT_PORT) as client:
                    await client.subscribe("#")
                    async for message in client.messages:
                        topic = str(message.topic)
                        try:
                            payload = message.payload.decode("utf-8")
                        except (UnicodeDecodeError, AttributeError):
                            payload = str(message.payload)
                        self.topics[topic] = {
                            "topic": topic,
                            "payload": payload,
                            "timestamp": time.time(),
                        }
                        # Keep cache manageable
                        if len(self.topics) > 5000:
                            oldest = sorted(
                                self.topics, key=lambda t: self.topics[t]["timestamp"]
                            )
                            for old_topic in oldest[:1000]:
                                del self.topics[old_topic]
                retry_delay = 2  # Reset on successful connection
            except aiomqtt.MqttError:
                await asyncio.sleep(retry_delay)
                retry_delay = min(retry_delay * 2, 30)
            except asyncio.CancelledError:
                return


# ---------------------------------------------------------------------------
# Lifespan
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(server: FastMCP):
    """Start topic cache + heartbeat on startup, publish offline on shutdown."""
    cache = TopicCache()
    await cache.start()
    heartbeat_task = asyncio.create_task(_heartbeat_loop())
    logger.debug(
        "uns-mqtt started — agent=%s prefix=%s allow_production=%s",
        AGENT_NAME,
        AGENT_PUBLISH_PREFIX,
        AGENT_PUBLISH_ALLOW_PRODUCTION,
    )
    try:
        yield {"cache": cache}
    finally:
        heartbeat_task.cancel()
        try:
            await heartbeat_task
        except asyncio.CancelledError:
            pass
        # Final offline status, retained so subscribers see it on reconnect
        try:
            offline_payload = _build_status_payload("offline")
            await _publish_internal(HEARTBEAT_TOPIC, offline_payload, retain=True)
            logger.debug("offline status published (retained)")
        except Exception as e:  # pragma: no cover — defensive
            logger.debug("could not publish offline status: %s", e)
        await cache.stop()


mcp = FastMCP(
    name="uns-mqtt",
    instructions=(
        "Je bent verbonden met de MQTT broker (HiveMQ) van een metaalbewerkingsbedrijf. "
        "De broker is onderdeel van een Unified Namespace (UNS) architectuur. "
        "Topics volgen de structuur: umh/v1/{enterprise}/{site}/... "
        "Je kunt berichten publiceren, topics uitlezen, en zien welke topics actief zijn. "
        f"Je publishes zijn beperkt tot prefix '{AGENT_PUBLISH_PREFIX}' "
        "(tenzij AGENT_PUBLISH_ALLOW_PRODUCTION=true). Subscriben/listen mag op alles."
    ),
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# Scope guard
# ---------------------------------------------------------------------------
def _check_publish_scope(topic: str) -> str | None:
    """Returns None if topic is allowed, or an error string if denied."""
    if AGENT_PUBLISH_ALLOW_PRODUCTION:
        if topic.startswith(PRODUCTION_PREFIX):
            return None
        return (
            f"PUBLISH_DENIED: topic '{topic}' outside production scope "
            f"'{PRODUCTION_PREFIX}'. Allowed: {PRODUCTION_PREFIX}#"
        )
    if topic.startswith(AGENT_PUBLISH_PREFIX):
        return None
    return (
        f"PUBLISH_DENIED: topic '{topic}' outside agent scope "
        f"'{AGENT_PUBLISH_PREFIX}'. Allowed: {AGENT_PUBLISH_PREFIX}#"
    )


# ===========================================================================
# Tools
# ===========================================================================

@mcp.tool()
async def mqtt_publish(topic: str, payload: str) -> str:
    """Publish a message to an MQTT topic.

    Use this to send commands, trigger work order updates, or inject test data.
    Payload should be a valid JSON string for UNS compatibility.

    Args:
        topic: The MQTT topic to publish to (e.g. 'umh/v1/smc/agents/luke-agent/notes/test').
        payload: The message payload, preferably valid JSON.

    NOTE: Publishes are restricted to AGENT_PUBLISH_PREFIX by default.
    """
    async with processing():
        denied = _check_publish_scope(topic)
        if denied:
            return denied
        try:
            async with aiomqtt.Client(MQTT_HOST, MQTT_PORT) as client:
                await client.publish(topic, payload.encode("utf-8"))
            return f"Bericht gepubliceerd naar {topic}"
        except aiomqtt.MqttError as e:
            return f"MQTT publish error: {e}"
        except Exception as e:
            return f"Error: {e}"


@mcp.tool()
async def mqtt_subscribe(
    topic: str,
    timeout_seconds: int = 5,
    max_messages: int = 10,
) -> str:
    """Subscribe to an MQTT topic and collect messages for a given duration.

    Args:
        topic: The MQTT topic to subscribe to. Supports wildcards: + (single level), # (multi level).
        timeout_seconds: How long to listen for messages (default: 5, max: 30).
        max_messages: Maximum number of messages to collect (default: 10, max: 50).
    """
    async with processing():
        timeout_seconds = min(timeout_seconds, 30)
        max_messages = min(max_messages, 50)
        messages = []

        try:
            async with aiomqtt.Client(MQTT_HOST, MQTT_PORT) as client:
                await client.subscribe(topic)

                try:
                    async with asyncio.timeout(timeout_seconds):
                        async for message in client.messages:
                            try:
                                payload = message.payload.decode("utf-8")
                            except (UnicodeDecodeError, AttributeError):
                                payload = str(message.payload)

                            messages.append({
                                "topic": str(message.topic),
                                "payload": payload,
                            })

                            if len(messages) >= max_messages:
                                break
                except TimeoutError:
                    pass  # Normal — timeout reached

        except aiomqtt.MqttError as e:
            return f"MQTT subscribe error: {e}"

        if not messages:
            return f"Geen berichten ontvangen op '{topic}' binnen {timeout_seconds} seconden."

        return json.dumps(messages, indent=2, ensure_ascii=False)


@mcp.tool()
async def mqtt_list_topics(
    filter_prefix: str | None = None,
) -> str:
    """List active MQTT topics seen on the broker.

    The server maintains a background subscription to all topics (#).
    This tool returns the topics that have been seen since the server started.

    Args:
        filter_prefix: Only show topics starting with this prefix (e.g. 'umh/v1/smc').
    """
    async with processing():
        cache: TopicCache = mcp.get_context().lifespan_context["cache"]

        topics = cache.topics

        if filter_prefix:
            topics = {
                t: v for t, v in topics.items() if t.startswith(filter_prefix)
            }

        if not topics:
            if filter_prefix:
                return f"Geen topics gevonden met prefix '{filter_prefix}'. Er zijn {len(cache.topics)} topics in totaal."
            return (
                "Nog geen topics gezien. De broker is mogelijk leeg, "
                "of de achtergrond-listener is net gestart. Wacht even en probeer opnieuw."
            )

        # Sort by most recent
        sorted_topics = sorted(
            topics.values(), key=lambda t: t["timestamp"], reverse=True
        )

        result = []
        for entry in sorted_topics[:100]:
            # Truncate long payloads
            payload_preview = entry["payload"][:200]
            if len(entry["payload"]) > 200:
                payload_preview += "..."
            result.append({
                "topic": entry["topic"],
                "last_payload": payload_preview,
                "seconds_ago": round(time.time() - entry["timestamp"], 1),
            })

        output = json.dumps(result, indent=2, ensure_ascii=False)
        if len(sorted_topics) > 100:
            output += f"\n\n... en nog {len(sorted_topics) - 100} topics (niet getoond)"
        return output


# ===========================================================================
# Resources
# ===========================================================================

@mcp.resource("uns://broker-info")
def broker_info() -> str:
    """Connection details for the MQTT broker."""
    return json.dumps({
        "host": MQTT_HOST,
        "port": MQTT_PORT,
        "protocol": "MQTT 5.0 (HiveMQ CE)",
        "authentication": "Geen (HIVEMQ_ALLOW_ALL_CLIENTS=true)",
        "topic_structure": "umh/v1/{enterprise}/{site}/{area}/{line}/{workcell}/...",
        "agent": {
            "name": AGENT_NAME,
            "heartbeat_topic": HEARTBEAT_TOPIC,
            "publish_prefix": AGENT_PUBLISH_PREFIX,
            "allow_production": AGENT_PUBLISH_ALLOW_PRODUCTION,
        },
        "examples": {
            "sensor_data": "umh/v1/smc/vienna/cnc-1/temperature",
            "work_order": "umh/v1/smc/vienna/_operator/work-order/WO-001",
            "erp_event": "umh/v1/smc/vienna/_historian/erp-work-order",
        },
    }, indent=2)


# ===========================================================================
# Prompts
# ===========================================================================

@mcp.prompt()
def explore_uns() -> str:
    """Verken de Unified Namespace — welke topics zijn er actief?"""
    return (
        "Verken de Unified Namespace op de MQTT broker.\n"
        "1. Lijst alle actieve topics op met mqtt_list_topics\n"
        "2. Groepeer ze per enterprise/site/area\n"
        "3. Lees de broker-info resource\n"
        "4. Kies de 3 meest interessante topics en lees hun laatste berichten\n"
        "5. Geef een samenvatting van wat er op de UNS gebeurt."
    )


@mcp.prompt()
def publish_work_order(order_nr: str, product: str, qty: int) -> str:
    """Publiceer een werkorder op de UNS via MQTT."""
    payload = json.dumps({
        "order_nr": order_nr,
        "product": product,
        "qty": qty,
        "status": "CREATED",
        "change_type": "CREATE",
    })
    return (
        f"Publiceer de volgende werkorder op de UNS:\n"
        f"Topic: umh/v1/smc/vienna/_operator/work-order/{order_nr}\n"
        f"Payload: {payload}\n\n"
        "1. Publiceer het bericht met mqtt_publish\n"
        "2. Wacht 2 seconden en subscribe dan op hetzelfde topic om te bevestigen\n"
        "3. Check ook of het bericht doorkomt op het _historian topic"
    )


@mcp.prompt()
def monitor_production() -> str:
    """Monitor live productiedata van de fabriek."""
    return (
        "Monitor de live productiedata.\n"
        "1. Subscribe op 'umh/v1/#' voor 10 seconden en verzamel berichten\n"
        "2. Groepeer de berichten per topic\n"
        "3. Identificeer welke machines actief data sturen\n"
        "4. Zijn er alarmen of opvallende waarden?\n"
        "5. Geef een live status rapport."
    )


# ===========================================================================
# Entry point
# ===========================================================================

def main():
    logging.basicConfig(
        level=os.environ.get("UNS_MQTT_LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
