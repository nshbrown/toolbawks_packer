# Copyright (c) 2007 Nathaniel Brown
# Copyright (c) 2007 Scott Becker
# Copyright (c) 2007 James Adams
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
  module Helper
    
    def toolbawks_packer(package)
      # If we are in production, or have turned the flag to be always on, then include the compiled CSS and JS asset files
      if ToolbawksPacker.enabled
        head = []
        head << toolbawks_stylesheet_link_tag( ToolbawksPacker::Handler.new('stylesheets', package).build )
        head << toolbawks_javascript_include_tag( ToolbawksPacker::Handler.new('javascripts', package).build )
        ToolbawksPacker::Handler.reset!
        return head.join("\n")
      end
    end
    
    def toolbawks_javascript_include_tag(source)
      source = javascript_path(File.join('packer', source))
      logger.info 'toolbawks_javascript_include_tag -> source : ' + source
      content_tag("script", "", { "type" => "text/javascript", "src" => source })
    end
    
    def toolbawks_stylesheet_link_tag(source)
      source = stylesheet_path(File.join('packer', source))
      logger.info 'toolbawks_stylesheet_link_tag -> source : ' + source
      tag("link", { "rel" => "stylesheet", "type" => "text/css", "media" => "screen", "href" => source })
    end

  end
end

# Include the helper into the core of all templates
ActionView::Base.send :include, ToolbawksPacker::Helper

module ToolbawksPacker::RailsExtensions
end

module ToolbawksPacker::RailsExtensions::PublicAssetHelpers
  def self.included(base) #:nodoc:
    base.class_eval do
      [:stylesheet_link_tag, :javascript_include_tag].each do |m|
        alias_method_chain m, :toolbawks_packer_additions
      end
    end
  end
  
  # Adds plugin functionality to Rails' default stylesheet_link_tag method.
  def stylesheet_link_tag_with_toolbawks_packer_additions(*sources)
    if ToolbawksPacker.enabled
      type = 'stylesheets'
      begin
        sources = Engines::RailsExtensions::AssetHelpers.pluginify_sources(type, *sources)
      rescue
        # Engiens are not installed
      end
      sources.pop if sources.last.is_a?(Hash) # Remove the options if they are there
      sources.each { |source| ToolbawksPacker::Handler.add_source(type, stylesheet_path(source).gsub(/\?.*/, '')) }
      return ''
    else
      stylesheet_link_tag_without_toolbawks_packer_additions(*sources)
    end
  end

  # Adds plugin functionality to Rails' default javascript_include_tag method.  
  def javascript_include_tag_with_toolbawks_packer_additions(*sources)
    if ToolbawksPacker.enabled
      type = 'javascripts'
      
      begin
        sources = Engines::RailsExtensions::AssetHelpers.pluginify_sources(type, *sources)
      rescue
        # Engiens are not installed
      end
      
      sources.pop if sources.last.is_a?(Hash) # Remove the options if they are there
      sources.each { |source| ToolbawksPacker::Handler.add_source(type, javascript_path(source).gsub(/\?.*/, '')) }
      return ''
    else
      javascript_include_tag_without_toolbawks_packer_additions(*sources)
    end
  end
end

::ActionView::Helpers::AssetTagHelper.send(:include, ToolbawksPacker::RailsExtensions::PublicAssetHelpers)