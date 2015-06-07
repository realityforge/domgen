task :default => :build

desc 'Build site with Jekyll'
task :build do
  sh 'rm -rf _site'
  jekyll
end

desc 'Start server with --watch'
task :server do
  jekyll('serve --watch')
end

def jekyll(opts = '')
  sh "bundle exec jekyll #{opts}"
end
