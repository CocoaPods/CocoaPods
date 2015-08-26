require 'pathname'

module FileTree
  def to_tree(path, depth = 0)
    path = Pathname(path)
    indentation = ' ' * depth * 2
    tree = indentation << path.to_path << "\n"
    path.children.each do |child|
      tree << to_tree(child, depth + 1)
    end if path.directory?
    tree
  end

  module_function :to_tree
end
