import 'package:mcp_dart/mcp_dart.dart';

import 'calculater_tool.dart';

void main() async {
  MCPServer server = MCPServer(name: 'Calculator', version: '0.0.1');

  server.tool(CalculatorTool()).start(StdioTransport());
}
