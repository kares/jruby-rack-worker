
PROJECT_NAME = 'jruby-rack-worker'

SRC_DIR = 'src'

MAIN_SRC_DIR = File.join(SRC_DIR, 'main/java')
RUBY_SRC_DIR = File.join(SRC_DIR, 'main/ruby')
TEST_SRC_DIR = File.join(SRC_DIR, 'test/java')

OUT_DIR = 'out'

MAIN_BUILD_DIR = File.join(OUT_DIR, 'classes')
TEST_BUILD_DIR = File.join(OUT_DIR, 'test-classes')
TEST_RESULTS_DIR = File.join(OUT_DIR, 'test-results')

LIB_BASE_DIR = 'lib'

unless defined?(JRUBY_VERSION)
  raise "Hey, we're not running within JRuby my dear !"
end

load File.join(RUBY_SRC_DIR, "#{PROJECT_NAME.gsub('-', '/')}", 'version.rb')

def project_version
  JRuby::Rack::Worker::VERSION
end

def out_jar_path
  "#{OUT_DIR}/#{PROJECT_NAME}_#{project_version}.jar"
end

require 'ant'
ant.property :name => "ivy.lib.dir", :value => LIB_BASE_DIR

namespace :ivy do

  ivy_version = '2.1.0'
  ivy_jar_dir = File.join(LIB_BASE_DIR, 'build')
  ivy_jar_file = File.join(ivy_jar_dir, 'ivy.jar')

  task :download do
    mkdir_p ivy_jar_dir
    ant.get :src => "http://repo1.maven.org/maven2/org/apache/ivy/ivy/#{ivy_version}/ivy-#{ivy_version}.jar",
      :dest => ivy_jar_file,
      :usetimestamp => true
  end

  task :install do
    Rake::Task["ivy:download"].invoke unless File.exist?(ivy_jar_file)
    
    ant.path :id => 'ivy.lib.path' do
      fileset :dir => ivy_jar_dir, :includes => '*.jar'
    end
    ant.taskdef :resource => "org/apache/ivy/ant/antlib.xml", :classpathref => "ivy.lib.path"
  end
  
end

task :retrieve => :"ivy:install" do
  ant.retrieve :pattern => "${ivy.lib.dir}/[conf]/[artifact].[type]"
end

ant.path :id => "main.class.path" do
  fileset :dir => LIB_BASE_DIR do
    include :name => 'runtime/*.jar'
  end
end
ant.path :id => "test.class.path" do
  fileset :dir => LIB_BASE_DIR do
    include :name => 'test/*.jar'
  end
end

task :compile => :retrieve do
  mkdir_p MAIN_BUILD_DIR
  ant.javac :destdir => MAIN_BUILD_DIR, :source => '1.5' do
    src :path => MAIN_SRC_DIR
    classpath :refid => "main.class.path"
  end
end

task :copy_resources do
  mkdir_p ruby_dest_dir = File.join(MAIN_BUILD_DIR, '') # 'META-INF/jruby_rack_worker'
  ant.copy :todir => ruby_dest_dir do
    fileset :dir => RUBY_SRC_DIR do
      exclude :name => 'jruby_rack_worker.rb' # exclude :name => 'jruby/**'
    end
  end
end

desc "build jar"
task :jar => [ :compile, :copy_resources ] do
  ant.jar :destfile => out_jar_path, :basedir => MAIN_BUILD_DIR do
    manifest do
      attribute :name => "Built-By", :value => "${user.name}"
      attribute :name => "Implementation-Title", :value => PROJECT_NAME
      attribute :name => "Implementation-Version", :value => project_version
      attribute :name => "Implementation-Vendor", :value => "Karol Bucek"
      attribute :name => "Implementation-Vendor-Id", :value => "org.kares"
    end
  end
end

