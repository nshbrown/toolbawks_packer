# Copyright (c) 2007 Nathaniel Brown
# Copyright (c) 2007 Scott Becker
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

module ToolbawksPacker
  class Handler
    @@javascript_sources = []
    @@stylesheet_sources = []
    
    # instance methods
    attr_accessor :type, :sources
  
    def initialize(type, package)
      logger.info 'ToolbawksPacker::Handler.initialize(' + type + ')'
      @asset_type = type
      @package = package
      @extension = get_extension
      @root_path = File.join(RAILS_ROOT, 'public')
      @output_path = File.join(RAILS_ROOT, 'public', @asset_type, 'packer')
      @match_regex = @package ? Regexp.new("^toolbawks_#{@package}_[^\.]*\.#{@extension}$") : Regexp.new("^toolbawks_[^_]*_[^\.]*\.#{@extension}$")
      @match_all_regex = Regexp.new("^toolbawks_[^\.]*\.#{@extension}$")
      
      create_output_path
    end
    
    def create_output_path
      begin
        Dir.open(@output_path)
      rescue
        Dir.mkdir(@output_path)
        logger.info 'ToolbawksPacker::Handler.create_output_path -> created output directory'
      end
    end
  
    def build
      if use_cache?
        # return the file name
        logger.info 'ToolbawksPacker::Handler.build -> use cached build'
        packed_file_name
      else
        # build a new file and return the file name
        logger.info 'ToolbawksPacker::Handler.build -> create a new build'
        clear_cache
        create_new_build
      end
    end
    
    def self.reset!
      @@javascript_sources = []
      @@stylesheet_sources = []
    end
    
    def use_cache?
      if File.exists?(File.join(@output_path, packed_file_name))
        return true
      end
    end
    
    def clear_cache
      Dir.new(@output_path).entries.delete_if { |x| ! (x =~ @match_regex) }.each do |x|
        File.delete("#{@output_path}/#{x}")
        logger.info 'ToolbawksPacker::Handler.clear_cache -> Removing old cache file: ' + "#{@output_path}/#{x}"
      end
    end
    
    def self.add_source(type, source)
      logger.info 'ToolbawksPacker::Handler.add_source -> Adding file: ' + source
      source = source.gsub(/\w+:\/\/[^\/]+\//, '')
      logger.info 'ToolbawksPacker::Handler.add_source -> Adding file (cleaned): ' + source
      case type
        when 'javascripts'
          @@javascript_sources << source
        when 'stylesheets'
          @@stylesheet_sources << source
      end
    end
  
    def self.delete_all_builds
      logger.info 'ToolbawksPacker::Handler.delete_all_builds -> Removing all packed files'
      ['stylesheets', 'javascripts'].each { |type| self.new(type, 'all').delete_all }
    end

    def delete_all
      Dir.new(@output_path).entries.delete_if { |x| ! (x =~ @match_all_regex) }.each do |x|
        _file_path = File.join(@output_path, x)
        File.delete(_file_path)
        logger.info 'ToolbawksPacker::Handler.delete_all -> Deleted file: ' + _file_path
      end
    end
  
    private
      def sources
        case @asset_type
          when 'javascripts'
            return @@javascript_sources
          when 'stylesheets'
            return @@stylesheet_sources
          else
            logger.info 'ToolbawksPacker::Handler.sources -> no asset type configured'
            return []
        end
      end
      
      def packed_revision
        # go through all the sources, and compile a md5 hash of all the file revisions into a master number
        revision_string = sources.sort.inject([]) { |list, source|
          list << "#{source.sub(".#{@extension}", '')}.#{file_revision(source)}"
        }.join(':')

        Digest::MD5.hexdigest(revision_string)
      end
  
      def file_revision(path)
        path = File.join(@root_path, path)
        if File.exists?(path)
          File.mtime(path).to_i
        else
          0
        end
      end
      
      def packed_file_name
        "toolbawks_#{@package}_#{packed_revision}.#{@extension}"
      end

      def create_new_build
        file_name = packed_file_name
        
        if File.exists?("#{@output_path}/#{file_name}")
          logger.info "Latest version already exists: #{@output_path}/#{file_name}"
        else
          File.open("#{@output_path}/#{file_name}", "w") {|f| f.write(compressed_file) }
          logger.info "Created #{@output_path}/#{file_name}"
        end
        
        file_name
      end
      
      def merged_file
        merged_file = ""
        sources.each { |s| 
          _file_name = File.join(@root_path, s)
          
          if !File.exists?(_file_name)
            logger.error 'ToolbawksPacker::Handler.merged_file -> file is missing: ' + _file_name
            next
          else
            logger.info 'ToolbawksPacker::Handler.merged_file -> adding file: ' + _file_name
          end
          
          File.open(_file_name, "r") { |f| 
            merged_file += f.read + "\n" 
          }
        }
        merged_file
      end
    
      def compressed_file
        logger.info 'ToolbawksPacker::Handler.compressed_file -> @asset_type : ' + @asset_type
        
        case @asset_type
          when "javascripts" then compress_js(merged_file)
          when "stylesheets" then compress_css(merged_file)
        end
      end

      def compress_js(source)
        jsmin_path = File.dirname(__FILE__)
        
        tmp_path = "#{RAILS_ROOT}/tmp/#{Digest::MD5.hexdigest(source)}_#{file_revision(source)}"
      
        # write out to a temp file
        File.open("#{tmp_path}_uncompressed.js", "w") {|f| f.write(source) }
      
        # compress file with JSMin library
        `ruby #{jsmin_path}/jsmin.rb <#{tmp_path}_uncompressed.js >#{tmp_path}_compressed.js \n`

        # read it back in and trim it
        result = ""
        File.open("#{tmp_path}_compressed.js", "r") { |f| result += f.read.strip }
  
        # delete temp files if they exist
        File.delete("#{tmp_path}_uncompressed.js") if File.exists?("#{tmp_path}_uncompressed.js")
        File.delete("#{tmp_path}_compressed.js") if File.exists?("#{tmp_path}_compressed.js")

        result
      end
  
      def compress_css(source)
        source.gsub!(/\s+/, " ")           # collapse space
        source.gsub!(/\/\*\*(.*?)\*\/ /, "") # remove comments - caution, might want to remove this if using css hacks
        source.gsub!(/\} /, "}\n")         # add line breaks
        source.gsub!(/\n$/, "")            # remove last break
        source.gsub!(/ \{ /, " {")         # trim inside brackets
        source.gsub!(/; \}/, "}")          # trim inside brackets
        source
      end

      def get_extension
        case @asset_type
          when "javascripts" then "js"
          when "stylesheets" then "css"
        end
      end

      def self.build_file_list(path, extension)
        re = Regexp.new(".#{extension}\\z")
        file_list = Dir.new(path).entries.delete_if { |x| ! (x =~ re) }.map {|x| x.chomp(".#{extension}")}
        # reverse javascript entries so prototype comes first on a base rails app
        file_list.reverse! if extension == "js"
        file_list
      end
   
  end
end