#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra/base'
require 'page'
require 'atom/pub'

class App < Sinatra::Base

  RENDERER = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  PAGES = Page.parse_all(RENDERER)
  PAGE_CACHE = {}

  def cached(name)
    if not PAGE_CACHE.has_key? name
      puts "cache miss for #{name}"
      PAGE_CACHE[name] = yield
    end
    PAGE_CACHE[name]
  end

  helpers do
    def title
      if @page
        return "#{@page['title']} | bugsplat"
      else
        return "bugsplat"
      end
    end

    def link_list
      linked_pages = @pages.find_all { |p| p['order'] != nil }
      links = linked_pages.sort_by { |p| p['order'].to_i }.map do |p|
        "<li><a href=\"/#{p.name}.html\">#{p['title']}</a></li>"
      end
      links.join("\n")
    end
  end

  before do
    @pages = PAGES
  end

  get '/' do
    cached('index') do
      @index_pages = @pages.find_all { |p| p.is_blog_post? }.sort_by { |p| p.date }.reverse[0,5]
      erb :index
    end
  end

  get '/index.html' do
    cached('index') do
      @index_pages = @pages.find_all { |p| p.is_blog_post? }.sort_by { |p| p.date }.reverse[0,5]
      erb :index
    end
  end

  get '/index.xml' do
    cached 'index.xml' do
      @archive_pages = @pages.find_all { |p| p.is_blog_post? }.sort_by { |p| p.date }.reverse
      feed = Atom::Feed.new do |f|
        f.title = 'Bugsplat'
        f.links << Atom::Link.new(:href => 'http://bugsplat.info')
        f.updated = @archive_pages[0].date.to_time
        f.authors << Atom::Person.new(:name => 'Pete Keen', :email => 'pete@bugsplat.info')
  
        @archive_pages.each do |p|
          f.entries << Atom::Entry.new do |e|
            e.title = p['title']
            e.links << Atom::Link.new(:href => "http://bugsplat.info#{ p.html_path }")
            e.id = p['id']
            e.updated = p.date.to_time
            e.content = Atom::Content::Html.new(p.render)
          end
        end
      end
  
      feed.to_xml
    end
  end

  get '/archive.html' do
    cached 'archive' do
      @archive_pages = @pages.find_all { |p| p.is_blog_post? }.sort_by { |p| p.date }.reverse
      erb :archive
    end
  end

  get '/tags.html' do
    cached 'tags' do
      tags = {}
      @pages.each do |page|
        page.tags.each do |tag|
          tags[tag] = true
        end
      end
      @tags = tags.keys.sort
      erb :tags
    end
  end

  get '/tag/:tag' do
    cached "tags:#{params[:tag]}" do
      @tagged_pages = @pages.find_all { |p| p.has_tag params[:tag] }.sort_by{ |p| p.date }.reverse
      @tag_name = params[:tag]
      erb :tagged_pages
    end
  end

  get '/:page_name' do
    @page = @pages.detect { |p| p.matches_path(params[:page_name]) }
    unless @page
      raise Sinatra::NotFound
    end

    if params[:page_name] == @page['id']
      redirect @page.html_path
    end

    cached params[:page_name] do
      erb :entry_page
    end
  end

  post '/ping' do
    'pong'
  end
end
