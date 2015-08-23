require 'yaml'
require 'capybara/poltergeist'

# require 'pry'
# use pry.binding for debugging

hash = YAML.load File.read('credentials.yml')

vk_email = hash['vk_email']
vk_password = hash['vk_password']
instagram_username = hash['instagram_username']
instagram_password = hash['instagram_password']


Capybara.run_server = false
Capybara.default_wait_time = 10
Capybara.register_driver :poltergeist_errorless do |app|
  Capybara::Poltergeist::Driver.new(app, js_errors: false, timeout: 10000, phantomjs_options: 
    [
        '--load-images=no', 
        '--ignore-ssl-errors=yes', 
        '--ssl-protocol=any',
        '--cookies-file=poltergeist-cookies.txt'
    ])
end

session = Capybara::Session.new(:poltergeist_errorless)
session = session
def scr
    session.save_screenshot 'some.jpg'
end

# VK doesn't like old and unknown browsers
session.driver.add_header "User-Agent", 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.120 Safari/537.36'

#
# VK
# 
session.visit 'https://vk.com'

# log in
puts "Logging into VK"
element = session.all('#quick_email').first
if element # unless already logged in
    element.native.send_key(vk_email)
    element = session.find('#quick_pass')
    element.native.send_key(vk_password)
    element = session.find('#quick_login_button')
    element.native.click
end

# get friend links
puts "Loading friends"
session.visit "https://vk.com/friends"
new_friend_count = session.all('.user_block').count
begin # scroll while new friends can be loaded
    old_friend_count = new_friend_count
    session.execute_script("window.document.body.scrollTop = document.body.scrollHeight") 
    sleep(1) # wait for ajax to finish
    new_friend_count = session.all('.user_block').count
    puts "#{new_friend_count} friends..."
end while new_friend_count != old_friend_count
puts "You have #{new_friend_count} friends" 
user_links = session.all('.user_block a.img').map{|a| "https://vk.com#{a[:href]}"}

# visit all friend pages
instagram_links = []
puts "Visiting friend pages"
user_links.each_with_index do |u, i|
    begin 
        session.find('.profile_info_link').click
    rescue Capybara::ElementNotFound => e
    end
    link = session.all('#profile_full_info a').map{|e| e['href']}.select{|h| h.include?('instagram')}
    instagram_links.push link
    puts "#{i+1} / #{user_links.length} - #{u}, links: #{link}"
end
instagram_links.flatten!

# 
# Instagram
#

puts "Logging into instagram"
session.visit('https://instagram.com/accounts/login/')
element = session.all('input[name=username]').first
if element # unless already logged
    element.native.send_key(instagram_username)
    session.find('input[name=password]').native.send_key(instagram_password)
    session.find('form button').click
end

# go through friend instagram links and subscrive
puts "Subscribing to friends"
instagram_links.each_with_index do |link, i|
    session.visit(link)
    subscribe = session.all('.-cx-PRIVATE-IGButton__default').first # this may change
    if subscribe
        subscribe.click
        puts "#{i+1} / #{instagram_links.length} - #{link} - Subscribed!"
    else # already subscribed
        puts "#{i+1} / #{instagram_links.length} - #{link} - Already Subscribed!"
    end
end

puts 'Yay!'