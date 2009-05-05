require 'RMagick'
require 'digest/md5'
require 'stringio'
require 'image_size'

module DynamicImage

  include Radiant::Taggable

  def cache?
    false
  end

  desc %{
    *Usage*:

    <pre><code><r:image>...</r:image></code></pre>
  }

  tag 'image' do |tag|
    unless(tag.attr['menu'])
      DynamicImage.render_dynamic_image(tag.expand, tag.attr.dup, '#')
    else
      DynamicImage.render_dynamic_image(tag.render('title'), tag.attr.dup, tag.render('url'))
    end
  end

  class << self

    def render_dynamic_image(text, attributes, url)
      attributes.symbolize_keys!
      background_color = attributes[:background] || Radiant::Config['image.background'] || 'transparent'
      attributes[:style] ||= ''
      unless attributes[:style].include?('background-color')
        attributes[:style].strip!
        attributes[:style] += '; ' unless attributes[:style].empty? || attributes[:style][-1, 1] == ';'
        attributes[:style] += "background-color: #{background_color};"
      end
      hover = '_hover' if (attributes[:hovercolor])
      attributes['image.color'] = attributes['color'] if attributes['color']
      attributes[:alt] ||= text
      img_directory = get_image_directory
      filename = get_image(text, attributes, img_directory)
      file = img_directory+filename
      img_size = nil
      File.open(file, 'r') do |fh|
        img_size = ImageSize.new(fh)
      end
      width = attributes[:width]
      width = img_size.get_width.to_f unless (width)
      height = img_size.get_height.to_f
      height = height/2 if(hover)
      directory = check_multisite("dynamic_images")
      # remove the unbidden tags for the output
      attributes.delete(:hovercolor) if (attributes[:hovercolor])
      attributes.delete(:menu) if (attributes[:menu])
      attributes.delete(:width)
      attributes = attributes.inject([]) { |a, (k, v)| a << %Q{ #{k}="#{v}"} }.join(' ').strip
      css_cursor = 'cursor: default' if( url == '#')
      html = %Q{<a alt="#{text}" href="#{url}" class="dynamic_image_extension#{hover}" style="width:#{width}px;height:#{height}px;background-image:url(/#{directory}/#{filename});#{css_cursor};">
                  <span>#{text}</span>
                </a>}
      html
    end

    def check_multisite(directory)
      return directory + "/" + Page.current_site.base_domain if Object.const_defined?(:MultiSiteExtension)
      return directory
    end

    def get_image_directory
      path = RAILS_ROOT+'/'+Radiant::Config['image.cache_path']+'/'
      check_directory(path)
      path = RAILS_ROOT+'/'+Radiant::Config['image.cache_path']+'/'+Page.current_site.base_domain+'/' if Object.const_defined?(:MultiSiteExtension)
      check_directory(path) if Object.const_defined?(:MultiSiteExtension)
      return path
    end

    def check_directory(path)
      Dir.mkdir(path) unless File.exists?(path) && File.directory?(path)
    end

    def get_image(text, config, path)
      text.downcase! if config[:downcase]
      text.upcase! if config[:upcase]
      unless(config[:font])
        config[:font] = Radiant::Config['image.font']
      else
         tmp1 = Radiant::Config['image.font.dir']
         tmp2 = config[:font]
         config[:font] = tmp1 + tmp2
      end
      config[:size] ||= Radiant::Config['image.size']
      config[:size] = config[:size].to_f
      config[:cache] ||= true
      config[:background] ||= Radiant::Config['image.background']
      config[:spacing] ||= Radiant::Config['image.spacing']
      config[:spacing] = config[:spacing].to_f
      config[:color] = (config[:color] || Radiant::Config['image.color']).split(',')
      cache_path = path

      text = clean_text(text)
      words = text.split(/[\s]/)
      image_name = get_hash_file(text, config)
      image_path = File.join(cache_path, image_name)

      # Generate the image if not using cache
      if not config[:cache] or not File.exists?(image_path)
        # Generate the image list
        canvas = Magick::ImageList.new

        # Generate the draw object with the font parameters
        draw = Magick::Draw.new
        draw.stroke = 'transparent'
        draw.font = config[:font]
        draw.pointsize = config[:size]

        # Generate a temporary image for use with metrics and find metrics
        tmp = Magick::Image.new(100, 100)
        metrics = draw.get_type_metrics(tmp, text)

        # Generate the image of the appropriate size
        height = metrics.height
        height = 2 * metrics.ascent if (config[:hovercolor])
        # Workaround so that every font works
        width = metrics.width + metrics.max_advance
        canvas.new_image(width, height) do
          self.background_color = config[:background]
        end
        # Iterate over each of the words and generate the appropriate annotation
        # Alternate colors for each word

        x_pos, count = 0, 0
        words.each do |word|
          draw.fill = config[:color][(count % config[:color].length)]
          draw.annotate(canvas, 0, 0, x_pos, metrics.ascent, word)
          draw.annotate(canvas,0,0,x_pos,metrics.ascent*2,word) do
            self.fill = config[:hovercolor]
          end if (config[:hovercolor])
          metrics = draw.get_type_metrics(tmp, word)
          x_pos += metrics.width + config[:spacing]
          count += 1;
        end

        # Write the file
        canvas.write(image_path)
      end

      # Delete configuration parameters
      [:font, :size, :cache, :background, :spacing, :color, :hovercolor, :menu].each do |param|
        config.delete(param)
      end

      image_name
    end

    def get_hash_file(text, config)
      hash = Digest::MD5.hexdigest(
        text +
        config[:font].to_s +
        config[:size].to_s +
        config[:background].to_s +
        config[:spacing].to_s +
        config[:color].join +
        config[:hovercolor].to_s +
        config[:menu].to_s +
        config[:style].to_s
      ) + ".png"
    end

    def clean_text(text)
      javascript_to_html(text)
    end

    # TODO write replace
    # convert embedded, javascript unicode characters into embedded HTML
    #  entities. (e.g. '%u2018' => '&#8216;'). returns the converted string.
    def javascript_to_html(text)
      new_text = text
      #matches = text.scan(/%u([0-9A-F]{4})/i)
      #matches.each do |match|
      #  text = text.replace()
      #end
      new_text
    end

  end

end
