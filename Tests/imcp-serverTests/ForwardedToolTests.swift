import MCP
import XCTest

final class ForwardedToolTests: XCTestCase {
    func testPrefixPreservesUpstreamContractAndResult() async throws {
        let schema: Value = ["type": "object", "properties": ["scope": ["enum": ["one", "future"]]]]
        let source = MCP.Tool(
            name: "update_event",
            title: "Update Event",
            description: "Update a test event.",
            inputSchema: schema,
            annotations: .init(readOnlyHint: false),
            outputSchema: ["type": "object"]
        )
        let tool = Tool(forwarding: source, prefix: "busycal_") { args in
            XCTAssertEqual(args["scope"], "future")
            return CallTool.Result(
                content: [.text(text: "Conflict", annotations: nil, _meta: nil)],
                structuredContent: Optional(Value.object(["reason": "conflict"])),
                isError: true
            )
        }
        let descriptor = try tool.definition
        XCTAssertEqual(descriptor.name, "busycal_update_event")
        XCTAssertEqual(descriptor.inputSchema, source.inputSchema)
        XCTAssertEqual(descriptor.outputSchema, source.outputSchema)
        XCTAssertEqual(descriptor.annotations, source.annotations)
        XCTAssertEqual(descriptor.title, source.title)
        let reply = try await tool.forwardedResult(["scope": "future"])
        XCTAssertEqual(reply?.isError, true)
        XCTAssertEqual(reply?.structuredContent, ["reason": "conflict"])
    }
}
