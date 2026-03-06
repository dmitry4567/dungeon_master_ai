#!/usr/bin/env python3
"""Test script to demonstrate the beautiful colored logger."""

import logging

from src.core.logging import setup_logging


def main():
    # Setup logging with different formats
    print("\n=== Console Format (Default) ===\n")
    logger = setup_logging(level="DEBUG", log_format="console")
    
    logger.debug("This is a debug message 🔍")
    logger.info("This is an info message ℹ️")
    logger.warning("This is a warning message ⚠️")
    logger.error("This is an error message ❌")
    logger.critical("This is a critical message 🔥")
    
    # Test with dungeon theme
    print("\n=== Dungeon Master Theme ===\n")
    logger_dungeon = setup_logging(level="DEBUG", log_format="dungeon", logger_name="dungeon")
    
    logger_dungeon.debug("Checking crystal ball for omens...")
    logger_dungeon.info("Adventure hook generated successfully")
    logger_dungeon.warning("Dragon approaching! Prepare for combat!")
    logger_dungeon.error("Player character fell into a pit trap")
    logger_dungeon.critical("Total party wipe imminent!")
    
    # Test exception logging
    try:
        raise ValueError("You stumbled into a mimic!")
    except Exception:
        logger.exception("An exception occurred during the adventure")


if __name__ == "__main__":
    main()
