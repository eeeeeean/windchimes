# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  # Returns HTML string of an event or venue description for display in a view.
  def format_description(string)
    sanitize(auto_link(upgrade_br(markdown(string))))
  end

  def markdown(text)
    BlueCloth.new(text, :relaxed => true).to_html
  end

  # Return a HTML string with the BR tags converted to XHTML compliant markup.
  def upgrade_br(content)
    content.gsub('<br>','<br />')
  end

  FLASH_TYPES = [:success, :failure]

  def render_flash
    FLASH_TYPES.map{|type|
      next unless flash[type].present?
      content_tag(:div, :class => "flash #{type} flash_#{type}") do
        "#{type == :failure ? 'ERROR: ' : ''}#{flash[type]}".html_safe
      end
    }.compact.join.html_safe
  end

  def datetime_format(time,format)
    format = format.gsub(/(%[dHImU])/,'*\1')
    time.strftime(format).gsub(/\*0*/,'').html_safe
  end

  def self.source_code_version_raw
    # Return a string describing the source code version being used
    " - Git timestamp: #{`git log -1 --format=format:"%ad" 2>&1`}"
  rescue Errno::ENOENT
    # Fail quietly if that didn't work; we don't want to get in the way.
    ""
  end

  ApplicationController::SOURCE_CODE_VERSION = self.source_code_version_raw

  def source_code_version
    ApplicationController::SOURCE_CODE_VERSION
  end

  # returns html markup with source (if any), imported/created time, and - if modified - modified time
  def datestamp(item)
    stamp = "This item was "
    if item.source.nil?
      stamp << "added directly to #{SETTINGS.name}"
    else
      stamp << "imported from " << link_to(truncate(item.source.name, :length => 40), item.source)
    end
    stamp << " <br />" << content_tag(:strong, normalize_time(item.created_at, :format => :html) )
    if item.updated_at > item.created_at
      stamp << " and last updated <br />" << content_tag(:strong, normalize_time(item.updated_at, :format => :html) )
    end
    stamp << "."
    stamp.html_safe
  end

  # Caches +block+ in view only if the +condition+ is true.
  # http://skionrails.wordpress.com/2008/05/22/conditional-fragment-caching/
  def cache_if(condition, name={}, &block)
    if condition
      cache(name, &block)
    else
      block.call
    end
  end

  # Insert a chunk of +javascript+ into the page, and execute it when the document is ready.
  def insert_javascript(javascript)
    content_for(:javascript_insert) do
      (<<-HERE).html_safe
        <script>
          $(document).ready(function() {
            #{javascript}
          });
        </script>
      HERE
    end
  end

  # Focus cursor on DOM element specified by +xpath_query+ using JavaScript, e.g.:
  #
  #   <% focus_on '#search_field' %>
  def focus_on(xpath_query)
    insert_javascript "$('#{xpath_query}').focus();"
  end

  # Set the first tabindex to DOM element specified by +xpath_query+.
  def tabindex_on(xpath_query)
    #insert_javascript "$('#{xpath_query}')[0].tabindex = 1;"
    #insert_javascript "$('#{xpath_query}')[0].attributes['tabindex'] = 1;"
    # TODO Figure out how to set tabindex, because neither of these work right.
  end

  # Returns a string with safely encoded entities thanks to #h, while preserving any existing HTML entities.
  def cleanse(string)
    return escape_once(string)
  end

  def tag_links_for(model)
    model.tags.map{|tag| tag_link(model.class.name.downcase.to_sym, tag)}.join(', ').html_safe
  end

  def tag_link(type, tag, link_class=nil)
    internal_url = "/#{type.to_s.pluralize}/tag/#{tag.name}"

    link_classes = [link_class, "p-category"]
    link_classes << "external #{tag.machine_tag[:namespace]} #{tag.machine_tag[:predicate]}" if tag.machine_tag[:url]

    link_to escape_once(tag.name), (tag.machine_tag[:url] || internal_url), :class => link_classes.compact.join(' ')
  end

  def subnav_class_for(controller_name, action_name)
    return [
      "#{controller.controller_name}_#{controller.action_name}_subnav",
      controller.controller_name == controller_name && controller.action_name == action_name ?
        "active" :
        nil
    ].compact.join(" ")
  end

  # String name of the mobile preference cookie's name, e.g. "calagator_mobile".
  MOBILE_COOKIE_NAME = "#{SECRETS.session_name}_mobile"

  # Returns mobile stylesheet's :media option, which can be overriden by params or cookies.
  #
  # If user provides a "mobile" param to certain values, rendering will be affected:
  # * "1" forces mobile rendering and saves this preference as a cookie.
  # * "0" forces non-mobile rendering and saves this preference as a cookie.
  # * "-1" forces default rendering and clears any previous prefernece cookie.
  #
  # Example:
  #    stylesheet_link_tag 'mobile', :media => mobile_stylesheet_media("only screen and (max-device-width: 960px)") %>
  def mobile_stylesheet_media(default)
    # TODO Figure out if it's possible to use the same handling for Rails "cookies" and Rspec "request.cookies", which seem to have totaly different behavior and no relationship to each other, which makes testing rather awkward.
    expiration = 1.year.from_now
    cookie = {:expires => expiration}
    cookie_name = MOBILE_COOKIE_NAME

    case params[:mobile]
    when "1", "true", 1, true
      cookies[cookie_name] = cookie.merge(:value => "1")
      request.cookies[cookie_name] = "1"
      return :all
    when "0", "false", 0, false
      cookies[cookie_name] = cookie.merge(:value => "0")
      request.cookies[cookie_name] = "0"
      return false
    when "-1"
      request.cookies.delete(cookie_name)
      cookies.delete(cookie_name)
      return default
    else
      case cookies[cookie_name] || request.cookies[cookie_name]
      when "1"
        return :all
      when "0"
        return false
      else
        return default
      end
    end
  end

  # CGI escape a string-like object. The issue is that CGI::escape fails if used on a RailsXss SafeBuffer: https://github.com/rails/rails_xss/issues/8
  def cgi_escape(data)
    return CGI::escape(data.to_str)
  end
end
