module Pod
  class Command
    class Help < Command
      def run
        puts %{
### Setup

    $ pod help setup

      pod setup
        Creates a directory at `~/.cocoa-pods' which will hold your spec-repos.
        This is where it will create a clone of the public `master' spec-repo.

### Managing PodSpec files

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
        spec-repo. In case `REMOTE' is omitted, it defaults to `master'.

### Managing spec-repos

    $ pod help repo

      pod repo add NAME URL
        Clones `URL' in the local spec-repos directory at `~/.cocoa-pods'. The
        remote can later be referred to by `NAME'.

      pod repo update NAME
        Updates the local clone of the spec-repo `NAME'.

      pod repo change NAME URL
        Changes the git remote of local spec-repo `NAME' to `URL'.

      pod repo cd NAME
        Changes the current working dir to the local spec-repo `NAME'.
}
      end
    end
  end
end
