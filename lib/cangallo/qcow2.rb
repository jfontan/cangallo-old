
require 'json'
require 'systemu'
require 'tempfile'
require 'fileutils'

module Cangallo

  class Qcow2
    attr_reader :path

    def initialize(path=nil)
      @path=path
    end

    def info
      res = execute :info, '--output=json', @path

      JSON.parse res
    end

    def compress(destination = nil)
      new_path = destination || @path + '.compressed'

      execute :convert, '-O qcow2', '-c', @path, new_path

      if !destination
        begin
          File.rm @path
          File.mv new_path, @path
        ensure
          File.rm new_path if File.exist? new_path
        end
      else
        @path = new_path
      end
    end

    def sparsify(destination)
      parent = info['backing_file']
      parent_options = ''

      parent_options = "-o backing_file=#{parent}" if parent

      command = "TMPDIR=#{File.dirname(destination)} virt-sparsify #{parent_options} #{@path} #{destination}"
      status, stdout, stderr = systemu command
    end

    def rebase(new_base)
      execute :rebase, '-u', "-b #{new_base}", @path
    end

    def execute(command, *params)
      self.class.execute(command, params)
    end

    def self.execute(command, *params)
      command = "qemu-img #{command} #{params.join(' ')}"
      STDERR.puts command

      status, stdout, stderr = systemu command

      if status.success?
        stdout
      else
        raise stderr
      end
    end

    def self.create_from_base(origin, destination, size=nil)
      cmd = [:create, '-f qcow2', "-o backing_file=#{origin}", destination]
      cmd << size if size

      pp execute(*cmd)
    end

    def self.create(image, parent=nil, size=nil)
      cmd = [:create, '-f qcow2']
      cmd << "-o backing_file=#{parent}" if parent
      cmd << image
      cmd << size if size

      pp execute(*cmd)
    end
  end

end
