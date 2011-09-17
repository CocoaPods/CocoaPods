module Pod
  class Command
    class Spec < Command
      def self.banner
%{Managing PodSpec files:

    $ pod help spec

      pod spec create NAME
        Creates a directory for your new pod, named `NAME', with a default
        directory structure and accompanying `NAME.podspec'.

      pod spec init NAME
        Creates a PodSpec, in the current working dir, called `NAME.podspec'.
        Use this for existing libraries.

      pod spec lint NAME
        Validates `NAME.podspec' from a local spec-repo. In case `NAME' is
        omitted, it defaults to the PodSpec in the current working dir.

      pod spec push REMOTE
        Validates `NAME.podspec' in the current working dir, copies it to the
        local clone of the `REMOTE' spec-repo, and pushes it to the `REMOTE'
        spec-repo. In case `REMOTE' is omitted, it defaults to `master'.}
      end
    end
  end
end
