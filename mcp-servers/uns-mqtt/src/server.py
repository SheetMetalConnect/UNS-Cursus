"""
UNS MQTT MCP Server
====================
Geeft Claude toegang tot de MQTT broker (HiveMQ) van de UNS stack.

Tools:
  - mqtt_publish     Publiceer een bericht naar een topic
  - mqtt_subscribe   Abonneer en ontvang de laatste N berichten
  - mqtt_list_topics Toon actieve topics op de broker
"""

import asyncio
import json
import os
import time
from contextlib import asynccontextmanager

import aiomqtt
from mcp.server.fastmcp import FastMCP

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
MQTT_HOST = os.environ.get("UNS_MQTT_HOST", "localhost")
MQTT_PORT = int(os.environ.get("UNS_MQTT_PORT", "1883"))

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
    """Start the topic cache listener on startup."""
    cache = TopicCache()
    await cache.start()
    try:
        yield {"cache": cache}
    finally:
        await cache.stop()


mcp = FastMCP(
    name="uns-mqtt",
    instructions=(
        "Je bent verbonden met de MQTT broker (HiveMQ) van een metaalbewerkingsbedrijf. "
        "De broker is onderdeel van een Unified Namespace (UNS) architectuur. "
        "Topics volgen de structuur: umh/v1/{enterprise}/{site}/... "
        "Je kunt berichten publiceren, topics uitlezen, en zien welke topics actief zijn."
    ),
    lifespan=lifespan,
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
        topic: The MQTT topic to publish to (e.g. 'umh/v1/smc/vienna/_operator/work-order/WO-001').
        payload: The message payload, preferably valid JSON.
    """
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
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
