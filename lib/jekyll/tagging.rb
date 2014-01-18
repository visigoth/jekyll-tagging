require 'nuggets/range/quantile'
require 'erb'

module Jekyll

  class PagerFacade
    attr_accessor :liquid

    def initialize(d)
      self.liquid = d
    end

    def to_liquid
      return self.liquid
    end
  end

  class Tagger < Generator

    safe true

    attr_accessor :site

    @types = [:page, :feed]

    class << self; attr_accessor :types, :site; end

    def generate(site)
      self.class.site = self.site = site

      generate_tag_pages
      add_tag_cloud
    end

    private

    # Generates a page per tag and adds them to all the pages of +site+.
    # A <tt>tag_page_layout</tt> have to be defined in your <tt>_config.yml</tt>
    # to use this.
    def generate_tag_pages
      active_tags.each { |tag, posts| new_tag(tag, posts) }
    end

    def generate_page_path(root, idx)
        page_path = "/page/#{idx+1}/"
      if idx == 0
        page_path = "/"
      end
      return "#{root}#{page_path}"
    end

    def generate_page_url_path(type, root_path, idx)
      return generate_page_path(site.config["tag_#{type}_dir"] + "/" + root_path, idx)
    end

    def new_tag(tag, posts)
      posts = posts.sort.reverse!
      self.class.types.each { |type|
        if layout = site.config["tag_#{type}_layout"]
          data = { 'layout' => layout, 'posts' => posts }

          name = yield data if block_given?
          root_path = "#{name || tag}"

          if type == :page
            if site.config["paginate"]
              slice_count = site.config["paginate"]
              paged_posts = posts.each_slice(slice_count).to_a
              paged_posts.each_index do |idx|

                data = { 'layout' => layout, 'posts' => paged_posts[idx] }

                paginator = {
                  'page' => idx+1,
                  'per_page' => slice_count,
                  'posts' => paged_posts[idx],
                  'total_posts' => posts.count,
                  'total_pages' => paged_posts.count,
                  'previous_page' => (idx == 0) ? nil : idx,
                  'previous_page_path' => (idx == 0) ? nil : generate_page_url_path(type, root_path, idx-1),
                  'next_page' => (idx+1 == paged_posts.count) ? nil : idx+1,
                  'next_page_path' => (idx+1 == paged_posts.count) ? nil : generate_page_url_path(type, root_path, idx+1)
                }
                page_path = generate_page_path(root_path, idx)

                tagpage = TagPage.new(
                  site, site.source, site.config["tag_page_dir"],
                  "#{page_path}", data
                )
                tagpage.pager = PagerFacade.new(paginator)
                site.pages << tagpage
              end
            else
              site.pages << TagPage.new(
                site, site.source, site.config["tag_#{type}_dir"],
                "#{root_path}#{site.layouts[data['layout']].ext}", data
              )
            end
          else
            site.pages << TagPage.new(
              site, site.source, site.config["tag_#{type}_dir"],
              "#{root_path}#{site.layouts[data['layout']].ext}", data
            )
          end
        end
      }
    end

    def add_tag_cloud(num = 5, name = 'tag_data')
      s, t = site, { name => calculate_tag_cloud(num) }
      s.respond_to?(:add_payload) ? s.add_payload(t) : s.config.update(t)
    end

    # Calculates the css class of every tag for a tag cloud. The possible
    # classes are: set-1..set-5.
    #
    # [[<TAG>, <CLASS>], ...]
    def calculate_tag_cloud(num = 5)
      tags = active_tags.map { |tag, posts|
        [tag.to_s, posts.size]
      }

      tags.sort!{|a,b| b[1] <=> a[1]}
    end

    def active_tags
      return site.tags unless site.config["ignored_tags"]
      site.tags.reject { |t| site.config["ignored_tags"].include? t[0] }
    end

  end

  class TagPage < Page

    def initialize(site, base, dir, name, data = {})
      self.content = data.delete('content') || ''
      self.data    = data

      super(site, base, dir[-1, 1] == '/' ? dir : '/' + dir, name)

      data['tag'] ||= basename
    end

    def read_yaml(*)
      # Do nothing
    end

  end

  module Filters

    def tag_cloud(site)
      active_tag_data.map { |tag, size|
        tag_link(tag, tag_url(tag), size)
      }.join(' ')
    end

    def tag_link(tag, url = tag_url(tag), size)
      if size
        %Q{<li><a href="#{url}">##{tag} (#{size})</a></li>}
      else
        %Q{<li><a href="#{url}">##{tag}</a></li>}
      end
    end

    def tag_url(tag, type = :page, site = Tagger.site)
      url = File.join('', site.config["tag_#{type}_dir"], ERB::Util.u(tag))
      site.permalink_style == :pretty ? url : url << '.html'
    end

    def tags(obj)
      tags = obj['tags'].dup
      tags.map! { |t| t.first } if tags.first.is_a?(Array)
      tags.map! { |t| tag_link(t, tag_url(t), nil) if t.is_a?(String) }.compact!
      tags.join(' ')
    end

    def active_tag_data(site = Tagger.site)
      return site.config['tag_data'] unless site.config["ignored_tags"]
      site.config["tag_data"].reject { |tag, set| site.config["ignored_tags"].include? tag }
    end
  end

end
