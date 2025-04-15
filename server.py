# Model Context Protocol (MCP) Server
from mcp.server.fastmcp import FastMCP

# Create an MCP server
mcp = FastMCP("My MCP Server")


# Add a simple greeting resource
@mcp.resource("greeting://{name}")
def get_greeting(name: str) -> str:
    """Get a personalized greeting"""
    return f"Hello, {name}!"


# Add a simple calculator tool
@mcp.tool()
def calculate(operation: str, a: float, b: float) -> float:
    """
    Perform a calculation on two numbers.
    
    Parameters:
    - operation: The operation to perform (add, subtract, multiply, divide)
    - a: First number
    - b: Second number
    
    Returns:
    - The result of the calculation
    """
    if operation == "add":
        return a + b
    elif operation == "subtract":
        return a - b
    elif operation == "multiply":
        return a * b
    elif operation == "divide":
        if b == 0:
            raise ValueError("Cannot divide by zero")
        return a / b
    else:
        raise ValueError(f"Unknown operation: {operation}")


# Only needed if running the file directly
if __name__ == "__main__":
    mcp.run()
