---
name: antigrav-tool-shapes-tools-view-content-chunk
description: Antigravity prompt from tool_shapes/tools/view_content_chunk.md
---

# `view_content_chunk`

**Cortex step type:** `CortexStepViewContentChunk`

**Source:** `third_party/jetski/cortex_pb/cortex.proto` (byte-exact, recovered from the embedded `FileDescriptorProto`)

## Proto schema

```proto
message CortexStepViewContentChunk {
  string document_id = 5;
  int32 position = 2;
  exa.codeium_common_pb.KnowledgeBaseItem cropped_item = 4;
}
```

## Field descriptions

See [`../byte_exact_field_index.md`](../byte_exact_field_index.md) for byte-exact `(field_name, jsonschema tag)` records recovered from Go reflect-name tables in the binary. Cortex-step proto messages and JSON-schema tool-arg structs are different namespaces, so a clean static attribution from one to the other is not possible. Match by reading the description text against this tool's purpose.