desc "build gem"
task :gem => [ :jar ] do
  mkdir_p gem_out = File.join(OUT_DIR, 'gem')
  mkdir_p gem_out_lib = File.join(gem_out, 'lib')

  cp FileList["LICENSE", "README.md"], gem_out
  cp out_jar_path, gem_out_lib
  
  if (jars = FileList["#{gem_out_lib}/*.jar"].to_a).size > 1
    abort "too many jars! #{jars.map{ |j| File.basename(j) }.inspect}\nrake clean first"
  end

  ant.copy :todir => gem_out_lib do
    fileset :dir => RUBY_SRC_DIR do
      include :name => '*.rb'
      include :name => 'jruby/**/*.rb'
    end
  end
  
  Dir.chdir(gem_out) do
    rm_f gemspec_file = "#{PROJECT_NAME}.gemspec"
    gem_spec = Gem::Specification.new do |spec|
      spec.name = PROJECT_NAME
      spec.version = project_version
      spec.platform = 'jruby'
      spec.authors = ["Karol Bucek"]
      spec.email = ["self@kares.org"]
      spec.homepage = 'http://github.com/kares/jruby-rack-worker'
      spec.summary = 'Threaded Workers with JRuby-Rack'
      spec.description = 
        "Implements a thread based worker pattern on top of JRuby-Rack. " +
        "Useful if you'd like to run background workers within your (deployed) " + 
        "web-application (concurrently in 'native' threads) instead of using " + 
        "separate daemon processes. " +
        "Provides (thread-safe) implementations for popular worker libraries " + 
        "such as Resque and Delayed::Job, but one can easily write their own " + 
        "'daemon' scripts as well."
      
      spec.add_dependency 'jruby-rack', ">= 1.1.10"
      spec.files = FileList["./**/*"].exclude("*.gem").map{ |f| f.sub(/^\.\//, '') }
      spec.has_rdoc = false
      spec.rubyforge_project = '[none]'
    end
    Gem::Builder.new(gem_spec).build
    File.open(gemspec_file, 'w') {|f| f << gem_spec.to_ruby }
    mv FileList['*.gem'], '..'
  end
end

task :'test:compile' => :compile do
  mkdir_p TEST_BUILD_DIR
  ant.javac :destdir => TEST_BUILD_DIR, :source => '1.5' do
    src :path => TEST_SRC_DIR
    classpath :refid => "main.class.path"
    classpath :refid => "test.class.path"
    classpath { pathelement :path => MAIN_BUILD_DIR }
  end
end

task :'bundler:setup' do
  begin
    require 'bundler/setup'
  rescue LoadError
    puts "Please install Bundler and run `bundle install` to ensure you have all dependencies"
  end
end

namespace :test do
  
  desc "run ruby tests"
  task :ruby do # => :'bundler:setup'
    Rake::Task['jar'].invoke unless File.exists?(out_jar_path)
    test = ENV['TEST'] || File.join("src/test/ruby/**/*_test.rb")
    #test_opts = (ENV['TESTOPTS'] || '').split(' ')
    test_files = FileList[test].map { |path| path.sub('src/test/ruby/', '') }
    ruby "-Isrc/main/ruby:src/test/ruby", "-e #{test_files.inspect}.each { |test| require test }"
  end
  
  desc "run java tests"
  task :java => :'test:compile' do
    mkdir_p TEST_RESULTS_DIR
    ant.junit :fork => true,
              :haltonfailure => false,
              :haltonerror => true,
              :showoutput => true,
              :printsummary => true do

      classpath :refid => "main.class.path"
      classpath :refid => "test.class.path"
      classpath do
        pathelement :path => MAIN_BUILD_DIR
        pathelement :path => TEST_BUILD_DIR
      end

      formatter :type => "xml"

      batchtest :fork => "yes", :todir => TEST_RESULTS_DIR do
        fileset :dir => TEST_SRC_DIR do
          include :name => "**/*Test.java"
        end
      end
    end
  end
  
end

desc "run all tests"
task :test => [ 'test:java', 'test:ruby' ]

desc "clean up"
task :clean do
  rm_rf OUT_DIR
end

task :default => [ :jar ]
