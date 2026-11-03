# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "#{ENV['protocol']}://#{ENV['domain']}"

SitemapGenerator::Sitemap.create do
  
  add(root_path, priority: 1)

end
