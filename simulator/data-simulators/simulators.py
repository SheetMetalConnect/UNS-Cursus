"""
UNS Course Data Source Simulators
- Modbus TCP Solar Inverter (port 5020)
- Weather REST API (port 8084)
- Energy Spot Price REST API (port 8085)

All three correlate: weather drives solar, solar affects prices.
"""

import math
import random
import struct
import threading
import time
from datetime import datetime, timezone, timedelta

from pymodbus.server import StartTcpServer
from pymodbus.datastore import (
    ModbusSlaveContext,
    ModbusServerContext,
    ModbusSequentialDataBlock,
)
from flask import Flask, jsonify


# ---------------------------------------------------------------------------
# Shared state — correlation engine
# ---------------------------------------------------------------------------

class WorldState:
    """Single source of truth for correlated simulation values."""

    def __init__(self):
        self.lock = threading.Lock()
        # Solar
        self.dc_power = 0.0
        self.ac_power = 0.0
        self.daily_yield = 0.0
        self.total_yield = 152.347  # MWh historical
        self.dc_voltage = 0.0
        self.dc_current = 0.0
        self.panel_temp = 15.0
        self.inverter_status = 0  # 0=off
        self.grid_freq = 50.0
        self.efficiency = 96.0
        # Weather
        self.temperature = 12.0
        self.humidity = 65.0
        self.wind_speed = 8.0
        self.wind_direction = "W"
        self.cloud_cover = 30.0
        self.solar_irradiance = 0.0
        self.condition = "clear"
        self.pressure = 1013.0
        self.uv_index = 0
        # Energy
        self.price_eur_mwh = 55.0
        self.day_avg = 65.0
        self.peak_price = 110.0
        self.off_peak_price = 40.0
        self.trend = "stable"
        # Internal
        self._cloud_event_until = 0.0
        self._cloud_event_factor = 1.0
        self._last_day = -1
        self._hourly_prices = []
        self._forecast = []

    def _sun_elevation(self, utc_now: datetime) -> float:
        """Approximate solar elevation for ~52N latitude (Netherlands)."""
        hour_utc = utc_now.hour + utc_now.minute / 60.0
        # Rough day-of-year declination
        doy = utc_now.timetuple().tm_yday
        declination = 23.45 * math.sin(math.radians((360 / 365) * (doy - 81)))
        lat = 52.0
        # Hour angle (solar noon ~ 12:00 UTC for ~5E longitude, close enough)
        hour_angle = (hour_utc - 12.3) * 15.0
        sin_elev = (
            math.sin(math.radians(lat)) * math.sin(math.radians(declination))
            + math.cos(math.radians(lat))
            * math.cos(math.radians(declination))
            * math.cos(math.radians(hour_angle))
        )
        return math.degrees(math.asin(max(-1, min(1, sin_elev))))

    def _base_price(self, hour: int) -> float:
        """EPEX-style base price curve."""
        # Night trough, morning ramp, afternoon peak, evening decline
        curve = {
            0: 35, 1: 32, 2: 30, 3: 30, 4: 32, 5: 38,
            6: 52, 7: 68, 8: 78, 9: 82, 10: 80, 11: 75,
            12: 72, 13: 70, 14: 73, 15: 78, 16: 85, 17: 95,
            18: 105, 19: 110, 20: 90, 21: 72, 22: 55, 23: 42,
        }
        return curve.get(hour, 60)

    def _generate_daily_prices(self, utc_now: datetime):
        """Generate 24 hourly prices for the day."""
        random.seed(utc_now.strftime("%Y-%m-%d"))  # Deterministic per day
        prices = []
        for h in range(24):
            base = self._base_price(h)
            noise = random.gauss(0, 8)
            # Occasional spike
            if random.random() < 0.08:
                noise += random.uniform(20, 50)
            # Duck curve: midday solar depression
            if 10 <= h <= 14:
                base -= random.uniform(5, 15)
            prices.append(round(max(15, base + noise), 2))
        self._hourly_prices = prices
        self.day_avg = round(sum(prices) / 24, 2)
        self.peak_price = max(prices)
        self.off_peak_price = min(prices)

    def _generate_forecast(self, utc_now: datetime):
        """Generate 6-hour weather forecast."""
        forecast = []
        temp = self.temperature
        cloud = self.cloud_cover
        for i in range(1, 7):
            future = utc_now + timedelta(hours=i)
            # Temperature follows sin curve
            hour_local = (future.hour + 2) % 24  # rough CET
            temp_base = 10 + 8 * math.sin(math.radians((hour_local - 6) * 180 / 16))
            temp_f = round(temp_base + random.gauss(0, 1.5), 1)
            # Cloud cover drifts
            cloud = max(0, min(100, cloud + random.gauss(0, 10)))
            elev = self._sun_elevation(future)
            irr = max(0, round(1000 * max(0, math.sin(math.radians(elev))) * (1 - cloud / 130), 1))

            conditions = ["clear", "partly_cloudy", "cloudy", "overcast", "light_rain"]
            if cloud < 20:
                cond = "clear"
            elif cloud < 50:
                cond = "partly_cloudy"
            elif cloud < 75:
                cond = "cloudy"
            elif cloud < 90:
                cond = "overcast"
            else:
                cond = "light_rain"

            forecast.append({
                "timestamp": future.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "temperature_c": temp_f,
                "humidity_pct": max(30, min(98, int(65 + (cloud - 40) * 0.4 + random.gauss(0, 5)))),
                "wind_speed_kmh": round(max(0, 10 + random.gauss(0, 5)), 1),
                "cloud_cover_pct": round(cloud, 1),
                "solar_irradiance_wm2": irr,
                "condition": cond,
            })
        self._forecast = forecast

    def update(self):
        """Tick the world forward. Called every 5 seconds."""
        with self.lock:
            now = datetime.now(timezone.utc)
            t = time.time()

            # Generate daily prices if new day
            if now.day != self._last_day:
                self._last_day = now.day
                self._generate_daily_prices(now)
                self.daily_yield = 0.0

            # --- Sun position ---
            sun_elev = self._sun_elevation(now)
            sun_factor = max(0, math.sin(math.radians(max(0, sun_elev))))

            # --- Cloud events ---
            if t > self._cloud_event_until:
                # Chance of new cloud event
                if random.random() < 0.02:  # ~every 4 minutes on average
                    self._cloud_event_until = t + random.uniform(60, 300)
                    self._cloud_event_factor = random.uniform(0.3, 0.7)
                else:
                    self._cloud_event_factor = 1.0

            # --- Weather ---
            hour_local = (now.hour + 2) % 24  # rough CET
            self.temperature = round(
                10 + 8 * math.sin(math.radians((hour_local - 6) * 180 / 16))
                + random.gauss(0, 0.3),
                1,
            )

            base_cloud = 25 + 15 * math.sin(math.radians(hour_local * 15 + 90))
            if self._cloud_event_factor < 1.0:
                self.cloud_cover = round(
                    min(95, base_cloud + (1 - self._cloud_event_factor) * 60 + random.gauss(0, 2)),
                    1,
                )
            else:
                self.cloud_cover = round(max(5, base_cloud + random.gauss(0, 3)), 1)

            self.solar_irradiance = round(
                max(0, 1000 * sun_factor * self._cloud_event_factor * (1 - self.cloud_cover / 130))
                + random.gauss(0, 5),
                1,
            )
            self.solar_irradiance = max(0, self.solar_irradiance)

            self.humidity = max(30, min(98, round(
                65 + (self.cloud_cover - 40) * 0.3 - (self.temperature - 15) * 0.5
                + random.gauss(0, 1),
                1,
            )))

            self.wind_speed = round(max(0, 8 + 4 * math.sin(t / 600) + random.gauss(0, 1)), 1)
            directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
            self.wind_direction = directions[int((t / 3600) % 8)]

            self.pressure = round(1013 + 3 * math.sin(t / 7200) + random.gauss(0, 0.2), 1)

            if self.cloud_cover < 20:
                self.condition = "clear"
            elif self.cloud_cover < 45:
                self.condition = "partly_cloudy"
            elif self.cloud_cover < 70:
                self.condition = "cloudy"
            elif self.cloud_cover < 90:
                self.condition = "overcast"
            else:
                self.condition = "light_rain"

            self.uv_index = max(0, round(sun_factor * 8 * self._cloud_event_factor * (1 - self.cloud_cover / 150)))

            # --- Solar inverter ---
            if sun_elev <= 0:
                self.inverter_status = 0
                self.dc_power = 0
                self.ac_power = 0
                self.dc_voltage = 0
                self.dc_current = 0
                self.panel_temp = round(self.temperature - 2 + random.gauss(0, 0.3), 1)
            elif sun_elev < 5:
                self.inverter_status = 1  # starting
                self.dc_power = round(sun_factor * 500 * self._cloud_event_factor + random.gauss(0, 10), 1)
                self.dc_voltage = round(200 + sun_factor * 100, 1)
                self.dc_current = round(self.dc_power / max(1, self.dc_voltage), 2)
                self.efficiency = round(92 + random.gauss(0, 0.3), 1)
                self.ac_power = round(self.dc_power * self.efficiency / 100, 1)
                self.panel_temp = round(self.temperature + 5 + random.gauss(0, 0.5), 1)
            else:
                self.inverter_status = 2  # producing
                max_power = 8000
                self.dc_power = round(
                    max_power * sun_factor * self._cloud_event_factor
                    * (1 - self.cloud_cover / 150)
                    + random.gauss(0, 30),
                    1,
                )
                self.dc_power = max(0, min(max_power, self.dc_power))
                self.dc_voltage = round(
                    300 + 250 * sun_factor * self._cloud_event_factor + random.gauss(0, 2),
                    1,
                )
                self.dc_voltage = min(600, max(0, self.dc_voltage))
                self.dc_current = round(self.dc_power / max(1, self.dc_voltage), 2)
                self.dc_current = min(15, max(0, self.dc_current))
                self.efficiency = round(94 + 3 * (self.dc_power / max_power) + random.gauss(0, 0.2), 1)
                self.efficiency = min(97.5, max(93, self.efficiency))
                self.ac_power = round(self.dc_power * self.efficiency / 100, 1)
                self.panel_temp = round(
                    self.temperature + 15 + 30 * sun_factor * (1 - self.cloud_cover / 200)
                    + random.gauss(0, 0.5),
                    1,
                )

            # Accumulate yield (5 second ticks)
            self.daily_yield = round(self.daily_yield + self.ac_power * 5 / 3_600_000, 4)
            self.total_yield = round(self.total_yield + self.ac_power * 5 / 3_600_000_000, 6)

            self.grid_freq = round(50 + random.gauss(0, 0.05), 2)
            self.grid_freq = max(49.8, min(50.2, self.grid_freq))

            # Fault injection: very rare
            if self.inverter_status == 2 and random.random() < 0.0005:
                self.inverter_status = 3  # fault

            # --- Energy prices ---
            current_hour = now.hour
            if self._hourly_prices:
                base = self._hourly_prices[current_hour]
                # Interpolate within the hour
                minute_frac = now.minute / 60
                next_hour = (current_hour + 1) % 24
                next_base = self._hourly_prices[next_hour]
                interp = base + (next_base - base) * minute_frac
                # Add real-time noise
                self.price_eur_mwh = round(max(10, interp + random.gauss(0, 2)), 2)

                # Trend
                if current_hour > 0:
                    prev = self._hourly_prices[current_hour - 1]
                    if self.price_eur_mwh > prev + 5:
                        self.trend = "rising"
                    elif self.price_eur_mwh < prev - 5:
                        self.trend = "falling"
                    else:
                        self.trend = "stable"

            # Regenerate forecast periodically
            if int(t) % 300 < 6:
                self._generate_forecast(now)

    def get_snapshot(self):
        with self.lock:
            return {
                "solar": {
                    "dc_power": self.dc_power,
                    "ac_power": self.ac_power,
                    "daily_yield": self.daily_yield,
                    "total_yield": self.total_yield,
                    "dc_voltage": self.dc_voltage,
                    "dc_current": self.dc_current,
                    "panel_temp": self.panel_temp,
                    "inverter_status": int(self.inverter_status),
                    "grid_freq": self.grid_freq,
                    "efficiency": self.efficiency,
                },
                "weather": {
                    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "temperature_c": self.temperature,
                    "humidity_pct": int(self.humidity),
                    "wind_speed_kmh": self.wind_speed,
                    "wind_direction": self.wind_direction,
                    "cloud_cover_pct": round(self.cloud_cover, 1),
                    "solar_irradiance_wm2": self.solar_irradiance,
                    "condition": self.condition,
                    "pressure_hpa": self.pressure,
                    "uv_index": self.uv_index,
                },
                "energy": {
                    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "price_eur_mwh": self.price_eur_mwh,
                    "price_eur_kwh": round(self.price_eur_mwh / 1000, 4),
                    "zone": "NL",
                    "trend": self.trend,
                    "day_average_eur_mwh": self.day_avg,
                    "peak_price_eur_mwh": self.peak_price,
                    "off_peak_price_eur_mwh": self.off_peak_price,
                },
                "hourly_prices": self._hourly_prices,
                "forecast": self._forecast,
            }


