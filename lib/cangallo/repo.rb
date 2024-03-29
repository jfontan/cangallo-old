
# vim:tabstop=2:sw=2:et:

require 'json'
require 'fileutils'
require 'securerandom'
require 'open-uri'
require 'date'

module Cangallo

  class Repo
    attr_reader :config, :path, :index

    def initialize(config)
      @config = config
      @path = @config['path']

      if @config['index']
        @index = @config['index']
      else
        read_index
      end
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
      if tag = image['set_tag']
        if old_image = find_image(tag)
          old_image['set_tag'] = nil
        end

        @index['tags'][image.tag] = name
      end

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
      file_name = File.basename(path)
      tmp = tmp_name(file_name)

      if data['parent']
        parent_img = get(data['parent'])

        if parent_img
          parent = image_path(parent_img.sha1)
          data['parent_tag'] = parent_img.tag if parent_img.tag
          data['parent'] = parent_img.sha1
        else
          # should give error
          parent = nil
          data['parent'] = nil
        end
      else
        parent = nil
      end

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

      info['time'] = DateTime.now

      repo_path = File.join(@path, name+'.qcow2')
      FileUtils.mv(tmp, repo_path)

      info.delete('parent')
      info.merge!(data)

      image=Image.new(info)
      put(image)

      image
    end

    def publish(directory, compress=false)
      new_repo = Cangallo::Repo.new({
        'path' => directory,
        'index' => self.index
      })

      FileUtils.mkdir_p(directory) if !File.directory?(directory)

      new_repo.write_index

      self.list.each do |img|
        origin = self.image_path(img)
        destination = new_repo.image_path(img)
        destionation += ".xz" if compress

        if File.exist?(destination)
          puts "Image #{img} already exists. Skipping"
          next
        end

        if compress
          puts "Compressing #{img}"
          command = "xz -T0 -0vc #{origin} > #{destination}"
        else
          puts "Copying #{img}"
          command = "cp #{origin} #{destination}"
        end

        puts command
        system(command)
      end
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

