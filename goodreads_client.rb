#!/usr/bin/env ruby -v

# Some simple methods to manipulate a user's Goodreads library.  An API key is
# needed and OAuth has to be configured for the account. See the Goodreads API
# docs for instructions.

require "rexml/document"
require "oauth"

class GoodreadsClient
  SITE = "http://www.goodreads.com"

  attr_accessor :api_key, :api_key_secret
  attr_accessor :user_id, :oauth_token, :oauth_token_secret

  def initialize(api_key, api_key_secret,
                 user_id, oauth_token, oauth_token_secret)
    @api_key            = api_key
    @api_key_secret     = api_key_secret
    @user_id            = user_id
    @oauth_token        = oauth_token
    @oauth_token_secret = oauth_token_secret
  end

  def consumer
    @consumer ||= OAuth::Consumer.new(api_key, api_key_secret, :site => SITE)
  end

  def access_token
    @access_token ||=
      OAuth::AccessToken.new(consumer, oauth_token, oauth_token_secret)
  end

  def get_book_id_by_isbn(isbn)
    get_with_timeout(build_uri("/book/isbn_to_id",
                               :isbn => isbn,
                               :key  => api_key))
  end

  def get_review_id_for_book(book_id)
    uri = build_uri("/review/show_by_user_and_book.xml",
                    :user_id => user_id,
                    :book_id => book_id,
                    :key     => api_key)

    doc     = REXML::Document.new(get_with_timeout(uri))
    element = REXML::XPath.first(doc, "//review/id")
    element.text if element
  end

  def mark_book_owned(book_id, purchase_date)
    purchase_date = Date.parse(purchase_date) rescue ""
    access_token.post("/owned_books.xml",
                      "owned_book[book_id]"                => book_id,
                      "owned_book[original_purchase_date]" => purchase_date)
  end

  def add_review_for_isbn(isbn, review, read_at, rating)
    book_id = get_book_id_by_isbn(isbn)
    sleep 1
    read_at = Date.parse(read_at) rescue ""
    access_token.post("/review.xml",
                      "book_id"         => book_id,
                      "review[review]"  => review,
                      "review[read_at]" => read_at,
                      "review[rating]"  => rating)
  end

  def update_review_for_book(book_id, review, read_at, rating)
    review_id = get_review_id(book_id)
    sleep 1
    read_at = Date.parse(read_at) rescue ""
    access_token.put("/review/#{review_id}.xml",
                     "review[review]"  => review,
                     "review[read_at]" => read_at,
                     "review[rating]"  => rating)
  end

  private

  def build_uri(path, params={})
    query = params.map { |k, v| "#{k}=#{v}" }.join("&")
    URI.parse("#{SITE}#{path}?#{query}")
  end

  def get_with_timeout(uri)
    Timeout::timeout(10) { Net::HTTP.get(uri) }
  end
end
