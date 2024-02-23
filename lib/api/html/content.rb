# frozen_string_literal: true

#
# Copyright (C) 2014 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require "nokogiri"

module Api
  module Html
    class UnparsableContentError < StandardError; end

    class Content
      def self.process_incoming(html, host: nil, port: nil)
        return html unless html.present?

        content = new(html, host:, port:)

        content.validate_is_parsable!

        # shortcut html documents that definitely don't have anything we're interested in
        return html unless content.might_need_modification?

        content.modified_html
      end

      def self.rewrite_outgoing(html, account, url_helper, include_mobile: false, rewrite_api_urls: true)
        return html if html.blank?

        new(html, account, include_mobile:, rewrite_api_urls:)
          .rewritten_html(url_helper)
      end

      attr_reader :html

      class << self
        def apply_mathml(node)
          equation = node["data-equation-content"] || node["alt"]
          mathml = UserContent.latex_to_mathml(equation)
          return if mathml.blank?

          # NOTE: we use "x-canvaslms-safe-mathml" instead of just "data-mathml"
          # because canvas_sanitize will strip it out on the way in but it won't
          # strip out data-mathml. This means we can guarantee that there is never
          # user input in x-canvaslms-safe-mathml and we can safely pass it to
          # $el.html() in translateMathmlForScreenreaders in the js in the frontend
          node["x-canvaslms-safe-mathml"] = mathml
        end
      end

      def initialize(html_string, account = nil, include_mobile: false, rewrite_api_urls: true, host: nil, port: nil)
        @account = account
        @html = html_string
        @include_mobile = include_mobile
        @rewrite_api_urls = rewrite_api_urls
        @host = host
        @port = port
      end

      def might_need_modification?
        !!(html =~ %r{verifier=|['"]/files|instructure_inline_media_comment}) ||
          !!(@host && html.include?(@host))
      end

      # Take incoming html from a user or similar and modify it for safe storage and display
      def modified_html
        parsed_html.search("*").each do |node|
          scrub_links!(node)
        end

        # translate audio and video tags generated by media comments back into anchor tags
        # try to add the relevant attributes to media comment anchor tags to retain MediaObject info
        parsed_html.css("audio.instructure_inline_media_comment, video.instructure_inline_media_comment, a.instructure_inline_media_comment").each do |node|
          tag = Html::MediaTag.new(node, parsed_html)
          next unless tag.has_media_comment?

          node.replace(tag.as_anchor_node)
        end

        parsed_html.to_s
      end

      # a hash of allowed html attributes that represent urls, like { 'a' => ['href'], 'img' => ['src'] }
      # we used to use CanvasSanitize::SANITIZE[:protocols] but using that full
      # list is SLOW, and we don't care about most of them.
      URL_ATTRIBUTES = {
        "a" => ["href"].freeze,
        "img" => ["src"].freeze,
        "object" => ["data"].freeze, # needed?
        "embed" => ["src"].freeze, # needed?
        "iframe" => ["src"].freeze, # needed?
        "source" => ["srcset"].freeze, # needed?
      }.freeze

      # rewrite HTML being sent out to an API request to make sure
      # it has all necessary media elements and full URLs for later usage
      def rewritten_html(url_helper)
        # translate media comments into html5 video tags
        parsed_html.css("a.instructure_inline_media_comment").each do |anchor|
          tag = Html::MediaTag.new(anchor, parsed_html)
          next unless tag.has_media_comment?

          anchor.replace(tag.as_html5_node(url_helper))
        end

        UserContent.find_user_content(parsed_html) do |node, uc|
          apply_user_content_attributes(node, uc)
        end

        UserContent.find_equation_images(parsed_html) do |node|
          apply_mathml(node)
        end

        if @rewrite_api_urls || @rewrite_api_urls.nil?
          URL_ATTRIBUTES.each do |tag, attributes|
            parsed_html.css(tag).each do |element|
              url_helper.rewrite_api_urls(element, attributes)
            end
          end
        end

        add_css_and_js_overrides
        parsed_html.to_s
      end

      def add_css_and_js_overrides
        return parsed_html unless @include_mobile
        return parsed_html unless @account&.effective_brand_config

        overrides = @account.effective_brand_config.css_and_js_overrides
        self.class.add_overrides_to_html(parsed_html, overrides)

        parsed_html
      end

      def validate_is_parsable!
        # Make Nokogiri attempt to parse the HTML.
        # A failure to parse will result in a raised error
        parsed_html
      rescue ArgumentError => e
        raise UnparsableContentError, e.message
      end

      def self.add_overrides_to_html(parsed_html, overrides)
        if (mobile_css_overrides = overrides[:mobile_css_overrides])
          mobile_css_overrides.reverse_each do |url|
            tag = parsed_html.document.create_element("link", rel: "stylesheet", href: url)
            parsed_html.prepend_child(tag)
          end
        end
        if (mobile_js_overrides = overrides[:mobile_js_overrides])
          mobile_js_overrides.each do |url|
            tag = parsed_html.document.create_element("script", src: url)
            parsed_html.add_child(tag)
          end
        end
      end

      private

      APPLICABLE_ATTRS = %w[href src].freeze

      def scrub_links!(node)
        APPLICABLE_ATTRS.each do |attr|
          if (link = node[attr])
            node[attr] = corrected_link(link)
          end
        end
      end

      def corrected_link(link)
        Html::Link.new(link, host: @host, port: @port).to_corrected_s
      end

      def parsed_html
        @parsed_html ||= Nokogiri::HTML5.fragment(html, nil, **CanvasSanitize::SANITIZE[:parser_options])
      end

      def apply_user_content_attributes(node, user_content)
        node["class"] = "instructure_user_content #{node["class"]}"
        node["data-uc_width"] = user_content.width
        node["data-uc_height"] = user_content.height
        node["data-uc_snippet"] = user_content.node_string
        node["data-uc_sig"] = user_content.node_hmac
      end

      def apply_mathml(node)
        self.class.apply_mathml(node)
      end
    end
  end
end
