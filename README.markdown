Dynamic Image Generator Extension
===========

This extension generates images from text using RMagick for titles and navigations

Inspired by
------------
[Dynamic Text Replacement by Stewart Rosenberger] (http://www.alistapart.com/articles/dynatext)

Dependencies
------------

This extension needs the following gems installed:

* rmagick
* imagesize

Setup
------------

1. Copy the extension directory into your vendor/extensions folder
2. Place a font file in a known directory on your server.
3. Create a folder called "dynamic_images" in public and chmod 755 it
4. Configure default text settings in environment.rb.  Here are some sample settings

`Radiant::Config['image.font'] = "/CenturyGothic-Bold.ttf" # default font path`

`Radiant::Config['image.font.dir'] = "/public/" # font directory`

`Radiant::Config['image.size'] = 28.0 # default font size`

`Radiant::Config['image.spacing'] = 5 # Spacing between words in pixels`

`Radiant::Config['image.color'] = '#8FC757' # Font color

`Radiant::Config['image.cache_path'] = 'public/dynamic_images' # Path to cache the images, don't change this now`

`Radiant::Config['image.background'] = '#0D0D0D' # Background color of the image or 'transparent' for transparent background (may have problems in IE)`

`Radiant::Config['image.image_size'] = '500x300' # Image dimensions; if you specify just width image magick will wrap the text for you`

5. make a rake update
6. insert `<link href="/stylesheets/extensions/dynamic_image/dynamic_image.css" type="text/css" rel="stylesheet">` into your layout


Usage
------------

`<r:image>Text to turn into image</r:image>`

To customize the characteristics of the image you can set attributes in the tag (font, size, spacing, color, background, hovercolor)
For example 
`<r:image size="19">My Text</r:image>`

You can also add HTML attributes which will be passed through,
`<r:image id="my_id">My Text</r:image>`

You can also add it in navigations, see example
`<r:image menu="true" hovercolor="red" size="20" />'

Authors
-------

* Andrew Metcalf
* Roman Simecek

Sponsors
--------

Some work has been kindly sponsored by [ScreenConcept](http://www.screenconcept.ch).

License
-------

This extension is released under the MIT license, see the [LICENSE](master/LICENSE) for more
information.

TODO
-------
* Optimize the image generating process, with some fonts the text is croped