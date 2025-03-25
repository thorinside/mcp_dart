import 'package:mcp_dart/src/types/server_result.dart';
import 'package:mcp_dart/src/types/tool.dart';

/// An abstract class that represents a tool runner, which extends the [Tool] class.
/// A tool runner is responsible for executing a tool with the provided arguments.
abstract class ToolRunner extends Tool {
  /// Creates a new [ToolRunner].
  ///
  /// - [description]: A brief description of the tool.
  /// - [inputSchema]: The schema that defines the expected input for the tool.
  /// - [name]: The unique name of the tool.
  const ToolRunner({
    super.description,
    required super.inputSchema,
    required super.name,
  });

  /// Executes the tool with the given [args].
  ///
  /// - [args]: A map of arguments required for the tool's execution.
  /// - Returns a [CallToolResult] containing the result of the tool execution.
  Future<CallToolResult> execute(Map<String, dynamic> args);
}
