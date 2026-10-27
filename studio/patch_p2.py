import re

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    code = f.read()

# Add hover states
state_vars = """
  bool _isDraggingNode = false;
  int? _hoverRungIndex;
  int? _hoverInsertIndex;
"""
code = code.replace("bool _isDraggingNode = false;", state_vars)

# Replace the IntrinsicWidth child with the new DragTarget
# We'll locate "child: IntrinsicWidth(" and its contents.
# But it's easier to find the whole LayoutBuilder builder body.

builder_body = """                  builder: (context, constraints) {
                    return DragTarget<Object>(
                      onWillAcceptWithDetails: (details) => true,
                      onMove: (details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final localOffset = box.globalToLocal(details.offset);
                        
                        // Heurística de proximidade (cada componente ocupa ~80px + gap)
                        // A inserção no começo é no x ~ 0-40, dps vai pulando.
                        int newIndex = ((localOffset.dx - 20) / 90).round().clamp(0, rung.nodes.length);
                        
                        if (_hoverRungIndex != index || _hoverInsertIndex != newIndex) {
                          setState(() {
                            _hoverRungIndex = index;
                            _hoverInsertIndex = newIndex;
                          });
                        }
                      },
                      onLeave: (data) {
                        setState(() {
                          _hoverRungIndex = null;
                          _hoverInsertIndex = null;
                        });
                      },
                      onAcceptWithDetails: (details) {
                        final data = details.data;
                        final insertIndex = _hoverInsertIndex ?? rung.nodes.length;
                        setState(() {
                          _hoverRungIndex = null;
                          _hoverInsertIndex = null;
                        });
                        
                        if (data is NodeType) {
                          final newNode = LadderNode(
                            id: 'node_${DateTime.now().microsecondsSinceEpoch}',
                            type: data,
                            config: NodeConfig(),
                          );
                          setState(() {
                            _project.networks[index].insertNode(newNode, insertIndex);
                            _saveProject();
                          });
                          _showEditNodeBottomSheet(index, insertIndex);
                        } else if (data is Map<String, dynamic> && data['type'] == 'move') {
                          final srcRung = data['srcRung'] as int;
                          final srcNode = data['srcNode'] as int;
                          final nodeToMove = _project.networks[srcRung].nodes[srcNode];
                          
                          setState(() {
                            _project.networks[srcRung].removeNodeAt(srcNode);
                            int actualInsertIdx = insertIndex;
                            if (srcRung == index && srcNode < insertIndex) {
                              actualInsertIdx--;
                            }
                            _project.networks[index].insertNode(nodeToMove, actualInsertIdx);
                            _saveProject();
                          });
                        }
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovered = _hoverRungIndex == index && candidateData.isNotEmpty;
                        
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: IntrinsicWidth(
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  // Fio contínuo
                                  Positioned(
                                    left: 6, right: 6,
                                    child: Container(height: 2, color: Colors.grey[700]),
                                  ),
                                  Row(
                                    children: [
                                      // Rail Left
                                      Container(
                                        width: 6,
                                        height: 64,
                                        color: Colors.blueGrey[300],
                                      ),
                                      
                                      // Indicator at index 0
                                      if (isHovered && _hoverInsertIndex == 0)
                                        _buildHoverIndicator()
                                      else
                                        _buildWireSegment(rung.nodes.isEmpty || rung.nodes[0].isEnergized),
                          
                                      ...List.generate(rung.nodes.length, (i) {
                                        final node = rung.nodes[i];
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            LongPressDraggable<Map<String, dynamic>>(
                                              data: {
                                                'type': 'move',
                                                'srcRung': index,
                                                'srcNode': i,
                                              },
                                              onDragStarted: () {
                                                setState(() {
                                                  _isDraggingNode = true;
                                                });
                                              },
                                              onDragEnd: (details) {
                                                setState(() {
                                                  _isDraggingNode = false;
                                                });
                                              },
                                              onDraggableCanceled: (velocity, offset) {
                                                setState(() {
                                                  _isDraggingNode = false;
                                                });
                                              },
                                              feedback: Material(
                                                color: Colors.transparent,
                                                child: Opacity(
                                                  opacity: 0.7,
                                                  child: _buildLadderNodeVisual(node, false),
                                                ),
                                              ),
                                              childWhenDragging: Opacity(
                                                opacity: 0.3,
                                                child: _buildLadderNodeVisual(node, false),
                                              ),
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedRungIndex = index;
                                                    _selectedNodeIndex = i;
                                                  });
                                                  _showEditNodeBottomSheet(index, i);
                                                },
                                                onLongPress: () {
                                                  _showNodeOptionsBottomSheet(index, i);
                                                },
                                                child: _buildLadderNodeVisual(
                                                  node,
                                                  _selectedRungIndex == index && _selectedNodeIndex == i,
                                                ),
                                              ),
                                            ),
                                            // Indicator after the node
                                            if (isHovered && _hoverInsertIndex == i + 1)
                                              _buildHoverIndicator()
                                            else
                                              _buildWireSegment(i + 1 < rung.nodes.length ? rung.nodes[i + 1].isEnergized : node.isEnergized),
                                          ],
                                        );
                                      }),
                                      
                                      // Espaçamento flexível para empurrar o trilho direito
                                      Expanded(child: Container()),
                                      
                                      // Rail Right
                                      Container(
                                        width: 6,
                                        height: 64,
                                        color: Colors.blueGrey[300],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },"""

