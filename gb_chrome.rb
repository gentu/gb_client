require 'capybara'
require 'selenium-webdriver'
require 'json'
require 'optparse'
require 'optparse/time'
require 'ostruct'

class GB_phantomjs
  def initialize options
    Capybara.register_driver :chrome do |app|
      capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
        chromeOptions: { args: ["user-data-dir=#{ENV['HOME']}/BotChrome/GB"] }
      )
      Capybara::Selenium::Driver.new app, browser: :chrome, desired_capabilities: capabilities
    end
    Capybara.javascript_driver = :chrome
    Capybara.default_max_wait_time = 5

    @session = Capybara::Session.new(:chrome)

    @url_login = 'https://login.gearbest.com/m-users-a-sign.htm?type=1'
    @url_login_info = 'https://www.gearbest.com/fun/?act=info_check&action=1'
    @url_cart = 'https://cart.gearbest.com/m-flow-a-cart.htm'

    @options = options
  end

  def url_login_info
    "#{@url_login_info}&_=#{(Time.now.to_f*1000).to_i}"
  end

  def page type
    case type
    when 'main'
      @session.has_title? /GearBest: Online Shopping - Best Gear at Best Prices/i
    when 'favorites'
      @session.has_title? /My Account - My Favorites | GearBest.com/i
    when 'login'
      @session.has_title? /Sign In | GearBest.com/i
    when 'login_info'
      @session.current_url.include? @url_login_info
    when 'orders'
      @session.has_title? /My Account - My order | GearBest.com/i
    when 'cart'
      @session.has_title? /My Cart | GearBest.com/i
    when 'checkout'
      @session.has_title? /My Cart | GearBest.com/i #&& @session.current_url.include? 'https://order.gearbest.com/m-flow-a-checkout.htm'
    when 'paypal'
      @session.has_title? 'Log in to your PayPal account'
    end
  end

  def page_wait type
    puts type
    until page type
      sleep 0.1
    end
  end

  def login
    @session.visit(url_login_info)
    page_wait 'login_info'
    return true if not (JSON.parse @session.text)['firstname'].empty?
    @session.visit(@url_login)
    page_wait 'login'
    #@session.find('button#js_signInBtn').send_keys(:enter)
    page_wait 'favorites'
  end

  def shipmethod_select
    puts 'shipmethod_select'
    # Method shipping selection
    method = submethod = {}
    @session.all('dd.w_subColItem').each do |ship|
      method[ ship.find('span.w_ColShippingPrice')['orgp'].to_f ] = ship
    end
    method.min.last.find('input.js_w_item').send_keys(:space)
    if method.min.first > 0
      begin
        # Submethod shipping selection
        method.min.last.all('li.clearfix').each do |ship|
          submethod[ ship.find('span.w_subColShippingPrice')['orgp'].to_f ] = ship
        end
        submethod.min.last.find('input.js_w_method_item').send_keys(:space)
      rescue Capybara::ElementNotFound
        puts 'No shipping submethod'
      end
    end
  end

  def price
    c_price = @session.find('div.totalPrice').find('span.my_shop_price')['data-orgp'].to_f
    puts "Current price: #{c_price} Matching price: #{@options.price}"
    c_price > 0 && c_price <= @options.price
  end

  def coupon_or_refresh
    if @options.coupon.empty?
      @session.refresh()
    else
      # coupon apply
      @session.find('input#promotion_code').set @options.coupon
      @session.find('button.applybtn').send_keys(:enter)
    end
  end

  def buy
    timestamp=Time.now
    @session.visit(@url_cart)
    continue
    page_wait 'cart'

    until price
      rand(0.1..1) if (Time.now-timestamp) < 1
      timestamp=Time.now
      coupon_or_refresh if (Time.now.sec+2)%60 < 15
    end

    test?

    # checkout
    @session.find_link('js_checkoutBtn').send_keys(:enter)
    page_wait 'checkout'

    #shipmethod_select

    test?

    # buy
    @session.find('#js_upFormBtn').send_keys(:enter) if not @options.test
    page_wait 'paypal'

    continue
  end

  def test?
    continue if @options.test
  end

  def continue
    puts "Press any key to continue\r"
    gets
  end

  def check_headers
    @session.visit('http://www.xhaus.com/headers')
    p @session.all('td.odd').first.text.to_s
    continue
  end
end

options = OpenStruct.new
options.buy = false
options.coupon = ''
options.test = false

ARGV << '-h' if ARGV.empty?
OptionParser.new do |opts|
  opts.banner = "Usage: gb [options]"
  opts.separator ""
  opts.separator "Specific options:"

  opts.on( '-b', '--buy', 'buy' ) do
    options.buy = true
  end
  opts.on( '-c', '--coupon [COUPON]', String, 'coupon' ) do |coupon|
    options.coupon = coupon
  end
  opts.on( '-p', '--price [DOLLARS]', Float, 'matching price' ) do |price|
    options.price = price
  end
  opts.on( '-t', '--test', 'test' ) do
    options.test = true
  end
end.parse!

# No matching price
raise ArgumentError, 'Please set matching price' if options.price.nil?

#p options
site = GB_phantomjs.new options

p options
site.login
site.buy if options.buy

#  def referer url='https://www.gearbest.com/'
#    @session.driver.add_header 'Referer', url
#  end
#https://www.gearbest.com/fun/?act=info_check&action=1&_=1510159062825
#https://www.gearbest.com/

#  def initialize2
#    Capybara.register_driver :poltergeist do |app|
#      Capybara::Poltergeist::Driver.new(app, :phantomjs_options => ["--cookies-file=#{ENV['HOME']}/gbjs_cookies.txt", "--proxy-type=socks5", "--proxy=127.0.0.1:3333"])
#    end
#    @session = Capybara::Session.new(:poltergeist)
#    @session.driver.headers = {
#      'Connection' => 'keep-alive',
#      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.30 Safari/537.36',
#      'Upgrade-Insecure-Requests' => '1',
#      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
#      'Referer' => 'https://www.gearbest.com/',
#    }
#    @url_login = 'https://login.gearbest.com/m-users-a-sign.htm?type=1'
#  end

