require "RMagick"
require 'digest/md5'
module DynamicImage
  include Radiant::Taggable

    desc %{
    *Usage*:

    <pre><code><r:image>...</r:image></code></pre>
    }
  tag "image" do |tag|
    unless(tag.attr['menu'])
      text = tag.expand # Get the text contained in the tag
      url = '#'
    else
      text = tag.render('title')
      url = tag.render('url')
    end
    config = tag.attr # Get tag attributes
    filename = getImage(text, config) # Get the image filename, attributes are deleted once used
#    if(not tag.attr['alt'])
#      tag.attr['alt'] = text
#    end

    # remove the unbidden tags for the output
    tag.attr.delete('hovercolor') if (tag.attr['hovercolor'])
    tag.attr.delete('menu') if (tag.attr['menu'])

    attributes = tag.attr.inject([]){ |a,(k,v)| a << %{#{k}="#{v}"} }.join(" ").strip # Remaining attributes are passed through to HTML
    
    %{<a href="#{url}" class="dynamic_image_extension" style="display:block;width:200px;height:100%;background-image:url(/dynamic_images/#{filename});"><span style="visibility:hidden">#{text}</span></a>}
    #<img src="/dynamic_images/#{filename}" #{attributes + " " unless attributes.empty?} border="0" />
  end

  def cache?
    false
  end

  def getImage(text, config)
    unless(config['font'])
      config['font'] = Radiant::Config['image.font']
    else
       tmp1 = Radiant::Config['image.font.dir']
       tmp2 = config['font']
       config['font'] = tmp1 + tmp2
    end
    config['size'] ||= Radiant::Config['image.size']
    config['size'] = config['size'].to_f
    config['cache'] ||= true
    config['background'] ||= Radiant::Config['image.background']
    config['spacing'] ||= Radiant::Config['image.spacing']
    config['spacing'] = config['spacing'].to_f
    if(config['color'])
      config['color'] = config['color'].split(',')
    else
      config['color'] = Radiant::Config['image.color'].split(',')
    end
    cache_path =  Radiant::Config['image.cache_path']

    text = cleanText(text)
    words = text.split(/[\s]/)
    image_name = getHashFile(text, config)
    image_path = File.join(cache_path, image_name)

    # Generate the image if not using cache
    if(not config['cache'] or not File.exists?(image_path))
      # Generate the image list
      canvas = Magick::ImageList.new

      # Generate the draw object with the font parameters
      draw = Magick::Draw.new
      draw.stroke = 'transparent'
      draw.font = config['font']
      draw.pointsize = config['size']

      # Generate a temporary image for use with metrics and find metrics
      tmp = Magick::Image.new(100,100)
      metrics = draw.get_type_metrics(tmp, text)

      unless(config['hovercolor'])
        height = metrics.height
      else
        height = metrics.height*2
      end
      # Generate the image of the appropriate size
      canvas.new_image(metrics.width,height){
        self.background_color = config['background']
      }
      # Iterate over each of the words and generate the appropriate annotation
      # Alternate colors for each word

      x_pos = 0;
      count = 0;
      words.each do |word|
        draw.fill = config['color'][(count % config['color'].length)]
        draw.annotate(canvas,0,0,x_pos,metrics.ascent,word)
        draw.annotate(canvas,0,0,x_pos,metrics.ascent+height/2,word) {
            self.fill = config['hovercolor']
        } if (config['hovercolor'])

        metrics = draw.get_type_metrics(tmp, word)
        x_pos = x_pos + metrics.width + config['spacing']
        count = count + 1;
      end

      # Write the file
      canvas.write(image_path)
    end

    # Delete configuration parameters
    config.delete('font')
    config.delete('size')
    config.delete('cache')
    config.delete('background')
    config.delete('spacing')
    config.delete('color')
    config.delete('hovercolor')

    return image_name
  end

  def getHashFile(text, config)
    hash = Digest::MD5.hexdigest(
      text+config['font'].to_s+config['size'].to_s+config['background'].to_s+
        config['spacing'].to_s+config['color'].join+config['hovercolor'].to_s+config['menu'].to_s)
    return hash + ".png"
  end

  def cleanText(text)
    text = javascriptToHtml(text)
  end

  # TODO write replace
  # convert embedded, javascript unicode characters into embedded HTML
  #  entities. (e.g. '%u2018' => '&#8216;'). returns the converted string.
  def javascriptToHtml(text)
    newText = text
    #matches = text.scan(/%u([0-9A-F]{4})/i)
    #matches.each do |match|
    #  text = text.replace()
    #end
    newText
  end

end
