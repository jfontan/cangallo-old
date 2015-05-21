
require 'json'
require 'fileutils'
require 'securerandom'
require 'open-uri'

module Cangallo

  class Repo
    attr_reader :config, :path

    def initialize(config)
      @config = config
      @path = @config['path']

      read_index
    end

    def read_index
      index_file = metadata_name('index')

      begin
        index_data = nil
        open(index_file) do |f|
          index_data = f.read
        end
        @index = JSON.parse(index_data)
      rescue
        @index = {
          'version' => 0,
          'images'  => {},
          'tags'    => {}
        }
      end
    end

    def metadata_name(name)
      File.join(@path, "#{name}.json")
    end

    def image_path(sha1)
      File.join(@path, "#{sha1}.qcow2")
    end

    def tmp_name(name)
      n = "#{name}.#{Time.now.to_i}"
      File.join(@path, 'tmp', n)
    end

    def copy_tmp(origin)
      name = File.basename(origin)
      tmp = tmp_name(name)

      FileUtils.cp(origin, tmp)

      tmp
    end

    def list
      @index['images'].keys
    end

    def tags
      @index['tags']
    end

    def images
      @index['images']
    end

    def find_image(name)
      keys = @index['images'].keys
      length = name.length

      matches = keys.select {|k| k[0,length] == name }
      sha1 = matches.first

      sha1 = @index['tags'][name] if !sha1

      sha1
    end

    def get(name)
      sha1 = find_image(name)
      data = @index['images'][sha1]

      if data
        Image.new(data, :repo => self)
      else
        nil
      end
    end

    def put(image)
      name = image.sha1

      @index['images'][name] = image.data
      @index['tags'][image.tag] = name if image.tag

      write_index
    end

    def get_index
      begin
        text = File.read(metadata_name('index'))
        index = JSON.parse(text)
      rescue
        index = {}
      end

      index
    end

    def write_index
      text = JSON.pretty_generate @index
      File.open(metadata_name('index'), 'w') do |f|
        f.write(text)
      end
    end

    def rebuild_index
      index = {}
      l = list.map do |i|
        image = get(i)
        index[image.sha1] = image.data
      end
      write_index(index)
    end

    def put_file(path, data = {})
      tmp = tmp_name(path)
      parent = data['parent']
      parent = parent+'.qcow2' if parent

      if data['sha1']
        tmp = path
        name = data['sha1']
        info = {}
      else
        disk = Disk.new(path)
        disk.prepare_image(tmp, parent)

        info = disk.info
        sha1 = info['sha1'] = disk.sha1
        name = sha1
      end

      repo_path = File.join(@path, name+'.qcow2')
      FileUtils.mv(tmp, repo_path)

      info.delete('parent')
      info.merge!(data)

      image=Image.new(info)
      put(image)

      image
    end
  end

  class Image
    attr_reader :data

    def initialize(data, options = {})
      @data = data
    end

    def [](key)
      @data[key]
    end

    def []=(key, value)
      @data[key] = value
    end

    def sha1
      @data['sha1']
    end

    def tag
      @data['tag']
    end
  end

end

