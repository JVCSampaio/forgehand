from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

from forgehand.config import ForgehandConfig, write_config


@pytest.mark.asyncio
async def test_stdio_mcp_handshake(tmp_path: Path) -> None:
    config_path = tmp_path / "config.yaml"
    write_config(ForgehandConfig(project_root=tmp_path), config_path)
    parameters = StdioServerParameters(
        command=sys.executable,
        args=["-m", "forgehand.mcp_server"],
        cwd=os.getcwd(),
        env={**os.environ, "FORGEHAND_CONFIG": str(config_path)},
    )
    async with (
        stdio_client(parameters) as (reader, writer),
        ClientSession(reader, writer) as session,
    ):
        await session.initialize()
        tools = await session.list_tools()
        names = {tool.name for tool in tools.tools}
        assert names == {
            "forgehand_health",
            "forgehand_delegate",
            "forgehand_tasks",
            "forgehand_result",
        }
        health = await session.call_tool("forgehand_health", {})

    assert not health.isError
    assert health.structuredContent is not None
    assert health.structuredContent["ok"] is True
    assert health.structuredContent["security"]["final_review_required"] is True
