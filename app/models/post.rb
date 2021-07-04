
require 'nokogiri'

class Post < ActiveRecord::Base

  BASE_POST_FILE_PATH = "../trafficking/backpage/newyork.backpage.com/"
          
  after_initialize :setup_default_data

  def setup_default_data
    self.url = "http://newyork.backpage.com/#{category}/#{slug}/#{post_id}"
    @file_path = "#{BASE_POST_FILE_PATH}#{category}/#{slug}/#{post_id}"
  end

  # Preconditions - the object should be set up and these should be inside it already
  #   file_path
  def parse_file!()
    File.open(@file_path) do |f|
      doc = Nokogiri::HTML(f)
      doc.css('script').each { |node| node.remove }
      doc.css('link').each { |node| node.remove }

      self.title = doc.css("#postingTitle h1").text
      report_nodes = doc.css("#postingTitle h1 a")
      self.report_url = report_nodes.first.attributes['href'].value if report_nodes.count > 0
      self.body = doc.css(".postingBody").text

      self.posted_at = Post.parse_date(doc.css(".adInfo").text) # TODO need to regex out the date from posted:
      if posted_at.blank?
        logger.error "No date found for #{url}"
      end

      posting = doc.css(".posting").text
      self.location = Post.parse_location(posting)
      if self.location.blank?
        logger.error "No location found for #{url}"
      end

      self.age = Post.parse_age(posting)
      if self.age.nil? || self.age == 0
        logger.error "No age found for #{url}"
      end

      self.phone = Post.parse_phone("#{self.title} #{self.body}")
      if self.phone.nil? || self.phone == 0
        logger.warn "No phone found for #{url}"
      end

      self.save
    end
  end

  # TODO parse and save phone
  def self.parse_phone(text)
    text.downcase!
    text.gsub!(/[^a-z0-9]/, "")
    text.gsub!(/\n/, " ")
    phone = try_parse(text)
    if phone.nil?
      text.gsub!(/o/,"0")
      phone = try_parse(text)
    end
    return phone
  end

  def self.try_parse(text)
    m = /(\d{10,13})/.match(text)
    m[1] if m
  end

  def self.parse_date(date_string)
    DateTime.strptime(date_string, "posted: %B %e, %Y, %I:%M %p").to_time if !date_string.blank?
  end
