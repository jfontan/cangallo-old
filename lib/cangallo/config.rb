
require 'fileutils'
require 'yaml'

module Cangallo
  class Config
    CONFIG_DIR = '.cangallo'
    CONFIG_FILE = 'config.yaml'

    DEFAULT_CONFIG = <<EOT
default_repo: default
repos:
    default:
        type: local
        path: ~/#{CONFIG_DIR}/default
EOT

    def initialize
      create_config_dir
      create_default_config
      load_conf
    end

    def repo(name = nil)
      repo_name = name || @conf['default_repo'] || 'default'
      raise(%q{Configuration malformed, no 'repos'.}) if !@conf['repos']

      repo_conf = @conf['repos'][repo_name]
      raise(%Q<No repo with name '#{repo_name}>) if !repo_conf
      raise(%Q<Repo path no defined for '#{repo_name}>) if !repo_conf['path']

      create_repo_dir(repo_conf['path'])
      Cangallo::Repo.new(repo_conf)
    end

    def load_conf
      @conf = YAML.load_file(config_file)
    end

    def create_config_dir
      if !File.exist?(config_dir)
        FileUtils.mkdir_p(config_dir)
      end
    end

    def create_default_config
      if !File.exist?(config_file)
        open(config_file, 'w') do |f|
          f.write(DEFAULT_CONFIG)
        end
      end
    end

    def create_repo_dir(path)
      if !File.exist?(path)
        FileUtils.mkdir_p(path)
        FileUtils.mkdir_p(File.join(path, 'metadata'))
        FileUtils.mkdir_p(File.join(path, 'images'))
      end
    end

    def config_dir
      File.join(ENV['HOME'], CONFIG_DIR)
    end

    def config_file
      File.join(config_dir, CONFIG_FILE)
    end
  end
end
