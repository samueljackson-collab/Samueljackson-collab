import asyncio
from typing import Any, Optional

from geopy.geocoders import Nominatim

geocoder = Nominatim(user_agent="location_service")


async def reverse_geocode(latitude: float, longitude: float) -> Optional[Any]:
    """Reverse geocode the provided coordinates without blocking the event loop."""
    location = await asyncio.to_thread(geocoder.reverse, (latitude, longitude))
    await asyncio.sleep(1)
    return location
