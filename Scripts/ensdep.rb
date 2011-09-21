#!/usr/bin/env ruby

def printUsage
  puts "You must specify dependencies to ensure existance of.

usage: ensdep [-p] <repo> ...

    -p     Pull in existing repos
    <repo> One or more git repos to ensure

Repos are cloned into ../ unless DEPENDENCIES_PATH is set to a path."
end

def ensureRepoInDirectory(repo_url, dep_path, pull)
  repo_path = File.join(dep_path, repo_url.slice(/[^\/]*(?=\.git$)/))
  unless File.directory?(repo_path)
    puts "will clone repo #{repo_url} into #{repo_path}"
    system "git clone #{repo_url} #{repo_path}"
  else
    if pull
      puts "will pull #{repo_url} in #{repo_path}"
      system "git --git-dir=#{repo_path} --work-tree=#{repo_path} pull"
    else
      puts "will ignore #{repo_url} in #{repo_path}"
    end
  end
end

# Main
if ARGV.length == 0
  printUsage
else
  pull = ARGV[0] == '-p'
  repos = ARGV[(pull ? 1 : 0)..-1]
  dep_path = ENV['DEPENDENCIES_PATH'] || '..'
  repos.each do|repo_url|
    ensureRepoInDirectory(repo_url, dep_path, pull)
  end
end

