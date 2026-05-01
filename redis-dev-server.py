#!/usr/bin/env python
"""
Development Redis server using fakeredis for local testing.
Runs an async Redis server on localhost:6379
"""
import asyncio
import logging
import signal

from fakeredis import aioredis
from fakeredis.server import Server

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def main():
    """Start fake Redis server."""
    server = Server()
    logger.info("Starting fake Redis server on localhost:6379...")
    
    # Handle graceful shutdown
    loop = asyncio.get_event_loop()
    
    def signal_handler():
        logger.info("Shutting down...")
        loop.stop()
    
    loop.add_signal_handler(signal.SIGINT, signal_handler)
    loop.add_signal_handler(signal.SIGTERM, signal_handler)
    
    try:
        # Start the server - this runs indefinitely
        # fakeredis.server.Server handles TCP connections
        await server.start("localhost", 6379)
        logger.info("Fake Redis server started on localhost:6379")
    except Exception as exc:
        logger.error(f"Error starting Redis server: {exc}", exc_info=True)
        raise


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Server stopped by user")
    except Exception as exc:
        logger.error(f"Fatal error: {exc}", exc_info=True)
        exit(1)
