
require 'cangallo/qcow2'
require 'systemu'
require 'fileutils'

module Cangallo

  class Disk
    def initialize(path)
      @path = path
    end

    def info
      qcow2 = Qcow2.new(@path)

      nfo = qcow2.info

      {
        'total_size' => nfo['virtual-size'],
        'size' => nfo['actual-size'],
        'parent' => nfo['backing-filename']
      }
    end

    def sha1(path = nil)
      path ||= @path

      status, stdout, stderr = systemu "sha1sum #{path}"

      stdout.split.first
    end

    def prepare_image(destination, parent = nil)
      qcow2 = Qcow2.new(@path)
      qcow2.copy(destination, :parent => parent)

      qcow2.rebase(File.basename(parent)) if parent

      @path = destination
    end
  end

end