# Use regex to find LayoutBuilder inside _buildRungList
pattern_layout_builder = re.compile(r'builder:\s*\(context,\s*constraints\)\s*\{[\s\S]*?return SingleChildScrollView\([\s\S]*?scrollDirection:\s*Axis\.horizontal,[\s\S]*?child:\s*ConstrainedBox\([\s\S]*?child:\s*IntrinsicWidth\([\s\S]*?child:\s*Stack\([\s\S]*?alignment:\s*Alignment\.centerLeft,[\s\S]*?children:\s*\[[\s\S]*?// Fio contínuo[\s\S]*?// Rail Right[\s\S]*?Container\([\s\S]*?width:\s*6,[\s\S]*?height:\s*64,[\s\S]*?color:\s*Colors\.blueGrey\[300\],[\s\S]*?\),[\s\S]*?\],[\s\S]*?\),[\s\S]*?\],[\s\S]*?\),[\s\S]*?\),[\s\S]*?\),[\s\S]*?\);[\s\S]*?\},')

code = pattern_layout_builder.sub(builder_body, code)

# Remove the old _buildInsertionPoint method completely
pattern_insertion = re.compile(r'Widget _buildInsertionPoint\(int rungIndex, int insertIndex, bool isEnergized\) \{[\s\S]*?\}\s*\}\s*Widget _buildLadderNodeVisual')
# wait, it might end before another method
code = re.sub(r'Widget _buildInsertionPoint\(int rungIndex, int insertIndex, bool isEnergized\) \{[\s\S]*?\}\n\s*\}\n', '', code)

# Add _buildHoverIndicator and _buildWireSegment just before _buildLadderNodeVisual
helpers = """
  Widget _buildHoverIndicator() {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.yellowAccent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('▼', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildWireSegment(bool isEnergized) {
    return Container(
      width: 30,
      height: 2,
      color: isEnergized ? Colors.greenAccent : Colors.transparent,
    );
  }

  Widget _buildLadderNodeVisual"""
code = code.replace("Widget _buildLadderNodeVisual", helpers)


# Now fix P1-2: Add Mover Esquerda / Direita in _showNodeOptionsBottomSheet
# Actually wait, _showNodeOptionsBottomSheet does exactly what?
# Let's replace _showNodeOptionsBottomSheet
bottom_sheet_opts = """
          ListTile(
            leading: const Icon(Icons.arrow_back, color: Colors.blueAccent),
            title: const Text('Mover para Esquerda', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              if (nodeIndex > 0) {
                setState(() {
                  final node = _project.networks[rungIndex].nodes.removeAt(nodeIndex);
                  _project.networks[rungIndex].insertNode(node, nodeIndex - 1);
                  _saveProject();
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.arrow_forward, color: Colors.blueAccent),
            title: const Text('Mover para Direita', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              if (nodeIndex < _project.networks[rungIndex].nodes.length - 1) {
                setState(() {
                  final node = _project.networks[rungIndex].nodes.removeAt(nodeIndex);
                  _project.networks[rungIndex].insertNode(node, nodeIndex + 1);
                  _saveProject();
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.redAccent),"""

code = code.replace("ListTile(\n            leading: const Icon(Icons.delete, color: Colors.redAccent),", bottom_sheet_opts)

# Now P1-3: _buildToolboxCard -> Ensure 'Nova Rung' is identical to the rest
# Currently, Nova Rung might not be in the toolbox. In the standard Endap, where is it?
# Let's look for "Nova Rung" or similar in the toolbox code.

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'w') as f:
    f.write(code)

print("Patch logic 1 applied")
