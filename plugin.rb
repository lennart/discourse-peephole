# name: peephole
# about: watch forum as a media channel with a continuously running programme 
# version: 0.0.1
# author: Lennart Melzer

require 'uri'

after_initialize do
  AUDIO_EXTENSIONS = %w{mp3 wav aiff ogg aac m4a}.map{|a| ".#{a}" }.freeze
  IMAGE_EXTENSIONS = %w{png jpg gif jpeg}.map{|a| ".#{a}" }.freeze
  VIDEO_EXTENSIONS  = %w{mp4 mov  ogm mkv ogv avi }.map{|a| ".#{a}" }.freeze
  
  ::ActionController::Base.prepend_view_path File.expand_path("../custom_views", __FILE__)

  module Peephole
    class Medium
      attr_accessor :url
      def initialize(url)
        @url = url
      end
    end

    class Image < Medium
      def render
        "<img src='#{url}'>"
      end
    end

    class Audio < Medium
      def render
        "<audio src='#{url}' controls></audio>"
      end
    end

    class Video < Medium
      def render
        "<video src='#{url}' controls></video>"
      end
    end

    class YouTube < Medium
      def render
        embed_url = url.to_s.gsub(%r{/v/},"/embed/").gsub(%r{/watch\?v=}, "/embed/")
        <<-YOUTUBE
      <iframe width="560" height="315" src="#{embed_url}" 
              frameborder="0" allow="autoplay; encrypted-media" allowfullscreen></iframe>
      YOUTUBE
      end
    end

    class Vimeo < Medium
      def render
        "<iframe src='#{url}'></iframe>"
      end
    end

    class Dummy < Medium
      def render
        "...nothing's on right now"
      end
    end

  end
  
  ListController.class_eval do
    layout "blank", only: :peephole
    def peephole
      @hole = peepholes_for(DateTime.now).first || Peephole::Dummy.new
    end

    private

    def peepholes_for(date)
      @holes = Post.where(updated_at: (date - 2.weeks)..(date + 2.weeks) ).order(:updated_at).pluck(:raw).map do |html|
        html.scan(%r{(?:\[[^\]]*\]\((https?://[^"<\s]+)\)|(https?://[^"<\s]+))}).flatten.compact.map do |url|
          begin
            URI.parse(url)
          rescue URI::InvalidURIError
            URI.parse(URI.escape(url))
          end
        end.map do |url|
          case
          when (url.host =~ /youtube(-nocookie)?.com/)
            Peephole::YouTube.new(url)
          when (url.host =~ /vimeo.com/)
            Peephole::Vimeo.new(url)            
          when (AUDIO_EXTENSIONS.include? File.extname(url.path).downcase)
            Peephole::Audio.new(url)            
          when (VIDEO_EXTENSIONS.include? File.extname(url.path).downcase)
            Peephole::Video.new(url)            
          when (IMAGE_EXTENSIONS.include? File.extname(url.path).downcase)            
            Peephole::Image.new(url)
          end
        end.compact
      end.flatten
    end
  end

  Discourse::Application.routes.prepend do
    get '/raw/peephole' => "list#peephole", format: [:json]
  end
end
