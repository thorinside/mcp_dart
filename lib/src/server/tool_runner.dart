import 'package:mcp_dart/src/types/server_result.dart';
import 'package:mcp_dart/src/types/tool.dart';

abstract class ToolRunner extends Tool {
  const ToolRunner({
    super.description,
    required super.inputSchema,
    required super.name,
  });

  Future<CallToolResult> execute(Map<String, dynamic> args);
}
