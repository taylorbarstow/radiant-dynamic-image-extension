require 'RMagick'
require 'digest/md5'
require 'stringio'
require 'image_size'
require 'rvg/rvg'

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
      filename = get_image(text, attributes, img_directory) unless attributes[:fade]
      filename = get_animated_image(text, attributes, img_directory) if attributes[:fade]
      file = img_directory+filename
      img_size = nil
      File.open(file, 'r') do |fh|
        img_size = ImageSize.new(fh)
      end
      width = attributes[:width]
      width = img_size.get_width.to_f unless (width)
      height = img_size.get_height.to_f unless attributes[:height]
      height = height/2 if(hover) unless attributes[:height]
      height = attributes[:height] if attributes[:height]
      directory = check_multisite("dynamic_images")
      # remove the unbidden tags for the output
      attributes.delete(:hovercolor) if (attributes[:hovercolor])
      attributes.delete(:menu) if (attributes[:menu])
      attributes.delete(:width)
      attributes.delete(:height)
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
      row = config[:row]
      cache_path = path
      text = clean_text(text)
      words = text.split(/[\s]/) unless row
      if row
        row = row.to_i
        firstrow = config[:firstrow]
        firstrow = firstrow.to_i
        words = Array.new
        words.push(text[0,firstrow])
        words.push(text[firstrow,text.length].rstrip)
      end
      image_name = get_hash_file(text, config)+".png"
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
        draw.text_antialias(true)
#        draw.font_stretch(Magick::UltraExpandedStretch)
#        draw.font_weight(800)
        # Generate a temporary image for use with metrics and find metrics
        tmp = Magick::Image.new(100, 100)
        metrics = draw.get_type_metrics(tmp, text)
        # Generate the image of the appropriate size
        height = metrics.height
        height = 2 * metrics.ascent if (config[:hovercolor])
        height = height * (row+1) if row
        # Workaround so that every font works
        width = metrics.width + metrics.max_advance

        canvas.new_image(width, height) do
          self.background_color = config[:background]
        end
        
        # Iterate over each of the words and generate the appropriate annotation
        # Alternate colors for each word
        x_pos, count = 0, 0
        if config[:hovercorrection]
          hover_correction = config[:hovercorrection].to_i
        else
          hover_correction = 0
        end

        words.each do |word|
          draw.fill = config[:color][(count % config[:color].length)]
          draw.annotate(canvas, 0, 0, x_pos, metrics.ascent, word)
          draw.annotate(canvas,0,0,x_pos,metrics.ascent*2+hover_correction,word) do
            self.fill = config[:hovercolor]
          end if (config[:hovercolor])
          metrics = draw.get_type_metrics(tmp, word)
          x_pos += metrics.width + config[:spacing]
          count += 1;
        end unless row

        img_height = metrics.ascent+(-1*metrics.descent) if row
        row_count = 1 if row
        if config[:row] and config[:rowcorrection]
          row_correction = config[:rowcorrection].to_i
        else
          row_correction = 0
        end
        
        if config[:toprowcorrection]
          first_row_correction = config[:toprowcorrection].to_i
        else
          first_row_correction = 0
        end

        words.each do |word|
          if count == 0
            row_corr = first_row_correction
          else
            row_corr = row_correction
          end
          draw.fill = config[:color][(count % config[:color].length)]
          draw.annotate(canvas,0,0,0,row_corr+(img_height*row_count), word.rstrip)
          draw.annotate(canvas,0,0,0,row_corr+(img_height*row_count)+(img_height*row)+hover_correction,word.rstrip) do
            self.fill = config[:hovercolor]
          end if (config[:hovercolor])
          metrics = draw.get_type_metrics(tmp, word)
          # x_pos += metrics.width + config[:spacing]
          count += 1;
          row_count += 1;
        end if row

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
        config[:style].to_s +
        config.to_s
      )
    end

    def get_animated_image(text, config, path)
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
      if config[:hovercorrection]
        hover_correction = config[:hovercorrection].to_i
      else
        hover_correction = 0
      end
      if config[:topcorrection]
        top_correction = config[:topcorrection].to_i
      else
        top_correction = 0
      end
      cache_path = path
      text = clean_text(text)
      words = text.split(/[\s]/)
      image_name = get_hash_file(text, config)+".gif"
      image_path = File.join(cache_path, image_name)
      # Generate the image if not using cache
      if not config[:cache] or not File.exists?(image_path)
        tmp = Magick::Image.new(100, 100)
        anim = Magick::ImageList.new
        text_img = Magick::Draw.new
        text_img.gravity = Magick::NorthWestGravity
        text_img.pointsize = config[:size]
        text_img.font = config[:font]
        text_img.text_antialias(true)
        text_img.font_weight = Magick::BoldWeight if config[:bold]
#        text_img.font_style = Magick::ItalicStyle
#        text_img.stroke = 'transparent'
        metrics = text_img.get_type_metrics(tmp, text)
        # Generate the image of the appropriate size
        height = metrics.height
        height = 2 * (metrics.ascent+(-1*metrics.descent)) if (config[:hovercolor])
        # Workaround so that every font works
        width = metrics.width + metrics.max_advance
        ex = Magick::Image.new(width, height)
        ex.background_color = '#FFFFFF'
        text_img.annotate(ex,0,0,0,0+top_correction, text) do
            self.fill = 'transparent'
        end
        anim << ex.copy
        j = 10
        # fade from transparent to black
        for i in (1..9)
          text_img.annotate(ex, 0,0,0,0+top_correction, text) do
              self.fill = 'gray'+j.to_s+'0'
              j=j-1
          end
          if config[:hovercolor]
            text_img.annotate(ex, 0,0,0,height/2+hover_correction+top_correction, text) do
              self.fill = config[:hovercolor]
            end
          else
            text_img.annotate(ex, 0,0,0,height/2+hover_correction+top_correction, text) do
              self.fill = 'black'
            end
          end
          anim << ex.copy
        end
        # the black text
        text_img.annotate(ex, 0,0,0,0+top_correction, text) do
          self.fill = 'black'
        end
        if config[:hovercolor]
          text_img.annotate(ex, 0,0,0,height/2+hover_correction+top_correction, text) do
            self.fill = config[:hovercolor]
          end
        else
          text_img.annotate(ex, 0,0,0,height/2+hover_correction+top_correction, text) do
            self.fill = 'black'
          end
        end
        anim << ex.copy
        # fade from black to grey
        for y in (1..8)
          text_img.annotate(ex, 0,0,0,0+top_correction, text) do
              self.fill = 'gray'+y.to_s+'0'
          end
          if config[:hovercolor]
            text_img.annotate(ex, 0,0,0,height/2+hover_correction+top_correction, text) do
              self.fill = config[:hovercolor]
            end
          else
            text_img.annotate(ex, 0,0,0,height/2+hover_correction+top_correction, text) do
              self.fill = 'black'
            end
          end
          anim << ex.copy
        end
        anim.delay = 20
        if (config[:loop])
          anim.iterations = 0
        elseif(config[:iterations])
          anim.iterations = config[:iterations].to_i
        else
          anim.iterations = 1
        end
        anim.write(image_path)
        # Delete configuration parameters
        [:font, :size, :cache, :background, :spacing, :color, :hovercolor, :menu].each do |param|
          config.delete(param)
        end
      end
      image_name
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
