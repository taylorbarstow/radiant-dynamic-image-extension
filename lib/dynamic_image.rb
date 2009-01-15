require "RMagick"
require 'digest/md5'

module DynamicImage
  include Radiant::Taggable

  desc %{
    *Usage*:
  
    <pre><code><r:image>...</r:image></code></pre>
  }
  tag "image" do |tag|
    text = tag.expand # Get the text contained in the tag
    config = tag.attr # Get tag attributes
    filename = get_image(text, config) # Get the image filename, attributes are deleted once used
    tag.attr['alt'] ||= text
    attributes = tag.attr.inject([]) { |a, (k, v)| a << %{#{k}="#{v}"} }.join(' ').strip # Remaining attributes are passed through to HTML
    %{<img src="/dynamic_images/#{filename}" #{attributes + ' ' unless attributes.empty?}/>} # Create the image tag
  end

  def cache?
    false
  end

  def get_image(text, config)
    config['font'] ||= Radiant::Config['image.font']
    config['size'] ||= Radiant::Config['image.size']
    config['size'] = config['size'].to_f
    config['cache'] ||= true
    config['background'] ||= Radiant::Config['image.background']
    config['spacing'] ||= Radiant::Config['image.spacing']
    config['spacing'] = config['spacing'].to_f
    config['color'] = (config['color'] || Radiant::Config['image.color']).split(',')
    cache_path =  Radiant::Config['image.cache_path']
 
    text = clean_text(text)
    words = text.split(/[\s]/)
    image_name = get_hash_file(text, config)
    image_path = File.join(cache_path, image_name)
    
    # Generate the image if not using cache
    if (not config['cache'] or not File.exists?(image_path))
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

      # Generate the image of the appropriate size
      canvas.new_image(metrics.width,metrics.height) {
        self.background_color = config['background']
      }
      # Iterate over each of the words and generate the appropriate annotation
      # Alternate colors for each word
      
      x_pos = 0;
      count = 0;
      words.each do |word|
        draw.fill = config['color'][(count % config['color'].length)]
        draw.annotate(canvas, 0, 0, x_pos, metrics.ascent, word)
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
    
    image_name
  end

  def get_hash_file(text, config)
    Digest::MD5.hexdigest(
      text +
      config['font'].to_s +
      config['size'].to_s +
      config['background'].to_s +
      config['spacing'].to_s +
      config['color'].join
    ) + ".png"
  end

  def clean_text(text)
    text = javascript_to_html(text)
  end

  # TODO write replace
  # convert embedded, javascript unicode characters into embedded HTML
  #  entities. (e.g. '%u2018' => '&#8216;'). returns the converted string.
  def javascript_to_html(text)
    newText = text
    #matches = text.scan(/%u([0-9A-F]{4})/i)
    #matches.each do |match|
    #  text = text.replace()
    #end
    newText
  end
end