# ---------------------------------------------------------------------------
# Global world state
# ---------------------------------------------------------------------------
world = WorldState()


# ---------------------------------------------------------------------------
# Modbus server (port 5020)
# ---------------------------------------------------------------------------

def float32_to_registers(value: float):
    """Pack a float32 into two 16-bit Modbus registers (big-endian)."""
    packed = struct.pack(">f", value)
    reg_hi = struct.unpack(">H", packed[0:2])[0]
    reg_lo = struct.unpack(">H", packed[2:4])[0]
    return [reg_hi, reg_lo]


def modbus_updater(context):
    """Update Modbus holding registers from world state every 5s."""
    while True:
        world.update()
        snap = world.get_snapshot()
        solar = snap["solar"]

        values = []
        values.extend(float32_to_registers(solar["dc_power"]))       # reg 0-1
        values.extend(float32_to_registers(solar["ac_power"]))        # reg 2-3
        values.extend(float32_to_registers(solar["daily_yield"]))     # reg 4-5
        values.extend(float32_to_registers(solar["total_yield"]))     # reg 6-7
        values.extend(float32_to_registers(solar["dc_voltage"]))      # reg 8-9
        values.extend(float32_to_registers(solar["dc_current"]))      # reg 10-11
        values.extend(float32_to_registers(solar["panel_temp"]))      # reg 12-13
        values.extend(float32_to_registers(float(solar["inverter_status"])))  # reg 14-15
        values.extend(float32_to_registers(solar["grid_freq"]))       # reg 16-17
        values.extend(float32_to_registers(solar["efficiency"]))      # reg 18-19

        slave = context[0x00]
        slave.setValues(3, 0, values)  # function code 3 = holding registers

        time.sleep(5)


