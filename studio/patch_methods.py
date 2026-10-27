import re

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'r') as f:
    content = f.read()

# Fix _insertNodeAt
target_insert = """  void _insertNodeAt(LadderNetwork rung, int index, LadderNode newNode) {
    setState(() {
      rung.nodes.insert(index, newNode);
      _saveProject();
    });
  }"""
rep_insert = """  void _insertNodeAt(LadderNetwork rung, int index, LadderNode newNode) {
    rung.nodes.insert(index, newNode);
    _saveProject();
    _notifyRung(rung.id);
  }"""
content = content.replace(target_insert, rep_insert)

# Fix _addNodeAtEnd
target_add = """  void _addNodeAtEnd(LadderNetwork rung, LadderNode newNode) {
    setState(() {
      rung.nodes.add(newNode);
      _saveProject();
    });
    
    // Auto-scroll para o novo nó
"""
rep_add = """  void _addNodeAtEnd(LadderNetwork rung, LadderNode newNode) {
    rung.nodes.add(newNode);
    _saveProject();
    _notifyRung(rung.id);
    
    // Auto-scroll para o novo nó
"""
content = content.replace(target_add, rep_add)

# Fix _executeEraseNode
target_erase = """  void _executeEraseNode(String nodeId, LadderNetwork rung, LadderNode node) {
    setState(() {
      _deletingNodes.add(nodeId);
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _deletingNodes.remove(nodeId);
          rung.nodes.remove(node);
          _saveProject();
        });
      }
    });
  }"""
rep_erase = """  void _executeEraseNode(String nodeId, LadderNetwork rung, LadderNode node) {
    _deletingNodes.add(nodeId);
    _notifyRung(rung.id);

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _deletingNodes.remove(nodeId);
        rung.nodes.remove(node);
        _saveProject();
        _notifyRung(rung.id);
      }
    });
  }"""
content = content.replace(target_erase, rep_erase)

# Fix drag and drop accept inside buildRungCardInternal
# It uses setState(() { _project.networks[index].insertNode(newNode, i + 1); _saveProject(); });
# We can't easily regex that without a good pattern, let's use a simpler one
target_drag1 = """                                  setState(() {
                                    _project.networks[index].insertNode(newNode, i + 1);
                                    _saveProject();
                                  });"""
rep_drag1 = """                                  _project.networks[index].insertNode(newNode, i + 1);
                                  _saveProject();
                                  _notifyRung(_project.networks[index].id);"""
content = content.replace(target_drag1, rep_drag1)

target_drag2 = """                                      setState(() {
                                        _project.networks[srcRung].nodes.removeAt(srcIndex);
                                        _project.networks[index].insertNode(srcNode, i + 1);
                                        _saveProject();
                                      });"""
rep_drag2 = """                                      _project.networks[srcRung].nodes.removeAt(srcIndex);
                                      _project.networks[index].insertNode(srcNode, i + 1);
                                      _saveProject();
                                      _notifyRung(_project.networks[srcRung].id);
                                      _notifyRung(_project.networks[index].id);"""
content = content.replace(target_drag2, rep_drag2)

# Same for the end of the rung drop target
target_drag3 = """                                setState(() {
                                  _project.networks[index].addNode(newNode);
                                  _saveProject();
                                });"""
rep_drag3 = """                                _project.networks[index].addNode(newNode);
                                _saveProject();
                                _notifyRung(_project.networks[index].id);"""
content = content.replace(target_drag3, rep_drag3)

target_drag4 = """                                    setState(() {
                                      _project.networks[srcRung].nodes.removeAt(srcIndex);
                                      _project.networks[index].addNode(srcNode);
                                      _saveProject();
                                    });"""
rep_drag4 = """                                    _project.networks[srcRung].nodes.removeAt(srcIndex);
                                    _project.networks[index].addNode(srcNode);
                                    _saveProject();
                                    _notifyRung(_project.networks[srcRung].id);
                                    _notifyRung(_project.networks[index].id);"""
content = content.replace(target_drag4, rep_drag4)

with open('lib/ladder/ui/editor/ladder_editor_page.dart', 'w') as f:
    f.write(content)
