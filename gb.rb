#!/usr/bin/ruby

require 'rubygems'
require 'mechanize'
require 'json'
require 'optparse'
require 'date'

class Site_GB
  def initialize
    @agent = Mechanize.new
    @agent.cookie_jar.load ENV['HOME'] + '/.gb_cookies.yml' rescue puts 'No cookies.yml'
    @agent.user_agent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.80 Safari/537.36'
    @agent.follow_meta_refresh = true

    $coupon = ''
  end

  def save_cookies
    @agent.cookie_jar.save_as ENV['HOME'] + '/.gb_cookies.yml', session: true
  end

  def login username, password
    url = 'https://login.gearbest.com/m-users-a-act_sign.htm'
    params = { 'email' => username, 'password' => password, 'code' => '', 'rem_name' => 1 }
    page = @agent.post(url, params).body
    puts page
    save_cookies
  end

  def logout
    url = 'http://www.gearbest.com/m-users-a-logout.htm'
    puts 'You are now logged out!'
    save_cookies
  end

#https://order.gearbest.com/m-flow-a-checkout.htm?select_goods[]=109133909
#https://order.gearbest.com/m-flow-a-done.htm?PaymentOption=
#method_item_47=88&shipping=49&method_item_49=386&point=&payment=PayPal&postscript=

#<div class="w_col1 fl"><label class="pl20"><input type="radio" class="js_w_item" value="49" checked  data-target-checked="386" name="shipping"> Priority Line  </label></div>
#<div class="w_col1 fl"><label class="sub_lineRadio" si="668"><input type="radio" class="js_w_method_item" name="method_item_49" value="386" >RU Line </label></div>

#    p page.forms.first.checkbox_with(:name => 'select_goods[]').check

  def cart
    url = 'http://cart.gearbest.com/m-flow-a-cart.htm'
    page = @agent.get url
    page.search('dd.js_productCanbuy').each do |item|  
      pcs = item.at('div.t_name').at('input')['value']
      name = item.at('div.t_name').at('a').children
      input_box = item.at('div.t_check').at('input')
      value = input_box['value']
      id = input_box['data-goods_id']
      checked = input_box['checked'].eql?('checked')
      puts "#{checked} #{pcs}pcs ID:#{id} CART:#{value} #{name}"
    end
    puts "Coupon: #{page.at('div.code-input-wrap').at('input')['value']}"
  end

  def set_quantity item, pcs
    url = 'http://cart.gearbest.com/m-flow-a-update_cart.htm'
    params = { 'rid' => item, 'goods_number' => pcs, 'token' => '', 'PayerID' => '' }
    @agent.post(url, params, {'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8'})
  end

  def clear_coupon
    @agent.get 'http://cart.gearbest.com/m-flow-a-clearCoupon.htm'
  end

  def select items
    url = "http://cart.gearbest.com/m-flow-a-cart.htm?"
    page = @agent.get url + $coupon + "checkgoods=#{items[0]}&"+"_=#{DateTime.now.strftime('%Q')}"
    puts page.at('p.apply_msg').children.to_s.lstrip.strip
  end

  def order
    url = 'https://order.gearbest.com/m-flow-a-done.htm?PaymentOption='
    params = { 'method_item_47' => 88, 'shipping' => 49, 'method_item_49' => 386, 'point' => '', 'payment' => 'PayPal', 'postscript' => '' }
    page = @agent.post(url, params, {'Content-Type' => 'application/x-www-form-urlencoded'})
    puts page.body
  end
end

site = Site_GB.new

OptionParser.new do |opts|
  opts.banner = "Usage: gb [options]"
  opts.separator ""
  opts.separator "Specific options:"

  opts.on( '-s', '--select item1[,item2,etc]', Array, 'Select items' ) do |items|
    site.select items
  end

  opts.on( '-p', '--coupon code', String, 'Add coupon' ) do |coupon|
    $coupon = "pcode=#{coupon}&"
  end

  opts.on( '-q', '--quantity item_id,pcs', Array, 'quantity' ) do |item|
    site.set_quantity item[0], item[1]
  end

  opts.on( '-r', '--clear_coupon', 'Clear coupon' ) do
    site.clear_coupon
  end

  opts.on( '-c', '--cart', 'cart' ) do
    site.cart
  end

  opts.on( '-o', '--order', 'order' ) do
    site.order
  end

  opts.on( '-u', '--logout', 'logout' ) do
    site.logout
  end

  opts.on( '-l', '--login username,password', Array, 'Login' ) do |user|
    username = user[0]
    password = user[1]
    site.login username, password
  end
end.parse!

#site.login
#site.get_token
#site.create_folder 123
#remove_file
#site.save_cookies
