class DynamicImageExtension < Radiant::Extension
  version "0.2"
  description "This is an extension to dynamically generate images from text for use on your page."
  url "http://github.com/simerom/radiant-dynamic-image-extension/tree/master"
  
  def activate
    Page.class_eval do
      include DynamicImage
    end
  end
  
  def deactivate
  end
end