def start_modbus():
    """Start the Modbus TCP server on port 5020."""
    # 20 registers (10 float32 params x 2 regs each)
    block = ModbusSequentialDataBlock(0, [0] * 20)
    store = ModbusSlaveContext(hr=block, ir=block)
    context = ModbusServerContext(slaves=store, single=True)

    # Start updater thread
    t = threading.Thread(target=modbus_updater, args=(context,), daemon=True)
    t.start()

    print("[Modbus] Starting on port 5020")
    StartTcpServer(context=context, address=("0.0.0.0", 5020))


# ---------------------------------------------------------------------------
# Flask REST APIs (Weather: 8084, Energy: 8085)
# ---------------------------------------------------------------------------

weather_app = Flask("weather")
energy_app = Flask("energy")


@weather_app.route("/api/weather/current")
def weather_current():
    snap = world.get_snapshot()
    return jsonify(snap["weather"])


@weather_app.route("/api/weather/forecast")
def weather_forecast():
    snap = world.get_snapshot()
    return jsonify({"forecast": snap["forecast"]})


@energy_app.route("/api/energy/current")
def energy_current():
    snap = world.get_snapshot()
    return jsonify(snap["energy"])


@energy_app.route("/api/energy/today")
def energy_today():
    snap = world.get_snapshot()
    now = datetime.now(timezone.utc)
    hours = []
    for i, price in enumerate(snap["hourly_prices"]):
        hours.append({
            "hour": i,
            "timestamp": now.replace(hour=i, minute=0, second=0, microsecond=0).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "price_eur_mwh": price,
            "price_eur_kwh": round(price / 1000, 4),
        })
    return jsonify({"zone": "NL", "date": now.strftime("%Y-%m-%d"), "prices": hours})


def start_weather_api():
    print("[Weather API] Starting on port 8084")
    weather_app.run(host="0.0.0.0", port=8084, threaded=True)


def start_energy_api():
    print("[Energy API] Starting on port 8085")
    energy_app.run(host="0.0.0.0", port=8085, threaded=True)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # Initial update + forecast generation
    world.update()
    world._generate_forecast(datetime.now(timezone.utc))

    # Start REST APIs in background threads
    t1 = threading.Thread(target=start_weather_api, daemon=True)
    t1.start()
    t2 = threading.Thread(target=start_energy_api, daemon=True)
    t2.start()

    # Modbus runs in main thread (blocking)
    start_modbus()
